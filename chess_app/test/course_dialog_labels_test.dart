import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/create_course_dialog.dart';

/// „Edit positions" in the room orders a tutorial's steps and leaves its labels
/// alone.
///
/// Found by the architecture audit on 16.9.2026 (`docs/audit/app.md`, 4 and 7).
/// The dialog sent `tags: ['lekcija_kurs']` on every save — a Serbian marker
/// nothing reads — so reordering the steps of a tutorial replaced the labels the
/// trainer had given it in the library or the studio. Asserted on the request.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return AppSettingsService.instance.init();
  });

  const fen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  final session = UserSession(
      token: 't', id: 1, email: 'a@b.c', name: 'Trainer', role: 'trener');

  Map<String, dynamic> labelledTutorial() => {
        'id': 7,
        'title': 'Weak squares',
        'tags': ['endgame', 'rook'],
        'position_list': [
          {'id': 'a3f9c1d2', 'fen': fen, 'title': 'Part 1'},
        ],
      };

  Future<List<http.Request>> openAndPress(
      WidgetTester tester, String button) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final sent = <http.Request>[];
    final api = LessonApiService(
      authToken: 't',
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(
            jsonEncode({
              'id': 8,
              'lesson': {'id': 8}
            }),
            200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => CreateCourseDialog(
                userSession: session,
                onCourseCreated: () {},
                existingLesson: labelledTutorial(),
                lessonApi: api,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return sent.where((r) => r.method != 'GET').toList();
  }

  testWidgets(
      'saving changes says nothing about the labels, so the server keeps them',
      (tester) async {
    final sent = await openAndPress(tester, 'Save changes');
    expect(sent, hasLength(1));
    final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
    expect(body.containsKey('tags'), isFalse, reason: 'body: $body');
    expect(sent.single.body, isNot(contains('lekcija_kurs')));
  });

  testWidgets('saving as a new version carries the original\'s labels',
      (tester) async {
    final sent = await openAndPress(tester, 'Save as new');
    expect(sent, hasLength(1));
    final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
    expect(body['tags'], ['endgame', 'rook']);
  });
}
