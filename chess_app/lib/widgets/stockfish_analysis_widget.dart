import 'package:chess_app/services/app_settings_service.dart';
import 'package:flutter/material.dart';
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
  final Function(String fen)? onLoadFenToMainBoard;

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
    this.onLoadFenToMainBoard,
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
            // Top Bar: Title, Engine Status & Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Prikaži evaluaciju',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (onOpenSettings != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onOpenSettings,
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Icon(Icons.settings, size: 14, color: Colors.grey),
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
                                  : (isOnline ? 'Spoljašnji Stockfish (Online API)' : 'Lokalni Engine (Nativni)')),
                          style: TextStyle(
                            fontSize: 10,
                            color: !isAllowedToUseEngine ? Colors.redAccent : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: isEngineEnabled,
                  activeThumbColor: Colors.tealAccent,
                  onChanged: isAllowedToUseEngine ? (_) => onToggleEngine() : null,
                ),
              ],
            ),

            if (onToggleShowEvalBar != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bar_chart, size: 18, color: Colors.amberAccent),
                      SizedBox(width: 8),
                      Text(
                        'Prikaži evaluacionu liniju',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                  Switch(
                    value: isShowEvalBarEnabled,
                    activeThumbColor: Colors.amberAccent,
                    onChanged: (_) => onToggleShowEvalBar?.call(),
                  ),
                ],
              ),
            ],

            if (isEngineEnabled && isAllowedToUseEngine) ...[
              const Divider(height: 16),

              // Best Move & Main Evaluation Banner
              if (bestLine != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Eval: ${bestLine.evaluation} (depth: ${bestLine.depth > 0 ? bestLine.depth : 0})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.tealAccent),
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
                            bestLine.bestMoveSan.isNotEmpty ? bestLine.bestMoveSan : '...',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
                'Top ${AppSettingsService.instance.defaultMultiPV} Linije (Klik na liniju za kompletan pregled):',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              if (lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Računanje poteza...',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...lines.take(AppSettingsService.instance.defaultMultiPV).map((line) {
                  return InkWell(
                    onTap: () => _openLineDialog(context, line),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
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
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
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
