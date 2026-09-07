import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/features/lessons/widgets/preview_assignment_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/models/user_session.dart';

/// P8b of `docs/PLAN-STUDIO-REDIZAJN.md`: the last two things the old step
/// editor was still needed for.
///
/// **The door** (D8). On Windows the studio is the editor; everywhere else
/// `LessonStepEditorPanel` stays exactly as it is, because it is reachable on
/// every platform and deleting it would take tutorial editing off Android
/// altogether. One predicate, one door — and deleting the panel later is one
/// edit in one file rather than a hunt through two screens.
///
/// **The preview**, which was buried in the panel and is the fastest answer a
/// trainer has to „does this feel right". Nothing it does reaches the server.
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
        'kind': 'ask_move',
        'instruction': 'Napadni pešaka na e5.',
      },
    ],
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  tearDown(() => debugTutorialStudioAvailable = null);

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
    testWidgets('where the studio exists, the studio is the editor',
        (tester) async {
      debugTutorialStudioAvailable = true;

      await pumpDoor(tester);

      expect(find.byType(TutorialStudioScreen), findsOneWidget);
      expect(find.byType(LessonStepEditorPanel), findsNothing,
          reason: 'the panel D8 retires is still what „Uredi" opens on the '
              'platform that has the studio');

      await close(tester);
    });

    testWidgets('where it does not, the old panel is untouched',
        (tester) async {
      debugTutorialStudioAvailable = false;

      await pumpDoor(tester);

      expect(find.byType(LessonStepEditorPanel), findsOneWidget,
          reason: 'editing a tutorial disappeared from Android, which is a '
              'capability loss nobody asked for');
      expect(find.byType(TutorialStudioScreen), findsNothing);

      await close(tester);
    });
  });

  group('Pregledaj kao učenik', () {
    testWidgets('opens the tutorial the way a child meets it', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = api();
      await tester.pumpWidget(MaterialApp(
        home: TutorialStudioScreen(
          session: session,
          entry: TutorialEntry.saved(lesson),
          lessonApi: service,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('preview-as-student')));
      await tester.pumpAndSettle();

      expect(find.byType(LessonViewerScreen), findsOneWidget);
      expect(find.textContaining('Napadni pešaka na e5.'), findsWidgets,
          reason: 'the preview opened on something other than the tutorial '
              'being written');

      await close(tester);
    });

    testWidgets('sends nothing', (tester) async {
      // A trainer trying their own question must not mark a child's schedule,
      // and a preview that wrote to the server would be a save nobody asked
      // for. The viewer is handed `PreviewAssignmentApiService`, which answers
      // every call locally.
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = api();
      await tester.pumpWidget(MaterialApp(
        home: TutorialStudioScreen(
          session: session,
          entry: TutorialEntry.saved(lesson),
          lessonApi: service,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('preview-as-student')));
      await tester.pumpAndSettle();

      final viewer =
          tester.widget<LessonViewerScreen>(find.byType(LessonViewerScreen));
      expect(viewer.api, isA<PreviewAssignmentApiService>(),
          reason: 'the viewer was handed a service that talks to the backend, '
              'so trying your own question marks a child as having attempted '
              'it');
      expect(sent, isEmpty, reason: 'the preview reached the network: $sent');

      await close(tester);
    });
  });
}
