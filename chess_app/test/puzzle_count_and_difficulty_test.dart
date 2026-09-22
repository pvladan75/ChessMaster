// „Number of puzzles" and „Difficulty" live in one widget
// (lib/widgets/puzzle_count_and_difficulty.dart), used by the homework
// editor's „A puzzle set" and by „Create assignment". Each dialog must still
// send what the reader set there — the wiring is what merging them could lose.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/widgets/create_assignment_dialog.dart';
import 'package:chess_app/features/homework/widgets/homework_item_pickers.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/puzzle_count_and_difficulty.dart';

Widget _host(void Function(BuildContext) open) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => open(c),
            child: const Text('open'),
          ),
        ),
      ),
    );

/// Moves every control off its default: the count to the far right of its
/// track, „from" up two steps, „to" down one.
Future<void> _setAll(WidgetTester tester) async {
  expect(find.byType(PuzzleCountAndDifficulty), findsOneWidget);
  await tester.ensureVisible(find.byKey(const Key('puzzle-count')));
  await tester.pumpAndSettle();
  final track = tester.getRect(find.byKey(const Key('puzzle-count')));
  await tester.tapAt(Offset(track.right - 24, track.center.dy));
  await tester.pump();
  for (final key in [
    'rating-from-plus',
    'rating-from-plus',
    'rating-to-minus'
  ]) {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }
  expect(find.text('Number of puzzles: 50'), findsOneWidget);
}

void main() {
  testWidgets('the homework puzzle set sends what was set', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? picked;
    await tester.pumpWidget(
      _host((c) async => picked = await pickPuzzleCriteria(c)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The homework dialog starts at 1000–1800.
    await _setAll(tester);
    expect(find.text('Difficulty: 1200–1700'), findsOneWidget);
    await tester.tap(find.byKey(const Key('homework-puzzle-submit')));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!['count'], 50);
    expect(picked!['minRating'], 1200);
    expect(picked!['maxRating'], 1700);
  });

  testWidgets('Create assignment sends what was set', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final posts = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/assignments')) {
        posts.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({
              'assignment': {'id': 1}
            }),
            201);
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(
      _host(
        (c) => showDialog<bool>(
          context: c,
          builder: (_) => CreateAssignmentDialog(
            api: AssignmentApiService(authToken: 't', client: client),
            studentId: 7,
            studentName: 'Ana',
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final before = RegExp(r'Difficulty: (\d+)–(\d+)').firstMatch(tester
        .widgetList<Text>(find.textContaining('Difficulty: '))
        .single
        .data!)!;
    final from = int.parse(before.group(1)!) + 200;
    final to = int.parse(before.group(2)!) - 100;
    await _setAll(tester);
    await tester.ensureVisible(find.text('Assign'));
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(posts.single['count'], 50);
    expect(posts.single['minRating'], from);
    expect(posts.single['maxRating'], to);
  });
}
