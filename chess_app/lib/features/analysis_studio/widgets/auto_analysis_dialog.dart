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
      _statusMsg = 'Starting automatic generation...';
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
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: context.colors.warning, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Automatic Position Analysis',
                  style:
                      AppText.title.copyWith(color: context.colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_isAnalyzing) ...[
              Text(
                'Configure parameters for automatic variation tree generation:',
                style: AppText.body.copyWith(color: context.colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),

              // N: Plies depth
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Search depth (N plies): $_pliesDepth',
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary)),
                  Text('$_pliesDepth plies',
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
                  Text('Candidate moves (n lines): $_candidateCount',
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary)),
                  Text('Top $_candidateCount moves',
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
                      'Cutoff threshold (delta): ${_deltaCutoff.toStringAsFixed(1)} pawns',
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
                  Text('Engine depth (d): $_engineDepth',
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
                  borderRadius: AppRadii.roundedSm,
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
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Up to $_worstCasePositions positions at depth $_engineDepth · estimate ~$_estimatedSeconds s'
                        '${_isHeavy ? '\nReduce N, n, or d to shorten analysis.' : ''}',
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

              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Start Automatic Analysis ⚡',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.warning,
                    foregroundColor: context.colors.canvas,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Done! Analyzed $_processedNodes positions.',
                      textAlign: TextAlign.center,
                      style: AppText.subtitle
                          .copyWith(color: context.colors.accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'The upper bound was $_totalEstimatedNodes (without pruning). '
                      'Branches whose eval was worse than the best move by more than ${_deltaCutoff.toStringAsFixed(1)} pawns were skipped — this is expected, not an error.',
                      textAlign: TextAlign.center,
                      style: AppText.caption
                          .copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.accent,
                          foregroundColor: context.colors.canvas),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
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
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Nodes processed: $_processedNodes / $_totalEstimatedNodes',
                      style: AppText.bodyLargeBold
                          .copyWith(color: context.colors.accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _statusMsg,
                      textAlign: TextAlign.center,
                      style: AppText.body
                          .copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Note: the number above is the upper bound without pruning — branches with weaker moves are skipped, so the actual count almost always stops much earlier.',
                      textAlign: TextAlign.center,
                      style: AppText.micro
                          .copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      icon: Icon(Icons.cancel, color: context.colors.danger),
                      label: Text('Cancel',
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
