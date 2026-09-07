import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';

/// The drawing interaction, tested without a board.
///
/// It is the pure half of P7 of `docs/PLAN-STUDIO-REDIZAJN.md`: the room has
/// had this behaviour for months, privately, and the studio needs the same one.
/// Everything about *what* a tap means is decided here, so the batch that draws
/// the annotation bar and wires two screens has nothing left to decide.
///
/// Two rules are load-bearing and both are asserted more than once: erasing
/// ignores the colour, and the marks belong to the lists the caller passes in —
/// never to the controller.
void main() {
  late BoardAnnotationController c;
  late List<ChessArrow> arrows;
  late List<SquareMark> squares;

  setUp(() {
    c = BoardAnnotationController();
    arrows = [];
    squares = [];
  });

  bool tap(String square) => c.tap(square, arrows: arrows, squares: squares);

  group('a tap means what the mode says', () {
    test('off: the board belongs to the game', () {
      expect(c.isDrawing, isFalse);
      expect(tap('e2'), isFalse);
      expect(tap('e4'), isFalse);
      expect(arrows, isEmpty);
      expect(squares, isEmpty);
      expect(c.pendingFrom, isNull,
          reason: 'a tap outside drawing mode started an arrow');
    });

    test('arrow: the first tap only remembers, the second draws', () {
      c.setMode(AnnotationMode.arrow);

      expect(tap('e2'), isFalse,
          reason: 'half an arrow is not a change, and a caller that persisted '
              'here would write a draft per tap');
      expect(c.pendingFrom, 'e2');
      expect(arrows, isEmpty);

      expect(tap('e4'), isTrue);
      expect(arrows.single.toString(), 'Ge2e4');
      expect(c.pendingFrom, isNull);
    });

    test('arrow: the same square twice is how you get out of a wrong start',
        () {
      c.setMode(AnnotationMode.arrow);

      tap('e2');
      expect(tap('e2'), isFalse);
      expect(arrows, isEmpty, reason: 'an arrow from a square to itself');
      expect(c.pendingFrom, isNull,
          reason: 'the cancelled start is still armed, so the next tap draws '
              'from a square the author had given up on');
    });

    test('square: one tap is the whole gesture', () {
      c.setMode(AnnotationMode.square);

      expect(tap('d5'), isTrue);
      expect(squares.single.toString(), 'Gd5');
      expect(c.pendingFrom, isNull);
      expect(arrows, isEmpty);
    });
  });

  group('drawing the same mark again takes it back', () {
    test('an arrow', () {
      c.setMode(AnnotationMode.arrow);
      tap('e2');
      tap('e4');

      tap('e2');
      expect(tap('e4'), isTrue);
      expect(arrows, isEmpty);
    });

    test('an arrow, whatever colour the picker is on now', () {
      // The correction being made is „wrong arrow", not „right arrow, wrong
      // colour". Having to remember the colour it was drawn in to erase it
      // would be worse than the button this gesture replaced.
      c.setMode(AnnotationMode.arrow);
      tap('e2');
      tap('e4');
      c.setColor(ArrowColor.r.id);

      tap('e2');
      tap('e4');
      expect(arrows, isEmpty,
          reason: 'the erase matched on colour, so the arrow could only be '
              'removed by the picker that drew it');
    });

    test('a square, whatever colour the picker is on now', () {
      c.setMode(AnnotationMode.square);
      tap('d5');
      c.setColor(ArrowColor.b.id);

      expect(tap('d5'), isTrue);
      expect(squares, isEmpty);
    });

    test('the other direction is a different arrow', () {
      c.setMode(AnnotationMode.arrow);
      tap('e2');
      tap('e4');
      tap('e4');
      tap('e2');

      expect(arrows.map((a) => a.toString()), ['Ge2e4', 'Ge4e2'],
          reason: 'e4->e2 erased e2->e4, so an author cannot draw a pair of '
              'arrows facing each other');
    });
  });

  group('the colour is the next mark, never the drawn ones', () {
    test('picking a colour leaves what is on the board alone', () {
      c.setMode(AnnotationMode.arrow);
      tap('e2');
      tap('e4');

      c.setColor(ArrowColor.r.id);

      expect(arrows.single.colorCode, ArrowColor.g.id);
    });

    test('the next mark takes the new colour', () {
      c.setMode(AnnotationMode.square);
      c.setColor(ArrowColor.r.id);
      tap('d5');

      expect(squares.single.toString(), 'Rd5');
    });

    test('green unless the caller said otherwise', () {
      expect(BoardAnnotationController().colorCode, ArrowColor.g.id);
      expect(BoardAnnotationController(colorCode: ArrowColor.p.id).colorCode,
          ArrowColor.p.id);
    });
  });

  group('a half-drawn arrow does not outlive what it was drawn on', () {
    test('switching mode forgets it', () {
      c.setMode(AnnotationMode.arrow);
      tap('e2');

      c.setMode(AnnotationMode.square);
      expect(c.pendingFrom, isNull);

      expect(tap('e4'), isTrue);
      expect(squares.single.toString(), 'Ge4');
      expect(arrows, isEmpty,
          reason: 'the square tap finished an arrow started in another mode');
    });

    test('stopping forgets it', () {
      c.setMode(AnnotationMode.arrow);
      tap('e2');

      c.stop();
      expect(c.isDrawing, isFalse);
      expect(c.pendingFrom, isNull);
    });

    test('the board moving under it forgets it, and drawing goes on', () {
      // The caller calls this when the cursor moves: `pendingFrom` names a
      // square on the position the author was looking at, and finishing that
      // arrow on the next position draws it somewhere nobody asked for.
      c.setMode(AnnotationMode.arrow);
      tap('e2');

      c.cancelPending();

      expect(c.pendingFrom, isNull);
      expect(c.mode, AnnotationMode.arrow,
          reason: 'moving the board also switched drawing off, so the trainer '
              'has to press the brush again after every move');
      expect(tap('d2'), isFalse, reason: 'this is a first tap again');
      expect(tap('d4'), isTrue);
      expect(arrows.single.toString(), 'Gd2d4');
    });
  });

  group('taking marks back', () {
    test('the last arrow, and a word when there is none', () {
      c.setMode(AnnotationMode.arrow);
      tap('e2');
      tap('e4');
      tap('d2');
      tap('d4');

      expect(c.undoLastArrow(arrows), isTrue);
      expect(arrows.map((a) => a.toString()), ['Ge2e4']);
      expect(c.undoLastArrow(arrows), isTrue);
      expect(c.undoLastArrow(arrows), isFalse,
          reason: 'an empty undo answers the same as one that removed '
              'something, so the screen says „done" over nothing');
    });

    test('the last square, and a word when there is none', () {
      c.setMode(AnnotationMode.square);
      tap('d5');
      tap('e5');

      expect(c.undoLastSquare(squares), isTrue);
      expect(squares.map((s) => s.toString()), ['Gd5']);
      expect(c.undoLastSquare(squares), isTrue);
      expect(c.undoLastSquare(squares), isFalse);
    });

    test('„Izbriši sve strelice" leaves the squares where they are', () {
      // The room's button says arrows. A lesson opened there can carry squares
      // it never drew, and a button that quietly removed them would be a button
      // that lies about what it does.
      arrows.add(ChessArrow(from: 'e2', to: 'e4', colorCode: 'G'));
      squares.add(SquareMark(square: 'd5', colorCode: 'R'));

      expect(c.clearArrows(arrows), isTrue);
      expect(arrows, isEmpty);
      expect(squares.single.toString(), 'Rd5');
      expect(c.clearArrows(arrows), isFalse);
    });

    test('clearing the marks of a node takes both', () {
      arrows.add(ChessArrow(from: 'e2', to: 'e4', colorCode: 'G'));
      squares.add(SquareMark(square: 'd5', colorCode: 'R'));

      expect(c.clearMarks(arrows: arrows, squares: squares), isTrue);
      expect(arrows, isEmpty);
      expect(squares, isEmpty);
      expect(c.clearMarks(arrows: arrows, squares: squares), isFalse,
          reason: 'clearing nothing reported a change, and the caller wrote a '
              'draft and broadcast an event for it');
    });
  });

  test('one controller draws onto whichever node it is handed', () {
    // The reason the lists are arguments and not fields. The author moves the
    // cursor; the interaction does not restart, and the marks land on the node
    // that is in front of them.
    final first = <ChessArrow>[];
    final second = <ChessArrow>[];
    final noSquares = <SquareMark>[];

    c.setMode(AnnotationMode.arrow);
    c.tap('e2', arrows: first, squares: noSquares);
    c.tap('e4', arrows: first, squares: noSquares);

    c.tap('d7', arrows: second, squares: noSquares);
    c.tap('d5', arrows: second, squares: noSquares);

    expect(first.map((a) => a.toString()), ['Ge2e4']);
    expect(second.map((a) => a.toString()), ['Gd7d5']);
  });
}
