// The student's report on the two screens that show it: the trainer's
// Overview (`StudentProgressScreen`) and the student's own card
// (`MyAssignmentsScreen`).
//
// Until 1.10.2026 the report counted attempts: „Solved 26/40" was 26 solved
// tries of 40, a puzzle tried five times was five, and a skip — `solved`
// false — counted as a wrong answer. The server now counts each puzzle once,
// a skip apart, through the Practise cards' own fold, and its accuracy is the
// share of new puzzles solved at the first attempt. These cases hold that the
// screens say so: the figures in the right places, a skip named as a skip,
// and no „null%" where there is no accuracy to give.
//
// The payload is the server's own (`getStudentProgress` over a small log, run
// on 1.10.2026), not one written from memory.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/screens/my_assignments_screen.dart';
import 'package:chess_app/features/assignments/screens/student_progress_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

const _studentId = 12;

UserSession _session(int id) => UserSession(
      token: 'tok',
      id: id,
      email: 'a@example.com',
      name: 'Someone',
      role: 'korisnik',
    );

/// Four pin puzzles (one solved at once, one retried and solved), four forks,
/// a skipped endgame, a failed game blunder.
Map<String, dynamic> _report({Map<String, dynamic> overrides = const {}}) => {
      'periodDays': 30,
      'overallRating': 1620,
      'ratingChange': 7,
      'themeRatings': <String, dynamic>{},
      'lifetimeSolved': 6,
      'lifetimeFailed': 3,
      'activeDays': 5,
      'assignments': {'total': 6, 'completed': 4, 'overdue': 1},
      'puzzles': 10,
      'solved': 6,
      'failed': 3,
      'skipped': 1,
      'firstTries': 9,
      'solvedFirstTry': 5,
      'accuracy': 56,
      'themes': [
        {'theme': 'pin', 'firstTries': 4, 'solvedFirstTry': 1, 'accuracy': 25},
        {
          'theme': 'fork',
          'firstTries': 4,
          'solvedFirstTry': 4,
          'accuracy': 100
        },
      ],
      'weakestThemes': [
        {'theme': 'pin', 'firstTries': 4, 'solvedFirstTry': 1, 'accuracy': 25},
      ],
      'strongestThemes': [
        {
          'theme': 'fork',
          'firstTries': 4,
          'solvedFirstTry': 4,
          'accuracy': 100
        },
      ],
      ...overrides,
    };

/// The server, for the two screens: the report under its own path, and empty
/// lists for everything else they ask.
AssignmentApiService _api(Map<String, dynamic> report, List<Uri> asked) =>
    AssignmentApiService(
      authToken: 'tok',
      client: MockClient((request) async {
        asked.add(request.url);
        final path = request.url.path;
        if (path.startsWith('/assignments/progress/')) {
          return http.Response(jsonEncode(report), 200);
        }
        if (path == '/assignments/mine' || path == '/assignments/given') {
          return http.Response(jsonEncode({'assignments': []}), 200);
        }
        return http.Response('{"error":"not found"}', 404);
      }),
    );

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}

/// The value printed above [label] in the Overview's row of figures.
Finder _figure(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(Column),
    );

void main() {
  group("the trainer's Overview", () {
    Future<List<Uri>> open(
        WidgetTester tester, Map<String, dynamic> report) async {
      final asked = <Uri>[];
      await _pump(
        tester,
        StudentProgressScreen(
          session: _session(9),
          studentId: _studentId,
          studentName: 'Ana',
          api: _api(report, asked),
        ),
      );
      return asked;
    }

    testWidgets(
        'counts puzzles, names a skip, and says the accuracy is a first try',
        (tester) async {
      final asked = await open(tester, _report());

      expect(
        asked.where((u) => u.path == '/assignments/progress/$_studentId'),
        hasLength(1),
      );
      expect(
          find.descendant(
              of: _figure('Solved').first, matching: find.text('6/10')),
          findsOneWidget);
      expect(
          find.descendant(
              of: _figure('Skipped').first, matching: find.text('1')),
          findsOneWidget);
      expect(
          find.descendant(
              of: _figure('First try').first, matching: find.text('56%')),
          findsOneWidget);
      expect(find.text('Accuracy'), findsNothing,
          reason: 'the figure says which tries it counts');
      // The theme row: its share, and how many new puzzles it rests on.
      expect(find.text('25% (4)'), findsOneWidget);
    });

    testWidgets('no skip, no skipped figure', (tester) async {
      await open(tester, _report(overrides: {'skipped': 0}));
      expect(find.text('Skipped'), findsNothing);
      expect(find.text('First try'), findsOneWidget,
          reason: 'the row of figures is there, without the skip');
    });

    testWidgets('only retries and skips: a dash, never 0% or null',
        (tester) async {
      await open(
          tester, _report(overrides: {'firstTries': 0, 'accuracy': null}));
      expect(
          find.descendant(
              of: _figure('First try').first, matching: find.text('—')),
          findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });
  });

  group("the student's own card", () {
    Future<void> open(WidgetTester tester, Map<String, dynamic> report) =>
        _pump(
          tester,
          MyAssignmentsScreen(
            session: _session(_studentId),
            api: _api(report, <Uri>[]),
          ),
        );

    String line(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('my-progress-line'))).data!;

    testWidgets('says puzzles, solved, skipped and the first-attempt share',
        (tester) async {
      await open(tester, _report());
      expect(
        line(tester),
        'Last 30 days: 10 puzzles, 6 solved, 1 skipped, '
        '56% at the first attempt, 5 active days.',
      );
    });

    testWidgets('no accuracy to give is left out, not printed as null%',
        (tester) async {
      await open(
          tester,
          _report(overrides: {
            'puzzles': 1,
            'solved': 0,
            'failed': 0,
            'skipped': 1,
            'firstTries': 0,
            'solvedFirstTry': 0,
            'accuracy': null,
            'activeDays': 1,
            'weakestThemes': [],
            'strongestThemes': [],
          }));
      expect(line(tester),
          'Last 30 days: 1 puzzle, 0 solved, 1 skipped, 1 active day.');
    });
  });
}
