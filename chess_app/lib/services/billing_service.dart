import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants.dart';
import 'app_logger.dart';

/// What a metered feature costs and how much of it is left this month.
class QuotaInfo {
  final int limit; // -1 means unmetered
  final int used;

  const QuotaInfo({required this.limit, required this.used});

  bool get isUnlimited => limit < 0;
  int get remaining => isUnlimited ? -1 : (limit - used).clamp(0, limit);

  factory QuotaInfo.fromJson(Map<String, dynamic> json) =>
      QuotaInfo(limit: json['limit'] ?? 0, used: json['used'] ?? 0);
}

/// The server's answer to "what is this account allowed to do right now".
///
/// The client never decides this — it only renders it. Every gate also exists on
/// the server, so a stale or tampered copy here changes what the UI shows and
/// nothing else.
class EntitlementState {
  final String tier;
  final Set<String> entitlements;
  final Map<String, QuotaInfo> quotas;

  const EntitlementState({
    required this.tier,
    required this.entitlements,
    required this.quotas,
  });

  static const free = EntitlementState(tier: 'free', entitlements: {}, quotas: {});

  bool get isPaid => tier != 'free';
  bool has(String entitlement) => entitlements.contains(entitlement);
  QuotaInfo? quota(String metric) => quotas[metric];

  factory EntitlementState.fromJson(Map<String, dynamic> json) {
    final rawQuotas = (json['quotas'] as Map<String, dynamic>?) ?? const {};
    return EntitlementState(
      tier: json['tier'] ?? 'free',
      entitlements: ((json['entitlements'] as List?) ?? const []).map((e) => e.toString()).toSet(),
      quotas: rawQuotas.map(
        (key, value) => MapEntry(key, QuotaInfo.fromJson(Map<String, dynamic>.from(value))),
      ),
    );
  }
}

/// Named to match the server's entitlement identifiers.
abstract final class Entitlements {
  static const mp4Export = 'mp4_export';
  static const unlimitedLessons = 'unlimited_lessons';
  static const unlimitedSessions = 'unlimited_sessions';
  static const aiComments = 'ai_comments';
}

enum PurchaseOutcome { success, pending, cancelled, failed, unavailable }

/// Buys subscriptions through Google Play and keeps the app's copy of the
/// account's rights in sync.
///
/// Play is the merchant of record: it takes the payment and pays out, which is
/// what makes this workable for a sole developer in a country Stripe does not
/// serve. It is also mandatory for digital goods on Android.
///
/// The purchase token is never trusted here. It is handed to the backend, which
/// asks Google what it is actually worth before granting anything.
class BillingService {
  BillingService({required this.authToken});

  final String authToken;

  final ValueNotifier<EntitlementState> entitlements = ValueNotifier(EntitlementState.free);
  final ValueNotifier<bool> purchaseInProgress = ValueNotifier(false);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _products = const [];
  List<String> _configuredProductIds = const [];
  bool _storeAvailable = false;

  List<ProductDetails> get products => _products;
  bool get canPurchase => _storeAvailable && _products.isNotEmpty;

  /// Play appends the app name to every product title ("Trener Pro (Chess
  /// Master)"), which reads as a duplicate inside the app itself.
  static String displayTitle(String rawTitle) {
    return rawTitle.replaceFirst(RegExp(r'\s*\([^()]*\)\s*$'), '').trim();
  }

  /// Play Billing only exists on Android; the Windows and Web builds fall back
  /// to showing tier state without a purchase button.
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  /// Loads entitlements, then — on Android — the purchasable products.
  /// Safe to call on every platform; it simply does less where there is no store.
  Future<void> init() async {
    await refreshEntitlements();

    if (!isSupportedPlatform) return;

    try {
      _storeAvailable = await InAppPurchase.instance.isAvailable();
      if (!_storeAvailable) {
        AppLogger.log('[Billing] Play Store nije dostupan na ovom uređaju.');
        return;
      }

      _purchaseSubscription ??= InAppPurchase.instance.purchaseStream.listen(
        _onPurchasesUpdated,
        onError: (Object e) => AppLogger.log('[Billing] Greška u toku kupovine: $e'),
      );

      await _loadProducts();

      // Picks up a subscription bought on another device, or one whose
      // verification did not finish last time.
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      AppLogger.log('[Billing] Inicijalizacija naplate nije uspela: $e');
      _storeAvailable = false;
    }
  }

