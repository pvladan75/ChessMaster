// The reveal — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 5.
//
// A puzzle from a game is the position before the mistake, and it must teach:
// once the student has moved, right or wrong, the solve screen shows what was
// played and how it was punished, what was best and the line behind it, and
// what became of the student's own move. The review arrives only with the
// answer to the attempt (phase 2), so nothing of it can be on the screen
// before the move. And **no line is ever shown under the student's move that
// is not that move's own**: the engine's second line when the student played
// it, the game's own refutation when the student played the game's move, and
// otherwise a sentence that there is no line.
//
// The pure half holds the rules; the screen half drives the real solve screen
// through the real API client over a fake server (rule 7), at a phone's size
// and a window's.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/models/puzzle_review.dart';
import 'package:chess_app/features/assignments/screens/custom_puzzle_solver_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart'
    show getSquareCenter;
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// 1.e4 e5 2.Nf3 Nc6, White to move. The game played 3.Bc4; 3.d4 is best,
/// 3.Nc3 the engine's second line.
const _fen = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';

Map<String, Object?> _reviewJson({double played = 47.9, String? words}) => {
      'played': 'Bc4',
      'bestLine': ['d4', 'exd4', 'Nxd4'],
      'refutationLine': ['Nf6', 'd3'],
      'secondLine': ['Nc3', 'Nf6'],
      'words': words,
      'chances': {'best': 58.2, 'played': played, 'second': 52.4},
    };

PuzzleReview _review({double played = 47.9}) =>
    PuzzleReview.fromJson(_reviewJson(played: played))!;

String _after(String fen, List<String> sans) {
  final line = RevealLine.of(RevealKind.best, '', '', fen, sans);
  expect(line.length, sans.length, reason: 'the fixture line must play');
  return line.fens.last;
}

