import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_spacing.dart';

/// A word of an app bar that opens a list under itself — „Board", „Save as…".
///
/// [height] pixels tall whatever the text is: a `PopupMenuButton` is as big as
/// its child, and a bare word is a target the height of its letters (measured
/// 20 px). Forty fits the 44 px bar of a phone held on its side
/// (`LandscapeBoardLayout.compactToolbarHeight`).
class BarWordMenu<T> extends StatelessWidget {
  const BarWordMenu({
    super.key,
    required this.word,
    required this.onSelected,
    required this.itemBuilder,
  });

  static const double height = 40;

  final String word;
  final PopupMenuItemSelected<T> onSelected;
  final PopupMenuItemBuilder<T> itemBuilder;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        itemBuilder: itemBuilder,
        child: SizedBox(
          height: height,
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(word),
            ),
          ),
        ),
      );
}

/// A word of an app bar that does one thing — „Open in Analysis", „Share…" —
/// drawn exactly as [BarWordMenu] draws its word, so that a bar of menus and
/// actions reads as one row of words rather than two kinds of control.
class BarWordButton extends StatelessWidget {
  const BarWordButton({
    super.key,
    required this.word,
    required this.onPressed,
  });

  final String word;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: BarWordMenu.height,
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(word),
            ),
          ),
        ),
      );
}
