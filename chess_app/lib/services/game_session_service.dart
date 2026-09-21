import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'room_session_api.dart';

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

  /// Forgets a saved room that is no longer somewhere to go back to, and says
  /// whether it did.
  ///
  /// The save used to be cleared by the Leave button and by nothing else, so a
  /// room that had ended — or had refused this account — went on blocking every
  /// other room and offering only the way back into itself. Asked of the server
  /// rather than guessed: **an answer that could not be fetched keeps the
  /// session**, because „I could not ask" is not „it is over".
  Future<bool> reconcile(RoomSessionApi api) async {
    final code = _roomCode;
    if (code == null) return false;
    final state = await api.state(code);
    if (state == null || state == RoomState.live) return false;
    // Somebody may have walked into another room while the question was out.
    if (_roomCode != code) return false;
    await clear();
    return true;
  }

  /// Whether the way into a session is clear — [targetRoomCode], or a new one
  /// of the caller's own when it is null. The whole rule, here rather than in
  /// Home so that it can be tested: Home does no network in a widget test.
  ///
  /// A remembered room used to **block** every other one and offer only the way
  /// back into itself, whether or not it was still a session; on 21.9.2026 that
  /// kept the owner in a room from an old invitation while his student waited
  /// in the new one. In order:
  ///
  ///  * nothing saved, or the saved room is the one being entered — clear;
  ///  * the saved room has ended or refuses this account — forgotten, no word;
  ///  * the saved room is **this trainer's own** and they are starting another —
  ///    forgotten without asking, because the server ends it for everybody the
  ///    moment the new one is made, and a question whose answer changes nothing
  ///    is noise;
  ///  * otherwise it is somebody's live session, and [askToLeave] decides.
  Future<bool> makeWayFor({
    required String? targetRoomCode,
    required RoomSessionApi api,
    required Future<bool?> Function(String roomCode) askToLeave,
  }) async {
    if (!hasActiveSession ||
        (targetRoomCode != null && isSameSession(targetRoomCode))) {
      return true;
    }
    if (await reconcile(api)) return true;
    final saved = _roomCode;
    if (saved == null) return true;

    if (targetRoomCode == null && _role == 'trener') {
      await clear();
      return true;
    }
    if (await askToLeave(saved) != true) return false;
    await clear();
    return true;
  }

  /// [clear], but only if [roomCode] is the saved one — for a room reporting
  /// its own end, which must not wipe a different session saved since.
  Future<void> clearIf(String roomCode) async {
    if (_roomCode == roomCode) await clear();
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
