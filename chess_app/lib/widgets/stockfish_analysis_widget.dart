import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/widgets/engine_analysis_dials.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/engine_line_dialog.dart';

class StockfishAnalysisWidget extends StatelessWidget {
  final bool isEngineEnabled;
  final bool isAllowedToUseEngine;
  final bool isOnline;
  final bool isCustomEngineActive;
  final List<AnalysisLine> lines;
  final PlayerColor orientation;
  final VoidCallback onToggleEngine;
  final bool isShowEvalBarEnabled;
  final VoidCallback? onToggleShowEvalBar;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onForceRestart;
  final Function(String fen)? onLoadFenToMainBoard;

  /// Plays an engine line into the screen's own move tree, as a variation off
  /// the position being analysed. Null on a screen that has no move tree to
  /// put it in, and then no button for it is offered.
  final Function(AnalysisLine line)? onInsertLineAsVariation;

  /// This board's own analysis dials. Null on a screen that has no say over
  /// them — a small preview, or a board somebody else is driving.
  final int? analysisDepth;
  final int? analysisLines;
  final ValueChanged<int>? onAnalysisDepthChanged;
  final ValueChanged<int>? onAnalysisLinesChanged;

  const StockfishAnalysisWidget({
    super.key,
    required this.isEngineEnabled,
    required this.isAllowedToUseEngine,
    required this.isOnline,
    required this.isCustomEngineActive,
    required this.lines,
    required this.orientation,
    required this.onToggleEngine,
    this.isShowEvalBarEnabled = false,
    this.onToggleShowEvalBar,
    this.onOpenSettings,
    this.onForceRestart,
    this.onLoadFenToMainBoard,
    this.onInsertLineAsVariation,
    this.analysisDepth,
    this.analysisLines,
    this.onAnalysisDepthChanged,
    this.onAnalysisLinesChanged,
  });

  void _openLineDialog(BuildContext context, AnalysisLine line) {
    showDialog(
      context: context,
      builder: (ctx) => EngineLineDialog(
        line: line,
        orientation: orientation,
        onLoadFenToMainBoard: onLoadFenToMainBoard,
        onInsertLineAsVariation: onInsertLineAsVariation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bestLine = lines.isNotEmpty ? lines.first : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: colors.brand.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The two switches side by side, and this board's own dials under
            // them. A Wrap rather than a Row: the panel is narrow on a phone,
            // and a Row that does not fit is clipped in a release build with no
            // stripes painted to say so.
            Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Show the evaluation at all.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology, color: colors.accent, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Prikaži evaluaciju',
                              style: AppText.subtitle.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (onOpenSettings != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onOpenSettings,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Icon(Icons.settings,
                                      size: 14, color: colors.textMuted),
                                ),
                              ),
                            ],
                            if (onForceRestart != null && isEngineEnabled) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onForceRestart,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Tooltip(
                                    message:
                                        'Prekini i ponovo pokreni analizu trenutne pozicije',
                                    child: Icon(Icons.restart_alt,
                                        size: 15, color: colors.accent),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          !isAllowedToUseEngine
                              ? 'Zaključano od strane trenera'
                              : (isCustomEngineActive
                                  ? 'Sopstveni lokalni engine (.exe)'
                                  : (isOnline
                                      ? 'Spoljašnji Stockfish (Online API)'
                                      : 'Lokalni Engine (Nativni)')),
                          style: AppText.micro.copyWith(
                            color: !isAllowedToUseEngine
                                ? colors.danger
                                : colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isEngineEnabled,
                      activeThumbColor: colors.accent,
                      onChanged:
                          isAllowedToUseEngine ? (_) => onToggleEngine() : null,
                    ),
                  ],
                ),
                // And the bar under the board, which is a different question:
                // one is "do I want a number", the other "do I want to see it
                // on the board".
                if (onToggleShowEvalBar != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart, size: 18, color: colors.warning),
                      const SizedBox(width: 8),
                      Text(
                        'Prikaži evaluacionu liniju',
                        style: AppText.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary),
                      ),
                      Switch(
                        value: isShowEvalBarEnabled,
                        activeThumbColor: colors.warning,
                        onChanged: (_) => onToggleShowEvalBar?.call(),
                      ),
                    ],
                  ),
              ],
            ),

            // How deep, and how many lines — for this board, not for the
            // engine's playing strength. Shown even while the evaluation is
            // switched off, so it can be set before it is turned on.
            if (analysisDepth != null &&
                analysisLines != null &&
                isAllowedToUseEngine) ...[
              const SizedBox(height: 2),
              EngineAnalysisDials(
                depth: analysisDepth!,
                lines: analysisLines!,
                onDepthChanged: onAnalysisDepthChanged ?? (_) {},
                onLinesChanged: onAnalysisLinesChanged ?? (_) {},
              ),
            ],

            if (isEngineEnabled && isAllowedToUseEngine) ...[
              Divider(height: 16, color: colors.border),

              // Best Move & Main Evaluation Banner
              if (bestLine != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: colors.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Eval: ${bestLine.evaluation} (depth: ${bestLine.depth > 0 ? bestLine.depth : 0})',
                        style: AppText.bodyLargeBold
                            .copyWith(color: colors.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Najbolji potez: ',
                            style:
                                AppText.body.copyWith(color: colors.textMuted),
                          ),
                          Text(
                            bestLine.bestMoveSan.isNotEmpty
                                ? bestLine.bestMoveSan
                                : '...',
                            style: AppText.subtitle.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Top 3 Lines List (Compact 1 line per row with '...' inspector button)
              Text(
                'Top ${analysisLines ?? AppSettingsService.instance.analysisLines} '
                'Linije (Klik na liniju za kompletan pregled):',
                style: AppText.captionBold.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 4),

              if (lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Računanje poteza...',
                    style: AppText.caption.copyWith(
                        color: colors.textMuted, fontStyle: FontStyle.italic),
                  ),
                )
              else
                // As many as this board asked for, not as many as some global
                // setting says.
                ...lines
                    .take(analysisLines ??
                        AppSettingsService.instance.analysisLines)
                    .map((line) {
                  return InkWell(
                    onTap: () => _openLineDialog(context, line),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              line.evaluation,
                              style: AppText.captionBold.copyWith(
                                color: colors.accent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line.continuationSan,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption
                                  .copyWith(color: colors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (onInsertLineAsVariation != null)
                            IconButton(
                              onPressed: () => onInsertLineAsVariation!(line),
                              icon: const Icon(Icons.call_split, size: 16),
                              color: colors.accent,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              tooltip: 'Ubaci liniju kao varijaciju',
                            ),
                          Icon(Icons.more_horiz,
                              size: 16, color: colors.textMuted),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
