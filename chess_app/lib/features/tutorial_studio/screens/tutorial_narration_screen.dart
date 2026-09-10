// tutorial_narration_screen.dart — the trainer's own voice over a tutorial.
//
// Phases 1 and 2 of `docs/PLAN-SNIMANJE.md`: record over the film's beats with
// the markers taken from the audio's own clock, and play the take back against
// the board with no server in it.
//
// The arithmetic is `narration_take.dart` and is tested there; this screen
// drives it and shows it. Two rules of its own:
//
//   * **Space means „next beat" and nothing else while recording.** It is
//     bound above every control, so it is heard before the button that has the
//     focus is asked — Space on a focused Pause button advances the beat and
//     does not pause. The controls stay reachable from the keyboard. When the
//     Record button goes away with the focus on it — Tab, then Enter — the
//     scope hands the focus back to the node that had it before, which is the
//     screen's own autofocused one; measured with a probe on 10.9.2026, so
//     there is no `requestFocus` here to do by hand what that already does.
//   * **A held key is one beat.** Repeats are not bound at all; the core also
//     refuses a beat the clock has not moved past, which is the second line of
//     defence and the only one a fast double press meets.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_player.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_storage.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/record_pcm_source.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// How long a live take may hear nothing before the screen says so.
///
/// Three seconds of *audio*, so a pause does not count. The threshold behind it
/// is a dead microphone, not a quiet trainer (`liveMicrophoneDbfs`), so this
/// fires for the muted Windows microphone the spike met and not for somebody
/// thinking between two sentences.
const int silenceWarningMs = 3000;

