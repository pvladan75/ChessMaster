import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Which of the Analysis board's panels are shown, and whether a move played
/// there is commented automatically — chosen from the board.
///
/// Both are read by the Analysis Studio and its own services and by nothing
/// else, so until 17.9.2026 changing what that screen does meant leaving it
/// for Settings and coming back. The choices are still remembered by
/// [AppSettingsService]; only where they are made moved. The screen listens to
/// the service, so a box ticked here changes the panels under the sheet.
const analysisPanels = <(String, String)>[
  ('Move tree', 'move_tree'),
  ('Tactical motifs', 'tactical_motifs'),
  ('Positional factors', 'positional_factors'),
  ('Opening Explorer', 'opening_explorer'),
  ('Tablebase (Syzygy)', 'syzygy'),
  ('Engine analysis panel', 'engine_analysis'),
];

Future<void> showAnalysisPanelsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const AnalysisPanelsSheet(),
  );
}

class AnalysisPanelsSheet extends StatelessWidget {
  const AnalysisPanelsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Panels and comments',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              for (final (label, key) in analysisPanels)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: settings.isPanelVisible(key),
                  title: Text(label, style: AppText.bodyLarge),
                  activeColor: context.colors.accent,
                  onChanged: (val) =>
                      settings.setPanelVisible(key, val ?? true),
                ),
              const Divider(height: AppSpacing.lg),
              // Worded the positive way round. The setting underneath is
              // `manualCommentMode`, and Settings asked the reader to tick
              // „manual" in order to turn something *off*.
              CheckboxListTile(
                key: const Key('analysis-auto-comments'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                visualDensity: VisualDensity.compact,
                value: !settings.manualCommentMode,
                title: const Text('Comment new moves automatically',
                    style: AppText.bodyLarge),
                subtitle: Text(
                  'Off: a move gets no comment until you pick which findings '
                  'to keep.',
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
                activeColor: context.colors.accent,
                onChanged: (val) =>
                    settings.setManualCommentMode(!(val ?? true)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
