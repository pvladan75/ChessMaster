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
import 'package:chess_app/models/user_session.dart';

/// A part that is nothing but a sentence — and the child has to read it.
///
/// „Pogledaj polje d5" is a whole lesson step, and the opening part of a
/// tutorial is very often exactly that: no moves, one paragraph. The path it
/// travels is longer than it looks — the comment lives on the tree's **root**,
/// `PgnExporterService` writes it ahead of move one, `pgnForSave` has to decide
/// that a part with no moves is still worth sending, the parser has to give it
/// back on the root, and the viewer has to draw it on the opening position.
///
/// Every one of those has been broken at least once: P3a found `pgnForSave`
/// dropping it, `mainLine()` used to parse it and not carry it out, and P8a
/// found the leak refusal reading it as „this part has a line". This file walks
/// the whole path in one go, from the trainer typing to the child reading,
/// because each of those bugs looked like a different feature from the inside.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const sentence = 'Ovaj tutorijal je o opoziciji. Gledaj gde stoje kraljevi.';

  final trainer = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  late List<Map<String, dynamic>> saves;

  LessonApiService recordingApi() {
    saves = [];
    return LessonApiService(
      authToken: 'tok',
      client: MockClient((req) async {
        if (req.body.isNotEmpty) {
          final body = jsonDecode(req.body);
          if (body is Map && body.containsKey('positionList')) {
            saves.add(Map<String, dynamic>.from(body));
          }
        }
        return http.Response(jsonEncode({'id': 5}), 201);
      }),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Future<void> openStudio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialStudioScreen(
          session: trainer,
          entry: const TutorialEntry.blank('Uvod'),
          lessonApi: recordingApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the sentence written on the opening position is sent', (
    tester,
  ) async {
    await openStudio(tester);

    await tester.enterText(find.byKey(const Key('example-sentence')), sentence);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();

    expect(saves, hasLength(1));
    final step = (saves.single['positionList'] as List).single as Map;
    expect(
      step['pgn']?.toString() ?? '',
      contains(sentence),
      reason: 'a part with no moves was sent without its line, so the only '
          'thing it had to say was dropped on the way out',
    );
  });

  testWidgets('and „Pregledaj kao učenik" reads it back on the board', (
    tester,
  ) async {
    await openStudio(tester);

    await tester.enterText(find.byKey(const Key('example-sentence')), sentence);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('preview-as-student')));
    await tester.pumpAndSettle();

    expect(find.byType(LessonViewerScreen), findsOneWidget);
    expect(
      find.textContaining('opoziciji'),
      findsWidgets,
      reason: 'the child opens on a board with nothing said about it',
    );

    await close(tester);
  });

  testWidgets(
    'a stored tutorial whose first part is only a sentence shows it',
    (tester) async {
      // The child's own path, with the step coming from the server rather than
      // from the screen that wrote it.
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: LessonViewerScreen(
            session: trainer,
            detail: AssignmentDetail(
              assignment: Assignment(id: 1, title: 'Uvod'),
              items: [AssignmentItem(puzzleId: null, position: 0)],
              steps: [
                LessonStep.fromJson({
                  'fen': startFen,
                  'pgn': '[Event "x"]\n\n{ $sentence } *',
                  'title': 'Deo 1',
                  'kind': 'show',
                }),
              ],
            ),
            api: PreviewAssignmentApiService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('opoziciji'), findsWidgets);

      await close(tester);
    },
  );
}