void main() {
  group('which lines, under which move', () {
    PuzzleReveal reveal(String? solverSan, {bool correct = false}) =>
        PuzzleReveal.of(
            fen: _fen,
            review: _review(),
            solverSan: solverSan,
            correct: correct);

    List<RevealKind> kinds(PuzzleReveal r) => [for (final l in r.lines) l.kind];

    test(
        'the game\'s move with its refutation, then the best move and its line',
        () {
      final r = reveal('d4', correct: true);
      expect(kinds(r), [RevealKind.played, RevealKind.best]);
      expect(r.lines[0].sans, ['Bc4', 'Nf6', 'd3']);
      expect(r.lines[0].caption, 'Its refutation');
      expect(r.lines[1].sans, ['d4', 'exd4', 'Nxd4']);
      expect(r.note, isNull);
    });

    test(
        'where the game\'s move still left the player better, it is not called '
        'a refutation', () {
      final r = PuzzleReveal.of(
          fen: _fen,
          review: _review(played: 55),
          solverSan: 'd4',
          correct: true);
      expect(r.lines[0].caption, 'How the advantage went');
    });

    test(
        'the engine\'s second line goes under the student\'s move only when it '
        'is that move', () {
      final second = reveal('Nc3');
      expect(kinds(second),
          [RevealKind.played, RevealKind.best, RevealKind.yours]);
      expect(second.lines.last.sans, ['Nc3', 'Nf6']);
      expect(second.note, isNull);

      final other = reveal('a3');
      expect(kinds(other), [RevealKind.played, RevealKind.best]);
      expect(other.note, 'No line for this move.');
      for (final line in other.lines) {
        expect(line.sans.first, isNot('a3'),
            reason: 'no line is shown as if it were a3\'s');
      }
    });

    test('the game\'s move played again is told so, and keeps its own line',
        () {
      final r = reveal('Bc4');
      expect(kinds(r), [RevealKind.played, RevealKind.best]);
      expect(r.note, "That was the game's move.");
    });

    test('another right answer is told it is right, with no line of its own',
        () {
      expect(reveal('Qe2', correct: true).note,
          'Also right — no line is kept for this move.');
    });

    test('an only move — the game\'s move was the best — has one line', () {
      final r = PuzzleReveal.of(
          fen: _fen,
          review: PuzzleReview.fromJson({
            ..._reviewJson(),
            'played': 'd4',
            'refutationLine': <String>[],
          })!,
          solverSan: 'd4',
          correct: true);
      expect(kinds(r), [RevealKind.best]);
    });

    test('the arrow shows the move about to be played, and none at the end',
        () {
      final line = reveal('d4', correct: true).lines.first;
      expect(line.arrowsAt(0).single.toString(), 'Rf1c4');
      expect(line.arrowsAt(1).single.toString(), 'Rg8f6');
      expect(line.arrowsAt(line.length), isEmpty);
    });

    test('what the server did not write is not read', () {
      expect(PuzzleReview.fromJson(null), isNull);
      expect(PuzzleReview.fromJson({'played': 'Bc4'}), isNull);
      expect(PuzzleReview.fromJson({..._reviewJson(), 'bestLine': <String>[]}),
          isNull);
      final withWords = PuzzleReview.fromJson(
          {..._reviewJson(), 'words': '  The centre first.  '})!;
      expect(withWords.words, 'The centre first.');
    });
  });

  group('the solve screen', () {
    UserSession session() => UserSession(
          token: 't',
          id: 1,
          email: 's@example.com',
          name: 'Student',
          role: 'korisnik',
        );

    Offset squareOn(WidgetTester tester, String square) {
      final rect = tester.getRect(find.byType(ChessBoardWithOverlay));
      return rect.topLeft +
          getSquareCenter(square, rect.width, PlayerColor.white);
    }

    Future<void> drag(WidgetTester tester, String from, String to) async {
      await tester.dragFrom(squareOn(tester, from),
          squareOn(tester, to) - squareOn(tester, from));
      await tester.pumpAndSettle();
    }

    String fenNow(WidgetTester tester) => tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
        .controller
        .getFen();

    List<String> arrowsNow(WidgetTester tester) => [
          for (final a in tester
              .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
              .arrows)
            a.toString()
        ];

    Future<void> open(WidgetTester tester, Size size,
        {bool withReview = true, String? words}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final client = MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final san = body['moveSan'] as String;
        return http.Response(
            jsonEncode({
              'correct': san == 'd4',
              'reason': san == 'd4'
                  ? "the author's move"
                  : 'That is not the move the exercise asks for.',
              'playedSan': san,
              'solutionSan': 'd4',
              'review': withReview ? _reviewJson(words: words) : null,
            }),
            200);
      });
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: CustomPuzzleSolverScreen(
          session: session(),
          detail: const AssignmentDetail(
            assignment: Assignment(id: 42, title: 'From the game'),
            items: [],
          ),
          positions: const [
            CustomPosition(
                puzzleId: 'ex_1',
                fen: _fen,
                sideToMove: 'w',
                instruction:
                    'A mistake was made in this position. Find the best move.'),
          ],
          startIndex: 0,
          api: AssignmentApiService(authToken: 't', client: client),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    for (final size in const [Size(360, 640), Size(1280, 800)]) {
      final at = '${size.width.toInt()} x ${size.height.toInt()}';

      testWidgets('$at: nothing of the review before the move', (tester) async {
        await open(tester, size);
        expect(find.byKey(const Key('reveal')), findsNothing);
        expect(find.textContaining('What was'), findsNothing);
        expect(find.textContaining('Bc4'), findsNothing,
            reason: 'the game\'s move is not named before the student moves');
      });

      testWidgets('$at: every line plays to its last move and back',
          (tester) async {
        await open(tester, size);
        await drag(tester, 'd2', 'd4');
        expect(find.byKey(const Key('reveal')), findsOneWidget);

        final ends = {
          RevealKind.played: _after(_fen, ['Bc4', 'Nf6', 'd3']),
          RevealKind.best: _after(_fen, ['d4', 'exd4', 'Nxd4']),
        };
        final firstArrow = {
          RevealKind.played: 'Rf1c4',
          RevealKind.best: 'Gd2d4',
        };
        for (final kind in ends.keys) {
          await tap(tester, find.byKey(ValueKey('reveal-line-${kind.name}')));
          expect(MoveTree.samePosition(fenNow(tester), _fen), isTrue,
              reason: '${kind.name} starts at the puzzle');
          expect(arrowsNow(tester), [firstArrow[kind]]);
          for (var i = 0; i < 3; i++) {
            await tap(tester, find.byTooltip('Next move'));
          }
          expect(MoveTree.samePosition(fenNow(tester), ends[kind]!), isTrue,
              reason: '${kind.name} reaches its last move');
          expect(arrowsNow(tester), isEmpty);
          for (var i = 0; i < 3; i++) {
            await tap(tester, find.byTooltip('Previous move'));
          }
          expect(MoveTree.samePosition(fenNow(tester), _fen), isTrue,
              reason: '${kind.name} walks back to the puzzle');
        }
        // Back to the puzzle from a line's last move, where the board is not
        // the puzzle — from the start of a line the button would prove nothing.
        await tap(tester, find.byTooltip('Go to end'));
        expect(MoveTree.samePosition(fenNow(tester), _fen), isFalse);
        await tap(tester, find.byKey(const Key('reveal-back')));
        expect(MoveTree.samePosition(fenNow(tester), _fen), isTrue);
        expect(arrowsNow(tester), isEmpty);
        expect(find.byKey(const Key('reveal-moves')), findsNothing);
      });

      testWidgets('$at: the second move played shows the second line',
          (tester) async {
        await open(tester, size);
        await drag(tester, 'b1', 'c3');
        final yours = find.byKey(const ValueKey('reveal-line-yours'));
        expect(yours, findsOneWidget);
        expect(
            find.descendant(of: yours, matching: find.text('Your move: Nc3')),
            findsOneWidget);
        await tap(tester, yours);
        expect(arrowsNow(tester), ['Bb1c3']);
        await tap(tester, find.byTooltip('Go to end'));
        expect(
            MoveTree.samePosition(fenNow(tester), _after(_fen, ['Nc3', 'Nf6'])),
            isTrue);
      });

      testWidgets(
          '$at: a third move is told there is no line, and never shown the '
          'game\'s refutation as its own', (tester) async {
        await open(tester, size);
        await drag(tester, 'a2', 'a3');
        expect(find.byKey(const Key('reveal-note')), findsOneWidget);
        expect(find.text('No line for this move.'), findsOneWidget);
        expect(find.byKey(const ValueKey('reveal-line-yours')), findsNothing);
        expect(find.textContaining('Your move'), findsNothing);
      });

      testWidgets('$at: every text of the reveal is read whole',
          (tester) async {
        // An explanation of the length a model writes: four sentences, so a
        // cut would show at a phone's width.
        await open(tester, size,
            words: 'Bc4 develops, but it lets Black play Nf6 with tempo on e4. '
                'The centre comes first here: after d4 Black has to take, and '
                'White recaptures with the knight, holding e4 and freeing the '
                'bishop. Nc3 was playable too, only slower.');
        await drag(tester, 'b1', 'c3');
        await tap(tester, find.byKey(const ValueKey('reveal-line-played')));
        expect(find.byKey(const Key('reveal-words')), findsOneWidget);
        for (final part in const [Key('reveal'), Key('reveal-strip')]) {
          final panel = tester.getRect(find.byKey(part));
          final paragraphs = tester
              .renderObjectList<RenderParagraph>(find.descendant(
                  of: find.byKey(part), matching: find.byType(RichText)))
              .toList();
          expect(paragraphs, isNotEmpty);
          for (final p in paragraphs) {
            final text = p.text.toPlainText();
            expect(p.didExceedMaxLines, isFalse, reason: '"$text" is cut');
            final box = p.localToGlobal(Offset.zero) & p.size;
            expect(
                box.left >= panel.left - 0.5 && box.right <= panel.right + 0.5,
                isTrue,
                reason: '"$text" runs outside the panel: $box in $panel');
          }
        }
      });

      testWidgets(
          '$at: a chosen line is walked with the whole board and its strip in '
          'view', (tester) async {
        await open(tester, size,
            words: 'Bc4 develops, but it lets Black play Nf6 with tempo on e4. '
                'The centre comes first here: after d4 Black has to take.');
        await drag(tester, 'b1', 'c3');
        await tap(tester, find.byKey(const ValueKey('reveal-line-yours')));
        final screen = Offset.zero & tester.view.physicalSize;
        final board = tester.getRect(find.byType(ChessBoardWithOverlay));
        final strip = tester.getRect(find.byKey(const Key('reveal-strip')));
        expect(
            screen.contains(board.topLeft) &&
                screen.contains(board.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: 'the board $board must be wholly on the screen $screen');
        expect(
            screen.contains(strip.topLeft) &&
                screen.contains(strip.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: 'the strip $strip must be on the screen $screen');
      });
    }

    testWidgets(
        'the arrow keys walk a chosen line, and do nothing while the '
        'position is the question', (tester) async {
      await open(tester, const Size(1280, 800));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(MoveTree.samePosition(fenNow(tester), _fen), isTrue,
          reason: 'before the move, the keys must not move the board');

      await drag(tester, 'a2', 'a3');
      await tap(tester, find.byKey(const ValueKey('reveal-line-best')));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
          MoveTree.samePosition(fenNow(tester), _after(_fen, ['d4'])), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(MoveTree.samePosition(fenNow(tester), _fen), isTrue);
    });

    testWidgets('an exercise with no review shows what it always showed',
        (tester) async {
      await open(tester, const Size(360, 640), withReview: false);
      await drag(tester, 'a2', 'a3');
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.byKey(const Key('reveal')), findsNothing);
    });
  });
}
