import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

/// What the app actually knows about its link to the backend.
enum ServerStatus {
  /// Not asked yet. Says nothing on screen — silence is honest here.
  unknown,

  /// The server answered and the token still means something.
  online,

  /// Nothing answered. The session on this device may be perfectly good; it
  /// simply cannot do anything right now.
  offline,

  /// The server answered and refused the token. Signed in on the phone, signed
  /// out everywhere that matters.
  expired,
}

/// Tells whether being "signed in" currently means anything.
///
/// A remembered login is restored from the device's own storage, so the app
/// greets someone by name whether or not the backend exists — which is how a
/// trainer sees "Dobrodošli, Vladan" with the server switched off and assumes
/// they are connected. The name proves the phone remembers them, nothing more.
///
/// Kept apart from [SessionService] on purpose: one answers "who is signed in
/// on this device", the other "can that do anything". Conflating them is the
/// mistake being fixed.
class ServerStatusService extends ChangeNotifier {
  ServerStatusService._();
  static final ServerStatusService instance = ServerStatusService._();

  ServerStatus _status = ServerStatus.unknown;
  DateTime? _checkedAt;
  Timer? _retry;
  String? _lastToken;

  ServerStatus get status => _status;
  DateTime? get checkedAt => _checkedAt;

  /// True only when we have actually heard back. `unknown` is not reassurance.
  bool get isOnline => _status == ServerStatus.online;

  /// Whether anything is worth saying to the user about the connection.
  bool get hasProblem =>
      _status == ServerStatus.offline || _status == ServerStatus.expired;

  String get message {
    switch (_status) {
      case ServerStatus.offline:
        return 'Nema veze sa serverom — prijava je zapamćena na uređaju, '
            'ali ništa se ne čuva niti učitava.';
      case ServerStatus.expired:
        return 'Prijava je istekla. Prijavite se ponovo da bi čuvanje radilo.';
      case ServerStatus.online:
      case ServerStatus.unknown:
        return '';
    }
  }

  void reset() {
    _retry?.cancel();
    _retry = null;
    _lastToken = null;
    _status = ServerStatus.unknown;
    _checkedAt = null;
    notifyListeners();
  }

  /// Records that the server just answered something else successfully.
  ///
  /// The socket connecting is proof the backend exists, and a warning that
  /// contradicts traffic already flowing is worse than no warning at all. This
  /// is how a check that happened to land during startup stops being the last
  /// word on the subject.
  void markOnline() {
    _retry?.cancel();
    _retry = null;
    if (_status == ServerStatus.online) return;
    _status = ServerStatus.online;
    _checkedAt = DateTime.now();
    notifyListeners();
  }

  /// Keeps asking while the answer is "no".
  ///
  /// The backend can take the better part of a minute to come up — the database
  /// migrations run against a managed cluster — so a check fired at app start
  /// often lands before the server is listening. Asked once and never again,
  /// that turns a few seconds of starting up into a banner that stays wrong for
  /// the rest of the session.
  void _scheduleRetry() {
    _retry?.cancel();
    final token = _lastToken;
    if (token == null || token.isEmpty) return;
    _retry = Timer(const Duration(seconds: 10), () {
      if (hasProblem) check(token);
    });
  }

  /// Asks the server whether it is there and whether [token] still counts.
  ///
  /// A guest has nothing to check: there is no token to be refused and no
  /// promise being made, so the status stays unknown rather than pretending an
  /// answer.
  Future<ServerStatus> check(String token) async {
    if (token.isEmpty) {
      _status = ServerStatus.unknown;
      notifyListeners();
      return _status;
    }

    _lastToken = token;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/session/check'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _status = ServerStatus.online;
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        _status = ServerStatus.expired;
      } else {
        // Reachable but unhappy — treat as offline rather than claiming a
        // working link on the strength of a 500.
        _status = ServerStatus.offline;
      }
    } catch (e) {
      AppLogger.log('[ServerStatus] Provera veze nije prošla: $e');
      _status = ServerStatus.offline;
    }

    _checkedAt = DateTime.now();
    if (_status == ServerStatus.online) {
      _retry?.cancel();
      _retry = null;
    } else if (_status == ServerStatus.offline) {
      // An expired token will not fix itself; an unreachable server usually does.
      _scheduleRetry();
    }
    notifyListeners();
    return _status;
  }
}
