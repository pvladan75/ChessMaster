import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/services/app_logger.dart';

/// Why the app is not speaking, when it is not.
///
/// [off] is the reader's choice; [failed] is a build whose clip bundle is
/// broken (D10 of `docs/PLAN-GOVOR-IZ-KLIPOVA.md`), said with the token's
/// name. There is no third state any more: the voice ships with the app, so
/// „no voice on this machine" cannot happen.
///
/// Until 3.10.2026 a device synthesiser (`flutter_tts`) stood beside the
/// clips, with its own `noVoice` state, a language list, a rate slider and a
/// reading-speed estimate measured sentence by sentence. Every screen speaks
/// from the clips now, and the device voice went with its settings on the
/// owner's word. `git log -S FlutterTtsEngine` finds it.
enum SpeechState { off, ready, failed }

/// Speaks what the screen says, when asked to.
///
/// Deliberately not clever about *what* to say: the caller passes the
/// [SpokenLine] it is already drawing, so the sentence heard and the sentence
/// shown are equal by construction. A second source of truth for the wording
/// would drift from the visible one, and the point of reading it aloud is
/// that the eyes can stay on the board.
class SpeechService extends ChangeNotifier {
  SpeechService._internal();

  static final SpeechService instance = SpeechService._internal();

  /// A service of its own, so a test can hand it a fake [ClipVoice] through
  /// [init] without touching the singleton the screens read.
  @visibleForTesting
  static SpeechService forTesting() => SpeechService.forSubclass();

  /// The same thing, as a constructor, so a test can subclass this and watch
  /// one answer. The only other way in is a private constructor, and a service
  /// nothing can extend means a screen that reads one of its getters has no way
  /// of being asked whether it read it.
  @visibleForTesting
  SpeechService.forSubclass();

  SpeechState _state = SpeechState.off;
  SpeechState get state => _state;

  /// The clips' voice, set by [init].
  ClipVoice? _clipVoice;
  AssetBundle? _clipBundle;

  /// Why [state] is [SpeechState.failed] — it names the token. Null when
  /// there is nothing specific to say.
  String? _failureReason;
  String? get failureReason => _failureReason;

  /// Whether a line would be spoken if asked for now.
  bool canSpeakNow() => _enabled && _state == SpeechState.ready;

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Whether a line is being played right now.
  ///
  /// Asked by anything that moves the board on a timer: a move played under a
  /// sentence that is still being spoken means the listener hears about a
  /// position that is no longer there.
  bool _speaking = false;

  /// True while a line is being said.
  ///
  /// Read by `SpeakableInfo`, whose one control has to mean "stop" while the
  /// voice is running and "say it again" when it is not — a speaker button that
  /// could only start is a button the reader presses to shut it up and is
  /// answered with the sentence a second time.
  bool get speaking => _speaking;
  bool get isSpeaking => _speaking;

  /// Stops [isSpeaking] from sticking when a player never reports that it
  /// finished. A flag that never clears would freeze the walkthrough forever,
  /// which is a far worse bug than a sentence talked over — so the wait has an
  /// end even if the player never says so.
  Timer? _watchdog;

  /// Roughly how long the line can take, generously.
  ///
  /// Measured from words rather than fixed, because "Correct." and a fork
  /// with three replies in it are an order of magnitude apart.
  static Duration _budget(String text) {
    final words = text.split(RegExp(r'\s+')).length;
    final ms = 1500 + words * 600;
    return Duration(milliseconds: ms > 20000 ? 20000 : ms);
  }

  /// What was said last, so the same sentence twice in a row is said once.
  ///
  /// The panel rebuilds for reasons that have nothing to do with its text — a
  /// resize, a chip changing — and every one of those would otherwise start
  /// the sentence again over itself.
  String _lastSpoken = '';

