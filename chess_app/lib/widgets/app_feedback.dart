import 'package:flutter/material.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';

/// One place to show the user a result of something that just happened,
/// instead of every screen building its own SnackBar (or, worse, only
/// `print()`-ing a failure and leaving the user staring at nothing).
abstract final class AppFeedback {
  /// Builds a SnackBar and shows it, or gives up quietly.
  ///
  /// `context.mounted` is not enough, and the log on 25.8.2026 is full of the
  /// proof: calling `showSnackBar` on the messenger throws *"Looking up a
  /// deactivated widget's ancestor is unsafe"* when the messenger it finds has
  /// itself been deactivated — a screen popped while a socket callback was
  /// still in flight, which in a room happens constantly.
  ///
  /// **A message that cannot be shown must never take down the thing it was
  /// reporting on.** That is the oldest lesson in this codebase: playback was
  /// broken for weeks because a failing audio call sat in front of the timer
  /// that actually ran the replay. Here it cost a recording that would not stop
  /// when a child's parent had refused it — the snackbar threw, and the line
  /// below it never ran.
  ///
  /// The bar arrives as a *builder* rather than as a built bar, because
  /// building one is itself an ancestor lookup on the same context —
  /// `context.colors` is `Theme.of(context)` — and a lookup that runs before
  /// the guard is a guard that does not guard. Everything the caller passes is
  /// built in here, behind both the mounted check and the catch.
  static void _show(BuildContext context, SnackBar Function() build) {
    if (!context.mounted) return;
    try {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(build());
    } catch (e) {
      // Deliberately swallowed, and deliberately logged: nothing the user does
      // depends on this, and everything they do depends on the caller.
      AppLogger.log('[Poruka] nije prikazana: $e');
    }
  }

  /// The escape hatch for a message the four helpers below cannot express — a
  /// [SnackBarAction], a close icon, a colour that carries its own meaning.
  /// Same promise as the rest: it either shows or it is logged, and either way
  /// the caller keeps running.
  ///
  /// New code should reach for [error], [success], [info] or [warning] first;
  /// this exists so that "build your own SnackBar" never means "go around
  /// AppFeedback".
  static void show(BuildContext context, SnackBar Function() build) =>
      _show(context, build);

  static void error(BuildContext context, String message) {
    _show(
      context,
      () => SnackBar(
        content: Text(message),
        backgroundColor: context.colors.danger.withValues(alpha: 0.9),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    _show(
      context,
      () => SnackBar(
        content: Text(message),
        backgroundColor: context.colors.success.withValues(alpha: 0.9),
      ),
    );
  }

  static void info(BuildContext context, String message) {
    _show(context, () => SnackBar(content: Text(message)));
  }

  /// A message that has to stay on screen long enough to be read — a refusal
  /// the user has to act on, rather than a confirmation they can miss.
  static void warning(BuildContext context, String message) {
    _show(
      context,
      () => SnackBar(
        content: Text(message, style: TextStyle(color: context.colors.canvas)),
        backgroundColor: context.colors.danger,
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
