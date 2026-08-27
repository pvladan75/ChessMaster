import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/jwt_expiry.dart';

/// Single source of truth for who is signed in.
///
/// Screens used to receive [UserSession] through their constructors, threaded
/// down from main.dart. That works only as long as every screen is reached by
/// a caller holding the session — it breaks for deep links and restored
/// routes, where the router builds a screen with no caller at all. Routes now
/// read the session from here instead.
/// Whether a connection was refused because of *this device's token*, rather
/// than for any of the ordinary reasons a socket does not connect.
///
/// The backend's socket middleware answers `Invalid or expired authentication
/// token` and nothing else does, so the match is on that sentence rather than
/// on the word "error". A server that is simply down produces `websocket error`
/// or a timeout, and must never sign anybody out: "I could not reach it" is not
/// "you are out", which is the distinction the whole session guard rests on.
bool looksLikeRefusedToken(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  return text.contains('authentication token') ||
      text.contains('jwt expired') ||
      text.contains('token expired');
}

class SessionService extends ChangeNotifier {
  SessionService._();
  static final SessionService instance = SessionService._();

  UserSession _current = UserSession.guest();

  UserSession get current => _current;
  bool get isSignedIn => !_current.isGuest;

  /// The address the last remembered sign-in used, for prefilling the form.
  ///
  /// Kept when the session is dropped, unlike the token beside it: signing out
  /// says "not right now", not "forget who I am", and the alternative is
  /// retyping an address the device already knows. **The password is not kept
  /// here and must not be** — that belongs to the platform's password manager,
  /// which is what the autofill hints on the login form are for. This file
  /// writes to `SharedPreferences`, which on Windows is a plain XML file in the
  /// user's profile.
  String? _lastEmail;
  String? get lastEmail => _lastEmail;

  /// Why the session ended without anybody signing out, when it did.
  ///
  /// `'expired'` — the token ran out, or the server refused it. `'account-gone'`
  /// — the account behind it is not there any more. Two answers rather than
  /// one, because they need opposite things from the person: the first is
  /// waiting for the same user to sign in again, the second has nobody to sign
  /// in as.
  ///
  /// The app used to have neither. A refused token left the session sitting
  /// there looking valid: the banner said *"Prijava je istekla"* while the app
  /// still greeted the user by name, and the only way back in was to find
  /// "Odjava" first and sign out of a session the server had already dropped.
  /// Reported live on 22.8.2026.
  String? _expiryReason;
  String? get expiryReason => _expiryReason;
  bool get sessionExpired => _expiryReason != null;

  /// Restores a remembered session at startup. Call before building the app.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final token = prefs.getString('user_token');
    _lastEmail = prefs.getString('last_email');

    // A stored token that is already past its own `exp` is not restored: the
    // app would come up greeting somebody by name, and every request behind
    // that greeting would be refused. Read from the token itself rather than
    // asked over the network, because this has to be decided before the first
    // screen is built and offline is not a reason to trust a dead slip.
    if (rememberMe && token != null && isJwtExpired(token)) {
      _current = UserSession.guest();
      _expiryReason = 'expired';
      await _clearStoredCredentials(prefs);
      notifyListeners();
      return;
    }

    if (rememberMe && token != null && token.isNotEmpty) {
      _current = UserSession(
        token: token,
        id: prefs.getInt('user_id') ?? 0,
        email: prefs.getString('user_email') ?? '',
        name: prefs.getString('user_name') ?? '',
        role: prefs.getString('user_role') ?? 'korisnik',
      );
    } else {
      _current = UserSession.guest();
    }
    notifyListeners();
  }

  /// Adopts [session] as the active one, persisting it when [rememberMe].
  Future<void> signIn(UserSession session, {required bool rememberMe}) async {
    _current = session;
    _expiryReason = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      _lastEmail = session.email;
      await prefs.setString('last_email', session.email);
      await prefs.setBool('remember_me', true);
      await prefs.setString('user_token', session.token);
      await prefs.setInt('user_id', session.id);
      await prefs.setString('user_email', session.email);
      await prefs.setString('user_name', session.name);
      await prefs.setString('user_role', session.role);
    } else {
      await _clearStoredCredentials(prefs);
    }
  }

  /// Drops the session and every stored credential, falling back to guest.
  ///
  /// Deliberately narrower than the old `prefs.clear()`: that also wiped the
  /// user's engine path, board scale, panel layout and Lichess token, which
  /// have nothing to do with being signed in.
  Future<void> signOut() async {
    _current = UserSession.guest();
    _expiryReason = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _clearStoredCredentials(prefs);
  }

  /// Ends the session because the server no longer accepts it.
  ///
  /// The same clearing as [signOut] plus the reason, which is the whole point:
  /// somebody who signed out asked to leave, and somebody whose session expired
  /// did not. The router reads [sessionExpired] and takes them to the login
  /// screen from wherever they are, and the login screen reads [expiryReason]
  /// to say which of the two things happened.
  ///
  /// Idempotent, and quiet when there is nothing to end: three refused requests
  /// arriving together must not be three trips to the login screen, and a guest
  /// has no session to lose.
  Future<void> expire({String reason = 'expired'}) async {
    final nothingLeftToEnd =
        _current.isGuest && (_expiryReason == null || _expiryReason == reason);
    if (nothingLeftToEnd) return;

    _current = UserSession.guest();
    _expiryReason = reason;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _clearStoredCredentials(prefs);
  }

  /// The login screen has shown the reason; stop redirecting there.
  ///
  /// Called after the frame that displays it, not during: this notifies, and a
  /// listener that rebuilds the router mid-build is the kind of thing that
  /// turns one message into a loop. Clearing it here is also what lets somebody
  /// choose "Nastavi kao Gost" from that screen instead of being sent back to
  /// it forever.
  void acknowledgeExpiry() {
    if (_expiryReason == null) return;
    _expiryReason = null;
    notifyListeners();
  }

  /// Ends the session if the token has run out while the app was open.
  ///
  /// Reads the token's own `exp`, so it costs nothing and works with no
  /// network. Called when the app comes back to the foreground — the case this
  /// catches is a phone left on the desk overnight, where nothing else would
  /// ask until the first request of the morning failed.
  Future<void> expireIfTokenRanOut() async {
    if (_current.isGuest) return;
    if (!isJwtExpired(_current.token)) return;
    await expire();
  }

  Future<void> _clearStoredCredentials(SharedPreferences prefs) async {
    await prefs.remove('remember_me');
    await prefs.remove('user_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
  }
}
