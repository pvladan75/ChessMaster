import 'package:flutter/material.dart';

import 'package:chess_app/core/services/game_analysis_walker_service.dart'
    show BlunderAlertSide;
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Says the review's end, and the engine's refusal, wherever the reader is —
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b. The model is
/// [EngineNotice], which sits beside it in `main.dart`'s builder for the same
/// reason: the review runs in the background, so its end has to reach
/// whichever screen the reader happens to be on, not only a dialog that may
/// already be closed.
///
/// A run that finishes while its dialog is open says nothing here — the
/// dialog is already showing it ([GameReviewRunner.watched]). A cancelled run
/// says nothing anywhere: nothing changed, so there is nothing to report.
class ReviewNotice extends StatefulWidget {
  const ReviewNotice({super.key, required this.child, this.runner});

  final Widget child;

  /// Defaults to the one the app runs reviews through; a test passes its own.
  final GameReviewRunner? runner;

  @override
  State<ReviewNotice> createState() => _ReviewNoticeState();
}

class _ReviewNoticeState extends State<ReviewNotice> {
  late final GameReviewRunner _runner =
      widget.runner ?? GameReviewRunner.instance;
  final StockfishService _engine = StockfishService();

  GameReviewRun? _watchedRun;
  int _refusedSeen = 0;
  bool _saidBusyThisHold = false;

  @override
  void initState() {
    super.initState();
    _refusedSeen = _engine.refusedWhileHeld.value;
    _engine.refusedWhileHeld.addListener(_onRefused);
    _engine.held.addListener(_onHeldChanged);
    _runner.addListener(_onRunnerChanged);
    _syncRunListener();
  }

  @override
  void dispose() {
    _engine.refusedWhileHeld.removeListener(_onRefused);
    _engine.held.removeListener(_onHeldChanged);
    _runner.removeListener(_onRunnerChanged);
    _watchedRun?.removeListener(_onRunChanged);
    super.dispose();
  }

  void _onHeldChanged() {
    // A new hold gets to say "busy" again.
    if (!_engine.held.value) _saidBusyThisHold = false;
  }

  void _onRefused() {
    final now = _engine.refusedWhileHeld.value;
    if (now <= _refusedSeen) return;
    _refusedSeen = now;
    if (_saidBusyThisHold) return;
    _saidBusyThisHold = true;
    if (!mounted) return;
    AppFeedback.warning(
        context, 'The engine is busy with the game review right now.');
  }

  void _onRunnerChanged() {
    _syncRunListener();
  }

  void _syncRunListener() {
    final run = _runner.current;
    if (identical(run, _watchedRun)) return;
    _watchedRun?.removeListener(_onRunChanged);
    _watchedRun = run;
    run?.addListener(_onRunChanged);
  }

  void _onRunChanged() {
    final run = _watchedRun;
    if (run == null) return;
    if (run.status == ReviewRunStatus.running ||
        run.status == ReviewRunStatus.cancelled) {
      return;
    }
    if (_runner.watched) return; // said in the dialog instead
    if (!mounted) return;
    // A result that did not land, or a run that failed, is a warning: the
    // reader's game does not hold what the review found.
    final loud = run.status == ReviewRunStatus.failed ||
        run.landing == ReviewLanding.notLanded;
    if (loud) {
      AppFeedback.warning(context, _endMessage(run));
    } else {
      AppFeedback.info(context, _endMessage(run));
    }
  }

  String _endMessage(GameReviewRun run) {
    if (run.status == ReviewRunStatus.failed) {
      return 'Game review stopped: ${run.failure ?? 'unknown error'}.';
    }
    final parts = <String>['Game review done.'];
    final result = run.result;
    if (run.options.markMistakes) {
      if (run.marked > 0) {
        parts.add(run.marked == 1
            ? 'Marked 1 mistake.'
            : 'Marked ${run.marked} mistakes.');
      } else if (result != null &&
          result.cleanWhere((m) => switch (run.options.side) {
                BlunderAlertSide.white => m.whiteMoved,
                BlunderAlertSide.black => !m.whiteMoved,
                BlunderAlertSide.both => true,
              })) {
        parts.add('No mistake found at depth ${result.depth}.');
      }
      if (run.landing == ReviewLanding.notLanded) {
        parts.add(
            'The game changed while it was reviewed — the marks were not written.');
      }
    }
    if (run.puzzles.isNotEmpty) {
      parts.add(run.puzzles.length == 1
          ? '1 puzzle waiting — open Review game in Analysis to keep it.'
          : '${run.puzzles.length} puzzles waiting — open Review game in '
              'Analysis to keep them.');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
