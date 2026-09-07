// The gate for P7a of `docs/PLAN-STUDIO-REDIZAJN.md` — the trainer draws on the
// board in the studio, and what they draw travels to the child.
//
// Written before the batch. It moves to
// `chess_app/test/tutorial_oznake_test.dart` in the merge commit.
//
// The node has carried `arrows` and `squares` since phase 2 of
// `PLAN-INTERAKTIVNA-LEKCIJA`, the viewer has drawn them since phase 6, and the
// studio has shown them read-only since it existed. Nothing anywhere writes
// one. „Pogledaj polje d5" is a whole lesson step, and until this batch a
// trainer could only say it in words.
//
// **It asserts on what gets saved.** A bar that lights up and a board that
// paints an arrow prove nothing about the `pgn` a child will open, so most of
// what follows draws, presses „Sačuvaj tutorijal", and reads the request body
// back through `LessonStepLine` — the one reader the student's screen uses.
// That is the P6b lesson applied ahead of time: an earlier gate asserted on a
// PGN by string position and could not tell which move a comment belonged to.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH 61
//
// **The interaction is already written, merged and gated.**
// `lib/widgets/game_screen/board_annotation_controller.dart` decides what a tap
// means: `AnnotationMode.off | arrow | square`, `colorCode`, `pendingFrom`,
// `tap`, `undoLastArrow`, `undoLastSquare`, `clearArrows`, `clearMarks`,
// `setMode`, `setColor`, `cancelPending`, `stop`. Nineteen headless tests in
// `test/board_annotation_controller_test.dart`, six mutations caught.
// **A second copy of any of those rules in a screen is a finding**, and the
// obvious one to get wrong is erasing: it ignores the colour, on purpose.
//
// **A new widget**, `lib/widgets/game_screen/board_annotation_bar.dart`,
// holding a stateless `BoardAnnotationBar`. It reports through callbacks and
// owns nothing: the screen owns the controller, exactly as the screen owns the
// cursor for `TutorialFlowPanel`. Its keys:
//
//   Key('annotation-bar')          the bar itself
//   Key('annotate-arrow')          arrow mode on/off
//   Key('annotate-square')         square mode on/off
//   Key('annotate-clear')          clears this node's marks, both kinds
//   Key('annotate-color-<id>')     one per ArrowColor.all, id as in the PGN
//
// **Serbian, and these five sentences are the whole of the new copy:**
//
//   'Strelica'          the arrow button's label/tooltip
//   'Polje'             the square button's
//   'Obriši oznake'     the clear button's
//   'Crtanje'           the bar's own heading, if the layout wants one
//   'Boja oznake'       the colour row's, likewise
//
// Anything else new is a sentence nobody decided on. The room's own drawing
// copy („Nacrtaj strelicu", „Završi crtanje", „Izbriši sve strelice") stays in
// the room and is not reused here: those are the words of a different surface.
//
// **The board is told what the controller knows.** `isDrawingMode` and
// `drawingStartSquare` come off the controller, and `onSquareTapForDrawing`
// goes into it. `ChessBoardWithOverlay` already ignores piece taps while
// drawing, so nothing about moving pieces needs writing.
//
// **The cursor moving cancels a half-drawn arrow.** `pendingFrom` names a
// square on the position the author was looking at; finishing that arrow after
// the board has moved draws it somewhere nobody asked for. `cancelPending()` is
// the call, and it deliberately does not leave drawing mode.
//
// **Not this batch:** the room. `chess_game_screen.dart` keeps its private copy
// for now — P7b moves it onto the controller, and it goes first through tests
// of the room's drawing, which do not exist. A refactor of the live-lesson
// screen on the strength of a report is the one thing this repository has
// promised itself not to do. Do not open that file.
//
// Also not this batch: undo buttons (the bar has clear, not undo — the gesture
// takes a mark back by redrawing it), marks on a *lesson step's* editor,
// anything in `chess_backend/`, and any change to the controller, to
// `AnalysisNode`, to `PgnExporterService` or to the P6 layout. The exporter
// already writes `[%cal]` and `[%csl]` for the root and for every move; if you
// believe it does not, stop and say so rather than editing it.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> saves;

  /// Every request that carried a `positionList`, whichever verb it used — a
  /// tutorial opened from the server is saved with `PUT`, not `POST`.
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
        return http.Response(jsonEncode({'id': 77}), 201);
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

  Map<String, dynamic> lessonOf(String pgn) => {
        'id': 31,
        'title': 'Otvaranje',
        'position_list': [
          {
            'fen': startFen,
            'title': 'Deo 1',
            'pgn': pgn,
            'kind': 'show',
          },
        ],
      };

  Future<_RecordingApi> open(WidgetTester tester,
      {String pgn = '1. e4 e5 2. Nf3'}) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = _RecordingApi();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lessonOf(pgn)),
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

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// A tap on a square of the board, the way the overlay reports one while
  /// drawing. The board's own gesture layer is not under test here.
  Future<void> tapSquare(WidgetTester tester, String square) async {
    board(tester).onSquareTapForDrawing(square);
    await tester.pumpAndSettle();
  }

  /// The one thing that leaves this screen, read back through the reader the
  /// child's screen uses. „The board painted an arrow" is not evidence.
  Future<LessonStepLine> saveAndRead(
      WidgetTester tester, _RecordingApi api) async {
    await tester.tap(find.text('Sačuvaj tutorijal'));
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1), reason: 'one tutorial is one write');
    final step = (api.saves.single['positionList'] as List).single as Map;
    return LessonStepLine.read(
      fen: step['fen'].toString(),
      pgn: step['pgn']?.toString(),
    );
  }

  group('the bar is under the board and says what mode it is in', () {
    testWidgets('it sits between the board and the move controls',
        (tester) async {
      await open(tester);

      final boardRect = tester.getRect(find.byType(ChessBoardWithOverlay));
      final bar = tester.getRect(find.byKey(const Key('annotation-bar')));

      expect(bar.top, greaterThan(boardRect.top),
          reason: 'the drawing controls belong under the board they draw on — '
              'the row is the target and the board is the tool');

      await close(tester);
    });

    testWidgets('pressing „Strelica" puts the board in drawing mode',
        (tester) async {
      await open(tester);

      expect(board(tester).isDrawingMode, isFalse,
          reason: 'the studio opens drawing, so an ordinary move cannot be '
              'played without turning it off first');

      await press(tester, 'annotate-arrow');
      expect(board(tester).isDrawingMode, isTrue);

      await press(tester, 'annotate-arrow');
      expect(board(tester).isDrawingMode, isFalse,
          reason: 'the same button does not turn drawing off again');

      await close(tester);
    });

    testWidgets('the started square reaches the board', (tester) async {
      // The board draws the half-finished arrow from it, which is the only
      // thing telling the trainer their first tap was heard.
      await open(tester);
      await press(tester, 'annotate-arrow');

      await tapSquare(tester, 'e2');

      expect(board(tester).drawingStartSquare, 'e2');

      await close(tester);
    });
  });

  group('what the trainer draws is what the child gets', () {
    testWidgets('an arrow on a move travels in the line', (tester) async {
      final api = await open(tester);

      // Stand on the move it is about, the way a trainer would.
      await tester.tap(find.byKey(const Key('beat-1')));
      await tester.pumpAndSettle();

      await press(tester, 'annotate-arrow');
      await tapSquare(tester, 'g1');
      await tapSquare(tester, 'f3');

      final step = await saveAndRead(tester, api);

      expect(step.replays, isTrue);
      expect(step.line.movesSan, ['e4', 'e5', 'Nf3']);
      expect(step.line.arrows.first.map((a) => a.toString()), ['Gg1f3'],
          reason: 'the arrow was stored against a different move than the one '
              'the trainer drew it on: the line came back as '
              '${step.line.arrows}');

      await close(tester);
    });

    testWidgets('a coloured square on a move travels too', (tester) async {
      final api = await open(tester);

      await tester.tap(find.byKey(const Key('beat-2')));
      await tester.pumpAndSettle();

      await press(tester, 'annotate-square');
      await tapSquare(tester, 'd5');

      final step = await saveAndRead(tester, api);

      expect(step.line.squares[1].map((s) => s.toString()), ['Gd5']);

      await close(tester);
    });

    testWidgets('marks on the starting position travel — a step with no moves',
        (tester) async {
      // „Pogledaj polje d5" is a whole step, and the root is the only place a
      // mark about a still position can live. A batch that wrote marks only
      // onto moves would lose exactly the lesson this feature was asked for.
      final api = await open(tester, pgn: '');

      await press(tester, 'annotate-square');
      await tapSquare(tester, 'd5');
      await press(tester, 'annotate-arrow');
      await tapSquare(tester, 'd5');
      await tapSquare(tester, 'e7');

      final step = await saveAndRead(tester, api);

      expect(step.line.movesSan, isEmpty);
      expect(step.line.rootSquares.map((s) => s.toString()), ['Gd5']);
      expect(step.line.rootArrows.map((a) => a.toString()), ['Gd5e7']);

      await close(tester);
    });

    testWidgets('the colour that was picked is the colour that is saved',
        (tester) async {
      final api = await open(tester, pgn: '');

      await press(tester, 'annotate-square');
      await press(tester, 'annotate-color-${ArrowColor.r.id}');
      await tapSquare(tester, 'd5');

      final step = await saveAndRead(tester, api);

      expect(step.line.rootSquares.single.colorCode, ArrowColor.r.id);

      await close(tester);
    });

    testWidgets('„Obriši oznake" takes both kinds off this node',
        (tester) async {
      final api = await open(tester, pgn: '');

      await press(tester, 'annotate-square');
      await tapSquare(tester, 'd5');
      await press(tester, 'annotate-arrow');
      await tapSquare(tester, 'g1');
      await tapSquare(tester, 'f3');

      await press(tester, 'annotate-clear');

      final step = await saveAndRead(tester, api);

      expect(step.line.rootSquares, isEmpty);
      expect(step.line.rootArrows, isEmpty);

      await close(tester);
    });
  });

  group('the screen obeys the controller rather than a copy of it', () {
    testWidgets('redrawing an arrow takes it back, whatever colour is picked',
        (tester) async {
      // The one rule a screen is likely to reimplement, and the one it is
      // likely to get wrong: erasing does not match on colour, because the
      // mistake being corrected is „wrong arrow", not „wrong colour".
      final api = await open(tester, pgn: '');

      await press(tester, 'annotate-arrow');
      await tapSquare(tester, 'd2');
      await tapSquare(tester, 'd4');
      await press(tester, 'annotate-color-${ArrowColor.r.id}');
      await tapSquare(tester, 'd2');
      await tapSquare(tester, 'd4');

      final step = await saveAndRead(tester, api);

      expect(step.line.rootArrows, isEmpty,
          reason: 'the screen wrote its own erase rule and matched on colour');

      await close(tester);
    });

    testWidgets('moving the board forgets a half-drawn arrow', (tester) async {
      final api = await open(tester);

      await press(tester, 'annotate-arrow');
      await tapSquare(tester, 'e2');

      // The author changes their mind and goes to another beat first.
      await tester.tap(find.byKey(const Key('beat-2')));
      await tester.pumpAndSettle();

      await tapSquare(tester, 'e4');

      final step = await saveAndRead(tester, api);

      expect(step.line.arrows.expand((a) => a), isEmpty,
          reason: 'an arrow was finished across a move of the board, so it was '
              'drawn from a square on the position the author had left');
      expect(step.line.rootArrows, isEmpty);

      await close(tester);
    });

    testWidgets('a tap while drawing does not play a move', (tester) async {
      await open(tester, pgn: '');

      await press(tester, 'annotate-arrow');

      expect(board(tester).isAllowedToMove || board(tester).isDrawingMode,
          isTrue);
      expect(board(tester).isDrawingMode, isTrue,
          reason: 'the board still takes piece taps while the trainer is '
              'drawing, so a drawing gesture grows the tree');

      await close(tester);
    });
  });
}
