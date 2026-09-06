// The gate for batch E — the authoring half of `TutorialStudioScreen`: the
// fields for the example being written, the running list, and the one save.
// Phase 4b of docs/PLAN-TUTORIJAL.md.
//
// Written before the batch, and kept here rather than in `test/` until the
// batch lands — a gate that names controls nobody has built yet does not
// compile, and a suite that does not compile is a suite that tells you nothing
// about anything else. Move it to `chess_app/test/tutorial_authoring_test.dart`
// in the merge commit, the way the vocabulary and branching gates were moved.
//
// The rule it exists for: a batch with no lead-written gate grades itself.
// Batch 53 was the one launched without one, and the test it wrote for itself
// had a „sanity check" with no assertions and a muted `FlutterError.onError`,
// which made it green over a real 91 px overflow.
//
// It drives the screen through its own controls and asserts on the **request**,
// not on the screen. That is deliberate: the thing this batch is for is a
// single `POST /lessons/save` carrying a whole tutorial, and a test that
// watched the screen say „sačuvano" would pass over a body with one example
// missing, or two in the wrong order, or a question with no answer in it.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH E
//
// Written here, once, so the batch does not decide it and the reviewer does not
// have to guess what was meant. Everything below is what this file asserts.
//
// **Controls.** Text fields carry keys because there is no other stable handle
// on a text field; buttons carry their words, because the plan froze those.
//
//   Key('tutorial-title')        the tutorial's name          „Naziv tutorijala"
//   Key('example-sentence')      the sentence for the node the trainer is
//                                standing on — writes `AnalysisNode.comment`
//   Key('example-instruction')   the task, per example        „Zadatak za učenika"
//   Key('example-kind')          the dropdown, per example    „Tip zadatka"
//   Key('example-choice-N')      one offered answer, per example
//   „Dodaj sledeću poziciju u tutorijal"   commits this example, starts the next
//   „Sačuvaj tutorijal"                    the one and only write
//
// The running list shows the example being written too, not only the committed
// ones — a screen that opens with an empty list is a screen on which the
// trainer's first example is nowhere until they leave it. So a fresh screen
// reads „Primer 1", and after one „Dodaj sledeću poziciju" it reads „Primer 1"
// and „Primer 2".
//
// The three kind labels are the ones `LessonStepEditorPanel` already uses —
// „Samo prikaži", „Traži potez na tabli", „Traži odgovor iz liste" — as are
// „Ponuđeni odgovori", „Dodaj odgovor" and „Tačan potez: …". A trainer who has
// learned one of those screens has learned this one.
//
// **What belongs to what.** The sentence is *per node*: it is the word beside
// one move, it travels inside the pgn, and the narrated walk reads it out. The
// task, the kind, the offered answers and the answer are *per example*, because
// that is what a lesson step is on the server. A batch that puts a kind on
// every node has invented a second model of a step.
//
// **„Dodaj sledeću poziciju" starts where the last line ended.** The end of the
// example's main line, which is exactly the position the child's screen joins
// on — show, then ask, on one board with no reset (R2, built in phase 7). The
// board editor is still there for a trainer who wants to go somewhere else.
//
// **An `ask_move` example carries no line, and its answer is played on the same
// board.** This is the one rule here that was not in the plan, and it comes
// from the server: `redactStepForStudent` takes out `solutionSan` and the
// `correct` flags — and leaves `pgn` alone, because a line is the lesson. So a
// question whose line *begins with the answer* hands the child the answer, and
// `lesson_viewer_screen.dart` reads that line for every kind. Therefore:
//
//   * with the kind set to „Traži potez na tabli", a move played on the board
//     is recorded as the answer and the board goes back to the position — the
//     same interaction `LessonStepEditorPanel` already has, on the board that
//     is already there rather than on a second one;
//   * an example that has a line **and** asks for a move is refused before the
//     save, in a sentence, and nothing is sent. The demonstration belongs to
//     the example before it.
//
// `ask_choice` is not restricted: its answers are text, the `correct` flags are
// redacted, and a line under it gives nothing away.
//
// **Refused here, not by the server.** A save that reaches the backend and
// comes back 400 tells the trainer they lost the last twenty minutes. Three
// things are checked before anything is sent, each in its own sentence: a
// tutorial with no name, an `ask_move` example with a line, and an
// `ask_choice` example with no answer marked correct.
//
// **Not asserted here** because it is already asserted in
// `test/tutorial_studio_test.dart`: no second board, tree or cursor; the
// platform predicate; the draft outliving the screen. That file stays green
// unchanged — if a test in it has to be edited to make this batch pass, that is
// a finding, not a chore.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Every request the screen made, and what was in it.
///
/// Answers the way the real server answers — **201** for a save, since that is
/// the code `LessonApiService.save` reads as success. A mock that answered 200
/// would make the screen report a failure while this file still passed, because
/// a request did go out.
class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.seen, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<({String method, String path, Map<String, dynamic> body})> seen;

  factory _RecordingApi() {
    final seen = <({String method, String path, Map<String, dynamic> body})>[];
    return _RecordingApi._(
      seen,
      MockClient((req) async {
        seen.add((
          method: req.method,
          path: req.url.path,
          body: req.body.isEmpty
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(jsonDecode(req.body) as Map),
        ));
        return http.Response(jsonEncode({'id': 77}), 201);
      }),
    );
  }

  List<Map<String, dynamic>> get saves => [
        for (final r in seen)
          if (r.method == 'POST' && r.path.endsWith('/lessons/save')) r.body,
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  const firstSentence = 'Beli odmah zauzima centar.';
  const secondSentence = 'Crni odgovara isto — i centar je podeljen.';

  final session = UserSession(
    token: 'tok',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  AnalysisMoveTreeWidget tree(WidgetTester tester) =>
      tester.widget<AnalysisMoveTreeWidget>(
          find.byType(AnalysisMoveTreeWidget).first);

  Future<_RecordingApi> open(WidgetTester tester,
      {TutorialHandover? handover}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingApi();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.fromAnalysis(
            handover ?? TutorialHandover.position(startFen)),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  /// Tears the tree down without waiting out the draft's 600 ms debounce — see
  /// the note on the same helper in `test/tutorial_studio_test.dart`.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    board(tester).onMove(from, to, '');
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String value) async {
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.pumpAndSettle();
  }

  Future<void> pickKind(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('example-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String fragment) async {
    await tester.tap(find.textContaining(fragment).first);
    await tester.pumpAndSettle();
  }

  /// The check the server will make. Written out here rather than trusted to
  /// the app, because „the answer plays in the position it is asked in" is the
  /// one thing a wrong `ask_move` example looks fine without.
  void expectPlaysIn(String fen, String san) {
    final game = chess.Chess.fromFEN(fen);
    expect(game.move(san), isTrue,
        reason: 'rešenje „$san" ne može da se odigra u poziciji koja se šalje');
  }

  group('a whole tutorial reaches the server as one request', () {
    testWidgets('two examples, in order, with their words and their question',
        (tester) async {
      final api = await open(tester);

      await type(tester, 'tutorial-title', 'Otvaranje u dva primera');

      // Primer 1 — a demonstration. A sentence beside each move, which is what
      // the narrated walk reads out.
      await play(tester, 'e2', 'e4');
      await type(tester, 'example-sentence', firstSentence);
      await play(tester, 'e7', 'e5');
      await type(tester, 'example-sentence', secondSentence);

      await tapText(tester, 'Dodaj sledeću poziciju');
      expect(api.seen, isEmpty,
          reason: 'adding an example wrote to the server; decision 3 saves '
              'once, at the end, so a tutorial abandoned halfway leaves '
              'nothing half-written in the library');

      // Primer 2 — the question, standing on the position Primer 1 ended on.
      final askedFen = board(tester).controller.getFen();
      await pickKind(tester, 'Traži potez na tabli');
      await type(tester, 'example-instruction', 'Napadni pešaka na e5.');
      await play(tester, 'g1', 'f3');
      expect(find.textContaining('Tačan potez: Nf3'), findsOneWidget,
          reason: 'the trainer cannot see what the child will be asked');

      await tapText(tester, 'Sačuvaj tutorijal');

      expect(api.saves, hasLength(1),
          reason: 'one tutorial is one write — ${api.seen.length} requests '
              'went out in total');

      final body = api.saves.single;
      expect(body['title'], 'Otvaranje u dva primera');

      final list = (body['positionList'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      expect(list, hasLength(2), reason: 'an example was dropped');

      final show = list.first;
      expect(show['fen'], startFen);
      expect(show['kind'], 'show');
      expect(show['pgn'], contains('e4'));
      expect(show['pgn'], contains('e5'));
      expect(show['pgn'], contains(firstSentence),
          reason: 'the sentence beside the first move did not travel');
      expect(show['pgn'], contains(secondSentence));

      final ask = list.last;
      expect(ask['kind'], 'ask_move');
      expect(ask['instruction'], 'Napadni pešaka na e5.');
      expect(ask['solutionSan'], 'Nf3');
      expect(ask['fen'].toString().split(' ').take(2).join(' '),
          askedFen.split(' ').take(2).join(' '),
          reason: 'the question is asked in a different position than the one '
              'the demonstration left the board on, so the child gets a reset '
              'where the plan promised one unbroken flow');
      expectPlaysIn(ask['fen'] as String, 'Nf3');

      await close(tester);
    });

    testWidgets('every example replays from its own position', (tester) async {
      // `StudioLessonStep.from` owns the fen/pgn pairing — one node answers for
      // both — and it is reused rather than reimplemented. Asserted the way the
      // student's screen will read it, which is the only reading that counts:
      // a step whose line does not replay is a board that silently loses its
      // moves, and the trainer finds out from a child.
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Provera linije');

      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      await play(tester, 'g1', 'f3');
      // Standing in the middle of the line rather than at its end: the pairing
      // has to come from the example's root either way.
      await tester.tap(find.byTooltip('Prethodni potez'));
      await tester.pumpAndSettle();

      await tapText(tester, 'Sačuvaj tutorijal');

      for (final raw in api.saves.single['positionList'] as List) {
        final step = Map<String, dynamic>.from(raw as Map);
        final read = LessonStepLine.read(
          fen: step['fen'] as String,
          pgn: step['pgn'] as String? ?? '',
        );
        expect(read.replays, isTrue,
            reason: '${read.rejectedMoves} poteza iz linije ne može da se '
                'odigra iz pozicije koja se uz nju šalje');
      }

      await close(tester);
    });
  });

  group('the running list is what the child will read', () {
    testWidgets('the examples are numbered as they are written',
        (tester) async {
      await open(tester);
      expect(find.text('Primer 1'), findsOneWidget);
      expect(find.text('Primer 2'), findsNothing);

      await play(tester, 'e2', 'e4');
      await tapText(tester, 'Dodaj sledeću poziciju');

      expect(find.text('Primer 1'), findsOneWidget,
          reason: 'the example just committed left the list');
      expect(find.text('Primer 2'), findsOneWidget);
      await close(tester);
    });

    testWidgets('the next example starts where the last line ended',
        (tester) async {
      // This is R2 on the authoring side. The child's screen joins one step to
      // the next without reloading the board *when the positions match*, and
      // they only match if the trainer was put on the right one.
      await open(tester);

      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      final ended = board(tester).controller.getFen();

      await tapText(tester, 'Dodaj sledeću poziciju');

      expect(board(tester).controller.getFen().split(' ').take(2).join(' '),
          ended.split(' ').take(2).join(' '),
          reason: 'the trainer was dropped somewhere else to start the next '
              'example, so show and ask cannot join');
      expect(tree(tester).rootNode.children, isEmpty,
          reason: 'the new example inherited the previous one\'s moves');
      await close(tester);
    });

    testWidgets('the sentence field follows the move you are standing on',
        (tester) async {
      // The classic fault in a panel like this: the field keeps the text of the
      // node you have left, and the next keystroke writes it onto the node you
      // arrived at. Then two moves carry one sentence and nobody knows which
      // was meant.
      await open(tester);

      await play(tester, 'e2', 'e4');
      await type(tester, 'example-sentence', firstSentence);
      await play(tester, 'e7', 'e5');

      expect(find.text(firstSentence), findsNothing,
          reason: 'the sentence of the previous move is still in the field, '
              'waiting to be written onto this one');

      await type(tester, 'example-sentence', secondSentence);
      await tester.tap(find.byTooltip('Prethodni potez'));
      await tester.pumpAndSettle();

      expect(find.text(firstSentence), findsOneWidget,
          reason: 'walking back does not bring back what was written there');
      await close(tester);
    });
  });

  group('what is refused here, before anything is sent', () {
    testWidgets('a tutorial with no name', (tester) async {
      final api = await open(tester);
      await play(tester, 'e2', 'e4');

      await tapText(tester, 'Sačuvaj tutorijal');

      expect(api.seen, isEmpty,
          reason: 'the server would answer 400 and the trainer would read it '
              'as „čuvanje nije uspelo" after the work was done');
      await close(tester);
    });

    testWidgets('a question about a move, on an example that has a line',
        (tester) async {
      // The rule the server forced: `redactStepForStudent` leaves `pgn` alone,
      // and the viewer reads the line whatever the kind — so an `ask_move`
      // example carrying a line is a question with its answer printed under it.
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Pitanje sa linijom');

      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      await pickKind(tester, 'Traži potez na tabli');

      await tapText(tester, 'Sačuvaj tutorijal');

      expect(api.seen, isEmpty,
          reason: 'a question was saved with the answer inside its own line');
      await close(tester);
    });

    testWidgets('a move played as the answer is not added to the line',
        (tester) async {
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Samo pitanje');
      await pickKind(tester, 'Traži potez na tabli');

      await play(tester, 'e2', 'e4');

      expect(tree(tester).rootNode.children, isEmpty,
          reason: 'the answer became the first move of the line the child is '
              'shown');
      expect(board(tester).controller.getFen().split(' ').first,
          startFen.split(' ').first,
          reason: 'the board stayed on the answer instead of going back to '
              'the position being asked about');
      expect(find.textContaining('Tačan potez: e4'), findsOneWidget);

      await tapText(tester, 'Sačuvaj tutorijal');
      final step = Map<String, dynamic>.from(
          (api.saves.single['positionList'] as List).single as Map);
      expect(step['solutionSan'], 'e4');
      expect(
          step['pgn'] == null || (step['pgn'] as String).trim().isEmpty, isTrue,
          reason: 'the question travelled with a line after all');
      await close(tester);
    });

    testWidgets('offered answers with none of them marked right',
        (tester) async {
      // The server refuses this with „Tačno jedan ponuđeni odgovor mora da bude
      // tačan", and it is right to. Refusing it here is what keeps that
      // sentence from arriving after the trainer believed they were finished.
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Pitanje sa ponuđenim odgovorima');
      await pickKind(tester, 'Traži odgovor iz liste');

      await tapText(tester, 'Dodaj odgovor');
      await type(tester, 'example-choice-0', 'Kontrola centra');
      await tapText(tester, 'Dodaj odgovor');
      await type(tester, 'example-choice-1', 'Napad na kralja');

      await tapText(tester, 'Sačuvaj tutorijal');
      expect(api.seen, isEmpty);

      // Marked, and now it goes — with exactly one `correct: true`, which is
      // the shape `buildChoices` validates.
      await tester.tap(find.byType(Radio<int>).first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Sačuvaj tutorijal');

      final step = Map<String, dynamic>.from(
          (api.saves.single['positionList'] as List).single as Map);
      expect(step['kind'], 'ask_choice');
      expect(step['choices'], [
        {'text': 'Kontrola centra', 'correct': true},
        {'text': 'Napad na kralja', 'correct': false},
      ]);
      await close(tester);
    });
  });

  group('what batch E must not do', () {
    // Relative to `chess_app/`, which is where this file runs once it is moved
    // into `test/` — the same path `test/tutorial_studio_test.dart` reads.
    final source =
        File('lib/features/tutorial_studio/screens/tutorial_studio_screen.dart')
            .readAsStringSync();

    /// Every source file of the feature, read as one string.
    ///
    /// **This is the one edit P1 of `docs/PLAN-STUDIO-REDIZAJN.md` made to this
    /// file, and it is a widening.** The assertion below used to read the
    /// screen alone, because the screen was where an example was built. P1
    /// moved that into `TutorialSection`, so that a finished part keeps its
    /// tree and can be reopened — the pairing is honoured exactly as before,
    /// one layer down. Reading the whole feature keeps the rule and makes it
    /// stricter: `PgnExporterService` may not appear anywhere in here, not just
    /// in the screen.
    final featureSource = Directory('lib/features/tutorial_studio')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    test('the fen and the pgn of an example still come from one node', () {
      // `StudioLessonStep.from` is the thing that made those two stop coming
      // from different places. Code that exports a pgn itself has taken that
      // pairing apart again, and the failure is invisible until a child opens
      // a step that lost its moves.
      //
      // Asked of the **imports** rather than of the identifiers, because a bare
      // `contains` over a whole directory also matches a doc comment — and a
      // comment explaining why the exporter is not called here would have
      // failed this. An import is what says the code reaches for a class; prose
      // about it is not.
      expect(
          featureSource
              .contains('analysis_studio/services/studio_lesson_step.dart'),
          isTrue,
          reason: 'the example is built without the class that owns the '
              'fen/pgn pairing');
      expect(
          featureSource
              .contains('analysis_studio/services/pgn_exporter_service.dart'),
          isFalse,
          reason: 'the feature exports the line itself, beside the class whose '
              'whole job that is');
    });

    test('the save is written once, in one place', () {
      // Not „no second call site" as a matter of taste: two of them means a
      // half-written tutorial can reach the library from the one nobody
      // remembered to guard.
      final calls = RegExp(r'\.save\(').allMatches(source).length;
      expect(calls, lessThanOrEqualTo(1),
          reason: 'the screen calls save() $calls times');
    });
  });
}
