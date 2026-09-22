import 'package:flutter/material.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_slider.dart';

class BoardViewMenu extends StatelessWidget {
  const BoardViewMenu({
    super.key,
    this.size,
    this.color,
    this.arrows = false,
    this.boardSize = false,
    bool? chosenMove,
    bool? statistics,
    bool? engine,
  })  : chosenMove = chosenMove ?? arrows,
        statistics = statistics ?? arrows,
        engine = engine ?? arrows;

  final double? size;
  final Color? color;

  /// All three arrow switches. The three below name them one at a time.
  final bool arrows;

  /// Which arrow switches this screen actually governs.
  ///
  /// Default to [arrows], so every existing caller keeps all three. A screen
  /// draws some layers and not others — the walkthrough has statistics and no
  /// engine, by design — and offering a switch for a layer that screen never
  /// draws is the „menu that does nothing" this codebase has already paid for
  /// twice. `board_arrows_reach_test` reads the sources for both halves of
  /// that: a layer drawn with no switch, and a switch offered for no layer.
  final bool chosenMove;
  final bool statistics;
  final bool engine;

  /// The board size slider. Off by default, and on only where the screen
  /// really sizes its board by `boardSizeScale` — the room, the exercise
  /// screen and the Analysis Studio. It lived in Settings until 17.9.2026,
  /// where it read as app-wide while every other board ignored it.
  /// `board_view_menu_reach_test` holds both halves: a screen that reads the scale
  /// offers the slider on every menu it mounts, and no other screen does.
  final bool boardSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final settings = AppSettingsService.instance;
        final showingCoords = settings.showBoardCoordinates;

        return PopupMenuButton<void>(
          icon: Icon(showingCoords ? Icons.grid_on : Icons.grid_off,
              size: size, color: color),
          tooltip: 'Board view',
          itemBuilder: (context) {
            return [
              PopupMenuItem<void>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: IgnorePointer(
                  ignoring: false,
                  child: _MenuSwitch(
                    label: 'Coordinates',
                    valueGetter: () =>
                        AppSettingsService.instance.showBoardCoordinates,
                    onChanged: (v) =>
                        AppSettingsService.instance.setShowBoardCoordinates(v),
                  ),
                ),
              ),
              if (boardSize) ...[
                const PopupMenuDivider(),
                const PopupMenuItem<void>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: _BoardSizeSlider(),
                ),
              ],
              if (chosenMove || statistics || engine) const PopupMenuDivider(),
              if (chosenMove)
                PopupMenuItem<void>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: IgnorePointer(
                    ignoring: false,
                    child: _MenuSwitch(
                      label: 'Arrows for the selected move',
                      valueGetter: () =>
                          AppSettingsService.instance.showChosenMoveArrow,
                      onChanged: (v) =>
                          AppSettingsService.instance.setShowChosenMoveArrow(v),
                    ),
                  ),
                ),
              if (statistics)
                PopupMenuItem<void>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: IgnorePointer(
                    ignoring: false,
                    child: _MenuSwitch(
                      label: 'Arrows with statistics',
                      valueGetter: () =>
                          AppSettingsService.instance.showStatisticsArrows,
                      onChanged: (v) => AppSettingsService.instance
                          .setShowStatisticsArrows(v),
                    ),
                  ),
                ),
              if (engine)
                PopupMenuItem<void>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: IgnorePointer(
                    ignoring: false,
                    child: _MenuSwitch(
                      label: 'Engine arrows',
                      valueGetter: () =>
                          AppSettingsService.instance.showEngineArrows,
                      onChanged: (v) =>
                          AppSettingsService.instance.setShowEngineArrows(v),
                    ),
                  ),
                ),
            ];
          },
        );
      },
    );
  }
}

class _MenuSwitch extends StatelessWidget {
  const _MenuSwitch({
    required this.label,
    required this.valueGetter,
    required this.onChanged,
  });

  final String label;
  final bool Function() valueGetter;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppText.body.copyWith(color: context.colors.textPrimary),
          ),
          ListenableBuilder(
            listenable: AppSettingsService.instance,
            builder: (context, _) {
              return Switch(
                value: valueGetter(),
                onChanged: onChanged,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BoardSizeSlider extends StatelessWidget {
  const _BoardSizeSlider();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final scale = AppSettingsService.instance.boardSizeScale;
        final percent = '${(scale * 100).round()}%';
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Board size',
                      style: AppText.body
                          .copyWith(color: context.colors.textPrimary),
                    ),
                  ),
                  Text(
                    percent,
                    style:
                        AppText.bodyBold.copyWith(color: context.colors.accent),
                  ),
                ],
              ),
              AppSlider(
                value: scale.clamp(0.6, 1.0),
                min: 0.6,
                max: 1.0,
                divisions: 8,
                label: percent,
                onChanged: AppSettingsService.instance.setBoardSizeScale,
              ),
            ],
          ),
        );
      },
    );
  }
}
