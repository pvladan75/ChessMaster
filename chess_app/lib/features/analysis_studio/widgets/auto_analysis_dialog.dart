import 'dart:math' as math;

import 'package:chess_app/services/app_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class AutoAnalysisDialog extends StatefulWidget {
  final AnalysisNode startNode;
  final StockfishService stockfishService;

  /// Called with the deltaCutoff the tree was actually generated with, so
  /// the tree view's post-hoc display filter can cap its slider there —
  /// letting the user pick a display cutoff *higher* than what generation
  /// used would silently do nothing (those branches were never generated),
  /// which would be a misleading control to offer.
  final ValueChanged<double> onAnalysisCompleted;

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
    _engineDepth = AppSettingsService.instance.analysisDepth;
  }

  bool _isAnalyzing = false;
  int _processedNodes = 0;
  int _totalEstimatedNodes = 10;
  String _statusMsg = '';
  bool _isDone = false;

  /// Positions the engine will be asked to evaluate, before delta pruning:
  /// 1 at the root, n at the next ply, n^2 after that, and so on.
  int get _worstCasePositions => _generatorService.calculateAnalyzedPositions(
      _pliesDepth, _candidateCount);

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
      widget.onAnalysisCompleted(_deltaCutoff);
      setState(() {
        _isDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPct = _totalEstimatedNodes > 0
        ? (_processedNodes / _totalEstimatedNodes).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: context.colors.warning, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Automatska Analiza Pozicije',
                  style:
                      AppText.title.copyWith(color: context.colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isAnalyzing) ...[
              Text(
                'Podesite parametre za automatsku izgradnju stabla varijanti:',
                style: AppText.body.copyWith(color: context.colors.textMuted),
              ),
              const SizedBox(height: 12),

              // N: Plies depth
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dubina pretrage (N polupoteza): $_pliesDepth',
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary)),
                  Text('$_pliesDepth polupoteza',
                      style: AppText.bodyBold
                          .copyWith(color: context.colors.accent)),
                ],
              ),
              Slider(
                value: _pliesDepth.toDouble(),
                min: 2,
                max: 6,
                divisions: 4,
                activeColor: context.colors.accent,
                onChanged: (val) => setState(() => _pliesDepth = val.round()),
              ),

              // n: Multi-PV candidates
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kandidat potezi (n linija): $_candidateCount',
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary)),
                  Text('Top $_candidateCount poteza',
                      style: AppText.bodyBold
                          .copyWith(color: context.colors.info)),
                ],
              ),
              Slider(
                value: _candidateCount.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                activeColor: context.colors.info,
                onChanged: (val) =>
                    setState(() => _candidateCount = val.round()),
              ),

              // deltaCutoff: Centipawn cutoff
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'Cutoff prag (delta): ${_deltaCutoff.toStringAsFixed(1)} pešaka',
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary)),
                  Text('${(_deltaCutoff * 100).round()} cp',
                      style: AppText.bodyBold
                          .copyWith(color: context.colors.warning)),
                ],
              ),
              Slider(
                value: _deltaCutoff,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                activeColor: context.colors.warning,
                onChanged: (val) => setState(() => _deltaCutoff = val),
              ),

              // d: Engine depth per position — the single biggest driver of runtime.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dubina motora (d): $_engineDepth',
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary)),
                  Text('depth $_engineDepth',
                      style: AppText.bodyBold
                          .copyWith(color: context.colors.warning)),
                ],
              ),
              Slider(
                value: _engineDepth.toDouble(),
                min: 5,
                max: 50,
                divisions: 45,
                activeColor: context.colors.warning,
                onChanged: (val) => setState(() => _engineDepth = val.round()),
              ),

              // Cost preview: N, n and d multiply out fast, so show the damage first.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _isHeavy
                          ? context.colors.danger
                          : context.colors.surfaceRaised),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isHeavy ? Icons.warning_amber : Icons.timer_outlined,
                      size: 16,
                      color: _isHeavy
                          ? context.colors.danger
                          : context.colors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Do $_worstCasePositions pozicija na dubini $_engineDepth · procena ~$_estimatedSeconds s'
                        '${_isHeavy ? '\nSmanjite N, n ili d da skratite analizu.' : ''}',
                        style: AppText.caption.copyWith(
                          color: _isHeavy
                              ? context.colors.danger
                              : context.colors.textMuted,
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
                  label: const Text('Započni Automatsku Analizu ⚡',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.warning,
                    foregroundColor: context.colors.canvas,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _startAnalysis,
                ),
              ),
            ] else if (_isDone) ...[
              // Done view — pruning almost always stops the real count well
              // short of the worst-case ceiling, so spell that out instead of
              // just vanishing on whatever number the progress bar last showed.
              Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle,
                        color: context.colors.accent, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Gotovo! Analizirano $_processedNodes pozicija.',
                      textAlign: TextAlign.center,
                      style: AppText.subtitle
                          .copyWith(color: context.colors.accent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gornja granica je bila $_totalEstimatedNodes (da nije bilo orezivanja). '
                      'Grane čiji je eval bio gori od najboljeg poteza za više od ${_deltaCutoff.toStringAsFixed(1)} pešaka su preskočene — to je očekivano, ne greška.',
                      textAlign: TextAlign.center,
                      style: AppText.caption
                          .copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.accent,
                          foregroundColor: context.colors.canvas),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Zatvori'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Progress view
              Center(
                child: Column(
                  children: [
                    LinearProgressIndicator(
                        value: progressPct,
                        backgroundColor: context.colors.surfaceRaised,
                        color: context.colors.warning),
                    const SizedBox(height: 16),
                    Text(
                      'Obrađeno čvorova: $_processedNodes / $_totalEstimatedNodes',
                      style: AppText.bodyLargeBold
                          .copyWith(color: context.colors.accent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMsg,
                      textAlign: TextAlign.center,
                      style: AppText.body
                          .copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Napomena: broj iznad je gornja granica bez orezivanja — grane sa slabijim potezima se preskaču pa se stvarni broj skoro uvek zaustavi mnogo ranije.',
                      textAlign: TextAlign.center,
                      style: AppText.micro
                          .copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: Icon(Icons.cancel, color: context.colors.danger),
                      label: Text('Otkaži',
                          style: TextStyle(color: context.colors.danger)),
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