  /// Loads the clips and settles the state.
  ///
  /// The clips are checked against the bundle at start (D10): a missing one
  /// is a broken build, and it is said, with the token's name, rather than
  /// found one sentence at a time.
  Future<void> init({
    required bool enabled,
    ClipVoice? clipVoice,
    AssetBundle? clipBundle,
  }) async {
    _enabled = enabled;
    _failureReason = null;

    final clips = clipVoice ?? _clipVoice ?? ClipVoice();
    _clipVoice = clips;
    _clipBundle = clipBundle ?? _clipBundle;
    try {
      await clips.load(_clipBundle ?? rootBundle);
    } catch (e) {
      _failureReason = e.toString();
      AppLogger.log('[Speech] $_failureReason');
      _state = SpeechState.failed;
      notifyListeners();
      return;
    }

    _state = _enabled ? SpeechState.ready : SpeechState.off;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) await stop();
    if (_state != SpeechState.failed) {
      _state = value ? SpeechState.ready : SpeechState.off;
    }
    notifyListeners();
  }

  /// A line waiting for the current one to finish.
  ///
  /// One slot, not a queue: if two verdicts arrive while a third is being read,
  /// the older of the two is already out of date and nobody wants to hear a
  /// backlog. What must not happen is losing the newest, which is the one that
  /// describes the board as it now stands.
  ({SpokenLine line, Completer<void> done})? _queued;

  /// Says a [SpokenLine] from the shipped clips.
  ///
  /// A line that has started is heard out. Nothing the app does on its own
  /// cuts it off — not the next verdict, not the board playing a move —
  /// because being interrupted mid-thought is how a spoken interface becomes
  /// noise. Only the reader stops it: by moving through the game, by
  /// answering, or by leaving. Those call [stop].
  ///
  /// [force] is for the speaker button and the Settings test button, which
  /// have to speak even though they are saying the same thing again.
  ///
  /// The future completes when the line has been played — also for a line
  /// that waited in the slot — and when the slot is overwritten or emptied,
  /// so nothing waits for ever. The puzzle's other defence holds a move back
  /// on it.
  Future<void> speakLine(SpokenLine line, {bool force = false}) async {
    if (!canSpeakNow()) return;
    if (_clipVoice == null || line.tokens.isEmpty) return;
    final spoken = line.text;
    if (!force && spoken == _lastSpoken) return;

    if (_speaking) {
      _queued?.done.complete();
      final done = Completer<void>();
      _queued = (line: line, done: done);
      return done.future;
    }
    _lastSpoken = spoken;
    await _utterLine(line);
  }

  /// One line, start to finish, and whatever was waiting behind it.
  Future<void> _utterLine(SpokenLine line) async {
    try {
      _startSpeaking(line.text);
      await _clipVoice?.speak(line);
    } catch (e) {
      AppLogger.log('[Speech] A line could not be played: $e');
    } finally {
      _finishSpeaking();
    }
    await _next();
  }

  /// What was waiting behind the line that has just ended.
  Future<void> _next() async {
    final next = _queued;
    _queued = null;
    if (next == null) return;
    try {
      if (!_enabled || _state == SpeechState.failed) return;
      _lastSpoken = next.line.text;
      await _utterLine(next.line);
    } finally {
      next.done.complete();
    }
  }

  // Neither of these notifies, on purpose, and it is not an oversight to be
  // tidied up later.
  //
  // The panel asks for a sentence from initState and didUpdateWidget — that is
  // to say, from inside a build — and a ChangeNotifier that fires there marks
  // its listeners dirty mid-build, which Flutter refuses:
  //
  //   setState() or markNeedsBuild() called during build.
  //
  // The frame then failed in layout, and what reached the screen was a board
  // with no squares and the pieces floating over the background. Nothing
  // watches [isSpeaking] anyway — the board's timers ask it, they are not told.
  void _startSpeaking(String text) {
    _speaking = true;
    _watchdog?.cancel();
    _watchdog = Timer(_budget(text), () {
      if (!_speaking) return;
      AppLogger.log(
          '[Speech] End of utterance was never reported, carrying on.');
      _finishSpeaking();
    });
  }

  void _finishSpeaking() {
    _watchdog?.cancel();
    _watchdog = null;
    _speaking = false;
  }

  /// Clears what was last said, so the same sentence is spoken again when it
  /// comes back. Called when a screen closes or a new exercise starts.
  void forget() => _lastSpoken = '';

  /// Cuts the voice off. For what the reader does, and nothing else.
  ///
  /// Moving to the next move, answering, leaving the screen — each of those
  /// says the sentence is no longer wanted, and each of them calls this. The
  /// app itself never does.
  Future<void> stop() async {
    _lastSpoken = '';
    _queued?.done.complete();
    _queued = null;
    _finishSpeaking();
    try {
      await _clipVoice?.stop();
    } catch (e) {
      AppLogger.log('[Speech] Stopping a line failed: $e');
    }
  }
}
