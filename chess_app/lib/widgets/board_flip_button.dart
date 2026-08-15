import 'package:flutter/material.dart';

/// The one button that flips the board's perspective.
///
/// It exists because the same action had grown four different icons —
/// `flip`, `flip_camera_android`, `swap_vert` and `rotate_right`/`rotate_left`
/// — across seven call sites, so the control a trainer reaches for looked
/// different on almost every screen. `swap_vert` is the survivor: it was
/// already the most common, and swapping the two sides vertically is literally
/// what the action does.
///
/// [size] is available because the strips this sits in are not all the same
/// height, but the icon and tooltip deliberately are not configurable — the
/// point of this widget is that they cannot drift apart again.
class BoardFlipButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double? size;
  final Color? color;

  const BoardFlipButton({
    super.key,
    required this.onPressed,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.swap_vert, size: size, color: color),
      tooltip: 'Okreni tablu',
      onPressed: onPressed,
    );
  }
}
