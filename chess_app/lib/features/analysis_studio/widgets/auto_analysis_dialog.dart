import 'dart:math' as math;

import 'package:chess_app/services/app_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart';
import 'package:chess_app/services/stockfish_service.dart';

class AutoAnalysisDialog extends StatefulWidget {
  final AnalysisNode startNode;
  final StockfishService stockfishService;
  final VoidCallback onAnalysisCompleted;

  const AutoAnalysisDialog({
    super.key,
    required this.startNode,
    required this.stockfishService,
    required this.onAnalysisCompleted,
  });

  @override
  State<AutoAnalysisDialog> createState() => _AutoAnalysisDialogState();
}

class _AutoAnalysisDialogState extends State<AutoAnalysisDialog> {
  final AutoTreeGeneratorService _generatorService = AutoTreeGeneratorService();

  int _pliesDepth = 4; // N
  int _candidateCount = 2; // n
  late int _engineDepth; // d
  double _deltaCutoff = 1.5; // delta

  @override
  void initState() {
    super.initState();
    _engineDepth = AppSettingsService.instance.defaultEngineDepth;
  }

  bool _isAnalyzing = false;
  int _processedNodes = 0;
  int _totalEstimatedNodes = 10;
  String _statusMsg = '';

  /// Positions the engine will be asked to evaluate, before delta pruning:
  /// 1 at the root, n at the next ply, n^2 after that, and so on.
  int get _worstCasePositions =>
      _generatorService.calculateAnalyzedPositions(_pliesDepth, _candidateCount);

  /// Rough wall-clock estimate. Search cost grows sharply with depth, so this is
  /// a ballpark meant to stop obviously runaway settings, not a promise.
  int get _estimatedSeconds {
    final perPosition = 0.08 * math.pow(1.35, _engineDepth - 8);
    return (_worstCasePositions * perPosition).round();
  }

  bool get _isHeavy => _estimatedSeconds > 120;

  @override
  void dispose() {
    _generatorService.cancel();
    super.dispose();
  }

  void _startAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _processedNodes = 0;
      _statusMsg = 'Pokretanje automatskog generisanja...';
    });

    final params = AutoAnalysisParams(
      pliesDepth: _pliesDepth,
      candidateCount: _candidateCount,
      engineDepth: _engineDepth,
      deltaCutoff: _deltaCutoff,
    );

    await _generatorService.generateTree(
      startNode: widget.startNode,
      params: params,
      stockfishService: widget.stockfishService,
      onProgress: (processed, total, statusMsg) {
        if (!mounted) return;
        setState(() {
          _processedNodes = processed;
          _totalEstimatedNodes = total;
          _statusMsg = statusMsg;
        });
      },
    );

    if (mounted) {
      widget.onAnalysisCompleted();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPct = _totalEstimatedNodes > 0
        ? (_processedNodes / _totalEstimatedNodes).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Automatska Analiza Pozicije',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isAnalyzing) ...[
              const Text(
                'Podesite parametre za automatsku izgradnju stabla varijanti:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // N: Plies depth
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dubina pretrage (N polupoteza): $_pliesDepth', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  Text('$_pliesDepth polupoteza', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                ],
              ),
              Slider(
                value: _pliesDepth.toDouble(),
                min: 2,
                max: 6,
                divisions: 4,
                activeColor: Colors.tealAccent,
                onChanged: (val) => setState(() => _pliesDepth = val.round()),
              ),

              // n: Multi-PV candidates
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kandidat potezi (n linija): $_candidateCount', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  Text('Top $_candidateCount poteza', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                ],
              ),
              Slider(
                value: _candidateCount.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                activeColor: Colors.cyanAccent,
                onChanged: (val) => setState(() => _candidateCount = val.round()),
              ),

              // deltaCutoff: Centipawn cutoff
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cutoff prag (delta): ${_deltaCutoff.toStringAsFixed(1)} pešaka', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  Text('${(_deltaCutoff * 100).round()} cp', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                ],
              ),
              Slider(
                value: _deltaCutoff,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                activeColor: Colors.amberAccent,
                onChanged: (val) => setState(() => _deltaCutoff = val),
              ),

              // d: Engine depth per position — the single biggest driver of runtime.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dubina motora (d): $_engineDepth', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  Text('depth $_engineDepth', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                ],
              ),
              Slider(
                value: _engineDepth.toDouble(),
                min: 8,
                max: 22,
                divisions: 14,
                activeColor: Colors.orangeAccent,
                onChanged: (val) => setState(() => _engineDepth = val.round()),
              ),

              // Cost preview: N, n and d multiply out fast, so show the damage first.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isHeavy ? Colors.redAccent : Colors.grey.shade700),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isHeavy ? Icons.warning_amber : Icons.timer_outlined,
                      size: 16,
                      color: _isHeavy ? Colors.redAccent : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Do $_worstCasePositions pozicija na dubini $_engineDepth · procena ~$_estimatedSeconds s'
                        '${_isHeavy ? '\nSmanjite N, n ili d da skratite analizu.' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isHeavy ? Colors.redAccent : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Započni Automatsku Analizu ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _startAnalysis,
                ),
              ),
            ] else ...[
              // Progress view
              Center(
                child: Column(
                  children: [
                    LinearProgressIndicator(value: progressPct, backgroundColor: Colors.grey.shade800, color: Colors.amberAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Obrađeno čvorova: $_processedNodes / $_totalEstimatedNodes',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      label: const Text('Otkaži', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () {
                        _generatorService.cancel();
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
