// The trainer says which language a tutorial is written in — phase 5 of
// docs/PLAN-JEZIK-GLASA.md.
//
// Until this, a tutorial got a language only from a JSON file or the
// translation script, so a trainer writing one in the studio had no way to say
// „this is Serbian" and the child heard it in the Settings voice. The model
// already carries all three answers (`tutorial_language_draft_test.dart`);
// this file is the control, and it asserts on the **request**, because a
// dropdown that shows the right word and sends the wrong one is exactly how a
// value is lost in this repository.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
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

  // One id per test: the studio adopts a stored draft whose `lessonId`
  // matches, and flushes its own on dispose.
  var nextLessonId = 400;

  /// A saved tutorial's row. [language] absent means a row from a server that
  /// does not send the column — the draft does not know its language at all.
  Map<String, dynamic> row({Object? language = _absent, int? id}) => {
        'id': id ?? nextLessonId++,
        'title': 'Opozicija',
        if (!identical(language, _absent)) 'language': language,
        'position_list': [
          {'id': 'step-5', 'fen': startFen, 'title': 'Deo 1', 'kind': 'show'},
        ],
      };

  Future<_RecordingApi> open(
    WidgetTester tester,
    Map<String, dynamic> lesson, {
    Size size = const Size(1600, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Closed even when an expectation fails: a studio left mounted flushes its
    // draft into the one slot the next test reads.
    addTearDown(() => close(tester));

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

  final dropdown = find.byKey(const Key('tutorial-language'));

  /// What the closed dropdown says it holds.
  String? shown(WidgetTester tester) =>
      tester.widget<DropdownButton<String?>>(dropdown).value;

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // The closed button draws its entries too; the open menu's is the last.
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
  }

  testWidgets('the language picked reaches the save', (tester) async {
    final api = await open(tester, row(language: null));

    await pick(tester, 'Serbian (Latin)');
    expect(shown(tester), 'sr-Latn', reason: 'the button says what was picked');
    await save(tester);

    expect(api.saves.single['language'], 'sr-Latn');
  });

  testWidgets('the language picked is kept on this device before any save',
      (tester) async {
    // The flush on close covers a screen that is closed; this is the window
    // that is not — the process killed, the laptop lid shut.
    await open(tester, row(language: null));

    await pick(tester, 'German');
    await tester.pump(const Duration(seconds: 1));

    final kept = await TutorialDraftService.instance.load();
    expect(kept?.language, 'de');
  });

  testWidgets('a saved tutorial opens on its language, and keeps it',
      (tester) async {
    final api = await open(tester, row(language: 'de'));

    // Asked of the button's value, not of its text: a closed dropdown builds
    // every entry and shows one, so „German" is found whichever is chosen.
    expect(shown(tester), 'de');

    await save(tester);
    expect(api.saves.single['language'], 'de',
        reason: 'untouched, it goes back as it came');
  });

  group('„Not set"', () {
    testWidgets('picked over a language says „not said", out loud',
        (tester) async {
      final api = await open(tester, row(language: 'sr-Cyrl'));

      await pick(tester, 'Not set');
      await save(tester);

      expect(api.saves.single.containsKey('language'), isTrue);
      expect(api.saves.single['language'], isNull);
    });

    testWidgets(
        'picked on a tutorial that never knew its language says nothing',
        (tester) async {
      // A row from a server without the column: „Not set" is what the menu
      // already shows, and choosing it again must not turn silence into „not
      // said" — that would clear a language set on another device.
      final api = await open(tester, row());

      expect(shown(tester), isNull);
      await pick(tester, 'Not set');
      await save(tester);

      expect(api.saves.single.containsKey('language'), isFalse);
    });
  });

  testWidgets(
      'a code this build does not know shows „Not set" and goes back '
      'untouched', (tester) async {
    // From a newer server. Guessing would be worse than reading it the old way,
    // and overwriting it would lose what that server knew.
    final api = await open(tester, row(language: 'pt'));

    expect(shown(tester), isNull);
    await save(tester);

    expect(api.saves.single['language'], 'pt');
  });

  testWidgets('follows the draft adopted after the first frame',
      (tester) async {
    // The reason this is not a `DropdownButtonFormField`: a form field keeps
    // the value it was built with, and the studio swaps in a draft of the same
    // tutorial kept on this device one frame later.
    final id = nextLessonId++;
    await TutorialDraftService.instance.flush(TutorialDraft(
      lessonId: id,
      title: 'Opozicija',
      language: 'fr',
      sections: [TutorialSection.blank(fen: startFen, title: 'Deo 1')],
    ));

    final api = await open(tester, row(language: 'de', id: id));

    expect(shown(tester), 'fr');
    await save(tester);
    expect(api.saves.single['language'], 'fr');
  });

  testWidgets('the preview is read in the language just picked',
      (tester) async {
    // The trainer picks a language to hear it — so the preview has to take
    // the draft's language as it is now, not as it was saved.
    await open(tester, row(language: null));

    await pick(tester, 'Italian');
    await tester.tap(find.byKey(const Key('preview-tutorial')));
    await tester.pumpAndSettle();

    final viewer =
        tester.widget<LessonViewerScreen>(find.byType(LessonViewerScreen));
    expect(viewer.detail.lessonLanguage, 'it');
  });

  testWidgets('a narrow window has it too', (tester) async {
    // Below 840 the authoring column is one scrolled stack under the board,
    // written separately from the wide pane — a field added to one branch and
    // not the other is how batch 58 arrived with a copied title.
    final api =
        await open(tester, row(language: null), size: const Size(700, 1000));

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await pick(tester, 'Spanish');
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();

    expect(api.saves.single['language'], 'es');
  });
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

const _absent = Object();
