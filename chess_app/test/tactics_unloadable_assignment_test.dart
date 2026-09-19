// An assigned puzzle that cannot be loaded is not an assignment completed.
//
// Found live on 20.9.2026. A trainer's own exercise reached this screen as if
// it were a Lichess id (the server's half is
// `chess_backend/test/assignment_custom_positions.test.js`); the screen could
// load none of the set, skipped each one *in silence*, reached the end of the
// list and said „Assignment complete. Your trainer can see the result." to a
// student who had never seen a board. Skipping one bad row so the rest can be
// solved is right; saying nothing about it and then announcing success is the
// recurring bug of this codebase (CLAUDE.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/services/tactics_api_service.dart';
import 'package:chess_app/models/user_session.dart';

const _puzzle = '''
{"puzzle": {"puzzle_id": "p1", "fen": "6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1",
 "setup_move": "h7h6", "solution": ["a1a8"], "rating": 1200, "themes": ["mateIn1"]}}
''';

Future<List<String>> _pump(WidgetTester tester, List<String> ids,
    {required Set<String> missing}) async {
  final asked = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: TacticsTrainerScreen(
      session: UserSession(
          token: 't', id: 1, email: 's@example.com', name: 'S', role: 'user'),
      assignmentId: 71,
      puzzleIds: ids,
      api: TacticsApiService(
        authToken: 't',
        client: MockClient((req) async {
          final id = req.url.pathSegments.last;
          if (req.url.path.contains('/by-id/')) {
            asked.add(id);
            return missing.contains(id)
                ? http.Response('{"error":"not found"}', 404)
                : http.Response(_puzzle, 200);
          }
          return http.Response('{}', 200);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return asked;
}

void main() {
  testWidgets('a set of which nothing could be loaded never says „complete"',
      (tester) async {
    final asked = await _pump(tester, const ['ex_54d406e054660c5b'],
        missing: {'ex_54d406e054660c5b'});

    expect(asked, ['ex_54d406e054660c5b'], reason: 'it really was asked for');
    expect(find.text('Assignment complete.'), findsNothing);
    expect(find.text('Your trainer can see the result.'), findsNothing);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt), findsNothing,
        reason: 'the shape says it too, not only the words');
  });

  testWidgets('one bad row does not strand the rest — and is still said',
      (tester) async {
    await _pump(tester, const ['gone', 'p1'], missing: {'gone'});
    // The good one is served: the board is up, not the end screen.
    expect(find.textContaining('could not be loaded'), findsNothing);
    expect(find.text('Assignment complete.'), findsNothing);
  });

  testWidgets(
      'control: a set that loads and is never reached the end of says '
      'nothing of the kind', (tester) async {
    await _pump(tester, const ['p1'], missing: {});
    expect(find.textContaining('could not be loaded'), findsNothing);
  });
}
