import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/core/services/board_on_screen.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/widgets/action_key_shortcuts.dart';

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
class CtrlPhysical extends ShortcutActivator {
  const CtrlPhysical(this.key);

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

/// Ctrl+C over a board: copy the position, the pair to the right click.
///
/// An [Action] rather than one more line in [CallbackShortcuts], because the
/// difference is what happens when it should *not* run. A callback binding
/// swallows the key whether or not the callback did anything, and this binding
/// sits closer to whatever has focus than Flutter's own text-editing shortcuts
/// do — so as a callback it took Ctrl+C away from every comment box in the app,
/// copying a chess position instead of the selected words, or nothing at all.
///
/// A disabled action declines the key instead, and it carries on up to the text
/// field's own copy. So: not while the reader is typing, and not where there is
/// no board to copy from.
class _CopyBoardIntent extends Intent {
  const _CopyBoardIntent();
}

class _CopyBoardAction extends Action<_CopyBoardIntent> {
  @override
  bool isEnabled(_CopyBoardIntent intent) {
    if (!BoardOnScreen.isPresent) return false;
    // The same question the letter keys ask, asked in one place: a second copy
    // of this condition is a second chance to get it wrong.
    return !readerIsTyping();
  }

  @override
  void invoke(_CopyBoardIntent intent) => BoardOnScreen.copyPosition();
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

  /// Opens [path] over whatever is underneath, and never twice.
  ///
  /// Holding the key down, or two bindings matching the same press, would
  /// otherwise stack the screen on top of itself — and then one Escape leaves
  /// the reader looking at a copy of what they just closed.
  void _openOver(String path) {
    if (router.state.uri.path == path) return;
    router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyC, control: true):
            _CopyBoardIntent(),
      },
      child: Actions(
        actions: {_CopyBoardIntent: _CopyBoardAction()},
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (router.canPop()) router.pop();
            },
            // Ctrl+, is what every desktop application uses for preferences, and
            // this app already has a path for them that opens over the work rather
            // than replacing it.
            const SingleActivator(LogicalKeyboardKey.comma, control: true):
                () => _openOver(AppRoutes.preferences),
            // The same chord by position, for layouts where the logical key that
            // arrives is not a comma.
            const CtrlPhysical(PhysicalKeyboardKey.comma): () =>
                _openOver(AppRoutes.preferences),
            // F1 and not `?`: the question mark is a character someone can be in
            // the middle of typing into a comment or a room code, and a binding
            // above the whole app would take it out of the field. F1 is a key
            // nothing types, on every layout, which is the same reason the settings
            // chord had to be bound by position.
            const SingleActivator(LogicalKeyboardKey.f1): () =>
                _openOver(AppRoutes.shortcuts),
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
        ),
      ),
    );
  }
}
