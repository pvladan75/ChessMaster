import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Which of the Analysis board's panels are shown — chosen from the board.
///
/// The tactical and positional panels and the switch that commented a new
/// move from them were removed on 22.9.2026: those findings are for the AI
/// only.
///
/// The panels are read by the Analysis Studio and by nothing else, so until
/// 17.9.2026 changing what that screen does meant leaving it for Settings and
/// coming back. From then until 30.9.2026 they were a sheet behind a bar icon
/// of their own; since `docs/PLAN-ANALIZA-TRAKA.md` they are rows of the
/// board view menu, which is the one place that says what the screen shows.
/// The choices are still remembered by [AppSettingsService], and this file is
/// still the only one that writes them. The screen listens to the service, so
/// a box ticked here changes the panels under the open menu.
const analysisPanels = <(String, String)>[
  ('Move tree', 'move_tree'),
  ('Opening Explorer', 'opening_explorer'),
  ('Tablebase (Syzygy)', 'syzygy'),
  ('Engine analysis panel', 'engine_analysis'),
];

/// The panels as entries of a popup menu: a heading and a checkbox a row.
///
/// Each row is a disabled item with a control of its own inside, as the
/// menu's switches are — a tick must not close the menu, because the reader
/// is looking at the screen change under it.
List<PopupMenuEntry<void>> analysisPanelMenuEntries(BuildContext context) => [
      PopupMenuItem<void>(
        enabled: false,
        height: 32,
        child: Text('Panels',
            style:
                AppText.captionBold.copyWith(color: context.colors.textMuted)),
      ),
      for (final (label, key) in analysisPanels)
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _PanelCheck(label: label, panel: key),
        ),
    ];

class _PanelCheck extends StatelessWidget {
  const _PanelCheck({required this.label, required this.panel});

  final String label;
  final String panel;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final shown = settings.isPanelVisible(panel);
        return InkWell(
          key: Key('analysis-panel-$label'),
          onTap: () => settings.setPanelVisible(panel, !shown),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            child: Row(
              children: [
                // The row is the target; the box only shows the state, so a
                // tap on it is the row's tap and not a second one.
                IgnorePointer(
                  child: Checkbox(
                    value: shown,
                    activeColor: context.colors.accent,
                    onChanged: (_) {},
                  ),
                ),
                Flexible(
                  child: Text(
                    label,
                    style: AppText.body
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }
}
