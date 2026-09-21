import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/local_puzzle_service.dart';

/// Local state that belongs to the person signed in rather than to the device,
/// and the one place that decides when it stops being theirs.
///
/// **The bug this exists for**, reported live on 18.9.2026 (TODO-provera
/// 177.2): a brand-new account signed in on this workstation and Home offered
/// „Resume analysis" — which opened the *previous* account's tree.
/// [SessionService.signOut] clears the credentials and deliberately nothing
/// else, since the old `prefs.clear()` also wiped the engine path and the board
/// scale; but every service below writes to one unscoped `SharedPreferences`
/// key, so what the last person was doing sat there waiting for the next one.
///
/// **Two categories, and only one of them is cleared.** What is listed here is
/// *scratch*: a draft, a room the app can walk back into, a "do not show me
/// this puzzle again" list. Losing one costs a session, not a piece of work.
/// Deliberately **not** listed, and the reason is that deleting them is not
/// reversible:
///
/// * `local_session_recordings_list` — a recording that has not reached the
///   server yet is the only copy there is. The same rule `chess_backend/
///   uploads/` lives under.
/// * `analysis_studio_puzzle_sets` — sets the user named and kept. A library,
///   not a session.
///
/// Both of those stay visible to the next account on the same device, which is
/// a known and deliberate hole: a thing seen is recoverable, a thing deleted is
/// not.
///
/// **Guest work is adopted, not thrown away.** Analysing without signing in and
/// then signing in carries the tree into the account — that is the same person
/// finishing the same thought, not one account reading another's.
abstract final class AccountLocalState {
  /// `user_id` of whoever this device's scratch state belongs to; `0` is the
  /// guest, absent means a device that has not been through this yet.
  static const String ownerKey = 'local_state_owner';

  static int _epoch = 0;

  /// Which wipe this process is on; it moves every time [clear] runs.
  ///
  /// **The wipe alone was not enough**, and that was reported live on
  /// 20.9.2026, two days after the wipe shipped. Signing out wipes the draft
  /// and *then* the shell is torn down, and the Analysis screen's `dispose`
  /// flushes the tree it still holds — as the guest, whose work the next
  /// sign-in adopts. So a writer takes this number when it is made and hands
  /// it back with every write, and a write from before the last wipe is
  /// dropped ([isCurrent]). Taken at birth, not at write time: at write time
  /// the number is always current, which is the bug.
  static int get epoch => _epoch;

  /// Whether a writer made at [epoch] may still write.
  static bool isCurrent(int epoch) => epoch == _epoch;

  /// Hands the device's scratch state to [userId] (`0` for the guest), wiping
  /// it first when it belonged to a *different* signed-in account.
  ///
  /// Called from the three places a session begins or ends — restore at
  /// startup, sign-in, sign-out/expiry — so there is no fourth door into the
  /// app that skips it.
  static Future<void> syncTo(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getInt(ownerKey);
    final adopt = owner == null || owner == userId || owner == 0;
    if (!adopt) await clear();
    await prefs.setInt(ownerKey, userId);
  }

  /// Wipes every scratch key, through the service that owns each one — the
  /// room code lives in memory as well as in preferences, and a second copy of
  /// its key here is a second copy of the rule.
  ///
  /// Each step is guarded on its own: one service failing must not leave the
  /// rest of the previous account's work on the device.
  static Future<void> clear() async {
    // First, so a write racing the wipe is already on the wrong side of it.
    _epoch++;
    for (final step in <(String, Future<void> Function())>[
      ('analysis draft', AnalysisDraftService.instance.clear),
      ('tutorial draft', TutorialDraftService.instance.clear),
      ('active room', GameSessionService.instance.clear),
      ('solved local puzzles', LocalPuzzleService.instance.forgetSolved),
    ]) {
      try {
        await step.$2();
      } catch (e) {
        AppLogger.log('[AccountLocalState] ❌ ${step.$1} not cleared: $e');
      }
    }
  }
}
