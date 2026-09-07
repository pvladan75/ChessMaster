// The gate for batch D — `TutorialStudioScreen`, the shell a trainer writes a
// tutorial in. Phase 4a of docs/PLAN-TUTORIJAL.md.
//
// Written before the screen exists, which is the rule batch 53 paid for: a
// batch with no gate written for it grades itself, and the test it writes for
// itself is green over the fault it shipped.
//
// It drives the screen through its own controls — the board reporting a move,
// the strip's buttons, the sheet at a fork — and names no private field. A gate
// written against internals passes a rewrite that broke the feature and fails a
// refactor that did not.
//
// What it does **not** assert: the per-node fields, the running list of
// examples, and the single `POST /lessons/save`. Those are batch E, and the
// gate for them is written before that batch, not now. What is here is the
// shell: a position to start from, a tree that grows as the trainer plays, a
// strip that walks it, a draft that outlives the screen, and — the two checks
// this plan exists for — no second copy of the board, the tree or the cursor,
// and one named predicate deciding where the door is drawn.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The opening position, and the same position after 1.e4. Nobody has to look
  // either of them up to read this file.
  const openingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

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

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  /// The move tree, whether or not it is the tab currently showing.
  ///
  /// `skipOffstage: false` was added ahead of P6a, which puts the tree behind
  /// a „Stablo" tab with „Tok" in front of it: `IndexedStack` keeps the hidden
  /// tab built — that is how the tree keeps its zoom across a switch — but
  /// offstage, and the default finder skips offstage widgets. Without this the
  /// helper throws „Bad state: No element" and takes a dozen assertions with
  /// it, none of which are about tabs.
  AnalysisMoveTreeWidget tree(WidgetTester tester) =>
      tester.widget<AnalysisMoveTreeWidget>(
          find.byType(AnalysisMoveTreeWidget, skipOffstage: false).first);

  /// A desktop window: the screen is Windows-only by decision 5, and a board
  /// beside a tree needs the width it was designed for.
  Future<void> open(WidgetTester tester,
      {TutorialHandover? handover, bool resumeDraft = true}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: handover == null
            ? const TutorialEntry.blank('')
            : TutorialEntry.fromAnalysis(handover),
      ),
    ));
    await tester.pumpAndSettle();

    // D4 of docs/PLAN-STUDIO-REDIZAJN.md, approved 6.9.2026: opening the studio
    // to start something new no longer adopts the stored draft in silence — it
    // says which tutorial is waiting and lets the trainer choose. Two tests
    // below reopen the screen to prove the draft survived, so they answer the
    // question. What they assert is unchanged, and the draft still comes back.
    if (resumeDraft && find.text('Nastavi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Nastavi'));
      await tester.pumpAndSettle();
    }
  }

  /// Tears the tree down — and deliberately does **not** wait out the draft's
  /// 600 ms debounce.
  ///
  /// That number is the whole point. A trainer who closes the window within
  /// half a second of their last move must still find it there, which is what
  /// the flush in `dispose` is for; waiting a full second here would let the
  /// debounced timer write the same payload and the gate would pass with the
  /// flush deleted. It did, until this was measured — mutation M5, 6.9.2026.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The board reporting a move the way a dragged piece reports one.
  Future<void> play(WidgetTester tester, String from, String to) async {
    board(tester).onMove(from, to, '');
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  group('the shell the trainer writes in', () {
    testWidgets('opens on the position handed over from the Studio',
        (tester) async {
      await open(tester, handover: TutorialHandover.position(openingFen));

      expect(board(tester).controller.getFen().split(' ').first,
          openingFen.split(' ').first,
          reason: 'the line worked out in the Studio is retyped otherwise, '
              'which is the whole reason for the door');
      expect(find.byType(AnalysisMoveTreeWidget, skipOffstage: false),
          findsOneWidget);
      expect(tree(tester).rootNode.fen, openingFen);
      await close(tester);
    });

    testWidgets('the whole tree comes across, not only its position',
        (tester) async {
      final root = AnalysisNode(fen: openingFen);
      root.addChild(childFen: afterE4, san: 'e4', uci: 'e2e4');

      await open(tester, handover: TutorialHandover.tree(root));

      expect(tree(tester).rootNode.children.map((c) => c.moveSan).toList(),
          ['e4']);
      // A copy, not the Studio's own nodes: writing a tutorial must not edit
      // the analysis it was started from.
      expect(identical(tree(tester).rootNode, root), isFalse,
          reason: 'the tutorial writes into the tree the Studio still shows');
      await close(tester);
    });

    testWidgets('a move joins the tree, and the strip walks back to it',
        (tester) async {
      await open(tester, handover: TutorialHandover.position(openingFen));

      await play(tester, 'e2', 'e4');
      expect(tree(tester).rootNode.children.map((c) => c.moveSan).toList(),
          ['e4']);
      expect(tree(tester).activeNode.moveSan, 'e4');

      await tapTooltip(tester, 'Prethodni potez');
      expect(tree(tester).activeNode.fen, openingFen);
      expect(board(tester).controller.getFen().split(' ').first,
          openingFen.split(' ').first,
          reason: 'the strip moved the tree and left the board behind');
      await close(tester);
    });

    testWidgets(
        'a second move from the same position is a fork, and the strip asks '
        'which line', (tester) async {
      // The rule from C2, on the authoring side: the strip must not walk into
      // the first child by itself. A trainer who wrote two answers to one move
      // and gets only one of them back has lost the same thing the child's
      // screen lost until batch 52.
      await open(tester, handover: TutorialHandover.position(openingFen));

      await play(tester, 'e2', 'e4');
      await tapTooltip(tester, 'Prethodni potez');
      await play(tester, 'd2', 'd4');
      await tapTooltip(tester, 'Prethodni potez');

      await tapTooltip(tester, 'Sledeći potez');
      expect(find.text('Odavde ide više linija — kojom?'), findsOneWidget,
          reason: 'two moves out of one position means "forward" has two '
              'meanings, and the sheet is where that is asked');
      expect(find.text('e4'), findsWidgets);
      expect(find.text('d4'), findsWidgets);

      await tester.tapAt(const Offset(20, 20)); // dismiss
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets('a start position can still be set on the screen itself',
        (tester) async {
      // Three ways in, per phase 4: a FEN typed in, the board editor, or the
      // handover. The first two are the same dialog the Studio already owns.
      await open(tester);

      await tapTooltip(tester, 'Unos pozicije');
      expect(find.byType(AnalysisBoardSetupDialog), findsOneWidget);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets('the name of the tutorial outlives it too', (tester) async {
      // Found by the lead while grading batch 54, and by no gate: the title was
      // read back out of the draft on restore and never written into it, so a
      // trainer who named their tutorial, closed the window and came back found
      // every example still there and the name gone. The half that works is the
      // half that makes the other half invisible.
      await open(tester, handover: TutorialHandover.position(openingFen));
      await tester.enterText(
          find.byKey(const Key('tutorial-title')), 'Opozicija');
      await play(tester, 'e2', 'e4');
      await close(tester);

      await open(tester);
      expect(find.text('Opozicija'), findsOneWidget,
          reason: 'the tutorial came back nameless');
      await close(tester);
    });

    testWidgets('the draft outlives the screen', (tester) async {
      await open(tester, handover: TutorialHandover.position(openingFen));
      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      await close(tester);

      await open(tester);
      expect(tree(tester).rootNode.fen, openingFen,
          reason: 'the trainer left the screen and lost the tutorial');
      expect(tree(tester).activeNode.moveSan, 'e5',
          reason: 'restored to a different move than the one left on');
      await close(tester);
    });
  });

  // P1 of docs/PLAN-STUDIO-REDIZAJN.md renamed `TutorialExample` to
  // `TutorialSection` and replaced its `String pgn` with the tree the pgn comes
  // from, so a finished part can be reopened — the missing piece that forced a
  // second editing screen to exist. **Every assertion below is unchanged**: what
  // moved is the constructor these tests call, not the wire shape they pin. The
  // `choices` pair became `List<TutorialChoice>`, which is the server's own
  // `{text, correct}` shape.
  group('the draft model, as C4 froze it', () {
    test('an example carries exactly what a lesson step is', () {
      final example = TutorialSection.fromStep({
        'fen': openingFen,
        'pgn': '1. e4 e5',
        'title': 'Primer 1',
        'instruction': 'Odigraj najbolji potez.',
        'kind': 'ask_move',
        'solutionSan': 'Nf3',
      });

      // The shape `services/lessonSteps.js` already validates. Quoted rather
      // than restated: a second idea of what a step is is how the two PGN
      // parsers happened.
      expect(example.toJson(), {
        'fen': openingFen,
        'pgn': '1. e4 e5',
        'title': 'Primer 1',
        'instruction': 'Odigraj najbolji potez.',
        'kind': 'ask_move',
        'solutionSan': 'Nf3',
        // Joined the list on 7.9.2026, on a live report: which way round the
        // board stands used to live only in the studio, so the child's viewer
        // guessed it from whose turn it is and the board turned over between
        // the parts of one tutorial. Always sent from here — absence means
        // „written before anyone could say" and is resolved on the way in.
        'blackOrientation': false,
      });
    });

    test('a plain example says nothing about questions', () {
      final example = TutorialSection.fromStep({
        'fen': openingFen,
        'pgn': '1. e4',
        'title': 'Primer 1',
      });
      expect(example.toJson(), {
        'fen': openingFen,
        'pgn': '1. e4',
        'title': 'Primer 1',
        'kind': 'show',
        'blackOrientation': false,
      });
    });

    test('a question with answers says which one is right', () {
      // The one field C4 did not name, added before batch E rather than
      // discovered inside it: C4 froze `List<String> choices`, which is the
      // *student's* model — the answer never travels to the child — and the
      // server takes `[{text, correct}]` with exactly one `correct: true`.
      // Without it an `ask_choice` example is unsaveable, and the batch that
      // found that out would have had to reopen a frozen contract mid-flight.
      final example = TutorialSection.fromStep({
        'fen': openingFen,
        'pgn': '1. e4',
        'title': 'Primer 1',
        'kind': 'ask_choice',
        'choices': [
          {'text': 'Kontrola centra', 'correct': true},
          {'text': 'Napad na kralja', 'correct': false},
        ],
      });

      expect(example.toJson()['choices'], [
        {'text': 'Kontrola centra', 'correct': true},
        {'text': 'Napad na kralja', 'correct': false},
      ]);
    });

    test('the draft is a list of them, in the order they were written', () {
      final draft = TutorialDraft(title: 'Opozicija', sections: [
        TutorialSection.fromStep(
            {'fen': openingFen, 'pgn': '1. e4', 'title': 'Primer 1'}),
        TutorialSection.fromStep(
            {'fen': openingFen, 'pgn': '1. d4', 'title': 'Primer 2'}),
      ]);

      expect(
          draft.positionList.map((e) => e['pgn']).toList(), ['1. e4', '1. d4']);
    });
  });

  group('what the shell must not become', () {
    final source =
        File('lib/features/tutorial_studio/screens/tutorial_studio_screen.dart')
            .readAsStringSync();

    test('it reuses the board, the tree and the cursor', () {
      for (final block in const [
        'ChessBoardWithOverlay(',
        'AnalysisMoveTreeWidget(',
        'MoveNavigationControls(',
        'AnalysisNodeCursor(',
      ]) {
        expect(source.contains(block), isTrue,
            reason: '$block is the existing building block for this; a screen '
                'that does not name it has grown its own');
      }
    });

    test('it grows no second board, tree or cursor of its own', () {
      // Two models of one tree is the fault this codebase has already paid for
      // twice — `AnalysisNode` versus `MoveTree` arrows, and the two PGN
      // parsers. Checked on the whole file rather than on a slice of it: a
      // source-reading test that slices reads into the next declaration and
      // matches something it was not asked about.
      for (final copy in const [
        'SkinnedChessBoard(',
        'ChessBoardPainter(',
        'implements MoveCursor',
        'extends MoveCursor',
      ]) {
        expect(source.contains(copy), isFalse,
            reason: '$copy is a copy of plumbing that already exists');
      }

      final declared = RegExp(r'^class\s+(\w+)', multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();
      expect(
        declared.where((n) =>
            n.endsWith('Node') ||
            n.endsWith('Cursor') ||
            n.endsWith('Tree') ||
            n.endsWith('Painter')),
        isEmpty,
        reason: 'a second model of the tree, beside the first: $declared',
      );
    });

    test('the door is behind one named predicate, in one place', () {
      // Decision 5: Windows-only for now, and which other screens stop making
      // sense on a phone is a decision the owner takes later — with the screen
      // in front of them. That decision is a one-line change only while the
      // predicate has one home.
      addTearDown(() => debugTutorialStudioAvailable = null);

      debugTutorialStudioAvailable = true;
      expect(isTutorialStudioAvailable, isTrue);
      debugTutorialStudioAvailable = false;
      expect(isTutorialStudioAvailable, isFalse);
      debugTutorialStudioAvailable = null;
      expect(isTutorialStudioAvailable, Platform.isWindows,
          reason: 'the predicate stopped reading the platform');

      // The Studio's door is read from source: the Studio does not build in a
      // widget test (an engine, a tablebase and three network services start
      // with it), and this is the weakest check in this file — it says the
      // door consults the predicate, not that it disappears. Proved by
      // mutation before it was trusted: deleting the guard turns it red.
      final studio = File(
              'lib/features/analysis_studio/screens/analysis_studio_screen.dart')
          .readAsStringSync();
      // Asserted on the answer rather than on the file, so a failure says what
      // is missing instead of printing 2400 lines of screen at whoever ran it.
      expect(studio.contains('Kreiraj interaktivni tutorijal'), isTrue,
          reason: 'the Studio has no door to the tutorial studio');
      expect(studio.contains('isTutorialStudioAvailable'), isTrue,
          reason: 'the Studio draws the door on Android too');
    });
  });
}
