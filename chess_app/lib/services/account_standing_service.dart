import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/session_service.dart';

/// What the server knows about the signed-in account, and what is still
/// missing before it can be used.
///
/// Separate from [UserSession] on purpose: the session says *who* is signed in
/// and is restored from disk, while this says what is still owed and can only
/// come from the server. A remembered token is not a remembered answer.
@immutable
class AccountStanding {
  const AccountStanding({
    required this.ageKnown,
    required this.birthYear,
    required this.age,
    required this.minor,
    required this.ageOfConsent,
    required this.parentConsentRequired,
    required this.parentConsentGiven,
    required this.parentEmailOnFile,
  });

  /// Whether anybody has ever asked. `false` is a real answer and not an
  /// error — until the gate below ran, it was the answer for every account.
  final bool ageKnown;

  final int? birthYear;
  final int? age;

  /// Below the threshold *as stated*. A number anybody can type, so nothing
  /// that actually protects a child rests on it; it decides which flow
  /// somebody goes through.
  final bool minor;

  /// The threshold itself, which is per-country configuration on the server
  /// rather than a constant here. The screen shows the server's number so the
  /// two cannot say different things.
  final int ageOfConsent;

  final bool parentConsentRequired;
  final bool parentConsentGiven;

  /// Whether there is an address to write to at all. Its own field because
  /// "the parent has not answered" and "no parent was ever asked" need
  /// different things from the person reading the screen.
  final bool parentEmailOnFile;

  factory AccountStanding.fromJson(Map<String, dynamic> json) {
    final consent = json['parentConsent'];
    final parent =
        consent is Map ? Map<String, dynamic>.from(consent) : const {};
    return AccountStanding(
      ageKnown: json['ageKnown'] == true,
      birthYear: (json['birthYear'] as num?)?.toInt(),
      age: (json['age'] as num?)?.toInt(),
      minor: json['minor'] == true,
      ageOfConsent: (json['ageOfConsent'] as num?)?.toInt() ?? 16,
      parentConsentRequired: parent['required'] == true,
      parentConsentGiven: parent['given'] == true,
      parentEmailOnFile: parent['parentEmailOnFile'] == true,
    );
  }
}

/// The client half of the age gate.
///
/// Holds one nullable [AccountStanding]. `null` means **the server has not
/// answered yet**, which is deliberately not the same as "adult" and not the
/// same as "unknown age": a client that collapsed those three into two would
/// gate the wrong people and let the rest through, which is the failure this
/// whole area exists to avoid.
class AccountStandingService extends ChangeNotifier {
  AccountStandingService({http.Client? client}) : _client = client;

  static final AccountStandingService instance = AccountStandingService();

  final http.Client? _client;

  AccountStanding? _current;
  AccountStanding? get current => _current;

  /// Whether the app should stop and ask. Only ever true after the server has
  /// said so — never while the answer is still missing, and never for a guest,
  /// who has no account to state anything about.
  bool get mustStateAge =>
      SessionService.instance.isSignedIn && _current?.ageKnown == false;

  /// Asks the server what is missing. Silent on failure by design: an
  /// unreachable server must not turn into a gate the user cannot pass, and
  /// every rule that matters is enforced there rather than here.
  Future<void> refresh() async {
    if (!SessionService.instance.isSignedIn) {
      forget();
      return;
    }
    final res = await _send(() => _get(Uri.parse('$backendUrl/me/standing')));
    if (res.body == null) return;
    _current = AccountStanding.fromJson(res.body!);
    notifyListeners();
  }

  /// States the year of birth. Returns an error to show, or null on success.
  ///
  /// The new standing is read from the server's answer rather than assembled
  /// from what was sent — the same rule the room's guest switch follows, for
  /// the same reason: a value that reports itself can be right on the screen
  /// and wrong in the database.
  Future<String?> stateBirthYear(int year) async {
    final res =
        await _send(() => _post('$backendUrl/me/age', {'birthYear': year}));
    if (res.body == null) {
      return res.error ?? 'Godina nije mogla da se sačuva.';
    }
    // `/me/age` answers with the age, not with the consent block, so the full
    // standing is fetched again. One extra request on a screen shown once.
    await refresh();
    return null;
  }

  /// States the parent's address, and with it sends whatever was waiting on it.
  ///
  /// The server does the sending: a relationship that stopped at "waiting for a
  /// parent" because there was no address is asked about the moment one
  /// arrives. Doing it here would mean the app deciding when a consent letter
  /// goes out, and forgetting the case where the address is added from a
  /// different screen.
  Future<String?> setParentEmail(String email) async {
    final res = await _send(
        () => _post('$backendUrl/me/parent-email', {'parentEmail': email}));
    if (res.body == null) {
      return res.error ?? 'Adresa nije mogla da se sačuva.';
    }
    await refresh();
    return null;
  }

  /// Drops what is known, on sign-out. The next account's standing is the next
  /// account's business.
  void forget() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${SessionService.instance.current.token}',
        'Content-Type': 'application/json',
      };

  Future<http.Response> _get(Uri uri) =>
      _client?.get(uri, headers: _headers) ?? http.get(uri, headers: _headers);

  Future<http.Response> _post(String url, Map<String, dynamic> body) {
    final uri = Uri.parse(url);
    final encoded = jsonEncode(body);
    return _client?.post(uri, headers: _headers, body: encoded) ??
        http.post(uri, headers: _headers, body: encoded);
  }

  Future<({Map<String, dynamic>? body, String? error})> _send(
      Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = res.body.isEmpty ? {} : jsonDecode(res.body);
        return (
          body: decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{},
          error: null,
        );
      }
      AppLogger.log('[Nalog] ⚠️ ${res.statusCode}: ${res.body}');
      return (body: null, error: _errorOf(res));
    } catch (e) {
      AppLogger.log('[Nalog] ❌ $e');
      return (
        body: null,
        error: 'Server nije dostupan — proverite da li backend radi.',
      );
    }
  }

  String _errorOf(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // A body that is not JSON says nothing about why.
    }
    return 'Server je odgovorio ${res.statusCode}.';
  }
}
