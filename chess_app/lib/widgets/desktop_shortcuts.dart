import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';

/// The two keys a desktop expects from any window, wrapped around the whole
/// app.
///
/// Here rather than on each screen because neither of them needs to know what
/// screen it is on: Escape leaves whatever is open, and the settings chord
/// opens a screen that draws itself over whatever was underneath. Doing it once
/// also means a screen added later gets them without being told.
///
/// Escape only ever *leaves*. It never closes something the reader is in the
/// middle of - a drill mid-move, a room - because those manage their own exit;
/// it pops a route the same way the back button does, and does nothing at all
/// on the shell, where there is nothing to pop.
class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({
    super.key,
    required this.router,
    required this.child,
  });

  /// Handed over rather than looked up. This sits above the navigator it acts
  /// on, so `GoRouter.maybeOf` from here finds nothing - the keys pressed and
  /// nothing happened, with no error to explain why.
  final GoRouter router;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (router.canPop()) router.pop();
        },
        // Ctrl+, is what every desktop application uses for preferences, and
        // this app already has a path for them that opens over the work rather
        // than replacing it.
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          final here = router.state.uri.path;
          // Not twice. Holding the chord would otherwise stack a settings
          // screen on top of a settings screen.
          if (here == AppRoutes.preferences) return;
          router.push(AppRoutes.preferences);
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
