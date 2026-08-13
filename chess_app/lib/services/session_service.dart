import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';

/// Single source of truth for who is signed in.
///
/// Screens used to receive [UserSession] through their constructors, threaded
/// down from main.dart. That works only as long as every screen is reached by
/// a caller holding the session — it breaks for deep links and restored
/// routes, where the router builds a screen with no caller at all. Routes now
/// read the session from here instead.
class SessionService extends ChangeNotifier {
  SessionService._();
  static final SessionService instance = SessionService._();

  UserSession _current = UserSession.guest();

  UserSession get current => _current;
  bool get isSignedIn => !_current.isGuest;

  /// Restores a remembered session at startup. Call before building the app.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final token = prefs.getString('user_token');

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
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
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
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _clearStoredCredentials(prefs);
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
