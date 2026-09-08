// Reopening a saved tutorial must not quietly downgrade it.
//
// Found on 7.9.2026 while trial-building P6b, by a fixture that opened a saved
// `ask_choice` part and pressed „Sačuvaj tutorijal" without touching anything.
// What came back was `{"kind":"show"}` with no `instruction` and no `choices`:
// the trainer's question, its answers and the recorded correct move, gone in
// one press, with „Tutorijal je sačuvan." on screen.
//
// **The cause was one missing call.** `initState` built the draft and then set
// the title and the board FEN by hand — it never called
// `_loadSelectedSection()`, which is the one place a part's kind, task,
// answers, solution and orientation are read into the editor. So those fields
// sat at their defaults, and the first `_persist()` — which any keystroke or
// the save itself triggers — wrote the defaults back over the part through
// `_syncSelectedSection()`.
//
// P2's round-trip test proved the **model** re-saves byte-identical, and it
// still does; the loss was on the way through the screen. That is why this
// file drives the widget and reads the request, and why it exists beside that
// one rather than inside it.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';

class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> saves;

  /// Any request carrying a `positionList`, whichever verb it used: a tutorial
  /// that already has an id is updated with a `PUT`, not created with a `POST`.
  factory _RecordingApi() {
    final saves = <Map<String, dynamic>>[];
    return _RecordingApi._(
      saves,
      MockClient((req) async {
        if (req.body.isNotEmpty) {
          final body = jsonDecode(req.body);
          if (body is Map && body.containsKey('positionList')) {
            saves.add(Map<String, dynamic>.from(body));
          }
        }
        return http.Response(jsonEncode({'id': 31}), 200);
      }),
    );
  }
}

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  /// A tutorial as the server hands it back. The step id is a **string**, which
  /// is what `routes/lessons.js` recognises — an integer here would test a
  /// shape the backend never sends.
  Map<String, dynamic> savedLesson(Map<String, dynamic> step) => {
        'id': 31,
        'title': 'Otvaranje',
        'position_list': [
          {'id': 'step-5', 'fen': startFen, 'title': 'Deo 1', ...step},
        ],
      };

  Future<_RecordingApi> open(
      WidgetTester tester, Map<String, dynamic> lesson) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingApi();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lesson),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<Map<String, dynamic>> saveAndReadStep(
      WidgetTester tester, _RecordingApi api) async {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1), reason: 'nothing was written at all');
    final list = (api.saves.single['positionList'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    expect(list, hasLength(1));
    return list.single;
  }

  group('a saved tutorial survives being reopened', () {
    testWidgets('a question saved unchanged is still a question',
        (tester) async {
      final api = await open(
          tester,
          savedLesson({
            'kind': 'ask_choice',
            'instruction': 'Šta beli postiže?',
            'choices': [
              {'text': 'Zauzima centar.', 'correct': true},
              {'text': 'Napada kralja.', 'correct': false},
            ],
          }));

      final step = await saveAndReadStep(tester, api);

      expect(step['kind'], 'ask_choice',
          reason: 'the part was downgraded to a plain position, and the child '
              'is now shown a board that asks nothing');
      expect(step['instruction'], 'Šta beli postiže?');
      expect(step['choices'], [
        {'text': 'Zauzima centar.', 'correct': true},
        {'text': 'Napada kralja.', 'correct': false},
      ]);
      expect(step['id'], 'step-5',
          reason: 'a step id resolves a schedule row and a recorded answer');

      await close(tester);
    });

    testWidgets('a question is on screen when the tutorial opens',
        (tester) async {
      // The other half of the same fault, and the half a trainer would notice:
      // the fields are empty, so the question looks as though it was never
      // written.
      await open(
          tester,
          savedLesson({
            'kind': 'ask_choice',
            'instruction': 'Šta beli postiže?',
            'choices': [
              {'text': 'Zauzima centar.', 'correct': true},
            ],
          }));

      expect(
          find.widgetWithText(TextField, 'Šta beli postiže?'), findsOneWidget,
          reason: 'the task the trainer wrote is not in the editor');
      expect(find.widgetWithText(TextField, 'Zauzima centar.'), findsOneWidget,
          reason: 'the offered answers are not in the editor');

      await close(tester);
    });

    testWidgets('a recorded answer move survives', (tester) async {
      final api = await open(
          tester,
          savedLesson({
            'kind': 'ask_move',
            'instruction': 'Napadni pešaka.',
            'solutionSan': 'Nf3',
          }));

      final step = await saveAndReadStep(tester, api);

      expect(step['kind'], 'ask_move');
      expect(step['solutionSan'], 'Nf3',
          reason: 'the move the child has to find was dropped, so the question '
              'can no longer be answered correctly by anybody');

      await close(tester);
    });
  });
}
