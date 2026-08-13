import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';

/// One place to show the user a result of something that just happened,
/// instead of every screen building its own SnackBar (or, worse, only
/// `print()`-ing a failure and leaving the user staring at nothing).
abstract final class AppFeedback {
  static void error(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.colors.danger.withValues(alpha: 0.9),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.colors.success.withValues(alpha: 0.9),
      ),
    );
  }

  static void info(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
