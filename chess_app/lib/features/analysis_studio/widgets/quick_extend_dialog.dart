import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// One-click branch extension: "add the engine's best line from here" —
/// unlike [AutoAnalysisDialog] (which branches into several candidate moves
/// per ply), this always asks for exactly one candidate per ply
/// ([AutoTreeGeneratorService] with `candidateCount: 1`), so the result is a
/// single straight continuation with no tree to configure — just how many
/// moves deep.
class QuickExtendDialog extends StatefulWidget {
  final AnalysisNode startNode;
  final StockfishService stockfishService;

  /// Called with the last node actually appended (null if none — e.g. the
  /// position was already game-over) once the run finishes.
  final ValueChanged<AnalysisNode?> onCompleted;

  const QuickExtendDialog({
    super.key,
    required this.startNode,
    required this.stockfishService,
    required this.onCompleted,
  });

  @override
  State<QuickExtendDialog> createState() => _QuickExtendDialogState();
}

class _QuickExtendDialogState extends State<QuickExtendDialog> {
  final AutoTreeGeneratorService _generator = AutoTreeGeneratorService();

  int _plies = 6;
  bool _isRunning = false;
  bool _isDone = false;
  int _processed = 0;
  int _total = 1;
  AnalysisNode? _lastAdded;

  @override
  void dispose() {
    _generator.cancel();
    super.dispose();
  }

  AnalysisNode _deepestMainLineDescendant(AnalysisNode node) {
    var cur = node;
    while (cur.children.isNotEmpty) {
      cur = cur.children.first;
    }
    return cur;
  }

  Future<void> _start() async {
    setState(() {
      _isRunning = true;
      _processed = 0;
      _total = _plies;
    });

    await _generator.generateTree(
      startNode: widget.startNode,
      params: AutoAnalysisParams(pliesDepth: _plies, candidateCount: 1),
      stockfishService: widget.stockfishService,
      onProgress: (processed, total, statusMsg) {
        if (!mounted) return;
        setState(() {
          _processed = processed;
          _total = total;
        });
      },
    );

    if (!mounted) return;
    final deepest = _deepestMainLineDescendant(widget.startNode);
    setState(() {
      _lastAdded = deepest.id == widget.startNode.id ? null : deepest;
      _isDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressPct =
        _total > 0 ? (_processed / _total).clamp(0.0, 1.0) : 0.0;

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_isRunning) return;
        AppFeedback.show(
          context,
          () => const SnackBar(
              content: Text('Sačekajte kraj ili kliknite Otkaži.'),
              duration: Duration(seconds: 2)),
        );
      },
      child: Dialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_flat,
                          color: context.colors.accent, size: 22),
                      const SizedBox(width: 8),
                      Text('Produži granu',
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
              if (!_isRunning)
                ..._buildSetup()
              else if (_isDone)
                ..._buildDone()
              else
                ..._buildProgress(progressPct),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSetup() {
    return [
      Text(
        'Motor odigrava svoj najbolji potez, iz poteza u potez, i dodaje ih kao pravu liniju (bez grananja) iza trenutne pozicije.',
        style: AppText.body.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Broj poteza: $_plies',
              style: AppText.body.copyWith(color: context.colors.textPrimary)),
        ],
      ),
      Slider(
        value: _plies.toDouble(),
        min: 1,
        max: 16,
        divisions: 15,
        activeColor: context.colors.accent,
        onChanged: (val) => setState(() => _plies = val.round()),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Dodaj poteze'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _start,
        ),
      ),
    ];
  }

  List<Widget> _buildProgress(double progressPct) {
    return [
      Center(
        child: Column(
          children: [
            LinearProgressIndicator(
                value: progressPct,
                backgroundColor: context.colors.surfaceRaised,
                color: context.colors.accent),
            const SizedBox(height: 16),
            Text(
              'Odigrano poteza: $_processed / $_total',
              style:
                  AppText.bodyLargeBold.copyWith(color: context.colors.accent),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(Icons.cancel, color: context.colors.danger),
              label: Text('Otkaži',
                  style: TextStyle(color: context.colors.danger)),
              onPressed: () {
                _generator.cancel();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildDone() {
    return [
      Center(
        child: Column(
          children: [
            Icon(Icons.check_circle, color: context.colors.accent, size: 36),
            const SizedBox(height: 12),
            Text(
              _lastAdded == null
                  ? 'Nije dodat nijedan potez (kraj partije?).'
                  : 'Dodato $_processed poteza.',
              textAlign: TextAlign.center,
              style: AppText.subtitle.copyWith(color: context.colors.accent),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                widget.onCompleted(_lastAdded);
                Navigator.pop(context);
              },
              child: const Text('Zatvori'),
            ),
          ],
        ),
      ),
    ];
  }
}
