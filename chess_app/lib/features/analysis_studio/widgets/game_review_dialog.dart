import 'package:flutter/material.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Walks [rootNode]'s main line through the engine and writes a combined
/// tactical+positional comment (and White-relative eval) into every move —
/// "review this whole game" in one click instead of stepping through move by
/// move.
class GameReviewDialog extends StatefulWidget {
  final AnalysisNode rootNode;
  final StockfishService stockfishService;
  final VoidCallback onCompleted;

  const GameReviewDialog({
    super.key,
    required this.rootNode,
    required this.stockfishService,
    required this.onCompleted,
  });

  @override
  State<GameReviewDialog> createState() => _GameReviewDialogState();
}

class _GameReviewDialogState extends State<GameReviewDialog> {
  final GameAnalysisWalkerService _walker = GameAnalysisWalkerService();

  late int _engineDepth;
  bool _overwriteExisting = false;

  bool _isRunning = false;
  bool _isDone = false;
  int _processed = 0;
  int _total = 1;

  int get _mainLineLength {
    var count = 0;
    var cur = widget.rootNode;
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
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _isRunning = true;
      _processed = 0;
      _total = _mainLineLength + 1;
    });

    await _walker.annotateNodeChain(
      rootNode: widget.rootNode,
      analyzer: widget.stockfishService.analyzePositionSync,
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
    widget.onCompleted();
    setState(() => _isDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final moveCount = _mainLineLength;
    final progressPct = _total > 0 ? (_processed / _total).clamp(0.0, 1.0) : 0.0;

    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check, color: context.colors.accent, size: 22),
                const SizedBox(width: 8),
                Text('Analiziraj celu partiju', style: AppText.title.copyWith(color: context.colors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isRunning) ...[
              Text(
                moveCount == 0
                    ? 'Trenutna partija nema odigranih poteza.'
                    : 'Motor će proći kroz svih $moveCount poteza glavne linije i za svaki zapisati taktički i pozicioni komentar plus eval.',
                style: AppText.body.copyWith(color: context.colors.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dubina motora (d): $_engineDepth', style: AppText.body.copyWith(color: context.colors.textPrimary)),
                  Text('depth $_engineDepth', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
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
                title: Text('Prepiši postojeće komentare', style: AppText.body.copyWith(color: context.colors.textPrimary)),
                onChanged: (val) => setState(() => _overwriteExisting = val ?? false),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Pokreni analizu', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: moveCount == 0 ? null : _start,
                ),
              ),
            ] else if (_isDone) ...[
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Zatvori'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    LinearProgressIndicator(value: progressPct, backgroundColor: Colors.grey.shade800, color: context.colors.accent),
                    const SizedBox(height: 16),
                    Text(
                      'Obrađeno pozicija: $_processed / $_total',
                      style: AppText.bodyLargeBold.copyWith(color: context.colors.accent),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: Icon(Icons.cancel, color: context.colors.danger),
                      label: Text('Otkaži', style: TextStyle(color: context.colors.danger)),
                      onPressed: () {
                        _walker.cancel();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