/// „ · 42 s left" in the last minute before a take stops itself, and nothing
/// before that: a countdown for the whole take would be a clock nobody asked
/// for, and one that appears only at the end is the one that gets read.
String narrationRemainingText(int positionMs, int stopAtMs) {
  final left = stopAtMs - positionMs;
  if (left > 60000) return '';
  final seconds = (left / 1000).ceil().clamp(0, 60);
  return ' · $seconds s left';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateOf(DateTime at) {
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  return '${at.day} ${_months[at.month - 1]} ${at.year}, $hh:$mm';
}

const _silentWhileRecording =
    'Nothing is reaching the microphone. Check the mute key and the input '
    'device — the recording keeps running either way.';

const _silentTake =
    'Nothing reached the microphone during this recording, so it is silent. '
    'Check the mute key and the input device, then record again.';

const _unreadableTake =
    'The recording kept on this device could not be read, so it is gone. '
    'Record it again.';

class TutorialNarrationScreen extends StatefulWidget {
  const TutorialNarrationScreen({
    super.key,
    required this.lessonId,
    required this.title,
    required this.draft,
    this.sourceFactory,
    this.store,
    this.player,
    this.stopAtMs = narrationStopAtMs,
  });

  /// Where a take is stopped because the server would refuse anything longer.
  /// A parameter only so a test need not record fifteen minutes.
  final int stopAtMs;

  /// The saved tutorial the take is kept under.
  final int lessonId;
  final String title;

  /// The tutorial as it is on screen, which is what the trainer talks over.
  final TutorialDraft draft;

  /// The microphone. Null means `record` — tests hand in a fake.
  final PcmSource Function()? sourceFactory;

  /// Null means the app's support directory.
  final NarrationTakeStore? store;

  /// Null means `audioplayers`, created the first time it is needed.
  final NarrationPlayer? player;

  @override
  State<TutorialNarrationScreen> createState() =>
      _TutorialNarrationScreenState();
}

class _TutorialNarrationScreenState extends State<TutorialNarrationScreen> {
  late final List<FilmBeat> _stops = filmBeatsOf(widget.draft);
  late final NarrationTakeStore _store = widget.store ?? deviceNarrationStore();
  final ChessBoardController _board = ChessBoardController();
  final FocusNode _keys = FocusNode(debugLabel: 'narration-keys');

  NarrationRecorder? _recorder;
  String? _recordingPath;
  NarrationLoad _load = const NarrationLoad.none();
  bool _loading = true;
  bool _playing = false;
  int _shown = 0;

  NarrationPlayer? _playerInstance;
  StreamSubscription<Duration>? _positions;
  StreamSubscription<void>? _completions;

  StoredNarration? get _stored => _load.stored;

  NarrationPlayer get _player {
    final existing = _playerInstance;
    if (existing != null) return existing;
    final player = widget.player ?? AudioplayersNarrationPlayer();
    _positions = player.positions.listen(_onPlaybackPosition);
    _completions = player.completed.listen((_) => _onPlaybackDone());
    return _playerInstance = player;
  }

  @override
  void initState() {
    super.initState();
    _board.loadFen(_stops.first.beat.node.fen);
    _loadTake();
  }

  @override
  void dispose() {
    final recorder = _recorder;
    if (recorder != null) {
      recorder.removeListener(_onRecorderChanged);
      // Leaving in the middle of a take throws it away: nothing half-recorded
      // is kept, and the microphone is let go.
      unawaited(recorder.cancel().whenComplete(recorder.dispose));
    }
    _positions?.cancel();
    _completions?.cancel();
    final player = _playerInstance;
    if (player != null) unawaited(player.dispose());
    _keys.dispose();
    _board.dispose();
    super.dispose();
  }

  Future<void> _loadTake() async {
    NarrationLoad load;
    try {
      load = await _store.load(widget.lessonId);
    } catch (_) {
      load = const NarrationLoad.unreadable();
    }
    if (!mounted) return;
    setState(() {
      _load = load;
      _loading = false;
    });
  }

  /// Puts beat [index] on the board. Called inside `setState`.
  void _show(int index) {
    final beat = index.clamp(0, _stops.length - 1);
    if (beat == _shown) return;
    _shown = beat;
    _board.loadFen(_stops[beat].beat.node.fen);
  }

  // ---------------------------------------------------------------- recording

  Future<void> _record() async {
    if (_recorder != null) return;
    if (_playing) await _stopListening();

    final path = await _store.newRecordingPath(widget.lessonId);
    final recorder = NarrationRecorder(
      source: (widget.sourceFactory ?? RecordPcmSource.new)(),
      sink: WavFileSink(path),
      eventCount: _stops.length,
    )..addListener(_onRecorderChanged);
    if (!mounted) {
      await recorder.cancel();
      recorder.dispose();
      return;
    }
    setState(() {
      _recorder = recorder;
      _recordingPath = path;
      _show(0);
    });
    final NarrationStart started;
    try {
      started = await recorder.start();
    } catch (e) {
      _dropRecorder();
      if (mounted) {
        AppFeedback.error(context, 'The microphone could not be started: $e');
      }
      return;
    }
    if (started == NarrationStart.noPermission) {
      _dropRecorder();
      if (mounted) {
        AppFeedback.error(
          context,
          'This app may not use the microphone. Allow it in your system '
          'settings, then try again.',
        );
      }
    }
  }

  void _dropRecorder() {
    final recorder = _recorder;
    if (recorder == null) return;
    recorder.removeListener(_onRecorderChanged);
    recorder.dispose();
    _recorder = null;
    _recordingPath = null;
    if (mounted) setState(() {});
  }

  void _onRecorderChanged() {
    final recorder = _recorder;
    if (recorder == null || !mounted) return;
    setState(() => _show(recorder.beat));
    // A take past the server's cap could never be sent, so it stops here,
    // still whole, rather than being refused after the trainer has talked
    // past it for however long. Asked of the recorder's own state, which
    // `stop()` changes before it awaits anything, so no chunk after this one
    // can stop the take a second time.
    if (recorder.state == NarrationState.recording &&
        recorder.positionMs >= widget.stopAtMs) {
      _stop(atCap: true);
    }
  }

  void _next() => _recorder?.next();

  Future<void> _togglePause() async {
    final recorder = _recorder;
    if (recorder == null) return;
    if (recorder.state == NarrationState.paused) {
      await recorder.resume();
    } else {
      await recorder.pause();
    }
  }

  /// Ends the take and keeps it — then says what is wrong with it, if anything.
  Future<void> _stop({bool atCap = false}) async {
    final recorder = _recorder;
    final path = _recordingPath;
    if (recorder == null || path == null) return;

    final take = await recorder.stop();
    _dropRecorder();
    if (take == null) {
      if (mounted) {
        AppFeedback.warning(context,
            'No sound arrived from the microphone, so nothing was kept.');
      }
      return;
    }

    final StoredNarration stored;
    try {
      stored = await _store.keep(widget.lessonId, take, path);
    } catch (e) {
      if (mounted) {
        AppFeedback.error(
            context, 'The recording could not be kept on this device: $e');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _load = NarrationLoad.found(stored);
      _show(0);
    });
    if (!take.heardAnything) {
      AppFeedback.warning(context, _silentTake);
    } else if (atCap) {
      AppFeedback.info(
        context,
        'The recording stopped at ${narrationClockOf(take.durationMs)}: '
        '${narrationMaxMs ~/ 60000} minutes is the most one recording may be.',
      );
    }
  }

  Future<void> _discard() async {
    final recorder = _recorder;
    if (recorder == null) return;
    await recorder.cancel();
    _dropRecorder();
    if (mounted) setState(() => _show(0));
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this recording?'),
        content: const Text(
            'You are still recording. Leaving now throws this recording away.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            key: const Key('narration-leave'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard and leave'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    await _discard();
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- listening

  Future<void> _listen() async {
    final stored = _stored;
    if (stored == null || _recorder != null) return;
    final player = _player;
    setState(() {
      _playing = true;
      _show(0);
    });
    try {
      await player.play(stored.audioPath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _playing = false);
      AppFeedback.error(context, 'The recording could not be played: $e');
    }
  }

  /// The board follows the audio: the beat on screen is the last one whose
  /// marker the playback has passed — the same reading the film will make.
  void _onPlaybackPosition(Duration at) {
    final stored = _stored;
    if (!_playing || stored == null || !mounted) return;
    final beat = stored.take.beatAt(at.inMilliseconds);
    if (beat != _shown) setState(() => _show(beat));
  }

  void _onPlaybackDone() {
    if (!mounted) return;
    setState(() => _playing = false);
  }

  Future<void> _stopListening() async {
    await _playerInstance?.stop();
    if (mounted) setState(() => _playing = false);
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final stop = _stops[_shown];
    final title = widget.title.isEmpty
        ? 'Record narration'
        : 'Record narration · ${widget.title}';

    return PopScope(
      canPop: _recorder == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppText.title),
        ),
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space,
                includeRepeats: false): _next,
          },
          child: Focus(
            focusNode: _keys,
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= Breakpoints.wide;
                if (wide) {
                  final boardSize = math
                      .min(constraints.maxHeight - AppSpacing.md * 2,
                          constraints.maxWidth - 420 - AppSpacing.md * 3)
                      .clamp(240.0, 900.0);
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _boardOf(boardSize, stop),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SingleChildScrollView(child: _panel(stop)),
                        ),
                      ],
                    ),
                  );
                }
                final boardSize = (constraints.maxWidth - AppSpacing.md * 2)
                    .clamp(240.0, 600.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _boardOf(boardSize, stop)),
                      const SizedBox(height: AppSpacing.md),
                      _panel(stop),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _boardOf(double size, FilmBeat stop) {
    final node = stop.beat.node;
    final orientation =
        stop.section.blackOrientation ? PlayerColor.black : PlayerColor.white;
    // The opening position of a part is a position, and nothing arrived at it.
    final uci = stop.beat.index > 0 ? node.moveUci : null;
    final moved = uci != null && uci.length >= 4;

    return SizedBox(
      width: size,
      height: size,
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: BoardWithCoordinates(
            size: size - AppSpacing.sm * 2,
            orientation: orientation,
            builder: (inner) => ChessBoardWithOverlay(
              controller: _board,
              boardOrientation: orientation,
              boardSize: inner,
              isAllowedToMove: false,
              isDrawingMode: false,
              drawingStartSquare: null,
              arrows: node.arrows,
              squares: node.squares,
              engineArrows: const [],
              lastMoveFrom: moved ? uci.substring(0, 2) : null,
              lastMoveTo: moved ? uci.substring(2, 4) : null,
              onMove: (_, __, ___) {},
              onSquareTapForDrawing: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(FilmBeat stop) {
    final colors = context.colors;
    final part = widget.draft.sections.indexOf(stop.section) + 1;
    final recorder = _recorder;
    final written = stop.caption.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Beat ${_shown + 1} of ${_stops.length} · Part $part',
          key: const Key('narration-beat'),
          style: AppText.captionBold.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        // The sentence is on screen so the trainer can say it — what the child
        // will read under the board is what the voice is speaking over.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: written
              ? Text(stop.caption,
                  key: const Key('narration-caption'),
                  style: AppText.bodyLarge.copyWith(color: colors.textPrimary))
              : Text('Nothing is written on this beat.',
                  key: const Key('narration-caption'),
                  style: AppText.body.copyWith(color: colors.textMuted)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(_nextLabel(),
            style: AppText.caption.copyWith(color: colors.textMuted)),
        const SizedBox(height: AppSpacing.md),
        if (recorder != null)
          ..._recordingControls(recorder)
        else
          ..._idleControls(),
      ],
    );
  }

  /// What pressing Space will put on the board.
  String _nextLabel() {
    if (_shown >= _stops.length - 1) return 'This is the last beat.';
    final here = _stops[_shown];
    final next = _stops[_shown + 1];
    if (identical(next.section, here.section)) {
      return 'Next: ${here.beat.playsLabel ?? 'the next move'}';
    }
    return 'Next: Part ${widget.draft.sections.indexOf(next.section) + 1}';
  }

  List<Widget> _recordingControls(NarrationRecorder recorder) {
    final colors = context.colors;
    final state = recorder.state;
    final listening =
        state == NarrationState.recording || state == NarrationState.paused;
    final status = switch (state) {
      NarrationState.warmingUp => 'Waiting for the microphone…',
      NarrationState.paused =>
        'Paused · ${narrationClockOf(recorder.positionMs)}',
      _ => 'Recording · ${narrationClockOf(recorder.positionMs)}'
          '${narrationRemainingText(recorder.positionMs, widget.stopAtMs)}',
    };
    final silent = state == NarrationState.recording &&
        recorder.silentMs >= silenceWarningMs;

    return [
      Row(
        children: [
          Icon(
            state == NarrationState.paused
                ? Icons.pause_circle_outline
                : Icons.fiber_manual_record,
            color: colors.danger,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(status,
                key: const Key('narration-status'),
                style: AppText.bodyBold.copyWith(color: colors.textPrimary)),
          ),
        ],
      ),
      if (silent) ...[
        const SizedBox(height: AppSpacing.sm),
        Container(
          key: const Key('narration-silent'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.dangerContainer,
            border: Border.all(color: colors.dangerContainerBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_silentWhileRecording,
              style: AppText.body.copyWith(color: colors.onDangerContainer)),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          FilledButton.icon(
            key: const Key('narration-next'),
            onPressed: listening && !recorder.isLastBeat ? _next : null,
            icon: const Icon(Icons.skip_next),
            label: const Text('Next beat (Space)'),
          ),
          OutlinedButton.icon(
            key: const Key('narration-pause'),
            onPressed: listening ? _togglePause : null,
            icon: Icon(state == NarrationState.paused
                ? Icons.play_arrow
                : Icons.pause),
            label: Text(state == NarrationState.paused ? 'Resume' : 'Pause'),
          ),
          FilledButton.icon(
            key: const Key('narration-stop'),
            onPressed: listening ? _stop : null,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
          TextButton(
            key: const Key('narration-discard'),
            onPressed: _discard,
            child: const Text('Discard'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _idleControls() {
    final colors = context.colors;
    final stored = _stored;

    return [
      if (_loading)
        Text('Looking for a recording on this device…',
            style: AppText.body.copyWith(color: colors.textSecondary))
      else if (_load.unreadable)
        _problem(_unreadableTake, key: const Key('narration-unreadable'))
      else if (stored == null)
        Text(
          'Press Record and talk over the tutorial. Press Space for each next '
          'beat. Pausing stops the recording too, so a pause leaves no gap.',
          style: AppText.body.copyWith(color: colors.textSecondary),
        )
      else
        ..._summaryOf(stored.take),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          FilledButton.icon(
            key: const Key('narration-record'),
            onPressed: _loading ? null : _record,
            icon: const Icon(Icons.mic),
            label: Text(stored == null ? 'Record' : 'Record again'),
          ),
          if (stored != null && _playing)
            OutlinedButton.icon(
              key: const Key('narration-stop-listening'),
              onPressed: _stopListening,
              icon: const Icon(Icons.stop),
              label: const Text('Stop listening'),
            )
          else if (stored != null)
            OutlinedButton.icon(
              key: const Key('narration-listen'),
              onPressed: _listen,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Listen'),
            ),
        ],
      ),
    ];
  }

  List<Widget> _summaryOf(NarrationTake take) {
    final colors = context.colors;
    final problems = [
      if (!take.heardAnything) _silentTake,
      // Phase 5 replaces this count with a signature over the beats; a count
      // already catches a beat added or removed, which is the commonest edit.
      if (take.eventCount != _stops.length)
        'This recording was made when the tutorial had ${take.eventCount} '
            'beats, and it has ${_stops.length} now. Record it again.'
      else if (!take.isComplete)
        'It stops at beat ${take.markersMs.length} of ${take.eventCount}. '
            'A video needs a recording that reaches the last beat.',
    ];

    return [
      Text(
        'Recorded ${_dateOf(take.recordedAt)} · '
        '${narrationClockOf(take.durationMs)} · '
        '${take.markersMs.length} of ${take.eventCount} beats',
        key: const Key('narration-summary'),
        style: AppText.bodyBold.copyWith(color: colors.textPrimary),
      ),
      for (final problem in problems) ...[
        const SizedBox(height: AppSpacing.xs),
        _problem(problem),
      ],
      const SizedBox(height: AppSpacing.xs),
      Text('Recording again replaces this one when you press Stop.',
          style: AppText.caption.copyWith(color: colors.textMuted)),
    ];
  }

  Widget _problem(String text, {Key? key}) {
    final colors = context.colors;
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: colors.warning, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(text,
              style: AppText.body.copyWith(color: colors.textPrimary)),
        ),
      ],
    );
  }
}
