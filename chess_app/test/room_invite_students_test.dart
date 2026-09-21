// Who the room offers to invite — docs/PLAN-SESIJA.md, §5.6.
//
// Reported live on 21.9.2026: a student started a session, invited their
// trainer, was told „successfully sent", and nothing arrived. The dialog read
// `/friends`, which holds both directions of every relationship. Whoever
// starts a session is teaching in it: the list is their accepted students.
//
// Supersedes `invite_friends_dialog_test.dart` (25.8.2026), which read this
// screen's source as text for `['friends']` and `loadError`. Its two rules are
// held here by behaviour instead: the list that is drawn is the list the server
// sent, and a server that fails is not „you have nobody".
//
// Real font (rule 8): with the test font the room's right column overflows.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart' show loadRoboto;

final _invite = find.text('Invite students to session');

/// [students] is `/trainer/students` as the server answers it; null is a
/// server that fails. `/friends` answers with the trainer, so a dialog that
/// still reads it shows a name this file can see.
Future<List<String>> _room(
  WidgetTester tester, {
  required List<Map<String, Object>>? students,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final asked = <String>[];
  final client = MockClient((req) async {
    asked.add(req.url.path);
    if (req.url.path == '/trainer/students') {
      if (students == null) return http.Response('boom', 500);
      return http.Response(jsonEncode({'students': students}), 200);
    }
    if (req.url.path == '/friends') {
      return http.Response(
          jsonEncode({
            'friends': [
              {'id': 7, 'name': 'My Trainer'}
            ]
          }),
          200);
    }
    if (req.url.path.endsWith('/library/positions')) {
      return http.Response(jsonEncode({'items': []}), 200);
    }
    return http.Response('[]', 200);
  });

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Roboto')
        .copyWith(extensions: const [AppColorTokens.light]),
    home: ChessGamePage(
      userSession: UserSession(
          id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
      roomCode: '123456',
      initialRole: 'trener',
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      groupApi: GroupApiService(client: client),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));

  await tester.ensureVisible(_invite);
  await tester.pump();
  await tester.tap(_invite);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return asked;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(loadRoboto);

  setUp(() async {
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

  testWidgets('the list is the students who accepted, and nobody else',
      (tester) async {
    await _room(tester, students: [
      {'id': 42, 'name': 'Ana', 'status': 'accepted'},
      {'id': 43, 'name': 'Marko', 'status': 'pending'},
      {'id': 44, 'name': 'Mila', 'status': 'awaiting_parent'},
    ]);

    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.text('Ana')),
        findsOneWidget);
    expect(
        find.descendant(of: dialog, matching: find.text('Marko')), findsNothing,
        reason: 'a request nobody answered is not a student');
    expect(
        find.descendant(of: dialog, matching: find.text('Mila')), findsNothing);
    expect(find.descendant(of: dialog, matching: find.text('My Trainer')),
        findsNothing,
        reason: 'the dialog still reads /friends');
    await _close(tester);
  });

  testWidgets('/friends is not asked at all', (tester) async {
    final asked = await _room(tester, students: [
      {'id': 42, 'name': 'Ana', 'status': 'accepted'},
    ]);
    expect(asked, isNot(contains('/friends')));
    await _close(tester);
  });

  testWidgets('somebody who teaches nobody is told so', (tester) async {
    await _room(tester, students: []);
    expect(find.textContaining('You have no students yet'), findsOneWidget);
    expect(find.text('Could not load list.'), findsNothing);
    await _close(tester);
  });

  testWidgets('a server that fails is not „you have nobody"', (tester) async {
    await _room(tester, students: null);
    expect(find.text('Could not load list.'), findsOneWidget);
    expect(find.textContaining('You have no students yet'), findsNothing);
    await _close(tester);
  });
}
