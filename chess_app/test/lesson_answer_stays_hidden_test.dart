// A question must not carry the line that answers it.
//
// Found on 6.9.2026 while writing the gate for the tutorial studio, in code
// that was already merged. The chain is short and every link of it is
// deliberate:
//
//   * a step's `pgn` is the lesson, so `redactStepForStudent`
//     (`chess_backend/services/lessonSteps.js`) takes out `solutionSan`,
//     `acceptedSans` and the `correct` flags and **leaves the line alone**;
//   * `lesson_viewer_screen.dart` reads that line for **every** kind of step,
//     and draws the move strip whenever it has moves in it;
//   * `LessonStepEditorPanel` is the one place in the app where a step's kind
//     is written, and it let a trainer set „Traži potez na tabli" on a step
//     that already had a line.
//
// So a child on a question could press „Sledeći potez" and watch the answer
// played for them. Nobody would report it as a bug: the child would simply
// stop getting anything wrong.
//
// **Where the fix lives, and why here rather than on the server.** The rule
// this file enforces is not one of the server's refusals being copied into
// Dart — `test/lesson_editor_test.dart` says the editor must not do that, and
// it is right. The server does not make this refusal and cannot: it stores
// `pgn` as opaque text and has no PGN reader, and giving it one would be a
// second parser disagreeing with the app's — which is a fault this codebase has
// already paid for. The app has exactly one reader, `LessonStepLine.read`, and
// this file is written against it.
//
// The trainer is not left stuck. The line is not deleted behind their back and
// the question is not refused outright: they are told what the child would see
// and asked, and the demonstration belongs in the step *before* the question —
// which is the „show, then ask" shape the viewer already joins without
// reloading the board.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return AppSettingsService.instance.init();
  });

  // White mates in one with Ra8#. The line below *is* the answer, which is
  // exactly the case that matters — a trainer who worked the position out on
  // the analysis board and then turned it into a question.
  const fen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  const linePgn = '[SetUp "1"]\n[FEN "$fen"]\n\n1. Ra8# {Mat po osmom redu.}';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  Map<String, dynamic> lesson({
    String? kind,
    String? pgn = linePgn,
    String? solutionSan,
  }) =>
      {
        'id': 7,
        'title': 'Mat po osmom redu',
        'position_list': [
          {
            'id': 'a3f9c1d2',
            'fen': fen,
            'title': 'Prvi',
            if (pgn != null) 'pgn': pgn,
            if (kind != null) 'kind': kind,
            if (solutionSan != null) 'solutionSan': solutionSan,
          },
          {'id': 'b7e2d4a1', 'fen': fen, 'title': 'Drugi'},
        ],
      };

  Future<void> openEditor(
    WidgetTester tester,
    _FakeApi api, {
    Map<String, dynamic>? withLesson,
  }) async {
    // A desktop panel: it draws a 300 px board and a column of fields, and the
    // default 800x600 test surface leaves „Sačuvaj korak" off the bottom as
    // soon as anything is added above it.
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonStepEditorPanel(
          session: session,
          api: api,
          lesson: withLesson ?? lesson(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> chooseAskMove(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('step-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traži potez na tabli').last);
    await tester.pumpAndSettle();
  }

  group('turning a step with a line into a question', () {
    testWidgets('asks before it happens, and says what the child would see',
        (tester) async {
      final api = _FakeApi();
      await openEditor(tester, api);

      await chooseAskMove(tester);

      expect(find.textContaining('Dete bi videlo odgovor'), findsOneWidget,
          reason: 'the trainer was allowed to publish the answer with no word '
              'about it');
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();
    });

    testWidgets('saying no leaves the step exactly as it was', (tester) async {
      final api = _FakeApi();
      await openEditor(tester, api);

      await chooseAskMove(tester);
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Samo prikaži'), findsOneWidget,
          reason: 'the dropdown is showing a kind the step does not have, so '
              'the trainer believes they set a question and did not');

      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      final step = api.saved.single.first;
      expect(step['kind'], isNull,
          reason: 'the question was set anyway, after the trainer said no');
      expect(step['pgn'], linePgn, reason: 'the line was taken even so');
    });

    testWidgets('saying yes takes the line and sets the question',
        (tester) async {
      final api = _FakeApi();
      await openEditor(tester, api);

      await chooseAskMove(tester);
      await tester.tap(find.text('Ukloni liniju i postavi pitanje'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      final step = api.saved.single.first;
      expect(step['kind'], 'ask_move');
      expect(
          step['pgn'] == null || (step['pgn'] as String).trim().isEmpty, isTrue,
          reason: 'the question still carries the line that answers it');
    });

    testWidgets('a step with no line is not asked about at all',
        (tester) async {
      // The ordinary case has to stay ordinary. A dialog in front of every
      // question is a dialog trainers learn to dismiss without reading.
      final api = _FakeApi();
      await openEditor(tester, api, withLesson: lesson(pgn: null));

      await chooseAskMove(tester);

      expect(find.textContaining('Dete bi videlo odgovor'), findsNothing);
      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();
      expect(api.saved.single.first['kind'], 'ask_move');
    });
  });

  group('a step already saved in that state', () {
    testWidgets('says so when it is opened', (tester) async {
      // These exist: the combination was reachable for as long as the editor
      // has, so the lesson a trainer opens tomorrow may already be leaking.
      final api = _FakeApi();
      await openEditor(tester, api,
          withLesson: lesson(kind: 'ask_move', solutionSan: 'Ra8#'));

      expect(find.textContaining('Dete bi videlo odgovor'), findsOneWidget);
    });

    testWidgets('is not sent while it is still in it', (tester) async {
      // The one place the editor refuses a save, and it is not a copy of a
      // server refusal — the server does not make this one. Loud, because the
      // quiet version is a child who stops getting anything wrong.
      final api = _FakeApi();
      await openEditor(tester, api,
          withLesson: lesson(kind: 'ask_move', solutionSan: 'Ra8#'));

      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      expect(api.saved, isEmpty);
      expect(find.textContaining('„Prvi"'), findsOneWidget,
          reason: 'the refusal has to name the step, or a trainer with twelve '
              'of them cannot act on it');
    });

    testWidgets('one tap fixes it, and then it saves', (tester) async {
      final api = _FakeApi();
      await openEditor(tester, api,
          withLesson: lesson(kind: 'ask_move', solutionSan: 'Ra8#'));

      await tester.tap(find.text('Ukloni liniju'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dete bi videlo odgovor'), findsNothing);

      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      final step = api.saved.single.first;
      expect(step['kind'], 'ask_move');
      expect(step['solutionSan'], 'Ra8#',
          reason: 'the answer was lost with it');
      expect(step['pgn'] == null || (step['pgn'] as String).trim().isEmpty,
          isTrue);
    });
  });

  group('what is not restricted', () {
    testWidgets('a question with offered answers may keep its line',
        (tester) async {
      // Its answers are text and their `correct` flags are redacted, so the
      // line gives nothing away — and a line under a question about a *plan* is
      // usually the whole point.
      final api = _FakeApi();
      await openEditor(tester, api);

      await tester.tap(find.byKey(const Key('step-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Traži odgovor iz liste').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Dete bi videlo odgovor'), findsNothing);

      await tester.tap(find.text('Sačuvaj korak'));
      await tester.pumpAndSettle();

      final step = api.saved.single.first;
      expect(step['kind'], 'ask_choice');
      expect(step['pgn'], linePgn);
    });
  });
}

class _FakeApi extends LessonApiService {
  _FakeApi() : super(authToken: 't');

  /// Every `positionList` the editor sent, in order.
  ///
  /// It always answers success. Every refusal in this file happens before a
  /// request goes out, so a failing server would only hide which of the two
  /// stopped it.
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
    return null;
  }
}
