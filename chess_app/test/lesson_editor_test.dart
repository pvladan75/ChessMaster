import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/create_course_dialog.dart';

/// Phase 7b of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: the trainer's editor.
///
/// **Written by the lead, before the batch, and the batch is graded on turning
/// these green without editing them.**
///
/// Two decisions from the owner, 5.9.2026, and most of this file is one or the
/// other:
///
/// 1. **The studio panel owns a step's content; `CreateCourseDialog` keeps only
///    the order.** The dialog goes on picking positions from the library and
///    arranging them, and loses its instruction field — one place a step's words
///    are written, not two. Two authoring surfaces is the same disease as two
///    parsers, which phase 2 spent a whole batch curing.
/// 2. **The preview shows and does not judge.** It runs the student's own
///    widget so the two cannot drift, and answers nothing: judging locally would
///    put a second authority in the app, which is the thing §2.4 exists to
///    prevent. The trainer is checking wording, drawing and layout, and already
///    knows the answer.
///
/// The third rule under most of this file is older: **the server is the only
/// authority on what a step may be.** `buildLessonStep` refuses with a sentence
/// a trainer can act on — the editor sends what was typed and shows what comes
/// back. A copy of those rules in Dart is a second copy to keep in step, and the
/// one that drifts is the one nobody is testing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return AppSettingsService.instance.init();
  });

  const fen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  /// A stored lesson: two steps, both carrying the id the server gave them.
  Map<String, dynamic> lessonWithIds() => {
        'id': 7,
        'title': 'Slaba polja',
        'position_list': [
          {
            'id': 'a3f9c1d2',
            'fen': fen,
            'title': 'Prvi',
            'instruction': 'Nađi mat u jednom potezu.',
            'kind': 'ask_move',
            'solutionSan': 'Ra8#',
          },
          {'id': 'b7e2d4a1', 'fen': fen, 'title': 'Drugi'},
        ],
      };

  Future<void> openEditor(
    WidgetTester tester,
    _FakeApi api, {
    Map<String, dynamic>? lesson,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonStepEditorPanel(
          session: session,
          api: api,
          lesson: lesson ?? lessonWithIds(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('the server is the only authority on what a step may be', () {
    testWidgets('a refusal is shown in the words it arrived in',
        (tester) async {
      // `buildLessonStep` says which rule was broken. „Čuvanje nije uspelo" in
      // its place throws away the only part a trainer can act on.
      final api = _FakeApi(error: 'Korak koji traži potez mora imati rešenje.');
      await openEditor(tester, api);

      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      expect(find.text('Korak koji traži potez mora imati rešenje.'),
          findsOneWidget);
    });

    testWidgets('an incomplete step is still sent, not blocked here',
        (tester) async {
      // The editor does not re-implement the refusals. If it did, the two would
      // drift, and the copy nobody tests is the one in Dart.
      final api = _FakeApi(error: 'Korak koji traži potez mora imati rešenje.');
      await openEditor(tester, api, lesson: {
        'id': 7,
        'title': 'Slaba polja',
        'position_list': [
          {
            'id': 'c1c1c1c1',
            'fen': fen,
            'title': 'Bez rešenja',
            'kind': 'ask_move'
          },
        ],
      });

      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      expect(api.saved, isNotEmpty,
          reason: 'the server has to be the one to say no');
    });
  });

  group('a step keeps its identity through an edit', () {
    testWidgets('every id the editor was given comes back out', (tester) async {
      // Phase 1's guarantee, exercised through the real editor rather than
      // through `buildLessonStep` alone. A step that loses its id orphans every
      // schedule row and every recorded answer naming it — silently, because
      // nothing joins on them.
      final api = _FakeApi();
      await openEditor(tester, api);

      await tester.enterText(
          find.byKey(const Key('step-instruction')), 'Nova rečenica.');
      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      final sent = api.saved.single;
      expect(sent.map((s) => s['id']), ['a3f9c1d2', 'b7e2d4a1']);
    });
  });

  group('the preview is the student’s screen, and it does not judge', () {
    testWidgets('it instantiates the viewer rather than drawing its own',
        (tester) async {
      // Two renderers drift. The preview must be the same widget in a different
      // container, which is the rule phase 2 paid for with two parsers.
      await openEditor(tester, _FakeApi());

      await tester.tap(find.text('Pregled'));
      await tester.pumpAndSettle();

      expect(find.byType(LessonViewerScreen), findsOneWidget);
    });

    testWidgets('and hands it a service of its own, never the live one',
        (tester) async {
      // §2.4: the server is the only judge, and the preview does not ask it
      // anything. `LessonViewerScreen` builds a real `AssignmentApiService` from
      // the session when none is given — which would mark steps seen and post
      // answers against the trainer's own account, from a preview. The seam
      // batch 48 added for its tests is the seam this needs: the preview must
      // pass something, and what it passes must not be reaching a server.
      await openEditor(tester, _FakeApi());

      await tester.tap(find.text('Pregled'));
      await tester.pumpAndSettle();

      final viewer =
          tester.widget<LessonViewerScreen>(find.byType(LessonViewerScreen));
      expect(viewer.api, isNotNull,
          reason: 'a preview that lets the viewer build its own service is a '
              'preview that talks to the server');

      // And the trainer sees their own wording, which is the whole point of
      // looking.
      expect(find.text('Nađi mat u jednom potezu.'), findsWidgets);
    });

    testWidgets('a move played in the preview reaches no server at all',
        (tester) async {
      // Added by the lead on 6.9.2026, after batch 50 satisfied the assertion
      // above with `AssignmentApiService(authToken: '')` — a real service with
      // no token, which posts, is refused, and marks steps seen against nobody.
      // `isNotNull` was the letter of the rule and this is the substance of it:
      // press the board in a preview and nothing may go out.
      //
      // A service that does reach the network answers null here (the test
      // harness refuses every request), and the viewer says «Odgovor nije
      // poslat — proveri vezu.» — so the failure is visible rather than
      // theoretical.
      await openEditor(tester, _FakeApi());

      await tester.tap(find.text('Pregled'));
      await tester.pumpAndSettle();

      final state = tester
          .state<LessonViewerScreenState>(find.byType(LessonViewerScreen));
      await state.submitMove('Ra8#');
      await tester.pumpAndSettle();

      expect(find.text('Odgovor nije poslat — proveri vezu.'), findsNothing,
          reason: 'the preview tried to send the answer somewhere');
      expect(find.text('Tačno.'), findsNothing,
          reason: 'and it must not have judged it either');
    });
  });

  group('the editor is reachable from the app', () {
    // Batch 50 shipped a panel nothing opened. Every gate passed — the widget
    // was built, tested and formatted — because what was missing was not code
    // but a *caller*, and a test that pumps a widget directly proves it works
    // without proving anyone can get to it. The same shape as `getDue`, which
    // was called by nothing for weeks with its own tests green.
    //
    // A source-reading test, so it is proved by mutation below rather than
    // believed: delete the studio's action and this goes red.
    test('something under lib/ opens LessonStepEditorPanel', () {
      const panel =
          'lib/features/lessons/widgets/lesson_step_editor_panel.dart';
      final callers = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.endsWith(panel.split('/').last)) continue;
        if (entity.readAsStringSync().contains('LessonStepEditorPanel(')) {
          callers.add(path);
        }
      }

      expect(callers, isNotEmpty,
          reason: 'the trainer cannot write a step from anywhere in the app: '
              'nothing under lib/ constructs LessonStepEditorPanel, so it is '
              'reachable only from this test file');
    });
  });

  group('one place a step’s words are written', () {
    testWidgets('the course dialog no longer asks for an instruction',
        (tester) async {
      // The owner's decision, 5.9.2026: the dialog keeps the order and the
      // picking, the studio panel keeps the content.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreateCourseDialog(
                  userSession: session,
                  onCourseCreated: () {},
                  existingLesson: lessonWithIds(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Zadatak za učenika'), findsNothing,
          reason:
              'the per-step instruction is written in the studio panel now');
    });
  });
}

/// Stands in for the server, and records what the editor tried to send.
class _FakeApi extends LessonApiService {
  _FakeApi({this.error}) : super(authToken: 't');

  final String? error;

  /// Every `positionList` the editor sent, in order.
  final List<List<Map<String, dynamic>>> saved = [];

  @override
  Future<String?> update({
    required int id,
    required String title,
    String? description,
    List<String>? tags,
    String? fen,
    String? pgn,
    List<Map<String, dynamic>>? positionList,
  }) async {
    if (positionList != null) saved.add(positionList);
    return error;
  }

  @override
  Future<String?> appendStep({
    required int lessonId,
    required Map<String, dynamic> step,
  }) async {
    saved.add([step]);
    return error;
  }
}
