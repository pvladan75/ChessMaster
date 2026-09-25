import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/models/user_session.dart';

/// P8b of `docs/PLAN-STUDIO-REDIZAJN.md`: the last two things the old step
/// editor was still needed for.
///
/// **The door** (D8, reversed by phase 6c of `docs/PLAN-REORGANIZACIJA.md`
/// on 17.9.2026). The studio is the editor everywhere now; the second editor
/// and the platform guard that chose between them are retired.
///
/// **The preview**, which was buried in the old editor and is the fastest
/// answer a trainer has to „does this feel right". Nothing it does reaches
/// the server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  late List<String> sent;

  LessonApiService api() {
    sent = [];
    return LessonApiService(
      authToken: 'tok',
      client: MockClient((req) async {
        sent.add('${req.method} ${req.url.path}');
        return http.Response(jsonEncode({'id': 77}), 200);
      }),
    );
  }

  final lesson = {
    'id': 31,
    'title': 'Otvaranje',
    'position_list': [
      {
        'fen': startFen,
        'title': 'Deo 1',
        'pgn': '{ Napadni pešaka na e5. } *',
      },
    ],
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Future<void> pumpDoor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openTutorialEditor(
              context,
              session: session,
              api: api(),
              lesson: lesson,
            ),
            child: const Text('Uredi'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Uredi'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('which editor opens', () {
    testWidgets('the studio is the editor, everywhere', (tester) async {
      await pumpDoor(tester);

      expect(find.byType(TutorialStudioScreen), findsOneWidget);

      await close(tester);
    });
  });
}
