// A part the trainer did not name is „Part 3" — on every screen that shows one.
//
// It was „Deo 3" until 11.9.2026: the one Serbian word the English pivot left
// in the studio, because it carries no letter the Serbian-text gate can see.
// The studio writes „Part N" now, and rewrites an old stored „Deo N" the next
// time the tutorial is saved — but every tutorial already on the server keeps
// its stored name until then, so each screen that shows a stored name reads it
// through `shownPartTitle`. This file drives every one of those screens with a
// tutorial stored the old way; the rule itself is pinned in
// `tutorial_section_titles_test.dart`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/preview_assignment_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/widgets/create_course_dialog.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final _trainer = UserSession(
  token: 't',
  id: 7,
  email: 'a@b.c',
  name: 'Trener',
  role: 'trener',
);

/// Two parts stored with the old generated names.
final _oldSteps = [
  {'id': 'aaaa1111', 'fen': _fen, 'title': 'Deo 1', 'kind': 'show'},
  {'id': 'bbbb2222', 'fen': _fen, 'title': 'Deo 2', 'kind': 'show'},
];

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  group('the child\'s viewer', () {
    Future<void> open(WidgetTester tester, List<LessonStep> steps) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: LessonViewerScreen(
          session: _trainer,
          detail: AssignmentDetail(
            assignment: Assignment(id: 1, title: 'Opozicija'),
            items: [
              for (var i = 0; i < steps.length; i++)
                AssignmentItem(puzzleId: null, position: i),
            ],
            steps: steps,
          ),
          api: PreviewAssignmentApiService(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows a stored „Deo" name as „Part N", numbered by place',
        (tester) async {
      await open(tester, const [
        LessonStep(title: 'Deo 2', fen: _fen),
        LessonStep(title: 'Deo 1', fen: _fen),
      ]);

      // The number is where the part stands, not what was stored: this one is
      // first, whatever a reorder the server never saw left in its name.
      expect(find.text('Part 1'), findsOneWidget);
      expect(find.textContaining('Deo'), findsNothing);
      await _close(tester);
    });

    testWidgets('shows a name the trainer wrote as they wrote it',
        (tester) async {
      await open(tester, const [LessonStep(title: 'Matni motiv', fen: _fen)]);

      expect(find.text('Matni motiv'), findsOneWidget);
      await _close(tester);
    });
  });

  testWidgets(
      'the studio\'s refusal names a part as its list does, never „Deo"',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => _close(tester));

    // A question stored with the line that answers it, from before the studio
    // refused to save one — the banner names it on the way in.
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: _trainer,
        entry: TutorialEntry.saved({
          'id': 9301,
          'title': 'Opozicija',
          'position_list': [
            {'id': 's1', 'fen': _fen, 'title': 'Deo 1', 'kind': 'show'},
            {
              'id': 's2',
              'fen': _fen,
              'title': 'Deo 2',
              'kind': 'ask_move',
              'solutionSan': 'e4',
              'pgn': '1. e4 e5 *',
            },
          ],
        }),
        lessonApi: LessonApiService(
          authToken: 'tok',
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final banner = find.byKey(const Key('leak-banner'));
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.textContaining('"Part 2"')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: banner, matching: find.textContaining('Deo')),
      findsNothing,
    );
  });

  group('the room', () {
    setUp(() => debugTutorialStudioAvailable = false);
    tearDown(() => debugTutorialStudioAvailable = null);

    testWidgets('loads, steps and lists a tutorial\'s parts as „Part N"',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = LessonApiService(
        authToken: 'tok',
        client: MockClient((req) async {
          if (req.method == 'GET' && req.url.path.endsWith('/labels')) {
            return http.Response('[]', 200);
          }
          if (req.method == 'GET' && req.url.path.endsWith('/lessons')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 42,
                  'title': 'Opozicija',
                  'tags': <String>[],
                  'position_list': _oldSteps,
                },
              ]),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: ChessGamePage(
          userSession: _trainer,
          roomCode: 'STUDIO',
          initialRole: 'trener',
          lessonApi: api,
        ),
      ));
      await tester.pumpAndSettle();

      // The room says „Position loaded" first and this second, one message
      // after the other, so it is waited for rather than expected at once.
      Future<bool> said(String text) async {
        for (var i = 0; i < 15; i++) {
          if (find.textContaining(text).evaluate().isNotEmpty) return true;
          await tester.pump(const Duration(seconds: 1));
        }
        return false;
      }

      await tester.tap(find.text('Opozicija').first);
      await tester.pump();
      expect(await said('from tutorial: "Part 1"'), isTrue);

      await tester.tap(find.byTooltip('Next step'));
      await tester.pump();
      expect(await said('Step 2/2: "Part 2"'), isTrue);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byTooltip('Jump to step'));
      await tester.pumpAndSettle();
      expect(find.text('1. Part 1'), findsOneWidget);
      expect(find.text('2. Part 2'), findsOneWidget);
      expect(find.textContaining('Deo'), findsNothing);

      await _close(tester);
    });
  });

  testWidgets('the course editor lists stored parts as „Part N"',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CreateCourseDialog(
          userSession: _trainer,
          onCourseCreated: () {},
          existingLesson: {
            'id': 42,
            'title': 'Opozicija',
            'position_list': _oldSteps,
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1. Part 1'), findsOneWidget);
    expect(find.text('2. Part 2'), findsOneWidget);
    await _close(tester);
  });
}
