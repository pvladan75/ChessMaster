// A kept puzzle takes its review to the server — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
// phase 4.
//
// Phase 2 gave `custom_puzzles` a `review` column and phase 5 a screen that
// reveals it once the puzzle is answered; this is the step between them: „Keep
// N as exercises" sends, with each puzzle, the game's move, the three lines and
// the chances — and no words until the language model writes them (phase 3).
// **The writer reads its own work back**: every line is replayed before the
// request, the refutation from the position after the game's move, and a
// puzzle whose line does not play cannot be ticked at all. What is sent is
// asserted on the client seam (rule 7).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/keep_puzzles_panel.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// 1.e4 e5 2.Nf3 Nc6, White to move: the game played 3.Bc4, 3.d4 was best.
const _fen = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';

LocalPuzzle _mistake({
  List<String> bestLine = const ['d4', 'exd4', 'Nxd4'],
  List<String> refutationLine = const ['Nf6', 'd3'],
}) =>
    LocalPuzzle(
      id: 'm',
      kind: PuzzleKind.mistake,
      fen: _fen,
      sourcePlyIndex: 4,
      playedSan: 'Bc4',
      playedUci: 'f1c4',
      answers: const ['d4'],
      bestLine: bestLine,
      refutationLine: refutationLine,
      secondLine: const ['Nc3', 'Nf6'],
      bestChances: 58.2,
      playedChances: 47.9,
      secondChances: 52.4,
    );

class _Server {
  final List<Map<String, dynamic>> bodies = [];

  http.Client get client => MockClient((req) async {
        final sent = jsonDecode(req.body) as Map<String, dynamic>;
        bodies.add(sent);
        return http.Response(
            jsonEncode({
              'exercise': {
                'id': 'ex_${bodies.length}',
                'fen': sent['fen'],
                'sideToMove': 'w',
                'name': 'kept',
                'themes': const [],
                'origin': 'mistakes',
                'task': sent['task'],
                'solution': sent['solution'],
                'assignable': true,
              },
            }),
            201);
      });
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

Future<void> _keep(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('keep-puzzles-save')));
  await tester.pumpAndSettle();
}

Checkbox _tick(WidgetTester tester, int i) =>
    tester.widget<Checkbox>(find.byKey(ValueKey('keep-puzzle-tick-$i')));

void main() {
  testWidgets('a kept puzzle sends its review, and no words', (tester) async {
    final server = await _panel(tester, [_mistake()]);
    await _keep(tester);

    final review = server.bodies.single['review'] as Map<String, dynamic>;
    expect(review, {
      'played': 'Bc4',
      'bestLine': ['d4', 'exd4', 'Nxd4'],
      'refutationLine': ['Nf6', 'd3'],
      'secondLine': ['Nc3', 'Nf6'],
      'chances': {'best': 58.2, 'played': 47.9, 'second': 52.4},
    });
    expect(review.containsKey('words'), isFalse,
        reason: 'no words until phase 3 writes them — absent, not empty');
    expect(server.bodies.single['solution'], [
      {
        'accept': ['d4']
      }
    ]);
  });

  testWidgets('an only move sends its review: the game\'s move is the answer',
      (tester) async {
    final server = await _panel(tester, [
      const LocalPuzzle(
        id: 'o',
        kind: PuzzleKind.onlyMove,
        fen: _fen,
        sourcePlyIndex: 4,
        playedSan: 'd4',
        playedUci: 'd2d4',
        answers: ['d4'],
        bestLine: ['d4', 'exd4'],
        secondLine: ['Nc3'],
        bestChances: 60,
        playedChances: 60,
      ),
    ]);
    await tester.tap(find.byKey(const ValueKey('keep-puzzle-tick-0')));
    await tester.pump();
    await _keep(tester);

    final review = server.bodies.single['review'] as Map<String, dynamic>;
    expect(review['played'], 'd4');
    expect(review['refutationLine'], isEmpty);
    expect((review['chances'] as Map).containsKey('second'), isFalse,
        reason: 'a second chance the builder did not have is not sent');
  });

  testWidgets('a puzzle whose line does not play cannot be ticked, and says so',
      (tester) async {
    final server = await _panel(tester, [
      _mistake(bestLine: const ['d4', 'exd4', 'Qxh7']),
      _mistake(),
    ]);

    expect(_tick(tester, 0).value, isFalse);
    expect(_tick(tester, 0).onChanged, isNull);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('keep-puzzle-0')),
            matching: find.textContaining('does not play')),
        findsOneWidget);
    expect(_tick(tester, 1).value, isTrue, reason: 'the good one stays ticked');
    await _keep(tester);
    expect(server.bodies, hasLength(1));
  });

  testWidgets(
      'the refutation is replayed after the game\'s move, not from the puzzle',
      (tester) async {
    // 3.Nc3 plays from the puzzle's position; after 3.Bc4 it is Black's move
    // and it does not.
    await _panel(tester, [
      _mistake(refutationLine: const ['Nc3'])
    ]);
    expect(_tick(tester, 0).onChanged, isNull);
  });
}
