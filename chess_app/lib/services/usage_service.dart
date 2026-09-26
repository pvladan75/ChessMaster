import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/billing_service.dart';

/// What one account has used this month, as the server counted it.
///
/// Two answers joined into one: the plan and its monthly limits
/// (`GET /billing/entitlements`) and everything metered without a limit
/// (`GET /billing/usage/me`). The server keeps both per account, not per
/// device, so a phone and a Windows build show the same numbers — and it never
/// sends what any of it costs us, which is our business and not the reader's.
class MonthlyUsage {
  const MonthlyUsage({
    required this.tier,
    required this.periodStart,
    required this.quotas,
    required this.metrics,
    required this.voiceMinutes,
  });

  /// `free`, `premium`, `pro` or `club`, as the server names them.
  final String tier;

  /// The first day of the month the numbers count from, in UTC.
  final DateTime periodStart;

  /// Every metric the plan puts a monthly ceiling on: used and limit, where
  /// a limit of -1 means none.
  final Map<String, QuotaInfo> quotas;

  /// Every raw counter the server holds for the account this month, by its
  /// wire name (`mp4_renders`, `scanned_pages`, `tts_azure_characters`…).
  final Map<String, int> metrics;

  /// Voice in sessions, in whole minutes, as the provider bills it.
  final int voiceMinutes;

  bool get isEmpty => quotas.isEmpty && metrics.isEmpty;
}

/// The server could not say what the account has used.
class UsageUnavailable implements Exception {
  const UsageUnavailable(this.message);
  final String message;
  @override
  String toString() => 'UsageUnavailable: $message';
}

class UsageService {
  UsageService({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final String authToken;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Future<MonthlyUsage> fetch() async {
    final entitlements = await _getJson('/billing/entitlements');
    final own = await _getJson('/billing/usage/me');

    final rawQuotas =
        (entitlements['quotas'] as Map<String, dynamic>?) ?? const {};
    final rawMetrics = (own['metrics'] as Map<String, dynamic>?) ?? const {};

    return MonthlyUsage(
      tier: (entitlements['tier'] ?? 'free').toString(),
      periodStart:
          _periodStart(own['periodStart'] ?? entitlements['periodStart']),
      quotas: rawQuotas.map((key, value) => MapEntry(
          key, QuotaInfo.fromJson(Map<String, dynamic>.from(value as Map)))),
      metrics: {
        for (final entry in rawMetrics.entries)
          if (entry.value is num) entry.key: (entry.value as num).round(),
      },
      voiceMinutes: (own['agoraMinutes'] is num)
          ? (own['agoraMinutes'] as num).round()
          : 0,
    );
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$backendUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw UsageUnavailable('No connection to the server ($path).');
    }
    if (response.statusCode != 200) {
      throw UsageUnavailable(
          'The server answered ${response.statusCode} for $path.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw UsageUnavailable(
          'The server answered something that is not usage.');
    }
    return decoded;
  }

  /// The server's month key, or this month's first day when it sent none —
  /// which it never does, but a screen that throws on a missing date helps
  /// nobody.
  static DateTime _periodStart(dynamic raw) {
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed != null) return parsed.toUtc();
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, 1);
  }
}
