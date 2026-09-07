import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/pgn_span.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_pgn_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// T3 and T4 of `docs/PLAN-PGN-TEKST.md` — the caret is the cursor, and the
/// right-click writes on the move it was clicked on.
///
/// One cursor, three surfaces: „Tok", „Stablo" and „PGN" are three renderings
/// of the same `AnalysisNode`, so putting the caret in a move is the same act
/// as clicking that beat card. What the menu offers is not a second way of
/// drawing — the first two items stand the cursor on the move and hand the work
/// to the board, which is where drawing has lived since P7.
///
/// The map itself is proved in `test/pgn_spans_test.dart`, headless. What is
/// proved here is the wiring, and it is asserted on the **model and the
/// request**: an arrow that lands on the wrong node looks identical on screen.
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

  late List<Map<String, dynamic>> saves;

  LessonApiService recordingApi() {
    saves = [];
    return LessonApiService(
      authToken: 'tok',
      client: MockClient((req) async {
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

  var nextLessonId = 700;

  Map<String, dynamic> lesson({String pgn = '1. e4 e5 2. Nf3'}) => {
        'id': nextLessonId++,
        'title': 'Otvaranje',
        'position_list': [
          {
            'id': 'step-1',
            'fen': startFen,
            'title': 'Deo 1',
            'pgn': pgn,
            'kind': 'show',
          },
        ],
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Future<void> open(WidgetTester tester, {String? pgn}) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(pgn == null ? lesson() : lesson(pgn: pgn)),
        lessonApi: recordingApi(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pgn-tab')));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  TutorialPgnPanel panel(WidgetTester tester) =>
      tester.widget<TutorialPgnPanel>(
          find.byType(TutorialPgnPanel, skipOffstage: false));

  TextField field(WidgetTester tester) => tester.widget<TextField>(
      find.byKey(const Key('pgn-field'), skipOffstage: false));

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  /// The move span of a written move, found the way a caller would: by asking
  /// the map what the text says.
  PgnSpan spanOf(WidgetTester tester, String san) {
    final export = panel(tester).export;
    return export.spans.firstWhere((s) =>
        s.kind == PgnSpanKind.move &&
        export.pgn.substring(s.start, s.end) == san);
  }

  /// A click inside a move: the caret goes there and the field reports it, the
  /// way `TextField.onTap` does when somebody clicks in the text.
  Future<void> clickInto(WidgetTester tester, String san) async {
    final span = spanOf(tester, san);
    final f = field(tester);
    f.controller!.selection = TextSelection.collapsed(offset: span.start + 1);
    f.onTap!();
    await tester.pumpAndSettle();
  }

  Future<LessonStepLine> saveAndRead(WidgetTester tester) async {
    await tester.tap(find.text('Sačuvaj tutorijal'));
    await tester.pumpAndSettle();
    expect(saves, hasLength(1));
    final step = (saves.single['positionList'] as List).single as Map;
    return LessonStepLine.read(
      fen: step['fen'].toString(),
      pgn: step['pgn']?.toString(),
    );
  }

  group('the caret is the cursor', () {
    testWidgets('clicking into a move stands the board on it', (tester) async {
      await open(tester);

      await clickInto(tester, 'e5');

      expect(board(tester).controller.getFen(), contains('rnbqkbnr/pppp1ppp'),
          reason: 'the board did not follow the caret, so drawing on it would '
              'land on whichever move was open before');

      await close(tester);
    });

    testWidgets('and the timeline moves with it', (tester) async {
      await open(tester);

      await clickInto(tester, 'Nf3');
      await tester.tap(find.byKey(const Key('tok-tab')));
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: find.byKey(const Key('beat-3')),
              matching: find.byKey(const Key('beat-current'))),
          findsOneWidget,
          reason: 'the timeline is showing a different current beat from the '
              'move the caret is in — one cursor, three surfaces');

      await close(tester);
    });

    testWidgets('moving the cursor elsewhere puts the caret on that move',
        (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('tok-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('beat-2')));
      await tester.pumpAndSettle();

      final span = spanOf(tester, 'e5');
      final selection = field(tester).controller!.selection;

      expect(selection.baseOffset, span.start,
          reason: 'the caret stayed where it was while the cursor moved, so '
              'the right-click menu would offer the wrong move');
      expect(selection.extentOffset, span.end);

      await close(tester);
    });

    testWidgets('but not over text the trainer is still writing',
        (tester) async {
      await open(tester);

      await tester.enterText(
          find.byKey(const Key('pgn-field')), '1. d4 { pišem još }');
      await tester.pumpAndSettle();
      final before = field(tester).controller!.selection;

      await tester.tap(find.byKey(const Key('tok-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('beat-1')));
      await tester.pumpAndSettle();

      expect(field(tester).controller!.selection, before,
          reason: 'the caret was moved inside text the trainer had typed, '
              'using offsets that describe a different string');

      await close(tester);
    });
  });

  group('what the right-click menu does', () {
    testWidgets('„Dodaj komentar" writes the words onto that move',
        (tester) async {
      await open(tester);

      panel(tester).onEditComment(spanOf(tester, 'e5').nodeId);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('pgn-comment-field')), 'Klasičan odgovor.');
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();

      final step = await saveAndRead(tester);

      expect(step.line.movesSan, ['e4', 'e5', 'Nf3']);
      expect(step.line.comments[1], 'Klasičan odgovor.',
          reason: 'the comment landed on a different move than the one that '
              'was clicked: ${step.line.comments}');

      await close(tester);
    });

    testWidgets('„Odustani" writes nothing', (tester) async {
      await open(tester);

      panel(tester).onEditComment(spanOf(tester, 'e5').nodeId);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('pgn-comment-field')), 'Ne ovo.');
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      final step = await saveAndRead(tester);

      expect(step.line.comments.every((c) => c.isEmpty), isTrue,
          reason: 'backing out of the dialog wrote the comment anyway: '
              '${step.line.comments}');

      await close(tester);
    });

    testWidgets('„Dodaj strelicu" hands the drawing to the board, on that move',
        (tester) async {
      // The menu draws nothing itself. It stands the cursor on the move that
      // was clicked and turns the board's arrow mode on; what happens next is
      // `BoardAnnotationController`, which has been the one home of this
      // gesture since P7.
      await open(tester);

      panel(tester).onDrawArrow(spanOf(tester, 'Nf3').nodeId);
      await tester.pumpAndSettle();

      expect(board(tester).isDrawingMode, isTrue,
          reason: 'the board was not put into drawing mode, so the trainer '
              'presses the brush themselves after asking for an arrow');

      board(tester).onSquareTapForDrawing('f1');
      board(tester).onSquareTapForDrawing('c4');
      await tester.pumpAndSettle();

      final step = await saveAndRead(tester);

      expect(step.line.arrows[2].map((a) => a.toString()), ['Gf1c4'],
          reason: 'the arrow landed on a different move than the one the menu '
              'was opened on');

      await close(tester);
    });

    testWidgets('„Označi polje" does the same for a square', (tester) async {
      await open(tester);

      panel(tester).onMarkSquare(spanOf(tester, 'e4').nodeId);
      await tester.pumpAndSettle();

      board(tester).onSquareTapForDrawing('d5');
      await tester.pumpAndSettle();

      final step = await saveAndRead(tester);

      expect(step.line.squares.first.map((s) => s.toString()), ['Gd5']);

      await close(tester);
    });
  });
}
