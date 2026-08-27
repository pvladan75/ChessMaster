import 'package:chess_app/services/app_settings_service.dart';
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bestLine = lines.isNotEmpty ? lines.first : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.deepPurple.withValues(alpha: 0.15),
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
                    const Icon(Icons.psychology,
                        color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Prikaži evaluaciju',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (onOpenSettings != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onOpenSettings,
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Icon(Icons.settings,
                                      size: 14, color: Colors.grey),
                                ),
                              ),
                            ],
                            if (onForceRestart != null && isEngineEnabled) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onForceRestart,
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Tooltip(
                                    message:
                                        'Prekini i ponovo pokreni analizu trenutne pozicije',
                                    child: Icon(Icons.restart_alt,
                                        size: 15, color: Colors.tealAccent),
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
                          style: TextStyle(
                            fontSize: 10,
                            color: !isAllowedToUseEngine
                                ? Colors.redAccent
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isEngineEnabled,
                      activeThumbColor: Colors.tealAccent,
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
                      const Icon(Icons.bar_chart,
                          size: 18, color: Colors.amberAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'Prikaži evaluacionu liniju',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      Switch(
                        value: isShowEvalBarEnabled,
                        activeThumbColor: Colors.amberAccent,
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
              const Divider(height: 16),

              // Best Move & Main Evaluation Banner
              if (bestLine != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.tealAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Eval: ${bestLine.evaluation} (depth: ${bestLine.depth > 0 ? bestLine.depth : 0})',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.tealAccent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Najbolji potez: ',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            bestLine.bestMoveSan.isNotEmpty
                                ? bestLine.bestMoveSan
                                : '...',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
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
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              if (lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Računanje poteza...',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic),
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
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.tealAccent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line.continuationSan,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.more_horiz,
                              size: 16, color: Colors.grey),
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
