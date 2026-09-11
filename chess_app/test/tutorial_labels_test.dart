// A tutorial's labels, from the studio to the request.
//
// `saved_lessons.tags` has existed since the first saved position: the
// saved-position dialog writes it, `GET /lessons/labels` lists it, and
// `GET /lessons?includeTags=` filters on it. What never reached it was a
// tutorial — the studio sent a title and a position list and nothing else — so
// a trainer with forty tutorials had a list with no handle on it. The column
// was there the whole time, which is the shape this repository keeps meeting:
// a capability that exists at every layer and is reachable from nowhere.
//
// The second half is a fault the same wiring uncovered. `PUT /lessons/:id`
// wrote `description = $2, tags = $3` on **every** request, out of `body.x ||
// null`, and `commitDraft` mentions neither — so opening a saved tutorial and
// pressing "Save tutorial" erased its description, silently. Nothing in the app
// had ever written a tutorial's description until the JSON import arrived, so
// nobody had seen it. The server leaves an unmentioned column alone now
// (`chess_backend/test/lesson_update_keeps_labels.test.js`), and this file is
// the app's half: what the draft holds is what the save carries.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_save.dart';
import 'package:chess_app/models/user_session.dart';

const String startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  /// Every body carrying a `positionList`, whichever verb sent it.
  final List<Map<String, dynamic>> saves;

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
        // 201 for a create, 200 for an edit: `saveTutorial` reads the status
        // and a 200 to a POST is a failure as far as it is concerned.
        return http.Response(
            jsonEncode({'id': 31}), req.method == 'POST' ? 201 : 200);
      }),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  // **One id per test.** The studio adopts a stored draft when its `lessonId`
  // matches, and a screen flushes its draft on dispose — asynchronously, so a
  // file whose fixtures all said lesson 31 watched one test read the labels the
  // test before it had typed. It is the shape CLAUDE.md already records, and it
  // passed for one afternoon before a layout change moved the timing.
  var nextLessonId = 100;

  Map<String, dynamic> savedLesson({
    List<String>? tags,
    String? description,
  }) =>
      {
        'id': nextLessonId++,
        'title': 'Opposition',
        if (description != null) 'description': description,
        if (tags != null) 'tags': tags,
        'position_list': [
          {'id': 'step-5', 'fen': startFen, 'title': 'Deo 1', 'kind': 'show'},
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

  group('the studio', () {
    testWidgets('sends the labels that were typed into it', (tester) async {
      final api = await open(tester, savedLesson());

      await tester.enterText(
          find.byKey(const Key('tutorial-labels')), 'endgame, rook');
      await tester.tap(find.text('Save tutorial'));
      await tester.pumpAndSettle();

      expect(api.saves.single['tags'], ['endgame', 'rook']);
      await close(tester);
    });

    testWidgets('shows the labels a saved tutorial already has',
        (tester) async {
      // The same fault `tutorial_reopen_test.dart` was written for, one field
      // further along: a value the screen does not draw is a value the next
      // save writes its default over.
      await open(tester, savedLesson(tags: ['endgame', 'rook']));

      // Scoped to the field by key rather than searched for across the
      // screen: the hint is a comma-separated pair too, and a `widgetWithText`
      // over the whole screen matched more than one thing. The fifth time a
      // finder in this repository stopped being unique because the screen
      // grew — scope it, do not weaken it.
      final field =
          tester.widget<TextField>(find.byKey(const Key('tutorial-labels')));
      expect(field.controller?.text, 'endgame, rook');
      await close(tester);
    });

    testWidgets('keeps them when nothing about them is touched',
        (tester) async {
      final api = await open(tester, savedLesson(tags: ['endgame']));

      await tester.tap(find.text('Save tutorial'));
      await tester.pumpAndSettle();

      expect(api.saves.single['tags'], ['endgame'],
          reason: 'a save that does not mention the labels is how they were '
              'lost in the first place');
      await close(tester);
    });

    testWidgets('an emptied field clears them rather than leaving them',
        (tester) async {
      // "This tutorial has no labels now" has to stay sayable, which is why
      // the server treats an explicit empty list differently from silence.
      final api = await open(tester, savedLesson(tags: ['endgame']));

      await tester.enterText(find.byKey(const Key('tutorial-labels')), '  ');
      await tester.tap(find.text('Save tutorial'));
      await tester.pumpAndSettle();

      expect(api.saves.single['tags'], isEmpty);
      await close(tester);
    });

    testWidgets('carries the description it was opened with', (tester) async {
      // Nothing in the studio draws or edits it, and that is exactly why it
      // was being lost: the save wrote nothing, and the server read nothing as
      // "clear it".
      final api = await open(
          tester, savedLesson(description: 'Six positions about it'));

      await tester.tap(find.text('Save tutorial'));
      await tester.pumpAndSettle();

      expect(api.saves.single['description'], 'Six positions about it');
      await close(tester);
    });
  });

  group('commitDraft', () {
    test('sends the draft\'s labels and description on a create and an edit',
        () async {
      for (final lessonId in [null, 31]) {
        final api = _RecordingApi();
        final draft = TutorialDraft(
          lessonId: lessonId,
          title: 'Opposition',
          description: 'Generated',
          tags: ['endgame'],
          sections: [TutorialSection.blank(fen: startFen, title: 'Deo 1')],
        );

        final error = await commitDraft(draft, api);

        expect(error, isNull);
        expect(api.saves.single['tags'], ['endgame'],
            reason: 'lessonId: $lessonId');
        expect(api.saves.single['description'], 'Generated',
            reason: 'lessonId: $lessonId');
      }
    });
  });
}
