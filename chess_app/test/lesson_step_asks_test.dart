import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 4b of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: a lesson step that asks.
///
/// **Written by the lead, before the batch, and the batch is graded on turning
/// them green without editing them.** A worker that writes the tests that judge
/// it is how an earlier batch on this project produced tests that pumped no
/// panel and reported success.
///
/// The backend is done and frozen (`c9d0513`): the server judges, and the
/// answer never reaches the client — `getAssignmentDetail` redacts it. So the
/// screen cannot mark its own work, and nothing here pretends it can. The fake
/// below stands in for the server, and it is the only thing that knows an
/// answer.
void main() {
  const mateFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  AssignmentDetail detailOf(List<LessonStep> steps) => AssignmentDetail(
        assignment: Assignment(
          id: 5,
          title: 'Slaba polja',
          kind: AssignmentKind.lesson,
          totalItems: steps.length,
        ),
        items: [
          for (var i = 0; i < steps.length; i++)
            AssignmentItem(puzzleId: null, position: i),
        ],
        steps: steps,
      );

  Future<void> open(
      WidgetTester tester, AssignmentDetail detail, _FakeApi api) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(session: session, detail: detail, api: api),
    ));
    await tester.pump();
  }

  group('the model carries what the step asks', () {
    test('a step with no kind is a show step', () {
      final step = LessonStep.fromJson({'title': 'A', 'fen': mateFen});

      expect(step.kind, LessonStepKind.show);
      expect(step.choices, isEmpty);
    });

    test('an ask_move step says so', () {
      final step = LessonStep.fromJson({
        'title': 'A',
        'fen': mateFen,
        'kind': 'ask_move',
        'instruction': 'Nađi mat u jednom potezu.',
      });

      expect(step.kind, LessonStepKind.askMove);
    });

    test('an ask_choice step keeps its options in order', () {
      final step = LessonStep.fromJson({
        'title': 'A',
        'fen': mateFen,
        'kind': 'ask_choice',
        'choices': [
          {'text': 'Otvoriti liniju'},
          {'text': 'Zameniti damu'},
        ],
      });

      expect(step.kind, LessonStepKind.askChoice);
      expect(step.choices, ['Otvoriti liniju', 'Zameniti damu']);
    });

    test('a kind this build does not know is read as show', () {
      // The opposite of the server's rule, and deliberately so. The server
      // refuses an unknown kind because a trainer typing one must be told; an
      // *older app* meeting a newer kind has nobody to tell and a child in
      // front of it, so it shows the board and asks nothing rather than
      // breaking the lesson.
      final step = LessonStep.fromJson({
        'title': 'A',
        'fen': mateFen,
        'kind': 'ask_something_from_2027',
      });

      expect(step.kind, LessonStepKind.show);
    });
  });

  group('a show step is untouched by any of this', () {
    testWidgets('no verdict, no options, and the board still takes a move',
        (tester) async {
      final api = _FakeApi();
      await open(
        tester,
        detailOf([
          const LessonStep(
              title: 'Zadnji red',
              fen: mateFen,
              instruction: 'Beli matira u jednom potezu.'),
        ]),
        api,
      );

      // The task is still shown — that behaviour was found live and is right.
      expect(find.text('Beli matira u jednom potezu.'), findsOneWidget);
      expect(find.text('Pokaži mi'), findsNothing);

      final board = tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
      expect(board.isAllowedToMove, isTrue);

      // And nothing is sent anywhere: a step that asks nothing has no answer.
      expect(api.answers, isEmpty);
    });
  });

  group('ask_choice', () {
    LessonStep choiceStep() => const LessonStep(
          title: 'Plan',
          fen: mateFen,
          kind: LessonStepKind.askChoice,
          instruction: 'Koji je plan?',
          choices: ['Otvoriti liniju', 'Zameniti damu'],
        );

    testWidgets('the options are on screen and the board is not playable',
        (tester) async {
      await open(tester, detailOf([choiceStep()]), _FakeApi());

      expect(find.text('Otvoriti liniju'), findsOneWidget);
      expect(find.text('Zameniti damu'), findsOneWidget);

      // Dragging pieces answers nothing here, and a board that moves under a
      // question the child is meant to answer in words is a board that says the
      // question was about a move.
      final board = tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
      expect(board.isAllowedToMove, isFalse);
    });

    testWidgets('choosing sends the index, and the server decides',
        (tester) async {
      final api = _FakeApi(correct: true);
      await open(tester, detailOf([choiceStep()]), api);

      await tester.tap(find.text('Zameniti damu'));
      await tester.pumpAndSettle();

      expect(api.answers.single.choiceIndex, 1);
      expect(api.answers.single.moveSan, isNull);
      expect(find.text('Tačno.'), findsOneWidget);
    });

    testWidgets('a wrong answer says why, in the server\'s own words',
        (tester) async {
      final api = _FakeApi(correct: false, reason: 'netačan odgovor');
      await open(tester, detailOf([choiceStep()]), api);

      await tester.tap(find.text('Otvoriti liniju'));
      await tester.pumpAndSettle();

      // The reason comes from the server rather than being composed here, so
      // the child is told what actually happened — „taj potez nije moguć" and
      // „nije traženi potez" mean very different things.
      expect(find.text('netačan odgovor'), findsOneWidget);
    });
  });

  group('ask_move', () {
    LessonStep moveStep() => const LessonStep(
          title: 'Zadnji red',
          fen: mateFen,
          kind: LessonStepKind.askMove,
          instruction: 'Nađi mat u jednom potezu.',
        );

    testWidgets('the board waits for a move and no options are offered',
        (tester) async {
      await open(tester, detailOf([moveStep()]), _FakeApi());

      final board = tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
      expect(board.isAllowedToMove, isTrue);
      expect(find.text('Nađi mat u jednom potezu.'), findsOneWidget);
    });

    testWidgets('an accepted alternative says where the lesson goes on from',
        (tester) async {
      // §2.5 of the plan. Without this sentence the board appears to silently
      // overrule a move the app has just called right.
      final api = _FakeApi(correct: true, solutionSan: 'Ra8#');
      await open(tester, detailOf([moveStep()]), api);

      await api.pretendMove(tester, 'Ra7');

      expect(find.text('Tačno. Mi nastavljamo posle Ra8#.'), findsOneWidget);
    });

    testWidgets('a wrong move puts the position back', (tester) async {
      // Added by the lead while grading batch 48, which left the wrong move
      // standing. The next attempt is read off the step's own FEN, so a board
      // showing something else offers the child moves that resolve to nothing
      // in the position being judged — and the board then snaps back with
      // nothing said. `wrong_move_board_test.dart` is the same rule on the
      // puzzle screen; this screen may not be the one place it does not hold.
      final api = _FakeApi(correct: false, reason: 'nije traženi potez');
      await open(tester, detailOf([moveStep()]), api);

      final board = tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
      board.controller.makeMove(from: 'a1', to: 'a7');
      await tester.pumpAndSettle();
      expect(board.controller.game.fen, isNot(mateFen),
          reason: 'the child has played, and the board shows it');

      await api.pretendMove(tester, 'Ra7');

      expect(board.controller.game.fen, mateFen);
    });
  });

  group('nobody gets stuck', () {
    LessonStep moveStep() => const LessonStep(
          title: 'Zadnji red',
          fen: mateFen,
          kind: LessonStepKind.askMove,
          instruction: 'Nađi mat u jednom potezu.',
        );

    testWidgets('„Pokaži mi" is not offered before the second wrong answer',
        (tester) async {
      final api = _FakeApi(correct: false, reason: 'nije traženi potez');
      await open(tester, detailOf([moveStep()]), api);

      expect(find.text('Pokaži mi'), findsNothing);

      await api.pretendMove(tester, 'Rb1');
      expect(find.text('Pokaži mi'), findsNothing,
          reason: 'one miss is a try, not a child who is stuck');
    });

    testWidgets('after the second wrong answer it appears', (tester) async {
      // A stuck child who cannot finish never writes `completed_at`, and the
      // trainer's unreviewed count can then never reach zero — the exact
      // failure `assignments.reviewed_at` was added to fix.
      final api = _FakeApi(correct: false, reason: 'nije traženi potez');
      await open(tester, detailOf([moveStep()]), api);

      await api.pretendMove(tester, 'Rb1');
      await api.pretendMove(tester, 'Ra7');

      expect(find.text('Pokaži mi'), findsOneWidget);
    });

    testWidgets('pressing it asks the server, and shows what comes back',
        (tester) async {
      final api = _FakeApi(
          correct: false, reason: 'nije traženi potez', solutionSan: 'Ra8#');
      await open(tester, detailOf([moveStep()]), api);

      await api.pretendMove(tester, 'Rb1');
      await api.pretendMove(tester, 'Ra7');
      await tester.tap(find.text('Pokaži mi'));
      await tester.pumpAndSettle();

      expect(api.reveals, 1,
          reason: 'the answer is not on this side of the wire');
      expect(find.text('Rešenje: Ra8#'), findsOneWidget);
    });

    testWidgets('a server that does not answer says so and keeps the board',
        (tester) async {
      // Homework happens on school wifi. Failing to submit must not lose the
      // child's place or leave the screen looking like it judged them.
      final api = _FakeApi.offline();
      await open(tester, detailOf([moveStep()]), api);

      await api.pretendMove(tester, 'Ra8#');

      expect(find.text('Odgovor nije poslat — proveri vezu.'), findsOneWidget);
      final board = tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
      expect(board.isAllowedToMove, isTrue, reason: 'they may try again');
    });
  });
}

