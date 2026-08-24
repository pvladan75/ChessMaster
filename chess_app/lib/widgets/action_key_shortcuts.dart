import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Whether the reader is in the middle of typing something.
///
/// Every shortcut that overlaps with a key a text field needs has to ask this
/// before it acts, and there must be one answer rather than one per screen: the
/// first copy of this condition, written inline for Ctrl+C, was wrong for a
/// week before anyone noticed that it was copying a position instead of the
/// selected words.
bool readerIsTyping() {
  final focused = FocusManager.instance.primaryFocus?.context;
  return focused != null &&
      (focused.widget is EditableText ||
          focused.findAncestorWidgetOfExactType<EditableText>() != null);
}

/// Keys a focused control already answers for itself.
///
/// Space presses the button that has the focus, and that is not a rule this app
/// gets to break: someone walking the screen with Tab has to be able to press
/// what they landed on. So these are bound only while the screen itself still
/// holds the focus - which, on the one screen that uses one, is exactly the
/// case where nothing else wants the key.
///
/// Not `const`: a constant set may not rely on an overridden equality, and
/// [LogicalKeyboardKey] has one.
final _sharedWithControls = <LogicalKeyboardKey>{
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.enter,
};

class _ActionKeyIntent extends Intent {
  const _ActionKeyIntent(this.key);

  final LogicalKeyboardKey key;
}

/// An [Action] and not a line in `CallbackShortcuts`, for the reason Ctrl+C
/// paid for: a callback binding swallows the key whether or not the callback
/// did anything, and a binding inside a screen sits closer to the focus than
/// Flutter's own text-editing shortcuts do. A disabled action declines the key
/// instead, and it travels on to whoever else wants it.
class _ActionKeyAction extends Action<_ActionKeyIntent> {
  _ActionKeyAction(this.bindings, this.node);

  /// Read on every press rather than captured: what a key means changes with
  /// the screen, and a map handed over once would answer for the screen as it
  /// was when the wrapper was built.
  final Map<LogicalKeyboardKey, VoidCallback?> Function() bindings;

  final FocusNode node;

  @override
  bool isEnabled(_ActionKeyIntent intent) {
    // Null means the button this key stands for is not on the screen right now.
    // Declining is the whole point: a key that works when its button does not
    // is a second, invisible way to do something, and it is the way nobody can
    // see to check.
    if (bindings()[intent.key] == null) return false;
    if (readerIsTyping()) return false;
    if (_sharedWithControls.contains(intent.key) &&
        FocusManager.instance.primaryFocus != node) {
      return false;
    }
    return true;
  }

  @override
  void invoke(_ActionKeyIntent intent) => bindings()[intent.key]!();
}

/// Single keys for the buttons a screen is already showing.
///
/// The rule this keeps is that a shortcut is never a second path to something:
/// each key stands for a button, and it does nothing at all when that button is
/// not there or is disabled. The caller says so by passing null, which is why
/// the map is of nullable callbacks - the alternative is a key that works in
/// states the screen does not offer, and no way to notice.
///
/// Single letters only where nothing is typed. While a text field has the
/// focus, the letter belongs to the field, and [readerIsTyping] is what makes
/// sure of it.
class ActionKeyShortcuts extends StatefulWidget {
  const ActionKeyShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });

  /// A key, and what it presses. Null where that button is not on the screen.
  final Map<LogicalKeyboardKey, VoidCallback?> bindings;

  final Widget child;

  @override
  State<ActionKeyShortcuts> createState() => _ActionKeyShortcutsState();
}

class _ActionKeyShortcutsState extends State<ActionKeyShortcuts> {
  final FocusNode _node = FocusNode(debugLabel: 'ActionKeyShortcuts');
  late final _ActionKeyAction _action =
      _ActionKeyAction(() => widget.bindings, _node);

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        for (final key in widget.bindings.keys)
          SingleActivator(key): _ActionKeyIntent(key),
      },
      child: Actions(
        actions: {_ActionKeyIntent: _action},
        child: Focus(
          focusNode: _node,
          // Holds the focus the route would otherwise keep for itself. A press
          // is offered to whatever has the focus and then to its ancestors, so
          // a binding sitting below the focused node is never asked - and a
          // freshly opened screen leaves the focus on the route. That is the
          // difference between a key that works and one that works "sometimes,
          // after you click something first".
          autofocus: true,
          // Here to hear keys, not to be a stop on the Tab tour.
          skipTraversal: true,
          child: widget.child,
        ),
      ),
    );
  }
}
