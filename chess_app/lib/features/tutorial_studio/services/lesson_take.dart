/// A lesson recorded alone in Preparation — phase 5b.1 of
/// `docs/PLAN-SESIJA.md`, the pure core.
///
/// **The audio is the clock**, exactly as in `narration_take.dart`: an event is
/// stamped with how much audio has been recorded when it happens, bytes ÷ byte
/// rate, and never with `DateTime.now()`. Phase 0 of `docs/PLAN-SNIMANJE.md`
/// measured a wall clock 2.6–3.1 s ahead of the audio after one pause; the
/// room's old recorder used one, and the server needed a step of its own to
/// cut the drift back out of the sound. Here a pause stops the microphone and
/// the clock together, so there is nothing to cut.
///
/// The narration's recorder places a fixed list of beats; a lesson has no list
/// — whatever the trainer does on the board is an event. The microphone
/// (`PcmSource`), the file (`NarrationSink`) and the arithmetic are the
/// narration's own, so the two recordings cannot disagree about what a
/// millisecond of audio is.
///
/// Deliberately knows nothing about the plugin, the board or a widget.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/models/recording_models.dart';

enum LessonMark {
  marked,

  /// Before [LessonTake.start], or after the take ended.
  notListening,
}

/// A finished take: the timeline the player replays, and how long the audio
/// beside it is.
class LessonRecording {
  LessonRecording({
    required this.events,
    required this.durationMs,
    required this.peakDbfs,
    required this.stoppedAtCap,
  });

  /// In order, each stamped with the audio position it happened at. The first
  /// is the board as it stood when recording began, at 0.
  ///
  /// **Three kinds, and only these**: `init` (the opening board), `move` (any
  /// change of position, with its FEN) and `arrow_drawn`. They are what both
  /// readers replay — the app's player and the server's film. The room's
  /// recorder also wrote `lesson_loaded` and `fen_change`, which the player
  /// understood and the film ignored, so a room lesson's video stayed on the
  /// old board through every jump the trainer made.
  final List<TimelineEvent> events;
  final int durationMs;
  final double peakDbfs;

  /// Stopped by the take itself, a second before the server's cap — said to
  /// the trainer, because a lesson that ended mid-sentence is otherwise a
  /// surprise.
  final bool stoppedAtCap;

  /// Whether the microphone was live at any point — a muted one records
  /// silence with a perfect clock and says nothing about it.
  bool get heardAnything => peakDbfs > liveMicrophoneDbfs;
}

class LessonTake extends ChangeNotifier {
  LessonTake({
    required this.source,
    required this.sink,
    required this.maxMs,
  });

  final PcmSource source;
  final NarrationSink sink;

  /// The longest recording the server accepts (`narrationUpload.js`), asked
  /// of it rather than copied. The take stops a second before it.
  final int maxMs;

  NarrationState _state = NarrationState.idle;
  StreamSubscription<Uint8List>? _subscription;
  final List<TimelineEvent> _events = [];
  int _bytes = 0;
  bool _heardFirstSample = false;
  double _peak = silenceFloorDbfs;
  final Completer<LessonRecording?> _done = Completer<LessonRecording?>();

  NarrationState get state => _state;

  /// How far into the audio the take is, by its own clock.
  int get positionMs => audioMsOf(_bytes);

  /// Audio left before the take stops itself.
  int get remainingMs => narrationStopAtFor(maxMs) - positionMs;

  int get eventCount => _events.length;

  /// Completes once, with what [stop] handed over — whether the trainer
  /// pressed Stop or the cap did — or null for a discarded take.
  Future<LessonRecording?> get done => _done.future;

  /// Starts the microphone. [opening] is the board as it stands, and becomes
  /// the event at 0.
  Future<NarrationStart> start({required Map<String, dynamic> opening}) async {
    if (_state != NarrationState.idle) return NarrationStart.busy;
    if (!await source.hasPermission()) {
      // The sink already made its file; a refusal must not leave it behind.
      await sink.discard();
      return NarrationStart.noPermission;
    }
    _events
        .add(TimelineEvent(timestampMs: 0, eventType: 'init', data: opening));
    _state = NarrationState.warmingUp;
    notifyListeners();
    try {
      final stream = await source.start();
      _subscription = stream.listen(_onChunk);
    } catch (_) {
      _state = NarrationState.idle;
      _events.clear();
      notifyListeners();
      await sink.discard();
      rethrow;
    }
    return NarrationStart.started;
  }

  void _onChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;
    sink.add(chunk);
    _heardFirstSample = true;
    _bytes += chunk.length;
    final level = peakDbfsOf(chunk);
    if (level > _peak) _peak = level;
    if (_state == NarrationState.warmingUp) _state = NarrationState.recording;
    notifyListeners();
    if (positionMs >= narrationStopAtFor(maxMs)) {
      unawaited(_finish(atCap: true));
    }
  }

  /// Stamps [type] at this point in the audio.
  ///
  /// **While warming up it is stamped at 0**: the microphone took 100–750 ms to
  /// deliver its first sample in phase 0, and a move made in that time
  /// happened before the audio's zero — dropped, the replay would open on a
  /// board the trainer had already changed. **While paused it lands on the
  /// seam**, where the trainer resumes talking about the board now in front of
  /// them.
  LessonMark mark(String type, Map<String, dynamic> data) {
    if (_state != NarrationState.warmingUp &&
        _state != NarrationState.recording &&
        _state != NarrationState.paused) {
      return LessonMark.notListening;
    }
    _events.add(
        TimelineEvent(timestampMs: positionMs, eventType: type, data: data));
    notifyListeners();
    return LessonMark.marked;
  }

  /// Stops the microphone, and with it the clock: no audio, no time.
  Future<void> pause() async {
    if (_state != NarrationState.recording) return;
    await source.pause();
    _state = NarrationState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != NarrationState.paused) return;
    await source.resume();
    _state = NarrationState.recording;
    notifyListeners();
  }

  /// Ends the take and hands it over, or null when no audio ever arrived.
  Future<LessonRecording?> stop() => _finish(atCap: false);

  Future<LessonRecording?> _finish({required bool atCap}) async {
    if (_state == NarrationState.idle || _state == NarrationState.stopped) {
      return _done.isCompleted ? _done.future : null;
    }
    // The subscription goes before the microphone, so a chunk still in flight
    // is neither written nor counted — the file and the clock stay one number.
    // Not awaited, for the reason `NarrationRecorder.stop` gives.
    _state = NarrationState.stopped;
    unawaited(_subscription?.cancel());
    _subscription = null;
    await source.stop();

    if (!_heardFirstSample) {
      await sink.discard();
      notifyListeners();
      _done.complete(null);
      return null;
    }
    await sink.finish();
    final recording = LessonRecording(
      events: List.unmodifiable(_events),
      durationMs: positionMs,
      peakDbfs: _peak,
      stoppedAtCap: atCap,
    );
    notifyListeners();
    _done.complete(recording);
    return recording;
  }

  /// Throws the take away.
  Future<void> cancel() async {
    if (_state == NarrationState.idle || _state == NarrationState.stopped) {
      return;
    }
    _state = NarrationState.stopped;
    unawaited(_subscription?.cancel());
    _subscription = null;
    await source.stop();
    await sink.discard();
    notifyListeners();
    if (!_done.isCompleted) _done.complete(null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
