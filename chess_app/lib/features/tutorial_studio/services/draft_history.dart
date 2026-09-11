/// The studio's undo and redo — phase 1 of `docs/PLAN-STUDIO-ISTORIJA.md`.
///
/// A list of whole-draft snapshots with a position in it, rather than a list
/// of operations that know how to reverse themselves. Every change in the
/// studio already reaches `_persist()`, and `_persist()` already encodes the
/// whole draft for the on-device slot; keeping those encodings instead of
/// throwing them away is the entire mechanism. An undo is therefore a restore
/// of something that was a complete, valid draft a moment ago — it cannot be
/// half-applied, and no action needs an inverse written for it.
///
/// Pure, with the clock injected, so every rule below is tested without a
/// screen.
///
/// The default is `package:clock`, not `DateTime.now`: the typing merge is
/// decided by time, and inside `testWidgets` only `clock` follows the test's
/// fake time. On the wall clock, a studio test typing six letters merged them
/// only when the machine was idle, and failed under the load of the full suite.
library;

import 'package:clock/clock.dart';

class DraftHistory {
  DraftHistory({
    this.limit = 100,
    this.typingPause = const Duration(milliseconds: 1200),
    DateTime Function()? now,
  }) : _now = now ?? clock.now;

  /// How many changes can be undone. The owner's number, 11.9.2026.
  ///
  /// Measured the same day on the largest tutorial there is — the 40-part,
  /// 200-move render fixture — one step holds a 100 KB snapshot and a 38 KB
  /// content signature, and recording it takes about 2 ms. A full history of
  /// that tutorial is therefore about 14 MB; an ordinary 12-part one is a
  /// quarter of that.
  final int limit;

  /// How long typing may stop before the next keystroke starts a new step.
  ///
  /// One undo removes what was typed before a pause, not one letter: a
  /// sentence is the unit a trainer thinks in, and a hundred steps would be
  /// spent on two sentences otherwise.
  final Duration typingPause;

  final DateTime Function() _now;

  final List<_Step> _steps = [];
  int _at = -1;

  /// True after an undo, and so after any redo, which can only follow one:
  /// typing must then open a new step rather than rewrite the one it landed
  /// on, which is still there to go back to. Only [record] appends a step, and
  /// it clears this, so while it is false the trainer stands on the newest
  /// step. The step [start] makes names no field, so typing never merges into
  /// it either.
  bool _sealed = false;

  bool get canUndo => _at > 0;
  bool get canRedo => _at >= 0 && _at < _steps.length - 1;

  /// The state the history starts from. Nothing before it can be undone.
  void start(String snapshot, String content) {
    _steps
      ..clear()
      ..add(_Step(snapshot, content, null, _now()));
    _at = 0;
  }

  /// The draft as it is now. [content] says what the trainer wrote — see
  /// `TutorialDraft.contentSignature` — and [snapshot] is the whole draft,
  /// cursor included.
  ///
  /// [typingIn] names the text field a change came from, so consecutive
  /// keystrokes in one field become one step.
  void record(String snapshot, String content, {String? typingIn}) {
    if (_at < 0) {
      start(snapshot, content);
      return;
    }

    final here = _steps[_at];
    final now = _now();

    if (content == here.content) {
      // Not an edit — walking the line, choosing another part, a save handing
      // out ids. The step is kept, but with where the trainer now stands, so
      // undoing the *next* change puts them back where they made it.
      _steps[_at] = _Step(snapshot, content, here.typingIn, here.at);
      return;
    }

    final continuesTyping = !_sealed &&
        typingIn != null &&
        here.typingIn == typingIn &&
        now.difference(here.at) < typingPause;
    if (continuesTyping) {
      _steps[_at] = _Step(snapshot, content, typingIn, now);
      return;
    }

    // A new change after an undo starts a new branch: what was undone cannot
    // be redone on top of something it never saw.
    _steps.removeRange(_at + 1, _steps.length);
    _steps.add(_Step(snapshot, content, typingIn, now));
    _at = _steps.length - 1;
    while (_steps.length > limit + 1) {
      _steps.removeAt(0);
      _at--;
    }
    _sealed = false;
  }

  /// The snapshot to go back to, or null when there is none.
  String? undo() {
    if (!canUndo) return null;
    _at--;
    _sealed = true;
    return _steps[_at].snapshot;
  }

  /// The snapshot to go forward to, or null when there is none.
  String? redo() {
    if (!canRedo) return null;
    _at++;
    return _steps[_at].snapshot;
  }
}

class _Step {
  const _Step(this.snapshot, this.content, this.typingIn, this.at);

  final String snapshot;
  final String content;
  final String? typingIn;
  final DateTime at;
}
