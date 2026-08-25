import 'package:chess_app/models/recording_models.dart';

/// What a finished recording hands over: the board timeline, plus the stretches
/// the microphone kept running through while the timeline was frozen.
class LessonRecording {
  final List<TimelineEvent> events;
  final List<PauseInterval> pauses;

  const LessonRecording({required this.events, required this.pauses});
}

/// Keeps the timeline of a lesson being recorded: when it started, how long it
/// was paused for, and what happened at which moment.
///
/// Extracted from the room screen because the arithmetic here is the kind that
/// fails silently. A timestamp that does not subtract paused time drifts further
/// out with every pause, and nothing complains — the recording saves, the
/// replay plays, and only someone watching the exported MP4 notices that the
/// board and the trainer's voice have come apart. There was no test for it.
///
/// Deliberately knows nothing about Agora, sockets, dialogs or widgets: those
/// belong to whoever drives it. That is what makes the arithmetic testable.
class LessonRecorder {
  /// The clock is injectable so pause boundaries can be tested without waiting.
  LessonRecorder({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  final List<TimelineEvent> _events = [];
  final List<PauseInterval> _pauses = [];
  int? _startedAtMs;
  int _pausedAtMs = 0;
  int _totalPausedMs = 0;
  bool _isPaused = false;

  /// True while this device is actually recording.
  ///
  /// Distinct from "someone in the room is recording", which every client is
  /// told over the socket. Conflating the two made a student's device buffer
  /// events it would never save.
  bool get isActive => _startedAtMs != null;

  bool get isPaused => _isPaused;
  int? get startedAtMs => _startedAtMs;
  int get totalPausedMs => _totalPausedMs;
  int get eventCount => _events.length;

  /// The buffered timeline, as an unmodifiable view.
  List<TimelineEvent> get events => List.unmodifiable(_events);

  /// Closed pauses so far, in the microphone's clock. An in-progress pause only
  /// joins this list once it ends — see [stop] for the case where it never does.
  List<PauseInterval> get pauses => List.unmodifiable(_pauses);

  int get _nowMs => _clock().millisecondsSinceEpoch;

  /// Milliseconds of *recorded* time so far — wall time minus everything spent
  /// paused. This is the number every event is stamped with, and the number the
  /// audio track is lined up against.
  int elapsedMs() {
    final startedAt = _startedAtMs;
    if (startedAt == null) return 0;

    // While paused the clock is frozen at the moment the pause began, so events
    // arriving during a pause (there should be none) cannot jump the timeline.
    final reference = _isPaused ? _pausedAtMs : _nowMs;
    final elapsed = (reference - startedAt) - _totalPausedMs;
    return elapsed < 0 ? 0 : elapsed;
  }

  /// Begins a recording, discarding anything buffered from a previous one.
  ///
  /// [initialEvent] describes the starting state of the board and is always
  /// stamped at zero, so a replay has something to draw before the first move.
  void start({
    required String initialEventType,
    required Map<String, dynamic> initialData,
  }) {
    _events.clear();
    _pauses.clear();
    _startedAtMs = _nowMs;
    _pausedAtMs = 0;
    _totalPausedMs = 0;
    _isPaused = false;

    _events.add(TimelineEvent(
      timestampMs: 0,
      eventType: initialEventType,
      data: initialData,
    ));
  }

  /// Freezes the timeline. Repeated calls are ignored, so a double tap cannot
  /// move the pause boundary and swallow real recorded time.
  void pause() {
    if (!isActive || _isPaused) return;
    _isPaused = true;
    _pausedAtMs = _nowMs;
  }

  /// Resumes, adding the time spent paused to the running total so the next
  /// event carries on from where the last one left off.
  void resume() {
    if (!isActive || !_isPaused) return;
    _closeOpenPause(_nowMs);
    _totalPausedMs += _nowMs - _pausedAtMs;
    _isPaused = false;
    _pausedAtMs = 0;
  }

  /// Records the pause that began at [_pausedAtMs] as ending at [endAtMs],
  /// in milliseconds since recording started — the audio file's own clock.
  void _closeOpenPause(int endAtMs) {
    final startedAt = _startedAtMs;
    if (startedAt == null) return;
    _pauses.add(PauseInterval(
      startMs: _pausedAtMs - startedAt,
      endMs: endAtMs - startedAt,
    ));
  }

  /// Appends an event at the current recorded time.
  ///
  /// Silently ignored when not recording or while paused — the callers are
  /// scattered all over the room screen, and making each of them check first is
  /// how one of them eventually forgets.
  void record(String eventType, Map<String, dynamic> data) {
    if (!isActive || _isPaused) return;
    _events.add(TimelineEvent(
      timestampMs: elapsedMs(),
      eventType: eventType,
      data: data,
    ));
  }

  /// Ends the recording and hands over the timeline and its pauses.
  ///
  /// Returns copies: the caller keeps them to save while this object is reset
  /// and ready to record again.
  ///
  /// Stopping while still paused closes that last pause here, so a trainer who
  /// pauses and then decides to end the lesson does not leave a gap the audio
  /// still carries but nothing accounts for.
  LessonRecording stop() {
    if (_isPaused) _closeOpenPause(_nowMs);

    final captured = LessonRecording(
      events: List<TimelineEvent>.from(_events),
      pauses: List<PauseInterval>.from(_pauses),
    );
    reset();
    return captured;
  }

  /// Drops everything without producing a timeline — used when the user backs
  /// out of saving.
  void reset() {
    _events.clear();
    _pauses.clear();
    _startedAtMs = null;
    _pausedAtMs = 0;
    _totalPausedMs = 0;
    _isPaused = false;
  }
}
