import 'package:flutter/material.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Walks [rootNode]'s main line looking for blunders (a big eval swing
/// against whoever just moved) and packages each one as a "winning
/// position" exercise — the position right after the mistake, with a
/// tactical-motif theme label — so a trainer can turn a played game into a
/// set of exercises in one click.
class ExtractPuzzlesDialog extends StatefulWidget {
  final AnalysisNode rootNode;
  final StockfishService stockfishService;
  final ValueChanged<LocalPuzzle> onPuzzleSelected;

  const ExtractPuzzlesDialog({
    super.key,
    required this.rootNode,
    required this.stockfishService,
    required this.onPuzzleSelected,
  });

  @override
  State<ExtractPuzzlesDialog> createState() => _ExtractPuzzlesDialogState();
}

class _ExtractPuzzlesDialogState extends State<ExtractPuzzlesDialog> {
  final LocalPuzzleExtractorService _extractor = LocalPuzzleExtractorService();

  late int _engineDepth;
  double _threshold = 2.0;
  int _maxPuzzles = 5;

  bool _isRunning = false;
  bool _isDone = false;
  int _processed = 0;
  int _total = 1;
  List<LocalPuzzle> _results = const [];

  List<String> get _mainLineUci {
    final uci = <String>[];
    var cur = widget.rootNode;
    while (cur.children.isNotEmpty) {
      cur = cur.children.first;
      uci.add(cur.moveUci ?? '');
    }
    return uci;
  }

  @override
  void initState() {
    super.initState();
    _engineDepth = AppSettingsService.instance.defaultEngineDepth;
  }

  @override
  void dispose() {
    _extractor.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _isRunning = true;
      _processed = 0;
    });

    final results = await _extractor.extractPuzzles(
      startingFen: widget.rootNode.fen,
      uciMoves: _mainLineUci,
      analyzer: widget.stockfishService.analyzePositionSync,
      blunderThreshold: _threshold,
      maxPuzzles: _maxPuzzles,
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
    setState(() {
      _results = results;
      _isDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final moveCount = _mainLineUci.length;
    final progressPct = _total > 0 ? (_processed / _total).clamp(0.0, 1.0) : 0.0;

    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension, color: context.colors.accent, size: 22),
                const SizedBox(width: 8),
                Text('Pretvori partiju u vežbe', style: AppText.title.copyWith(color: context.colors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isRunning) ...[
              Text(
                moveCount == 0
                    ? 'Trenutna partija nema odigranih poteza.'
                    : 'Motor prolazi kroz svih $moveCount poteza i pretvara svaki veći pad evaluacije u vežbu.',
                style: AppText.body.copyWith(color: context.colors.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prag greške: ${_threshold.toStringAsFixed(1)} pešaka', style: AppText.body.copyWith(color: context.colors.textPrimary)),
                ],
              ),
              Slider(
                value: _threshold,
                min: 1.0,
                max: 5.0,
                divisions: 8,
                activeColor: context.colors.warning,
                onChanged: (val) => setState(() => _threshold = val),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Maks. broj vežbi: $_maxPuzzles', style: AppText.body.copyWith(color: context.colors.textPrimary)),
                ],
              ),
              Slider(
                value: _maxPuzzles.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: context.colors.accent,
                onChanged: (val) => setState(() => _maxPuzzles = val.round()),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Pronađi vežbe', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: moveCount == 0 ? null : _start,
                ),
              ),
            ] else if (_isDone) ...[
              if (_results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Nije pronađena nijedna greška veća od ${_threshold.toStringAsFixed(1)} pešaka u ovoj partiji.',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: context.colors.textMuted),
                  ),
                )
              else ...[
                Text('Pronađeno ${_results.length} vežbi:', style: AppText.bodyBold.copyWith(color: context.colors.textPrimary)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _results.map((p) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.black26,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.extension, color: context.colors.accent, size: 18),
                            title: Text(
                              p.themeLabel,
                              style: AppText.caption.copyWith(color: context.colors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Posle ${p.sourceMoveSan} · pad ${p.swing.abs().toStringAsFixed(1)} pešaka',
                              style: AppText.micro.copyWith(color: context.colors.textMuted),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onPuzzleSelected(p);
                              },
                              child: const Text('Prikaži'),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zatvori'),
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
                        _extractor.cancel();
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
