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
          child: _PanelCheck(
            label: label,
            keyPrefix: 'analysis-panel',
            isShown: () => AppSettingsService.instance.isPanelVisible(key),
            toggle: (shown) =>
                AppSettingsService.instance.setPanelVisible(key, shown),
          ),
        ),
    ];

class _PanelCheck extends StatelessWidget {
  const _PanelCheck({
    required this.label,
    required this.keyPrefix,
    required this.isShown,
    required this.toggle,
  });

  final String label;

  /// `analysis-panel` for Analysis, `<scope>-panel` for a writing screen.
  final String keyPrefix;
  final bool Function() isShown;
  final void Function(bool shown) toggle;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final shown = isShown();
        return InkWell(
          key: Key('$keyPrefix-$label'),
          onTap: () => toggle(!shown),
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

/// The screens where a tutorial is written, each remembering its own panels
/// (`docs/PLAN-MOTOR-I-PANELI.md`, D1–D2).
enum PanelScope { preparation, studio }

/// The board panels a writing screen offers: Analysis's rows and words, so
/// one tick means one thing everywhere (D1). The move tree is not one of
/// them — both screens always show their own.
const writingPanels = <(String, String)>[
  ('Engine analysis panel', 'engine_analysis'),
  ('Opening Explorer', 'opening_explorer'),
  ('Tablebase (Syzygy)', 'syzygy'),
];

/// What each writing screen shows before its reader ticks anything (D2):
/// Preparation its engine, as before the plan; the studio nothing.
const writingPanelDefaults = <PanelScope, Set<String>>{
  PanelScope.preparation: {'engine_analysis'},
  PanelScope.studio: {},
};

/// Whether [scope] shows the panel [key] — remembered, or its default.
bool writingPanelShown(PanelScope scope, String key) =>
    AppSettingsService.instance.isPanelShownIn(scope.name, key) ??
    writingPanelDefaults[scope]!.contains(key);

/// Ticks [key] on or off in [scope], for this screen alone.
Future<void> setWritingPanelShown(PanelScope scope, String key, bool shown) =>
    AppSettingsService.instance.setPanelShownIn(scope.name, key, shown,
        defaults: writingPanelDefaults[scope]!);

/// [scope]'s panels as entries of the board view menu — a heading and a
/// checkbox a row, as Analysis's ([analysisPanelMenuEntries]).
List<PopupMenuEntry<void>> writingPanelMenuEntries(
        BuildContext context, PanelScope scope) =>
    [
      PopupMenuItem<void>(
        enabled: false,
        height: 32,
        child: Text('Panels',
            style:
                AppText.captionBold.copyWith(color: context.colors.textMuted)),
      ),
      for (final (label, key) in writingPanels)
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _PanelCheck(
            label: label,
            keyPrefix: '${scope.name}-panel',
            isShown: () => writingPanelShown(scope, key),
            toggle: (shown) => setWritingPanelShown(scope, key, shown),
          ),
        ),
    ];
