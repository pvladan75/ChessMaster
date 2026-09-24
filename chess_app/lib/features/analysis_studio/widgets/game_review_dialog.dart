import 'package:flutter/material.dart';

import 'package:chess_app/core/services/game_analysis_walker_service.dart'
    show BlunderAlertSide;
import 'package:chess_app/core/services/game_review_judge.dart'
    show ReviewProgress, ReviewStage;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/analysis_studio/widgets/keep_puzzles_panel.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_slider.dart';

/// Starts a whole-game review through [GameReviewRunner] and then only
/// watches it — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b.
///
/// The review is not this dialog's: closing it leaves the review running, and
/// its end is said wherever the reader is (`ReviewNotice`, when this dialog is
/// not open to say it itself). What a finished review found — the depth it
/// stands on, what was marked, what could not be judged, what came from the
/// store, and whether the game was clean — is the judge's own numbers
/// (`GameReviewJudge`, `mistake_rule.dart`), never a threshold this dialog
/// picks: the pawn slider is gone.
class GameReviewDialog extends StatefulWidget {
  final AnalysisNode rootNode;
  final AnalysisNode currentNode;
  final StockfishService stockfishService;

  /// Where kept puzzles go (`POST /exercises`). Required: a puzzle found and
  /// kept nowhere is the old set on one device in a new form.
  final ExerciseApiService exerciseApi;

  /// The game's name, which the kept exercises are named after; null names
  /// them by the date.
  final String? gameTitle;

  /// Defaults to the app's one runner.
  final GameReviewRunner? runner;

  const GameReviewDialog({
    super.key,
    required this.exerciseApi,
    this.gameTitle,
    required this.rootNode,
    required this.currentNode,
    required this.stockfishService,
    this.runner,
  });

  @override
  State<GameReviewDialog> createState() => _GameReviewDialogState();
}

class _GameReviewDialogState extends State<GameReviewDialog> {
  GameReviewRunner get _runner => widget.runner ?? GameReviewRunner.instance;
  GameReviewRun? _listenedRun;

  late int _engineDepth;
  bool _analyzeFromCurrent = false;

  bool _blunderAlertEnabled = false;
  BlunderAlertSide _blunderSide = BlunderAlertSide.both;
  bool _insertBetterMoveLine = true;

  bool _extractPuzzlesEnabled = false;
  int _maxPuzzles = 5;

  bool get _hasOutput => _blunderAlertEnabled || _extractPuzzlesEnabled;

  bool get _hasCurrentNodeOption => widget.currentNode.id != widget.rootNode.id;

  AnalysisNode get _effectiveStartNode =>
      (_analyzeFromCurrent && _hasCurrentNodeOption)
          ? widget.currentNode
          : widget.rootNode;

  int get _mainLineLength {
    var count = 0;
    var cur = _effectiveStartNode;
    while (cur.children.isNotEmpty) {
      cur = cur.children.first;
      count++;
    }
    return count;
  }

  /// Whether [run] is a review of the game this dialog opened on — matched by
  /// its moves, since the run and this dialog's tree are not always the same
  /// object.
  bool _isThisGame(GameReviewRun run) =>
      run.game.chainIn(widget.rootNode) != null;

  @override
  void initState() {
    super.initState();
    _engineDepth = AppSettingsService.instance.analysisDepth;
    _runner.watch();
    _runner.addListener(_onRunnerChanged);
    _syncRunListener();
  }

  @override
  void dispose() {
    _listenedRun?.removeListener(_onRunChanged);
    _runner.removeListener(_onRunnerChanged);
    _runner.unwatch();
    super.dispose();
  }

  void _onRunnerChanged() {
    _syncRunListener();
    if (mounted) setState(() {});
  }

  void _syncRunListener() {
    final run = _runner.current;
    if (identical(run, _listenedRun)) return;
    _listenedRun?.removeListener(_onRunChanged);
    _listenedRun = run;
    run?.addListener(_onRunChanged);
  }

  void _onRunChanged() {
    if (mounted) setState(() {});
  }