/// One answer the screen sent.
class _Sent {
  const _Sent({this.moveSan, this.choiceIndex});
  final String? moveSan;
  final int? choiceIndex;
}

/// Stands in for the server, and is the only thing here that knows an answer.
class _FakeApi extends AssignmentApiService {
  _FakeApi({this.correct = false, this.reason = '', this.solutionSan})
      : offlineMode = false,
        super(authToken: 't');

  _FakeApi.offline()
      : correct = false,
        reason = '',
        solutionSan = null,
        offlineMode = true,
        super(authToken: 't');

  final bool correct;
  final String reason;
  final String? solutionSan;
  final bool offlineMode;

  final List<_Sent> answers = [];
  int reveals = 0;

  @override
  Future<void> markLessonStep(
      {required int assignmentId, required int position}) async {}

  @override
  Future<StepAnswerResult?> answerLessonStep({
    required int assignmentId,
    required int position,
    String? moveSan,
    int? choiceIndex,
  }) async {
    answers.add(_Sent(moveSan: moveSan, choiceIndex: choiceIndex));
    if (offlineMode) return null;
    return StepAnswerResult(
      correct: correct,
      reason: reason,
      playedSan: moveSan,
      solutionSan: solutionSan,
    );
  }

  @override
  Future<StepRevealResult?> revealLessonStep({
    required int assignmentId,
    required int position,
  }) async {
    reveals++;
    if (offlineMode) return null;
    return StepRevealResult(solutionSan: solutionSan);
  }

  /// Drives one attempt the way a played move does, without a drag gesture.
  ///
  /// The board widget's own drag is not what these tests are about, and a
  /// gesture test over a chess board is a test of the board package. The screen
  /// must expose its move handler to the same path a real move takes.
  Future<void> pretendMove(WidgetTester tester, String san) async {
    final state =
        tester.state<LessonViewerScreenState>(find.byType(LessonViewerScreen));
    await state.submitMove(san);
    await tester.pumpAndSettle();
  }
}
