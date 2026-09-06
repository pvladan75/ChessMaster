import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/services/app_logger.dart';

/// Keeps a local, always-current copy of the tutorial being written, so closing
/// the screen — deliberately or not — never costs the trainer their work.
///
/// The same shape as `AnalysisDraftService`, deliberately: decision 3 of
/// `docs/PLAN-TUTORIJAL.md` says the tutorial is held in memory and saved once
/// at the end, and „held in memory" is only honest if leaving the screen does
/// not empty it. One slot, on the device, never on the server.
///
/// **P1 moved the working tree inside the draft.** It used to be stored beside
/// it, as a single tree with a path to the node the trainer stood on, because
/// the model could hold only one line at a time. Every part now carries its own
/// tree and its own cursor, so this class stores one object and resolves
/// nothing.
///
/// [TutorialDraft.fromJson] still reads the old shape, so a trainer who
/// upgrades mid-tutorial keeps what they had written.
class TutorialDraftService {
  TutorialDraftService._();
  static final TutorialDraftService instance = TutorialDraftService._();

  static const String _key = 'tutorial_studio_draft';

  Timer? _debounce;

  /// Writes after a short idle delay, so a burst of moves is one write.
  void scheduleSave(TutorialDraft draft) {
    _debounce?.cancel();
    // Snapshot synchronously: the tree keeps mutating while the timer waits.
    final payload = _encode(draft);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      await _write(payload);
    });
  }

  /// Writes now. Called before the screen goes away.
  ///
  /// The debounce is 600 ms, and a trainer who closes the window inside that
  /// half-second closes the process with it — the pending timer never runs, and
  /// the last thing they wrote is the thing they lose. Nothing in a widget test
  /// can see that on its own: there the timer outlives the screen and writes the
  /// same payload a moment later, which is how the gate for this passed with
  /// the flush deleted until it was measured.
  Future<void> flush(TutorialDraft draft) async {
    _debounce?.cancel();
    await _write(_encode(draft));
  }

  Future<TutorialDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final draft = TutorialDraft.fromJson(Map<String, dynamic>.from(decoded));

      // A single bare position with nothing written on it is not a tutorial
      // anybody started; restoring it would put a stale board in front of a
      // trainer who asked for a blank one.
      if (draft.title.trim().isEmpty &&
          draft.sections.length == 1 &&
          draft.sections.single.root.children.isEmpty &&
          draft.sections.single.root.comment.trim().isEmpty) {
        return null;
      }
      return draft;
    } catch (e) {
      AppLogger.log('[TutorialDraft] ❌ Učitavanje nije uspelo: $e');
      return null;
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      AppLogger.log('[TutorialDraft] ❌ Brisanje nije uspelo: $e');
    }
  }

  Future<void> _write(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, payload);
    } catch (e) {
      AppLogger.log('[TutorialDraft] ❌ Čuvanje nije uspelo: $e');
    }
  }

  String _encode(TutorialDraft draft) => jsonEncode({
        ...draft.toJson(),
        'savedAt': DateTime.now().toIso8601String(),
      });
}
