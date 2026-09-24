// Keeping the puzzles a review found — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
// phase 1.3.
//
// A puzzle is now the position *before* the game's move (1.3), so what is
// kept changes with it: the exercise's position is that one, its instruction
// is the one of §4 — „A mistake was made in this position. Find the best
// move." — which does not name the game's move, and its solution accepts
// every right answer (a mate may have two first moves). The only moves a
// player found are listed apart, under their own heading, and are **not
// ticked** by default: a review of one's own game is first about what went
// wrong. What goes to the server is asserted on the client seam (rule 7).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/legal_moves.dart' show walkGame;
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/keep_puzzles_panel.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 1.e4 e5 2.Nf3 Nc6 3.Bc4 Nf6 4.O-O.
final _italian = walkGame(
    startingFen: _start,
    uciMoves: const ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'e1g1']);

/// Kb6 and Rh1 against Ka8: Rh8 mates at once, Rh7 in two.
const _rookFen = 'k7/8/1K6/8/8/8/8/7R w - - 0 1';

/// 3.Bc4 was the mistake; 3.d4 the answer.
final _mistake = LocalPuzzle(
  id: 'm',
  kind: PuzzleKind.mistake,
  fen: _italian.fens[4],
  sourcePlyIndex: 4,
  playedSan: 'Bc4',
  playedUci: 'f1c4',
  answers: const ['d4'],
  bestLine: const ['d4', 'exd4'],
  secondLine: const ['Nc3'],
  refutationLine: const ['Nf6'],
  bestChances: 70,
  playedChances: 50,
  secondChances: 54,
  missedTimes: 3,
);

/// 1.Rh2 left a mate: Rh8 and Rh7 both force it.
const _mate = LocalPuzzle(
  id: 'mate',
  kind: PuzzleKind.mistake,
  fen: _rookFen,
  sourcePlyIndex: 0,
  playedSan: 'Rh2',
  playedUci: 'h1h2',
  answers: ['Rh8#', 'Rh7'],
  bestLine: ['Rh8#'],
  bestChances: 100,
  playedChances: 86,
  secondChances: 80,
);

/// 4.O-O was the one move that held.
final _onlyMove = LocalPuzzle(
  id: 'o',
  kind: PuzzleKind.onlyMove,
  fen: _italian.fens[6],
  sourcePlyIndex: 6,
  playedSan: 'O-O',
  playedUci: 'e1g1',
  answers: const ['O-O'],
  bestLine: const ['O-O'],
  secondLine: const ['d3'],
  bestChances: 55,
  playedChances: 55,
  secondChances: 38,
);

class _Server {
  final List<http.Request> posts = [];

  http.Client get client => MockClient((req) async {
        if (req.method == 'POST' && req.url.path == '/exercises') {
          posts.add(req);
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({
                'exercise': {
                  'id': 'ex_${posts.length}',
                  'fen': sent['fen'],
                  'sideToMove': 'w',
                  'name': sent['name'],
                  'themes': sent['themes'],
                  'origin': sent['origin'],
                  'task': sent['task'],
                  'solution': sent['solution'],
                  'assignable': true,
                },
              }),
              201);
        }
        return http.Response('{}', 404);
      });

  List<Map<String, dynamic>> get bodies => [
        for (final r in posts) jsonDecode(r.body) as Map<String, dynamic>,
      ];
}

Future<_Server> _panel(WidgetTester tester, List<LocalPuzzle> puzzles) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: SingleChildScrollView(
        child: KeepPuzzlesPanel(
          puzzles: puzzles,
          defaultName: 'Game of test',
          api: ExerciseApiService(authToken: 'tok', client: server.client),
          onDone: (_) {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

bool? _ticked(WidgetTester tester, int i) =>
    tester.widget<Checkbox>(find.byKey(ValueKey('keep-puzzle-tick-$i'))).value;

Future<void> _keep(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('keep-puzzles-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a mistake is ticked; an only move is listed apart, under its own '
      'heading, and not ticked', (tester) async {
    // Handed in the other order, to see the panel put the mistakes first.
    await _panel(tester, [_onlyMove, _mistake]);

    expect(_ticked(tester, 1), isTrue, reason: 'the mistake');
    expect(_ticked(tester, 0), isFalse, reason: 'the only move');
    final heading = find.byKey(const Key('keep-only-moves'));
    expect(heading, findsOneWidget);
    final mistakeTop =
        tester.getTopLeft(find.byKey(const ValueKey('keep-puzzle-1'))).dy;
    final headingTop = tester.getTopLeft(heading).dy;
    final onlyTop =
        tester.getTopLeft(find.byKey(const ValueKey('keep-puzzle-0'))).dy;
    expect(mistakeTop, lessThan(headingTop));
    expect(headingTop, lessThan(onlyTop));
    expect(find.text('Keep 1 as an exercise'), findsOneWidget);
  });

  testWidgets(
      'what is kept is the position before the move, the instruction that '
      'does not name it, and every right answer', (tester) async {
    final server = await _panel(tester, [_mate]);
    await _keep(tester);

    final body = server.bodies.single;
    expect(body['fen'], _rookFen);
    expect(body['instruction'], kMistakeInstruction);
    expect(body['instruction'], isNot(contains('Rh2')));
    expect(body['task'], {'type': 'find'});
    expect(body['solution'], [
      {
        'accept': ['Rh8#', 'Rh7']
      }
    ]);
    expect(body['origin'], 'mistakes');
  });

  testWidgets('an only move, once ticked, is kept with its own instruction',
      (tester) async {
    final server = await _panel(tester, [_mistake, _onlyMove]);
    await tester.tap(find.byKey(const ValueKey('keep-puzzle-tick-1')));
    await tester.pump();
    await _keep(tester);

    expect(server.bodies, hasLength(2));
    final only = server.bodies.firstWhere((b) => b['fen'] == _italian.fens[6]);
    expect(only['instruction'], kOnlyMoveInstruction);
    expect(only['solution'], [
      {
        'accept': ['O-O']
      }
    ]);
  });

  testWidgets('an answer that does not play is not sent, and it is said',
      (tester) async {
    // Qh5 cannot be played after 2...Nc6: the knight on f3 stands in the way.
    final broken = LocalPuzzle(
      id: 'b',
      kind: PuzzleKind.mistake,
      fen: _italian.fens[4],
      sourcePlyIndex: 4,
      playedSan: 'Bc4',
      playedUci: 'f1c4',
      answers: const ['Qh5'],
      bestChances: 70,
      playedChances: 50,
    );
    final server = await _panel(tester, [broken]);
    await _keep(tester);

    expect(server.posts, isEmpty);
    expect(find.textContaining('does not play'), findsOneWidget);
  });

  testWidgets(
      'a row says the move played, every answer, and how often the chance '
      'was missed', (tester) async {
    await _panel(tester, [_mistake, _mate]);

    final first = find.byKey(const ValueKey('keep-puzzle-0'));
    expect(find.descendant(of: first, matching: find.textContaining('Bc4')),
        findsWidgets);
    expect(
        find.descendant(
            of: first, matching: find.textContaining('missed 3 times')),
        findsOneWidget);
    final second = find.byKey(const ValueKey('keep-puzzle-1'));
    expect(
        find.descendant(
            of: second, matching: find.textContaining('Rh8# or Rh7')),
        findsOneWidget);
  });
}
