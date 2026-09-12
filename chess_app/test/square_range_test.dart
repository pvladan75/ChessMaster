import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';

/// Phase 4 of `docs/PLAN-OZNAKE-NA-TABLI.md`: marking a line of squares in one
/// gesture instead of one tap each.
///
/// The controller has no widget and no board in it, so this is a plain test
/// file — the pure core landed before the button that reaches it, on the rule
/// this repository already keeps.
void main() {
  late BoardAnnotationController controller;
  late List<SquareMark> squares;
  late List<ChessArrow> arrows;

  setUp(() {
    controller = BoardAnnotationController(mode: AnnotationMode.square)
      ..setColor('G');
    squares = [];
    arrows = [];
  });

  /// Two taps with the range on, which is what one gesture is.
  bool range(String from, String to) {
    controller.tap(from, arrows: arrows, squares: squares, asRange: true);
    return controller.tap(to, arrows: arrows, squares: squares, asRange: true);
  }

  Set<String> marked() => squares.map((s) => s.square).toSet();

  group('squaresBetween — which pairs are a line at all', () {
    test('a file', () {
      expect(squaresBetween('a2', 'a7'), ['a2', 'a3', 'a4', 'a5', 'a6', 'a7']);
    });

    test('a rank', () {
      expect(squaresBetween('a2', 'e2'), ['a2', 'b2', 'c2', 'd2', 'e2']);
    });

    test('a diagonal', () {
      expect(squaresBetween('a2', 'd5'), ['a2', 'b3', 'c4', 'd5']);
    });

    test('and the same three read backwards', () {
      expect(squaresBetween('a7', 'a2'), ['a7', 'a6', 'a5', 'a4', 'a3', 'a2']);
      expect(squaresBetween('e2', 'a2'), ['e2', 'd2', 'c2', 'b2', 'a2']);
      expect(squaresBetween('d5', 'a2'), ['d5', 'c4', 'b3', 'a2']);
    });

    test('the other diagonal, which a sign error gets wrong', () {
      expect(squaresBetween('a8', 'd5'), ['a8', 'b7', 'c6', 'd5']);
      expect(squaresBetween('h1', 'e4'), ['h1', 'g2', 'f3', 'e4']);
    });

    test('one square is a line of one', () {
      expect(squaresBetween('d4', 'd4'), ['d4']);
    });

    test('a pair on no line at all is null, not a rectangle', () {
      // Inferring a block from two corners would surprise anyone who
      // mis-clicked, and a rectangle is a different feature.
      for (final pair in [
        ('a2', 'c7'),
        ('d4', 'e6'),
        ('a1', 'b8'),
        ('h8', 'a2'),
      ]) {
        expect(squaresBetween(pair.$1, pair.$2), isNull,
            reason: '${pair.$1}-${pair.$2} is not a file, rank or diagonal');
      }
    });

    test('a name that is not a square is null', () {
      for (final pair in [
        ('z9', 'a2'),
        ('a2', 'z9'),
        ('', 'a2'),
        ('a', 'a2')
      ]) {
        expect(squaresBetween(pair.$1, pair.$2), isNull, reason: pair.$1);
      }
    });
  });

  group('two taps mark the line', () {
    test('a file, in the chosen colour', () {
      expect(range('a2', 'a7'), isTrue);
      expect(marked(), {'a2', 'a3', 'a4', 'a5', 'a6', 'a7'});
      expect(squares.every((s) => s.colorCode == 'G'), isTrue);
    });

    test('the first tap changes nothing and says so', () {
      expect(
          controller.tap('a2', arrows: arrows, squares: squares, asRange: true),
          isFalse,
          reason: 'a caller that recorded an edit here would put a half-made '
              'gesture in the undo history');
      expect(squares, isEmpty);
    });

    test('a diagonal', () {
      expect(range('a2', 'd5'), isTrue);
      expect(marked(), {'a2', 'b3', 'c4', 'd5'});
    });

    test('a pair on no line marks only the square just tapped', () {
      expect(range('a2', 'c7'), isTrue);
      expect(marked(), {'c7'});
    });
  });

  group('a range sets, it does not toggle each square', () {
    test('over a half-marked file, everything ends up marked', () {
      // Toggling each square would come out checkerboarded, which is nobody's
      // intention and takes another range to undo.
      controller.tap('a3', arrows: arrows, squares: squares);
      controller.tap('a5', arrows: arrows, squares: squares);
      expect(marked(), {'a3', 'a5'});

      expect(range('a2', 'a7'), isTrue);
      expect(marked(), {'a2', 'a3', 'a4', 'a5', 'a6', 'a7'});
    });

    test('and a square already marked in another colour is repainted', () {
      controller.setColor('R');
      controller.tap('a4', arrows: arrows, squares: squares);
      controller.setColor('G');

      expect(range('a2', 'a7'), isTrue);
      expect(squares.every((s) => s.colorCode == 'G'), isTrue,
          reason: 'one square of the line is still the colour it had before, '
              'so the line is two colours and the gesture only half happened');
    });
  });

  group('repeating a range clears it', () {
    test('the same two squares again, when all of it is marked', () {
      range('a2', 'a7');
      expect(range('a2', 'a7'), isTrue);
      expect(squares, isEmpty,
          reason: 'one gesture has to be reversible by itself');
    });

    test('backwards counts as the same range', () {
      range('a2', 'a7');
      expect(range('a7', 'a2'), isTrue);
      expect(squares, isEmpty);
    });

    test('whatever colour they were marked in', () {
      controller.setColor('R');
      range('c1', 'c4');
      controller.setColor('B');
      expect(range('c1', 'c4'), isTrue);
      expect(squares, isEmpty,
          reason: 'having to remember which colour a line was drawn in to '
              'erase it would be worse than the button this replaces');
    });

    test('but a range only part of which is marked fills it in instead', () {
      range('a2', 'a5');
      expect(range('a2', 'a7'), isTrue);
      expect(marked(), {'a2', 'a3', 'a4', 'a5', 'a6', 'a7'},
          reason: 'a longer line over a shorter one is asking for the longer '
              'line, not for nothing');
    });

    test('and squares outside the line are left alone', () {
      controller.tap('h8', arrows: arrows, squares: squares);
      range('a2', 'a7');
      range('a2', 'a7');
      expect(marked(), {'h8'});
    });
  });

  group('the range does not leak into an ordinary tap', () {
    test('turning it off between the two taps marks one square', () {
      controller.tap('a2', arrows: arrows, squares: squares, asRange: true);
      expect(controller.pendingRangeFrom, 'a2');

      // The trainer let go of SHIFT, or pressed the button again.
      expect(controller.tap('d5', arrows: arrows, squares: squares), isTrue);
      expect(marked(), {'d5'},
          reason: 'a line was drawn from a range the trainer had abandoned');
      expect(controller.pendingRangeFrom, isNull);
    });

    test('changing mode forgets a half-named range', () {
      controller.tap('a2', arrows: arrows, squares: squares, asRange: true);
      controller.setMode(AnnotationMode.arrow);
      controller.setMode(AnnotationMode.square);
      expect(controller.pendingRangeFrom, isNull);

      expect(range('d4', 'd6'), isTrue);
      expect(marked(), {'d4', 'd5', 'd6'},
          reason: 'the abandoned a2 was still remembered and joined the line');
    });

    test('and so does the board moving underneath', () {
      // `cancelPending` is called when a different node, part or position
      // arrives — the squares named so far are on a board that is gone.
      controller.tap('a2', arrows: arrows, squares: squares, asRange: true);
      controller.cancelPending();
      expect(controller.pendingRangeFrom, isNull);
    });

    test('a range in arrow mode is still an arrow', () {
      controller.setMode(AnnotationMode.arrow);
      controller.tap('a2', arrows: arrows, squares: squares, asRange: true);
      expect(
          controller.tap('a7', arrows: arrows, squares: squares, asRange: true),
          isTrue);
      expect(squares, isEmpty);
      expect(arrows, hasLength(1));
      expect(arrows.single.from, 'a2');
      expect(arrows.single.to, 'a7');
    });

    test('and off means off', () {
      controller.setMode(AnnotationMode.off);
      expect(range('a2', 'a7'), isFalse);
      expect(squares, isEmpty);
    });
  });
}
