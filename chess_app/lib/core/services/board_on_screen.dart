import 'package:flutter/widgets.dart';

/// Which board a keyboard shortcut is talking about.
///
/// Ctrl+C is bound once, above every screen, because a key that copies the
/// position on one board and does nothing on another is worse than no key at
/// all. But the binding sits above the navigator and the position sits inside a
/// screen, so the board announces itself as it appears and takes the
/// announcement back when it goes.
///
/// A stack rather than one slot: a dialog with a board over a screen with a
/// board must hand the screen back when it closes, and only a stack remembers
/// what was underneath. The top of it is what the keyboard means by "the
/// board" — the same thing the reader means, since it is the one drawn last
/// and over everything else.
///
/// What is registered is not the position but the *act* of copying it, so the
/// key and the right click end in the same line of code and cannot drift into
/// two behaviours. It also lets the board show its own confirmation with its
/// own context, which is a thing the global binding has no way to do.
class BoardOnScreen {
  BoardOnScreen._();

  static final List<VoidCallback> _stack = [];

  /// Called by a board as it mounts. The same callback must be handed to
  /// [forget] on the way out, which is why it is kept rather than rebuilt.
  static void register(VoidCallback copyPosition) => _stack.add(copyPosition);

  static void forget(VoidCallback copyPosition) => _stack.remove(copyPosition);

  /// True when there is a board to copy from at all.
  static bool get isPresent => _stack.isNotEmpty;

  /// Copies the position of the board drawn last, or does nothing where there
  /// is no board. Nothing is the honest answer on a screen without one: there
  /// is no position, so there is nothing to say about it either.
  static void copyPosition() {
    if (_stack.isEmpty) return;
    _stack.last();
  }

  /// For tests, which must not inherit a board left behind by another one.
  @visibleForTesting
  static void reset() => _stack.clear();
}
