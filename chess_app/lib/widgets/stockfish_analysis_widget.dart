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
    final shown = lines
        .take(analysisLines ?? AppSettingsService.instance.analysisLines)
        .toList();
    final running = isEngineEnabled && isAllowedToUseEngine;

    // The repertoire's „Pitaj motor" panel, which the owner picked on 4.9.2026
    // as the shape every engine readout should take: a bordered block on the
    // surface colour rather than a tinted Card, one accent heading, one muted
    // line saying which engine is answering, and then the lines themselves.
    //
    // **Only the appearance was brought over.** The switch stays — this panel
    // runs the engine continuously and the repertoire's asks once — and so does
    // the dialog on tap, because these screens have somewhere to put a line and
    // the repertoire's board does not. Both were decided, not assumed.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const SizedBox(height: AppSpacing.xxs),
          // Which engine is answering, and from whose side the number reads.
          // One muted line under the heading, the same slot the repertoire uses
          // for „Ocena je iz ugla belog" — and it says that too, because the
          // convention is the app's rather than this screen's.
          Text(
            !isAllowedToUseEngine
                ? 'Zaključano od strane trenera'
                : '${_engineName()} — ocena je iz ugla belog.',
            style: AppText.micro.copyWith(
              color: !isAllowedToUseEngine ? colors.danger : colors.textMuted,
            ),
          ),
          if (onToggleShowEvalBar != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            _evalBarSwitch(context),
          ],
          // How deep, and how many lines — for this board, not for the engine's
          // playing strength. Shown even while the evaluation is switched off,
          // so it can be set before it is turned on.
          if (analysisDepth != null &&
              analysisLines != null &&
              isAllowedToUseEngine) ...[
            const SizedBox(height: 6),
            EngineAnalysisDials(
              depth: analysisDepth!,
              lines: analysisLines!,
              onDepthChanged: onAnalysisDepthChanged ?? (_) {},
              onLinesChanged: onAnalysisLinesChanged ?? (_) {},
            ),
          ],
          if (running) ...[
            const SizedBox(height: AppSpacing.xs),
            if (shown.isEmpty)
              Text(
                'Računanje poteza...',
                style: AppText.micro.copyWith(color: colors.textMuted),
              )
            else
              for (final line in shown) _line(context, line),
            if (shown.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Dodirnite liniju za kompletan pregled.',
                style: AppText.micro.copyWith(color: colors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Which engine is behind the number, in the words the settings screen uses.
  String _engineName() {
    if (isCustomEngineActive) return 'Sopstveni lokalni engine (.exe)';
    return isOnline ? 'Spoljašnji Stockfish (Online API)' : 'Lokalni motor';
  }

  /// „Motor", the two icons that act on it, and the switch that runs it.
  ///
  /// A `Wrap` rather than a `Row`: the panel is narrow on a phone, and a `Row`
  /// that does not fit is clipped in a release build with no stripes painted to
  /// say so. That shape has cost this project time three times already.
  Widget _header(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined, size: 16, color: colors.accent),
            const SizedBox(width: 6),
            Text('Motor',
                style: AppText.bodyBold.copyWith(color: colors.accent)),
            if (onOpenSettings != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onOpenSettings,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child:
                      Icon(Icons.settings, size: 14, color: colors.textMuted),
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
                    child:
                        Icon(Icons.restart_alt, size: 15, color: colors.accent),
                  ),
                ),
              ),
            ],
            // The engine is on and has said nothing yet. The repertoire's panel
            // spins in the same place for the same reason: a panel that stays
            // blank is indistinguishable from an engine that is not answering.
            if (isEngineEnabled && isAllowedToUseEngine && lines.isEmpty) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.accent),
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text('Prikaži evaluaciju',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: colors.textMuted)),
            ),
            Switch(
              value: isEngineEnabled,
              activeThumbColor: colors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: isAllowedToUseEngine ? (_) => onToggleEngine() : null,
            ),
          ],
        ),
      ],
    );
  }

  /// The bar under the board, which is a different question: one is „do I want
  /// a number", the other „do I want to see it on the board".
  Widget _evalBarSwitch(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bar_chart, size: 14, color: colors.textMuted),
        const SizedBox(width: 6),
        // Flexible, because the label is long in Serbian and the switch beside
        // it is a fixed 60. A Row that does not fit is clipped in a release
        // build with nothing painted to say so, and this one is within a few
        // pixels of the edge at 360 dp before the reader raises their font
        // size at all.
        Flexible(
          child: Text('Prikaži evaluacionu liniju',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: colors.textMuted)),
        ),
        Switch(
          value: isShowEvalBarEnabled,
          activeThumbColor: colors.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (_) => onToggleShowEvalBar?.call(),
        ),
      ],
    );
  }

  /// One line, in the repertoire panel's columns: the number, the move it
  /// starts with, the rest of it, and how deep the search was.
  ///
  /// The depth sits on every row rather than once in a banner above them. The
  /// lines arrive at different depths and get better while the search runs, so
  /// one number over all of them is right about the first row and wrong about
  /// the others.
  Widget _line(BuildContext context, AnalysisLine line) {
    final colors = context.colors;
    return InkWell(
      onTap: () => _openLineDialog(context, line),
      borderRadius: AppRadii.roundedXs,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(line.evaluation,
                  style: AppText.bodyBold.copyWith(color: colors.textPrimary)),
            ),
            SizedBox(
              width: 52,
              child: Text(
                line.bestMoveSan.isNotEmpty ? line.bestMoveSan : '…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(color: colors.textPrimary),
              ),
            ),
            Expanded(
              child: Text(
                line.continuationSan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ),
            if (line.depth > 0)
              Text('d${line.depth}',
                  style: AppText.micro.copyWith(color: colors.textMuted)),
            if (onInsertLineAsVariation != null)
              IconButton(
                onPressed: () => onInsertLineAsVariation!(line),
                icon: const Icon(Icons.call_split, size: 16),
                color: colors.accent,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                tooltip: 'Ubaci liniju kao varijaciju',
              ),
          ],
        ),
      ),
    );
  }
}
