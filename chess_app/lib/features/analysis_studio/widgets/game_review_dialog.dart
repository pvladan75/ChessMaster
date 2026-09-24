import 'package:chess_app/core/services/eval_cache.dart';
import 'package:flutter/material.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/keep_puzzles_panel.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/app_slider.dart';

/// Walks the game through the engine and, in one pass:
/// - optionally tags blunders ('??') and adds the engine's suggested
///   improvement as a short side variation ("Blunder Alert");
/// - optionally finds the same blunders as puzzles, lists them, and keeps
///   the ticked ones as Find exercises from „mistakes" ([KeepPuzzlesPanel],
///   `docs/PLAN-MATERIJAL.md` phase 4 — until then they were a set of their
///   own that nothing judged).
///
/// Blunder tagging and puzzle extraction reuse the single engine walk this
/// dialog already runs (via [GameAnalysisWalkerService.annotateNodeChain]'s
/// returned moments) instead of re-analyzing the game.
///
/// It writes **no comment** under a move: since 22.9.2026 the tactical and
/// positional findings are not shown to the reader. So a review with neither
/// Blunder Alert nor puzzles on would walk the whole game (six minutes on a
/// phone) and change nothing; Start stays off until one of them is on, and
/// the end says what was found, never "commented". The owner waited out such
/// a walk on 24.9.2026 and went looking for the comments the dialog promised.
class GameReviewDialog extends StatefulWidget {
  final AnalysisNode rootNode;
  final AnalysisNode currentNode;
  final StockfishService stockfishService;

  /// Called once the walk has written its comments, before any puzzle is
  /// kept — the board behind is redrawn and its draft saved.
  final VoidCallback onCompleted;

  /// Where kept puzzles go (`POST /exercises`). Required: a puzzle found and
  /// kept nowhere is the old set on one device in a new form.
  final ExerciseApiService exerciseApi;

  /// The game's name, which the kept exercises are named after; null names
  /// them by the date.
  final String? gameTitle;

  const GameReviewDialog({
    super.key,
    required this.exerciseApi,
    this.gameTitle,
    required this.rootNode,
    required this.currentNode,
    required this.stockfishService,
    required this.onCompleted,
  });

  @override
  State<GameReviewDialog> createState() => _GameReviewDialogState();
}

class _GameReviewDialogState extends State<GameReviewDialog> {
  final GameAnalysisWalkerService _walker = GameAnalysisWalkerService();
  final LocalPuzzleExtractorService _puzzleExtractor =
      LocalPuzzleExtractorService();

  late int _engineDepth;
  bool _analyzeFromCurrent = false;

  double _blunderThreshold = 2.0;
  bool _blunderAlertEnabled = false;
  BlunderAlertSide _blunderSide = BlunderAlertSide.both;
  bool _insertBetterMoveLine = true;

  bool _extractPuzzlesEnabled = false;
  int _maxPuzzles = 5;

  bool _isRunning = false;
  bool _isDone = false;
  int _processed = 0;
  int _total = 1;

  int _taggedBlunders = 0;
  List<LocalPuzzle> _extractedPuzzles = const [];

  /// Whether the review would leave anything behind: the walk alone writes
  /// nothing onto the game.
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

  @override
  void initState() {
    super.initState();
    _engineDepth = AppSettingsService.instance.analysisDepth;
  }

