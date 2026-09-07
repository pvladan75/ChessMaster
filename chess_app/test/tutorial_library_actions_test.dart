// The two things a trainer could not do with a tutorial they had written.
//
// „Ne postoji mogućnost brisanja tutorijala" and „tutorijal ne može da se
// pošalje đaku", reported live on 7.9.2026 — and both were true of the app
// while the server had `DELETE /lessons/:id` and `POST /assignments/lesson`
// all along. The app called them too: deleting from the lesson list inside a
// room, and assigning from „Napredak učenika". Neither is a place somebody
// writing a tutorial has any reason to be, so a capability that existed at
// every layer was one the user did not have.
//
// The list of saved tutorials is where both belong, and it is now called
// „Sačuvani tutorijali" rather than „Otvori sačuvani tutorijal" — a trainer
// looking for a way to delete one does not open a door labelled „open".
//
// Two rules beyond the actions themselves. A row leaves the list only when the
// **server** says it is gone: a row still on the server that vanishes from the
// screen is the deletion reporting a success it did not have. And a student
// who has not accepted the invitation is not offered, because the relationship
// grants nothing until then — the same `status = 'accepted'` this repository
// has already lost three times.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';

const String _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The library, plus the DELETE requests it was asked for.
class _LibraryApi extends LessonApiService {
  _LibraryApi._(this.deleted, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<String> deleted;

  factory _LibraryApi({bool deleteFails = false}) {
    final deleted = <String>[];
    return _LibraryApi._(
      deleted,
      MockClient((req) async {
        if (req.method == 'DELETE') {
          deleted.add(req.url.path);
          return deleteFails
              ? http.Response(jsonEncode({'error': 'Nije obrisano.'}), 500)
              : http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response(
          jsonEncode([
            {
              'id': 12,
              'title': 'Opozicija',
              'position_list': [
                {'id': 's1', 'fen': _fen, 'title': 'Uvod', 'kind': 'show'},
              ],
            },
            {
              'id': 14,
              'title': 'Vezani top',
              'position_list': [
                {'id': 's2', 'fen': _fen, 'title': 'Prvi deo', 'kind': 'show'},
              ],
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }
}

/// The trainer's students — one accepted, one who has not answered yet.
class _Students extends GroupApiService {
  _Students(
      {this.rows = const [
        {'id': 3, 'name': 'Mila', 'status': 'accepted'},
        {'id': 4, 'name': 'Nepotvrđeni', 'status': 'pending'},
      ]});

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> myStudents() async => rows;
}

class _Assignments extends AssignmentApiService {
  _Assignments({this.fails = false}) : super(authToken: 'tok');

  final bool fails;
  final List<({int studentId, int lessonId})> sent = [];

  @override
  Future<CreateAssignmentResult> createLessonAssignment({
    required int studentId,
    required int lessonId,
    String? title,
    String? instructions,
    DateTime? dueAt,
  }) async {
    sent.add((studentId: studentId, lessonId: lessonId));
    return fails
        ? const CreateAssignmentResult(success: false, error: 'Nije poslato.')
        : const CreateAssignmentResult(success: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 'tok',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
    debugTutorialStudioAvailable = true;
  });

  tearDown(() => debugTutorialStudioAvailable = null);

  Future<void> openList(
    WidgetTester tester, {
    required LessonApiService api,
    AssignmentApiService? assignments,
    GroupApiService? students,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TutorialLibraryCard(
            session: session,
            api: api,
            assignmentApi: assignments,
            groupApi: students,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvani tutorijali'));
    await tester.pumpAndSettle();
  }

  /// The row of the tutorial named [title], whichever action is wanted from it.
  Finder actionOn(String title, String tooltip) => find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        ),
        matching: find.byTooltip(tooltip),
      );

  group('deleting a tutorial', () {
    testWidgets('every row offers it, and it asks first', (tester) async {
      final api = _LibraryApi();
      await openList(tester, api: api);

      expect(actionOn('Opozicija', 'Obriši tutorijal'), findsOneWidget);
      expect(actionOn('Vezani top', 'Obriši tutorijal'), findsOneWidget);

      await tester.tap(actionOn('Vezani top', 'Obriši tutorijal'));
      await tester.pumpAndSettle();

      expect(find.text('Obriši tutorijal?'), findsOneWidget);
      expect(find.textContaining('Vezani top'), findsWidgets,
          reason: 'a refusal that does not name what it is about is a refusal '
              'the trainer has to guess at');

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(api.deleted, isEmpty);
      expect(find.text('Vezani top'), findsOneWidget);
    });

    testWidgets('confirming asks the server and takes the row off the list',
        (tester) async {
      final api = _LibraryApi();
      await openList(tester, api: api);

      await tester.tap(actionOn('Vezani top', 'Obriši tutorijal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obriši'));
      await tester.pumpAndSettle();

      expect(api.deleted, ['/lessons/14']);
      expect(find.text('Vezani top'), findsNothing);
      expect(find.text('Opozicija'), findsOneWidget,
          reason: 'the list stays open so a second one can be deleted');
    });

    testWidgets('a deletion the server refused leaves the row where it is',
        (tester) async {
      final api = _LibraryApi(deleteFails: true);
      await openList(tester, api: api);

      await tester.tap(actionOn('Vezani top', 'Obriši tutorijal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obriši'));
      await tester.pumpAndSettle();

      expect(find.text('Vezani top'), findsOneWidget,
          reason: 'a row that is still on the server must stay on the screen');
    });
  });

  group('sending a tutorial to a student', () {
    testWidgets('the row offers it, and only accepted students are listed',
        (tester) async {
      final assignments = _Assignments();
      await openList(
        tester,
        api: _LibraryApi(),
        assignments: assignments,
        students: _Students(),
      );

      await tester.tap(actionOn('Opozicija', 'Pošalji učeniku'));
      await tester.pumpAndSettle();

      expect(find.text('Pošalji učeniku'), findsWidgets);
      expect(find.text('Mila'), findsOneWidget);
      expect(find.text('Nepotvrđeni'), findsNothing,
          reason: 'a relationship nobody has accepted grants nothing, and the '
              'server is right to refuse it');
    });

    testWidgets('picking one sends that tutorial to that child',
        (tester) async {
      final assignments = _Assignments();
      await openList(
        tester,
        api: _LibraryApi(),
        assignments: assignments,
        students: _Students(),
      );

      await tester.tap(actionOn('Opozicija', 'Pošalji učeniku'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mila'));
      await tester.pumpAndSettle();

      expect(assignments.sent, hasLength(1));
      expect(assignments.sent.single.studentId, 3);
      expect(assignments.sent.single.lessonId, 12,
          reason: 'the tutorial that was sent is the row it was asked for');
    });

    testWidgets('a trainer with no accepted student is told so',
        (tester) async {
      final assignments = _Assignments();
      await openList(
        tester,
        api: _LibraryApi(),
        assignments: assignments,
        students: _Students(rows: const [
          {'id': 4, 'name': 'Nepotvrđeni', 'status': 'pending'},
        ]),
      );

      await tester.tap(actionOn('Opozicija', 'Pošalji učeniku'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nemate nijednog učenika'), findsOneWidget);
      expect(assignments.sent, isEmpty);
    });
  });

  testWidgets('and the row still opens the tutorial when it is tapped',
      (tester) async {
    final api = _LibraryApi();
    await openList(tester, api: api);

    await tester.tap(find.text('Opozicija'));
    await tester.pumpAndSettle();

    expect(find.text('Studio za tutorijal'), findsOneWidget,
        reason: 'the actions were added beside opening, not in front of it');
  });
}