  Future<void> _loadProducts() async {
    _configuredProductIds = await _fetchConfiguredProductIds();
    if (_configuredProductIds.isEmpty) {
      AppLogger.log('[Billing] Server nije prijavio nijedan proizvod za kupovinu.');
      return;
    }

    final response =
        await InAppPurchase.instance.queryProductDetails(_configuredProductIds.toSet());
    if (response.notFoundIDs.isNotEmpty) {
      // Usually means the product is not yet active in Play Console, or the
      // build's application id does not match the one the products live under.
      AppLogger.log('[Billing] Play ne prepoznaje proizvode: ${response.notFoundIDs.join(', ')}');
    }
    _products = response.productDetails;
  }

  /// Product ids come from the server so a price change never needs an app release.
  Future<List<String>> _fetchConfiguredProductIds() async {
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/billing/config'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['playConfigured'] != true) return const [];
      return ((data['productIds'] as List?) ?? const []).map((e) => e.toString()).toList();
    } catch (e) {
      AppLogger.log('[Billing] Ne mogu da učitam konfiguraciju naplate: $e');
      return const [];
    }
  }

  Future<EntitlementState> refreshEntitlements() async {
    if (authToken.isEmpty) {
      entitlements.value = EntitlementState.free;
      return entitlements.value;
    }

    try {
      final response = await http
          .get(Uri.parse('$backendUrl/billing/entitlements'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        entitlements.value = EntitlementState.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      AppLogger.log('[Billing] Ne mogu da učitam prava pristupa: $e');
    }
    return entitlements.value;
  }

  /// Starts a purchase. The result arrives asynchronously on the purchase
  /// stream, so a `pending` outcome here is normal, not a failure.
  Future<PurchaseOutcome> buy(ProductDetails product) async {
    if (!canPurchase) return PurchaseOutcome.unavailable;

    purchaseInProgress.value = true;
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      return started ? PurchaseOutcome.pending : PurchaseOutcome.failed;
    } catch (e) {
      AppLogger.log('[Billing] Pokretanje kupovine nije uspelo: $e');
      purchaseInProgress.value = false;
      return PurchaseOutcome.failed;
    }
  }

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchaseInProgress.value = true;
          break;

        case PurchaseStatus.error:
          AppLogger.log('[Billing] Kupovina neuspešna: ${purchase.error?.message}');
          purchaseInProgress.value = false;
          break;

        case PurchaseStatus.canceled:
          purchaseInProgress.value = false;
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndComplete(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    final verified = await _verifyWithBackend(purchase);

    // Play must be told the purchase was delivered, otherwise it refunds it
    // after three days. Only skip when our own server rejected it, so an
    // unverified purchase stays open and is retried on the next launch.
    if (verified && purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }

    purchaseInProgress.value = false;
  }

  Future<bool> _verifyWithBackend(PurchaseDetails purchase) async {
    if (authToken.isEmpty) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/billing/play/verify'),
            headers: _headers,
            body: jsonEncode({
              'purchaseToken': purchase.verificationData.serverVerificationData,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        entitlements.value = EntitlementState.fromJson(jsonDecode(response.body));
        AppLogger.log('[Billing] Kupovina potvrđena — nivo: ${entitlements.value.tier}');
        return true;
      }

      final message = _errorMessage(response.body);
      AppLogger.log('[Billing] Server nije potvrdio kupovinu (${response.statusCode}): $message');
      return false;
    } catch (e) {
      AppLogger.log('[Billing] Provera kupovine nije uspela: $e');
      return false;
    }
  }

  String _errorMessage(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    entitlements.dispose();
    purchaseInProgress.dispose();
  }
}
