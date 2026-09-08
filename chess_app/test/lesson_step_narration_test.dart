import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/speakable_info.dart';

/// Phase 6 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: the viewer draws what the
/// author drew, and says what it shows.
///
/// **Written by the lead, before the batch, and the batch is graded on turning
/// these green without editing them.**
///
/// Everything these tests reach already exists. `MoveTree.parsePgn` has read
/// `[%cal]` and `[%csl]` since phase 2, `PgnLine` carries them per move and now
/// carries the ones written before the first move too, `ChessBoardWithOverlay`
/// gained a `squares` parameter on 5.9.2026, and `SpeakableInfo` has been the
/// one way a screen offers to read itself out since `PLAN-JEDNOSTAVNOST` phase
/// 0. Not one of them is wired into this screen. That wiring is the job.
///
/// The property under the second group is the one worth stating plainly: a
/// reader with speech switched off must lose **nothing**. Speech here is a
/// second channel over the words already on screen, never the only copy of
/// them — which is also why `SpeakableInfo` refuses to compose its own
/// sentence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return AppSettingsService.instance.init();
  });

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// A line whose author wrote about the **position** first and about a move
  /// second — which is the shape an interactive lesson is mostly made of.
  const drawnPgn = '{ Slabo polje d5. [%csl Rd5] [%cal Gf3d5] } '
      '1. e4 { Zauzima centar. [%csl Ge4] } e5';

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

  Future<void> open(WidgetTester tester, List<LessonStep> steps) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(
        session: session,
        detail: detailOf(steps),
        api: _SilentApi(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  /// Walks the line by pressing the control a child presses.
  ///
  /// Scrolled to first, and that is not a detail. This screen is a
  /// `SingleChildScrollView`, so a button below the fold is reached by
  /// scrolling and is not a defect — but `tester.tap` on an off-screen widget
  /// misses. Without this the batch was handed a test it could only pass by
  /// making the board smaller for every lesson on every screen, and it did
  /// exactly that. A gate that can be satisfied by changing the app instead of
  /// writing the feature is a gate that is measuring the wrong thing.
  Future<void> step(WidgetTester tester, String tooltip) async {
    await tester.ensureVisible(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  /// Every sentence this screen is offering to read out.
  List<SpeakableInfo> spoken(WidgetTester tester) =>
      tester.widgetList<SpeakableInfo>(find.byType(SpeakableInfo)).toList();

  /// The words actually drawn inside one panel.
  String shown(WidgetTester tester, Finder panel) => tester
      .widgetList<Text>(find.descendant(of: panel, matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .join(' ');

  group('what the author drew reaches the board', () {
    LessonStep drawnStep() => const LessonStep(
          title: 'Centar',
          fen: startFen,
          pgn: drawnPgn,
          instruction: 'Pogledaj polje d5.',
        );

    testWidgets('the position’s own drawing is there before any move',
        (tester) async {
      // `[%csl]` written before move one is about the position the step opens
      // on, and a step whose whole point is a square has no move to hang it on.
      await open(tester, [drawnStep()]);

      final marks = board(tester).squares;
      expect(marks.length, 1);
      expect(marks.single.square, 'd5');
      expect(marks.single.colorCode, 'R');

      final arrows = board(tester).arrows;
      expect(arrows.length, 1);
      expect(arrows.single.toString(), 'Gf3d5');
    });

    testWidgets('a move’s drawing replaces it', (tester) async {
      await open(tester, [drawnStep()]);

      await step(tester, 'Next move');

      final marks = board(tester).squares;
      expect(marks.length, 1);
      expect(marks.single.square, 'e4');
      expect(marks.single.colorCode, 'G');
      expect(board(tester).arrows, isEmpty,
          reason:
              'the arrow belonged to the position, not to every move after');
    });

    testWidgets('and stepping back brings the position’s drawing back',
        (tester) async {
      // Read off the move index every build, not set once when the step loads.
      await open(tester, [drawnStep()]);

      await step(tester, 'Next move');
      await step(tester, 'Previous move');

      expect(board(tester).squares.single.square, 'd5');
      expect(board(tester).arrows.single.toString(), 'Gf3d5');
    });

    testWidgets('a step with no line draws nothing', (tester) async {
      await open(tester, [
        const LessonStep(
            title: 'Mirna pozicija',
            fen: startFen,
            instruction: 'Samo gledaj.'),
      ]);

      expect(board(tester).squares, isEmpty);
      expect(board(tester).arrows, isEmpty);
    });
  });

  group('the screen says what it shows, and shows what it says', () {
    testWidgets('the step’s task is offered out loud', (tester) async {
      await open(tester, [
        const LessonStep(
            title: 'Centar',
            fen: startFen,
            pgn: drawnPgn,
            instruction: 'Pogledaj polje d5.'),
      ]);

      final panels = spoken(tester);
      expect(panels, isNotEmpty,
          reason: 'a lesson step that asks something of a child is exactly the '
              'sentence PLAN-JEDNOSTAVNOST phase 0 was written for');
      expect(panels.map((p) => p.text), contains('Pogledaj polje d5.'));
    });

    testWidgets('so is the trainer’s note on the move', (tester) async {
      await open(tester, [
        const LessonStep(title: 'Centar', fen: startFen, pgn: drawnPgn),
      ]);

      await step(tester, 'Next move');

      expect(spoken(tester).map((p) => p.text), contains('Zauzima centar.'));
    });

    testWidgets('every spoken sentence is also written on the screen',
        (tester) async {
      // The property, and the reason the wrapper never composes its own words:
      // a reader with speech off must lose nothing at all. A sentence that
      // exists only in `SpeakableInfo.text` is a sentence most readers of this
      // app — children, on school tablets, with the sound off — never get.
      await open(tester, [
        const LessonStep(
            title: 'Centar',
            fen: startFen,
            pgn: drawnPgn,
            instruction: 'Pogledaj polje d5.'),
      ]);

      final panels = find.byType(SpeakableInfo);
      expect(panels, findsWidgets);
      for (var i = 0; i < panels.evaluate().length; i++) {
        final panel = panels.at(i);
        final widget = tester.widget<SpeakableInfo>(panel);
        expect(shown(tester, panel), contains(widget.text),
            reason: 'this sentence would be heard and not read');
      }
    });
  });

  group('the question is untouched by any of this', () {
    testWidgets('a choice step still asks, and still locks the board',
        (tester) async {
      // Narration is added to the step that asks, not instead of it. The board
      // being locked on a choice is phase 4b's rule and stays phase 4b's rule.
      await open(tester, [
        const LessonStep(
          title: 'Plan',
          fen: startFen,
          kind: LessonStepKind.askChoice,
          instruction: 'Koji je plan?',
          choices: ['Otvoriti liniju', 'Zameniti damu'],
        ),
      ]);

      expect(find.text('Otvoriti liniju'), findsOneWidget);
      expect(board(tester).isAllowedToMove, isFalse);
      expect(spoken(tester).map((p) => p.text), contains('Koji je plan?'));
    });
  });
}

/// A server that is never asked anything. This screen marks a step seen when it
/// opens, and these tests are about what it draws.
class _SilentApi extends AssignmentApiService {
  _SilentApi() : super(authToken: 't');

  @override
  Future<void> markLessonStep(
      {required int assignmentId, required int position}) async {}
}
