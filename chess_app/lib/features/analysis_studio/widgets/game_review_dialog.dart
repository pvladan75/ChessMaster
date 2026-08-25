import 'package:chess_app/core/services/eval_cache.dart';
import 'package:flutter/material.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Walks the game through the engine and, in one pass:
/// - writes a combined tactical+positional comment (and White-relative eval)
///   into every move ("review this whole game" instead of stepping through
///   move by move);
/// - optionally tags blunders ('??') and adds the engine's suggested
///   improvement as a short side variation ("Blunder Alert");
/// - optionally extracts the same blunders as a set of puzzles, auto-saved
///   on-device (see [LocalPuzzleSetStorageService]).
///
/// Blunder tagging and puzzle extraction reuse the single engine walk this
/// dialog already runs (via [GameAnalysisWalkerService.annotateNodeChain]'s
/// returned moments) instead of re-analyzing the game.
class GameReviewDialog extends StatefulWidget {
  final AnalysisNode rootNode;
  final AnalysisNode currentNode;
  final StockfishService stockfishService;
  final void Function({List<LocalPuzzle>? extractedPuzzles}) onCompleted;

  const GameReviewDialog({
    super.key,
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
  bool _overwriteExisting = false;
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
    _engineDepth = AppSettingsService.instance.defaultEngineDepth;
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
      overwriteExisting: _overwriteExisting,
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
      final puzzles = _puzzleExtractor.buildPuzzlesFromMoments(
        result.moments,
        blunderThreshold: _blunderThreshold,
        maxPuzzles: _maxPuzzles,
      );
      if (puzzles.isNotEmpty) {
        final now = DateTime.now();
        final title =
            'Vežbe od ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        await LocalPuzzleSetStorageService.instance
            .saveSet(title: title, puzzles: puzzles);
      }
      if (!mounted) return;
      _extractedPuzzles = puzzles;
    }

    if (!mounted) return;
    widget.onCompleted(
        extractedPuzzles: _extractedPuzzles.isEmpty ? null : _extractedPuzzles);
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
              content: Text('Sačekajte kraj analize ili kliknite Otkaži.'),
              duration: Duration(seconds: 2)),
        );
      },
      child: Dialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
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
                      const SizedBox(width: 8),
                      Text('Analiziraj partiju',
                          style: AppText.title
                              .copyWith(color: context.colors.textPrimary)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.textMuted),
                    tooltip: 'Zatvori',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
            ? 'Nema odigranih poteza od izabrane pozicije.'
            : 'Motor će proći kroz $moveCount poteza i za svaki zapisati taktički i pozicioni komentar plus eval. Radi i nad delom partije — vidi opciju ispod.',
        style: AppText.body.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Dubina motora (d): $_engineDepth',
              style: AppText.body.copyWith(color: context.colors.textPrimary)),
          Text('depth $_engineDepth',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
        ],
      ),
      Slider(
        value: _engineDepth.toDouble(),
        min: 5,
        max: 30,
        divisions: 25,
        activeColor: Colors.orangeAccent,
        onChanged: (val) => setState(() => _engineDepth = val.round()),
      ),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _overwriteExisting,
        title: Text('Prepiši postojeće komentare',
            style: AppText.body.copyWith(color: context.colors.textPrimary)),
        onChanged: (val) => setState(() => _overwriteExisting = val ?? false),
      ),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _analyzeFromCurrent && _hasCurrentNodeOption,
        title: Text(
          'Analiziraj samo od trenutne pozicije nadalje',
          style: AppText.body.copyWith(
              color: _hasCurrentNodeOption
                  ? context.colors.textPrimary
                  : context.colors.textMuted),
        ),
        subtitle: !_hasCurrentNodeOption
            ? Text('Trenutna pozicija je već početak partije.',
                style: AppText.micro.copyWith(color: context.colors.textMuted))
            : null,
        onChanged: _hasCurrentNodeOption
            ? (val) => setState(() => _analyzeFromCurrent = val ?? false)
            : null,
      ),
      const Divider(height: 20),
      Text('Otkrivanje grešaka',
          style: AppText.bodyBold.copyWith(color: context.colors.textPrimary)),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Prag greške: ${_blunderThreshold.toStringAsFixed(1)} pešaka',
              style: AppText.body.copyWith(color: context.colors.textPrimary)),
        ],
      ),
      Slider(
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
        title: Text('Blunder Alert — označi greške i predloži bolji potez',
            style: AppText.body.copyWith(color: context.colors.textPrimary)),
        onChanged: (val) => setState(() => _blunderAlertEnabled = val ?? false),
      ),
      if (_blunderAlertEnabled) ...[
        Padding(
          padding: const EdgeInsets.only(left: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<BlunderAlertSide>(
                segments: const [
                  ButtonSegment(
                      value: BlunderAlertSide.both, label: Text('Oba')),
                  ButtonSegment(
                      value: BlunderAlertSide.white, label: Text('Beli')),
                  ButtonSegment(
                      value: BlunderAlertSide.black, label: Text('Crni')),
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
                title: Text('Dodaj kratku liniju sa boljim potezom',
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
        title: Text('Izvuci vežbe iz otkrivenih grešaka',
            style: AppText.body.copyWith(color: context.colors.textPrimary)),
        onChanged: (val) =>
            setState(() => _extractPuzzlesEnabled = val ?? false),
      ),
      if (_extractPuzzlesEnabled)
        Padding(
          padding: const EdgeInsets.only(left: 32.0),
          child: Row(
            children: [
              Text('Maks. broj vežbi: $_maxPuzzles',
                  style: AppText.caption
                      .copyWith(color: context.colors.textPrimary)),
              Expanded(
                child: Slider(
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
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Pokreni analizu',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: moveCount == 0 ? null : _start,
        ),
      ),
    ];
  }

  List<Widget> _buildDoneControls() {
    return [
      Center(
        child: Column(
          children: [
            Icon(Icons.check_circle, color: context.colors.accent, size: 36),
            const SizedBox(height: 12),
            Text(
              'Gotovo! Komentarisano $_processed pozicija.',
              textAlign: TextAlign.center,
              style: AppText.subtitle.copyWith(color: context.colors.accent),
            ),
            if (_blunderAlertEnabled) ...[
              const SizedBox(height: 6),
              Text('Označeno $_taggedBlunders grešaka.',
                  textAlign: TextAlign.center,
                  style:
                      AppText.body.copyWith(color: context.colors.textPrimary)),
            ],
            if (_extractPuzzlesEnabled) ...[
              const SizedBox(height: 6),
              Text(
                _extractedPuzzles.isEmpty
                    ? 'Nije pronađena nijedna vežba.'
                    : 'Izvučeno ${_extractedPuzzles.length} vežbi (sačuvano).',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: context.colors.textPrimary),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Zatvori'),
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
                backgroundColor: Colors.grey.shade800,
                color: context.colors.accent),
            const SizedBox(height: 16),
            Text(
              'Obrađeno pozicija: $_processed / $_total',
              style:
                  AppText.bodyLargeBold.copyWith(color: context.colors.accent),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(Icons.cancel, color: context.colors.danger),
              label: Text('Otkaži',
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
