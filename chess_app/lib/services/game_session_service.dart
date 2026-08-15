import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the one live room (if any) the user is currently part of.
///
/// This is distinct from [SessionService], which is about *account* login —
/// this is about a *game room*. A room stays "active" here across navigating
/// away from [ChessGamePage] (back button, going to Home, even an app
/// restart) so the user can find their way back to it; it's only cleared by
/// an explicit "leave" action, never by the widget simply being popped/
/// disposed (see chess_game_screen.dart's AppBar leave action vs. its
/// PopScope back-button handling).
///
/// 'STUDIO' (the solo analysis sandbox room code) never counts as an active
/// session — it has no other participant and never touches the backend.
class GameSessionService extends ChangeNotifier {
  GameSessionService._();
  static final GameSessionService instance = GameSessionService._();

  static const _roomCodeKey = 'active_room_code';
  static const _roleKey = 'active_role';

  String? _roomCode;
  String? _role;

  String? get roomCode => _roomCode;
  String? get role => _role;
  bool get hasActiveSession => _roomCode != null;
  bool isSameSession(String code) => _roomCode == code;

  /// Restores a still-active room at startup. Call before building the app.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _roomCode = prefs.getString(_roomCodeKey);
    _role = prefs.getString(_roleKey);
    notifyListeners();
  }

  /// Marks [roomCode] as the active session, persisting it so it survives
  /// navigation and app restarts. A no-op for the Studio sandbox.
  Future<void> setActive(String roomCode, String role) async {
    if (roomCode == 'STUDIO') return;
    _roomCode = roomCode;
    _role = role;
    _notifyAfterThisFrame();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomCodeKey, roomCode);
    await prefs.setString(_roleKey, role);
  }

  /// Ends the active session. Only ever call this from an explicit "leave"
  /// action — not from screen disposal, which happens for reasons other than
  /// actually leaving (e.g. stepping out to Settings then back).
  Future<void> clear() async {
    _roomCode = null;
    _role = null;
    _notifyAfterThisFrame();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roomCodeKey);
    await prefs.remove(_roleKey);
  }

  /// [setActive]/[clear] can run from a StatefulWidget's initState (e.g.
  /// ChessGamePage marking itself active as soon as it's mounted) — a widget
  /// still further down the *same* build could be a listener (HomeScreen,
  /// still mounted underneath the pushed room route) and calling its
  /// setState synchronously from there is illegal ("setState() or
  /// markNeedsBuild() called during build"). Deferring to after the current
  /// frame finishes sidesteps that.
  void _notifyAfterThisFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}
