import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/app_logger.dart';

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
/// Ctrl plus a key identified by where it sits, not by what it types.
///
/// [SingleActivator] matches the *logical* key, which is what the layout says
/// the key produces - and on a Serbian layout the key next to M does not
/// necessarily hand Flutter a comma when Ctrl is down. The chord is then bound
/// to a key nobody can press, silently: nothing happens and nothing is logged.
///
/// The physical key is the same hole in the plastic on every layout, so this
/// matches by that. The logical binding is kept beside it, since either may be
/// the one that arrives.
class _CtrlPhysical extends ShortcutActivator {
  const _CtrlPhysical(this.key);

  final PhysicalKeyboardKey key;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      event is KeyDownEvent &&
      event.physicalKey == key &&
      state.isControlPressed;

  /// Null means "offer me every key event": the trigger cannot be listed as a
  /// logical key, which is the whole point of this class.
  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  String debugDescribeKeys() => 'Ctrl + ${key.debugName}';
}

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

  void _openSettings() {
    // Not twice. Holding the chord, or having both bindings match the same
    // press, would otherwise stack a settings screen on top of a settings
    // screen.
    if (router.state.uri.path == AppRoutes.preferences) return;
    router.push(AppRoutes.preferences);
  }

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
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            _openSettings(),
        // The same chord by position, for layouts where the logical key that
        // arrives is not a comma.
        const _CtrlPhysical(PhysicalKeyboardKey.comma): () => _openSettings(),
      },
      child: Focus(
        autofocus: true,
        // Says what actually arrived when a chord does not fire. A shortcut
        // bound to a key the layout never produces is the quietest failure
        // there is - nothing happens and nothing is written down - and this is
        // the line that would have found it in one press instead of one guess.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              HardwareKeyboard.instance.isControlPressed) {
            AppLogger.log(
                '[Prečice] Ctrl + logički ${event.logicalKey.keyLabel}'
                ' / fizički ${event.physicalKey.debugName}');
          }
          // Never swallowed: this only watches.
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }
}
