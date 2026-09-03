import 'package:flutter/material.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class BoardViewMenu extends StatelessWidget {
  const BoardViewMenu({
    super.key,
    this.size,
    this.color,
    this.arrows = false,
  });

  final double? size;
  final Color? color;
  final bool arrows;

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
          tooltip: 'Prikaz na tabli',
          itemBuilder: (context) {
            return [
              PopupMenuItem<void>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: IgnorePointer(
                  ignoring: false,
                  child: _MenuSwitch(
                    label: 'Koordinate',
                    valueGetter: () =>
                        AppSettingsService.instance.showBoardCoordinates,
                    onChanged: (v) =>
                        AppSettingsService.instance.setShowBoardCoordinates(v),
                  ),
                ),
              ),
              if (arrows) ...[
                const PopupMenuDivider(),
                PopupMenuItem<void>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: IgnorePointer(
                    ignoring: false,
                    child: _MenuSwitch(
                      label: 'Strelice odabranog poteza',
                      valueGetter: () =>
                          AppSettingsService.instance.showChosenMoveArrow,
                      onChanged: (v) =>
                          AppSettingsService.instance.setShowChosenMoveArrow(v),
                    ),
                  ),
                ),
                PopupMenuItem<void>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: IgnorePointer(
                    ignoring: false,
                    child: _MenuSwitch(
                      label: 'Strelice sa statistikom',
                      valueGetter: () =>
                          AppSettingsService.instance.showStatisticsArrows,
                      onChanged: (v) => AppSettingsService.instance
                          .setShowStatisticsArrows(v),
                    ),
                  ),
                ),
                PopupMenuItem<void>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: IgnorePointer(
                    ignoring: false,
                    child: _MenuSwitch(
                      label: 'Strelice motora',
                      valueGetter: () =>
                          AppSettingsService.instance.showEngineArrows,
                      onChanged: (v) =>
                          AppSettingsService.instance.setShowEngineArrows(v),
                    ),
                  ),
                ),
              ],
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
