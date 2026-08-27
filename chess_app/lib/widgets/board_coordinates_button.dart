import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';

/// The one button that shows or hides the letters and numbers around a board.
///
/// Written once, for the same reason [BoardFlipButton] was: the same action
/// grown four icons across seven screens is a control that looks different
/// everywhere a person meets it. This one is `grid_on` when the labels are
/// showing and `grid_off` when they are not, and the tooltip says which way
/// pressing it goes.
///
/// The setting itself is app-wide ([AppSettingsService.showBoardCoordinates]),
/// so this is a shortcut to it rather than a per-screen switch: turning the
/// labels off in a lesson leaves them off in the endgame trainer, which is what
/// somebody who finds them cluttered means by turning them off.
class BoardCoordinatesButton extends StatelessWidget {
  const BoardCoordinatesButton({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final showing = AppSettingsService.instance.showBoardCoordinates;
        return IconButton(
          icon: Icon(showing ? Icons.grid_on : Icons.grid_off,
              size: size, color: color),
          tooltip: showing ? 'Sakrij koordinate' : 'Prikaži koordinate',
          onPressed: () =>
              AppSettingsService.instance.setShowBoardCoordinates(!showing),
        );
      },
    );
  }
}
