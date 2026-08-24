import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chess_app/core/models/move_cursor.dart';

/// Arrow keys for the move strip, wrapped around a screen that has one.
///
/// A desktop application that can only be walked with the mouse reads as a
/// phone application in a window, and stepping through a game is the thing this
/// app does most. The keys match what every board program uses: left and right
/// for one move, up and down for the ends.
///
/// It drives the same [MoveCursor] the buttons do, so there is one notion of
/// where the reader is and no second copy to keep in step. [onChanged] is the
/// screen's own "the cursor moved" - usually the very callback the strip's
/// buttons already run.
///
/// Text fields keep the keys they need: this listens on a [Focus] that does not
/// take focus for itself, so while a comment box has it, the arrows are the
/// comment box's.
class MoveKeyboardShortcuts extends StatelessWidget {
  const MoveKeyboardShortcuts({
    super.key,
    required this.cursor,
    required this.onChanged,
    required this.child,
    this.enabled = true,
  });

  final MoveCursor cursor;

  /// Called after the cursor has been moved, so the screen can redraw the board
  /// and whatever else follows the position.
  final VoidCallback onChanged;

  /// False where the screen may not be navigated - a seat in a room that does
  /// not drive the shared board, a drill that is being played rather than read.
  final bool enabled;

  final Widget child;

  void _step(void Function() move, bool allowed) {
    if (!enabled || !allowed) return;
    move();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _step(cursor.previous, cursor.canGoBack),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _step(cursor.next, cursor.canGoForward),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _step(cursor.first, cursor.canGoBack),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _step(cursor.last, cursor.canGoForward),
        // Home and End say the same thing as up and down, and are what a
        // reader coming from a text editor reaches for. Two names for one jump
        // costs a line here and saves the reader from having to learn ours.
        const SingleActivator(LogicalKeyboardKey.home): () =>
            _step(cursor.first, cursor.canGoBack),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _step(cursor.last, cursor.canGoForward),
      },
      child: Focus(
        // Holds the focus this screen would otherwise leave on the route itself
        // — and that is the whole difference between working and not. A key
        // press is offered to whatever has focus and then to its ancestors, so
        // a binding sitting *below* the focused node is never asked: without
        // this the arrows did nothing until the reader happened to click
        // something inside the screen first.
        //
        // Only when nothing else wants it. A text field takes the focus when it
        // is tapped, and from then on the arrows are the field's, which is what
        // anyone typing a comment expects.
        autofocus: true,
        // Never a stop on the Tab tour: it is here to hear keys, not to be
        // reached.
        skipTraversal: true,
        child: child,
      ),
    );
  }
}