  @override
  void dispose() {
    _walker.cancel();
    _puzzleExtractor.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _isRunning = true;
      _processed = 0;
      _total = _mainLineLength + 1;
    });

    final result = await _walker.annotateNodeChain(
      startNode: _effectiveStartNode,
      analyzer:
          EvalCache.instance.wrap(widget.stockfishService.analyzePositionSync),
      depth: _engineDepth,
      onProgress: (processed, total) {
        if (!mounted) return;
        setState(() {
          _processed = processed;
          _total = total;
        });
      },
    );

    if (!mounted) return;

    if (_blunderAlertEnabled) {
      _taggedBlunders = _walker.tagBlunders(
        chain: result.chain,
        moments: result.moments,
        threshold: _blunderThreshold,
        side: _blunderSide,
        insertAlternativeLine: _insertBetterMoveLine,
      );
    }

    if (_extractPuzzlesEnabled) {
      final found = _puzzleExtractor.buildPuzzlesFromMoments(
        result.moments,
        blunderThreshold: _blunderThreshold,
        maxPuzzles: _maxPuzzles,
      );
      // The game's last move has no next moment to take the answer from:
      // one search at this dialog's depth, and a puzzle it cannot answer is
      // listed as such and cannot be kept.
      final answered = <LocalPuzzle>[];
      for (final p in found) {
        if (p.refutationSan != null) {
          answered.add(p);
          continue;
        }
        final lines = await widget.stockfishService
            .analyzePositionSync(p.fen, depth: _engineDepth, multiPV: 1);
        if (!mounted) return;
        final san = lines.isEmpty ? '' : lines.first.bestMoveSan.trim();
        answered.add(p.withRefutation(san.isEmpty ? null : san));
      }
      _extractedPuzzles = answered;
    }

    if (!mounted) return;
    widget.onCompleted();
    setState(() => _isDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final moveCount = _mainLineLength;
    final progressPct =
        _total > 0 ? (_processed / _total).clamp(0.0, 1.0) : 0.0;

    return PopScope(
      // Blocks accidental barrier-tap / back-button dismissal while the
      // engine walk is running — losing a multi-minute analysis to a
      // misplaced tap was the #1 complaint about this dialog.
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_isRunning) return;
        AppFeedback.show(
          context,
          () => const SnackBar(
              content: Text('Wait for the analysis to finish or click Cancel.'),
              duration: Duration(seconds: 2)),
        );
      },
      child: Dialog(
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
                    children: !_isRunning
                        ? _buildSetupControls(moveCount)
                        : (_isDone
                            ? _buildDoneControls()
                            : _buildProgressControls(progressPct)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSetupControls(int moveCount) {
    return [
      Text(
        moveCount == 0
            ? 'No moves played from the selected position.'
            : 'The engine will step through $moveCount moves, mark the '
                'mistakes and find puzzles in them — choose which below. It '
                'writes no comment under a move; for that, use "Generate AI '
                'comment" on the move. Works on part of a game too.',
        style: AppText.body.copyWith(color: context.colors.textMuted),
      ),
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
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              'Blunder threshold: ${_blunderThreshold.toStringAsFixed(1)} pawns',
              style: AppText.body.copyWith(color: context.colors.textPrimary)),
        ],
      ),
      AppSlider(
        value: _blunderThreshold,
        min: 0.2,
        max: 5.0,
        divisions: 48,
        activeColor: context.colors.warning,
        onChanged: (val) => setState(() => _blunderThreshold = val),
      ),
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
          onPressed: moveCount == 0 || !_hasOutput ? null : _start,
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

  List<Widget> _buildDoneControls() {
    return [
      Center(
        child: Column(
          children: [
            Icon(Icons.check_circle, color: context.colors.accent, size: 36),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Done — reviewed $_processed positions.',
              textAlign: TextAlign.center,
              style: AppText.subtitle.copyWith(color: context.colors.accent),
            ),
            if (_blunderAlertEnabled) ...[
              const SizedBox(height: 6),
              Text(
                  _taggedBlunders == 1
                      ? 'Tagged 1 blunder.'
                      : 'Tagged $_taggedBlunders blunders.',
                  textAlign: TextAlign.center,
                  style:
                      AppText.body.copyWith(color: context.colors.textPrimary)),
            ],
            if (_extractPuzzlesEnabled && _extractedPuzzles.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'No puzzles found.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: context.colors.textPrimary),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (_extractedPuzzles.isNotEmpty)
              KeepPuzzlesPanel(
                puzzles: _extractedPuzzles,
                defaultName: widget.gameTitle ?? _gameOfToday(),
                api: widget.exerciseApi,
                // The exercises are written by now; the caller says so, on
                // its own screen, after this dialog is gone.
                onDone: (kept) => Navigator.pop(context, kept),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildProgressControls(double progressPct) {
    return [
      Center(
        child: Column(
          children: [
            LinearProgressIndicator(
                value: progressPct,
                backgroundColor: context.colors.surfaceRaised,
                color: context.colors.accent),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Positions processed: $_processed / $_total',
              style:
                  AppText.bodyLargeBold.copyWith(color: context.colors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              icon: Icon(Icons.cancel, color: context.colors.danger),
              label: Text('Cancel',
                  style: TextStyle(color: context.colors.danger)),
              onPressed: () {
                _walker.cancel();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ];
  }
}