  void _start() {
    _runner.start(
      root: widget.rootNode,
      start: _effectiveStartNode,
      options: ReviewOptions(
        depth: _engineDepth,
        markMistakes: _blunderAlertEnabled,
        side: _blunderSide,
        insertBetterLine: _insertBetterMoveLine,
        findPuzzles: _extractPuzzlesEnabled,
        maxPuzzles: _maxPuzzles,
      ),
      engine: widget.stockfishService,
      gameTitle: widget.gameTitle,
    );
    _syncRunListener();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final moveCount = _mainLineLength;
    final run = _runner.current;
    final otherGameRunning = run != null &&
        run.status == ReviewRunStatus.running &&
        !_isThisGame(run);
    final thisGameRun = run != null && _isThisGame(run) ? run : null;

    List<Widget> body;
    if (thisGameRun != null && thisGameRun.status == ReviewRunStatus.running) {
      body = _buildRunningControls(thisGameRun);
    } else if (thisGameRun != null &&
        (thisGameRun.status == ReviewRunStatus.done ||
            thisGameRun.status == ReviewRunStatus.failed)) {
      body = _buildDoneControls(thisGameRun);
    } else {
      body = _buildSetupControls(moveCount,
          blockedBy: otherGameRunning ? run : null);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(AppSpacing.xl),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.fact_check,
                        color: context.colors.accent, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Review game',
                        style: AppText.title
                            .copyWith(color: context.colors.textPrimary)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.colors.textMuted),
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSetupControls(int moveCount, {GameReviewRun? blockedBy}) {
    return [
      Text(
        moveCount == 0
            ? 'No moves played from the selected position.'
            : 'The engine will step through $moveCount moves, mark the '
                'mistakes and find puzzles in them — choose which below. It '
                'writes no comment under a move; for that, use "Generate AI '
                'comment" on the move. Works on part of a game too. The review '
                'may take long, and goes on if this window is closed.',
        style: AppText.body.copyWith(color: context.colors.textMuted),
      ),
      if (blockedBy != null) ...[
        const SizedBox(height: AppSpacing.md),
        Container(
          key: const Key('review-other-game'),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surfaceRaised,
            borderRadius: AppRadii.roundedSm,
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A review of another game is under way.',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text(_stageText(blockedBy.progress),
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: Icon(Icons.cancel, color: context.colors.danger),
                label: Text('Cancel that review',
                    style: TextStyle(color: context.colors.danger)),
                onPressed: () => _runner.cancel(),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Engine depth (d): $_engineDepth',
              style: AppText.body.copyWith(color: context.colors.textPrimary)),
          Text('depth $_engineDepth',
              style: AppText.bodyBold.copyWith(color: context.colors.warning)),
        ],
      ),
      AppSlider(
        value: _engineDepth.toDouble(),
        min: 5,
        max: AppSettingsService.kMaxEngineDepth.toDouble(),
        divisions: AppSettingsService.kMaxEngineDepth - 5,
        activeColor: context.colors.warning,
        onChanged: (val) => setState(() => _engineDepth = val.round()),
      ),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _analyzeFromCurrent && _hasCurrentNodeOption,
        title: Text(
          'Analyze only from the current position forward',
          style: AppText.body.copyWith(
              color: _hasCurrentNodeOption
                  ? context.colors.textPrimary
                  : context.colors.textMuted),
        ),
        subtitle: !_hasCurrentNodeOption
            ? Text('The current position is already the start of the game.',
                style: AppText.micro.copyWith(color: context.colors.textMuted))
            : null,
        onChanged: _hasCurrentNodeOption
            ? (val) => setState(() => _analyzeFromCurrent = val ?? false)
            : null,
      ),
      const Divider(height: 20),
      Text('Blunder detection',
          style: AppText.bodyBold.copyWith(color: context.colors.textPrimary)),
      const SizedBox(height: AppSpacing.xs),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _blunderAlertEnabled,
        title: Text('Blunder Alert — tag mistakes and suggest a better move',
            style: AppText.body.copyWith(color: context.colors.textPrimary)),
        onChanged: (val) => setState(() => _blunderAlertEnabled = val ?? false),
      ),
      if (_blunderAlertEnabled) ...[
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<BlunderAlertSide>(
                segments: const [
                  ButtonSegment(
                      value: BlunderAlertSide.both, label: Text('Both')),
                  ButtonSegment(
                      value: BlunderAlertSide.white, label: Text('White')),
                  ButtonSegment(
                      value: BlunderAlertSide.black, label: Text('Black')),
                ],
                selected: {_blunderSide},
                onSelectionChanged: (sel) =>
                    setState(() => _blunderSide = sel.first),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _insertBetterMoveLine,
                title: Text('Add a short line with the better move',
                    style: AppText.caption
                        .copyWith(color: context.colors.textPrimary)),
                onChanged: (val) =>
                    setState(() => _insertBetterMoveLine = val ?? true),
              ),
            ],
          ),
        ),
      ],
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _extractPuzzlesEnabled,
        title: Text('Extract puzzles from detected blunders',
            style: AppText.body.copyWith(color: context.colors.textPrimary)),
        onChanged: (val) =>
            setState(() => _extractPuzzlesEnabled = val ?? false),
      ),
      if (_extractPuzzlesEnabled)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxxl),
          child: Row(
            children: [
              Text('Max puzzles: $_maxPuzzles',
                  style: AppText.caption
                      .copyWith(color: context.colors.textPrimary)),
              Expanded(
                child: AppSlider(
                  value: _maxPuzzles.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: context.colors.accent,
                  onChanged: (val) => setState(() => _maxPuzzles = val.round()),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      if (moveCount > 0 && !_hasOutput) ...[
        Text(
          'Turn on Blunder Alert or puzzles — without either, the review '
          'has nothing to show.',
          key: const Key('review-needs-output'),
          style: AppText.caption.copyWith(color: context.colors.warning),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start analysis'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          onPressed: (moveCount == 0 || !_hasOutput || blockedBy != null)
              ? null
              : _start,
        ),
      ),
    ];
  }

  String _stageText(ReviewProgress? p) {
    if (p == null) return 'Starting…';
    switch (p.stage) {
      case ReviewStage.walk:
        return 'Walking the game: ${p.done} / ${p.total} positions';
      case ReviewStage.book:
        return 'Checking the book';
      case ReviewStage.tablebase:
        return 'Checking the tablebase: ${p.done} / ${p.total}';
      case ReviewStage.confirm:
        return 'Looking again: ${p.done} / ${p.total}';
      case ReviewStage.deepen:
        return 'Looking deeper: ${p.done} / ${p.total} searches';
    }
  }

  List<Widget> _buildRunningControls(GameReviewRun run) {
    final p = run.progress;
    final pct =
        (p != null && p.total > 0) ? (p.done / p.total).clamp(0.0, 1.0) : 0.0;
    return [
      Container(
        key: const Key('review-running'),
        child: Center(
          child: Column(
            children: [
              Text(_stageText(p),
                  textAlign: TextAlign.center,
                  style: AppText.bodyLargeBold
                      .copyWith(color: context.colors.accent)),
              const SizedBox(height: AppSpacing.lg),
              LinearProgressIndicator(
                  value: pct,
                  backgroundColor: context.colors.surfaceRaised,
                  color: context.colors.accent),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'The review may take long — it goes on if this window is '
                'closed.',
                textAlign: TextAlign.center,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              // A `Wrap`, not a `Row`: two buttons at 400 px do not fit side
              // by side, and a `Row` that does not fit is clipped in a
              // release build with nothing painted to say so.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    key: const Key('review-keep-working'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep working in the background'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('review-cancel'),
                    icon: Icon(Icons.cancel, color: context.colors.danger),
                    label: Text('Cancel',
                        style: TextStyle(color: context.colors.danger)),
                    onPressed: () {
                      _runner.cancel();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// „Game of 23.09.2026" — the name when the game has none of its own.
  static String _gameOfToday() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Game of ${two(now.day)}.${two(now.month)}.${now.year}';
  }

  List<Widget> _buildDoneControls(GameReviewRun run) {
    final result = run.result;
    final options = run.options;
    final depth = result?.depth ?? options.depth;
    final positions = (result?.moves.length ?? 0) + 1;
    final clean = options.markMistakes &&
        run.marked == 0 &&
        result != null &&
        result.cleanWhere((m) => switch (options.side) {
              BlunderAlertSide.white => m.whiteMoved,
              BlunderAlertSide.black => !m.whiteMoved,
              BlunderAlertSide.both => true,
            });

    return [
      Container(
        key: const Key('review-done'),
        child: Center(
          child: Column(
            children: [
              Icon(
                  run.status == ReviewRunStatus.failed
                      ? Icons.error
                      : Icons.check_circle,
                  color: run.status == ReviewRunStatus.failed
                      ? context.colors.danger
                      : context.colors.accent,
                  size: 36),
              const SizedBox(height: AppSpacing.md),
              if (run.status == ReviewRunStatus.failed)
                Text('The review stopped: ${run.failure ?? 'unknown error'}.',
                    textAlign: TextAlign.center,
                    style:
                        AppText.subtitle.copyWith(color: context.colors.danger))
              else ...[
                Text(
                  'Done — reviewed $positions positions.',
                  textAlign: TextAlign.center,
                  style:
                      AppText.subtitle.copyWith(color: context.colors.accent),
                ),
                const SizedBox(height: 6),
                Text('The review stands on depth $depth.',
                    key: const Key('review-depth'),
                    textAlign: TextAlign.center,
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted)),
                if (options.markMistakes) ...[
                  const SizedBox(height: 6),
                  Text(
                      run.marked == 1
                          ? 'Marked 1 mistake.'
                          : 'Marked ${run.marked} mistakes.',
                      textAlign: TextAlign.center,
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary)),
                  if (clean)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('No mistake found at depth $depth.',
                          key: const Key('review-clean'),
                          textAlign: TextAlign.center,
                          style: AppText.body
                              .copyWith(color: context.colors.textPrimary)),
                    ),
                ],
                if (result != null && result.unsettled > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'The looks still disagreed on ${result.unsettled} move(s).',
                        key: const Key('review-unsettled'),
                        textAlign: TextAlign.center,
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted)),
                  ),
                if (result != null && result.unjudged > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'The engine did not answer on ${result.unjudged} move(s).',
                        key: const Key('review-unjudged'),
                        textAlign: TextAlign.center,
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted)),
                  ),
                if (run.tally.fromStore > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        '${run.tally.fromStore} answer(s) came from earlier '
                        'searches.',
                        key: const Key('review-from-store'),
                        textAlign: TextAlign.center,
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted)),
                  ),
                if (result?.bookUnavailable != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'The book could not be asked (${result!.bookUnavailable}).',
                        textAlign: TextAlign.center,
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted)),
                  ),
                if (result != null && result.tablebaseUnanswered > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'The tablebase did not answer on '
                        '${result.tablebaseUnanswered} move(s).',
                        textAlign: TextAlign.center,
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted)),
                  ),
                if (run.landing == ReviewLanding.notLanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'The game changed while it was reviewed — the marks '
                        'were not written.',
                        textAlign: TextAlign.center,
                        style: AppText.body
                            .copyWith(color: context.colors.warning)),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (run.puzzles.isNotEmpty)
                KeepPuzzlesPanel(
                  puzzles: run.puzzles,
                  defaultName: run.gameTitle ?? _gameOfToday(),
                  api: widget.exerciseApi,
                  onDone: (kept) {
                    _runner.dismiss();
                    Navigator.pop(context, kept);
                  },
                )
              else
                ElevatedButton(
                  key: const Key('review-close'),
                  onPressed: () {
                    _runner.dismiss();
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}
