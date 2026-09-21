// Who gets the teaching tools in a room — item 5 of the owner's review of
// 21.9.2026, from TODO-provera 201.10: „ako učenik napravi sesiju i pozove
// trenera, obojica imaju panel".
//
// The rule itself is `mayTeachInRoom`, and every relationship the owner asked
// about is a case in `board_control_rules_test.dart`. This file holds the
// wiring: that a real room (not `STUDIO`, where everything is allowed) reads
// the account's accepted students and the room it opened, and hides „Make
// exercise" and the tutorial actions from someone who teaches nobody there —
// on a wide window, where the Board column is drawn for every seat.
//
// What it cannot reach: the room's roster arrives over Socket.IO, which a
// widget test has none of, so „trainer of somebody present" is held by the
// pure cases alone; here the roster is empty and the cases stand on „opened
// the room" and on nothing at all. Stated rather than papered over.
//
// Written against the real font (rule 8): with the test font the room's right
// column overflows, which is the font and not the room.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart' show loadRoboto;

/// [students] are this account's students, as `/trainer/students` answers.
http.Client _server(List<Map<String, Object>> students) =>
    MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/library/positions')) {
        return http.Response(
            jsonEncode({
              'items': [
                {
                  'kind': 'tutorial',
                  'id': '7',
                  'title': 'Opposition',
                  'fen': '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1',
                },
                {
                  'kind': 'position',
                  'id': '8',
                  'title': 'Kept from a lesson',
                  'fen': '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1',
                },
              ],
            }),
            200);
      }
      if (path == '/trainer/students') {
        return http.Response(jsonEncode({'students': students}), 200);
      }
      return http.Response('[]', 200);
    });

Future<void> _room(
  WidgetTester tester, {
  required String roomCode,
  required String role,
  List<Map<String, Object>> students = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = _server(students);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Roboto')
        .copyWith(extensions: const [AppColorTokens.light]),
    home: ChessGamePage(
      userSession: UserSession(
          id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
      roomCode: roomCode,
      initialRole: role,
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      groupApi: GroupApiService(client: client),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final _makeExercise = find.byType(MakeExerciseButton);
Finder _tutorialAction(String tooltip) => find.descendant(
    of: find.byKey(const ValueKey('library-row-tutorial-7')),
    matching: find.byTooltip(tooltip));

void main() {
  setUpAll(loadRoboto);

  setUp(() async {
    // GroupApiService reads its token from the session.
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'tok',
      'user_id': 1,
      'user_email': 'e',
      'user_name': 'N',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
  });

  testWidgets('a student seat that teaches nobody has no teaching tools',
      (tester) async {
    await _room(tester, roomCode: '123456', role: 'ucenik');

    expect(_makeExercise, findsNothing,
        reason: 'a student in somebody\'s room was offered „Make exercise"');
    expect(_tutorialAction('Options'), findsNothing);
    expect(_tutorialAction('Delete'), findsNothing);
    // Keeping one's own copy is not teaching: those stay.
    expect(find.text('Save analysis'), findsOneWidget);
    expect(find.text('Export PGN'), findsOneWidget);
    expect(find.text('Save position'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('the reported room: a student opened it — no teaching tools',
      (tester) async {
    // Seated 'trener' because they opened it, and nobody's trainer.
    await _room(tester, roomCode: '123456', role: 'trener');
    expect(_makeExercise, findsNothing,
        reason: 'the seat was read as the relationship');
    expect(_tutorialAction('Options'), findsNothing);
    await _close(tester);
  });

  testWidgets('a trainer who opened the room has them before anyone comes',
      (tester) async {
    await _room(tester, roomCode: '123456', role: 'trener', students: const [
      {'id': 2, 'name': 'Ana', 'status': 'accepted'},
    ]);
    expect(_makeExercise, findsOneWidget);
    expect(_tutorialAction('Options'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('an invitation nobody has answered makes nobody a trainer',
      (tester) async {
    await _room(tester, roomCode: '123456', role: 'trener', students: const [
      {'id': 2, 'name': 'Ana', 'status': 'pending'},
    ]);
    expect(_makeExercise, findsNothing,
        reason: 'a pending student counted as a student');
    await _close(tester);
  });

  testWidgets('Preparation keeps everything, students or not', (tester) async {
    await _room(tester, roomCode: 'STUDIO', role: 'host');
    expect(_makeExercise, findsOneWidget);
    expect(_tutorialAction('Options'), findsOneWidget);
    await _close(tester);
  });
}
