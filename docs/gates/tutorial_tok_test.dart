// The gate for P6a of `docs/PLAN-STUDIO-REDIZAJN.md` — the „Tok" timeline,
// drawing only.
//
// Written before the batch. It moves to
// `chess_app/test/tutorial_tok_test.dart` in the merge commit.
//
// P6 was split in two (owner, 6.9.2026), the way P5 was and for the same
// reason: a panel that arrives drawing *and* editing in one diff cannot be
// graded. **This batch draws.** Editing the comment and the question in place,
// and taking the fields out of the pane, is P6b.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH 59
//
// **The model is done and frozen.** `beatsOf(root, current)` is merged, gated
// headless in `test/tok_beats_test.dart`, and proved by nine mutations. It
// returns the beats of the line the author is standing on, in the order the
// child meets them, and every question about *what* the timeline says is
// already answered there:
//
//   beat.node          the AnalysisNode this beat is a view of
//   beat.index         0 at the opening position
//   beat.isCurrent     where the author is standing — exactly one beat
//   beat.arrivedLabel  „1. e4" — the move that arrived; null at the opening
//   beat.playsLabel    „1... e5" — the move that leaves; null on the last beat
//   beat.isLast        the line runs out here
//   beat.branches      at a fork: every move out, each with .label and .taken
//
// **Do not compute a move number, and do not walk the tree.** Both are done:
// `AnalysisNode.moveNumberLabel` reads the number out of the FEN, because a
// tutorial part may open on any position and the ply from the root is not the
// move number. A second copy of either is a finding, not a detail — that is
// the `status = 'accepted'` family, which has cost this project real bugs.
//
// **One new widget**,
// `lib/features/tutorial_studio/widgets/tutorial_flow_panel.dart`:
//
//   class TutorialFlowPanel extends StatelessWidget {
//     const TutorialFlowPanel({
//       super.key,
//       required this.root,      // AnalysisNode
//       required this.current,   // AnalysisNode
//       required this.onSelect,  // void Function(AnalysisNode)
//     });
//   }
//
// Stateless, and it decides nothing: it calls `beatsOf`, draws a card per beat,
// and reports through `onSelect`. Every move of the board goes through the
// screen, which owns the cursor.
//
// **A card, top to bottom.** The order is the viewer's, not the tree's:
//
//   header      „Polazna pozicija" at index 0, otherwise „posle 1. e4"
//   comment     node.comment, when it is not empty — no placeholder when it is
//   move out    „pa se igra: 1... e5", or, at a fork, one chip per branch
//               carrying `branch.label`
//
// The sentence sits **between** the move that arrived and the move that
// leaves, because that is what the child gets: standing on a node the viewer
// speaks that node's comment and only then plays the move onward. A card that
// drew the move first would teach the author something false about their own
// tutorial.
//
// **Marks are not drawn here.** Nothing in the studio writes arrows or squares
// yet — the editor that does is P7 — so a card that summarised them would be
// summarising an empty list on every beat of every tutorial that exists.
//
// **Keys**, and they are the only new literals besides the strings below:
//
//   Key('beat-<index>')   one per card, the whole card tappable
//   Key('beat-current')   **inside** the card of the beat where the author
//                         stands — exactly one on screen, nested within that
//                         card's own `beat-<index>` key rather than wrapped
//                         around it
//   Key('tok-tab')        the „Tok" control
//   Key('stablo-tab')     the „Stablo" control
//
// **Strings, frozen, Serbian:**
//
//   'Tok'                 the timeline's tab — the default view
//   'Stablo'              the tree's tab
//   'Polazna pozicija'    the first card's header
//   'posle '              prefix on every other header: „posle 1. e4"
//   'pa se igra: '        prefix on the move out: „pa se igra: 1... e5"
//
// Nothing else. „Linija ovog dela" goes: the two tabs replace that heading, and
// the string goes with it.
//
// **The tree keeps its state across a tab switch.** `AnalysisMoveTreeWidget`
// holds a zoom that `PLAN-TABLA-I-STABLO` phase 2 fought to keep across a
// layout change; a switch that rebuilds it throws that away. Both views stay in
// the tree and only one is shown — an `IndexedStack` does this, and the tests
// below use `hitTestable()` precisely because the hidden view is still built.
//
// **Not this batch:** editing anything (P6b), arrows and squares (P7), the
// question card under the last beat (P6b), retiring the old step editor (P8).
// The model, `beatsOf`, `TutorialSectionsPanel`'s API, the save routing and the
// P5b layout are frozen. The fields stay exactly where they are and keep doing
// the editing.
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

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

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  /// The tree, whether or not its tab is the one showing.
  ///
  /// `skipOffstage: false` is the point: the hidden tab is still built — that
  /// is how it keeps its zoom across a switch — and „the two views agree" is a
  /// claim about the hidden one as much as the visible one. Every assertion
  /// below that cares whether the tree is *shown* says so with `hitTestable`.
  AnalysisMoveTreeWidget tree(WidgetTester tester) =>
      tester.widget<AnalysisMoveTreeWidget>(
          find.byType(AnalysisMoveTreeWidget, skipOffstage: false).first);

  /// A saved tutorial whose one part carries [pgn], so a line arrives without
  /// a single tap. Fixtures here are data on purpose: batch 58's gate built its
  /// condition by tapping, and the taps began missing the moment the layout it
  /// was testing worked.
  Map<String, dynamic> lessonOf(String pgn) => {
        'id': 21,
        'title': 'Otvaranje',
        'position_list': [
          {'fen': startFen, 'title': 'Deo 1', 'pgn': pgn, 'kind': 'show'},
        ],
      };

  Future<void> open(WidgetTester tester, {String pgn = '1. e4 e5 2. Nf3'}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lessonOf(pgn)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String placement(WidgetTester tester) =>
      board(tester).controller.getFen().split(' ').first;

  group('the line, drawn the way the child meets it', () {
    testWidgets('„Tok" is what the panel opens on', (tester) async {
      await open(tester);

      expect(find.text('Tok'), findsOneWidget);
      expect(find.text('Stablo'), findsOneWidget);
      expect(find.text('Polazna pozicija').hitTestable(), findsOneWidget,
          reason: 'the timeline is the default view — D6, approved 6.9.2026');
      expect(find.byType(AnalysisMoveTreeWidget).hitTestable(), findsNothing,
          reason: 'the tree is the other tab, not a second thing on screen');
      expect(find.text('Linija ovog dela'), findsNothing,
          reason: 'the two tabs replace that heading and the string goes');

      await close(tester);
    });

    testWidgets('one card per beat, headed by the move that arrived',
        (tester) async {
      await open(tester);

      expect(find.text('Polazna pozicija').hitTestable(), findsOneWidget);
      expect(find.text('posle 1. e4').hitTestable(), findsOneWidget);
      expect(find.text('posle 1... e5').hitTestable(), findsOneWidget);
      expect(find.text('posle 2. Nf3').hitTestable(), findsOneWidget,
          reason: 'the number is read from the FEN, not counted from the root '
              '— see AnalysisNode.moveNumberLabel');

      await close(tester);
    });

    testWidgets('the move out is under the sentence, not above it',
        (tester) async {
      await open(tester);

      final header = tester.getRect(find.text('posle 1. e4'));
      final playsOut = tester.getRect(find.text('pa se igra: 1... e5'));
      expect(playsOut.top, greaterThan(header.top),
          reason: 'standing on a node the child hears what is said *here* and '
              'only then sees the move played onward; a card in the other '
              'order teaches the author something false');

      await close(tester);
    });

    testWidgets('the last beat plays nothing', (tester) async {
      await open(tester, pgn: '1. e4 e5');

      expect(find.text('posle 1... e5').hitTestable(), findsOneWidget);
      expect(find.textContaining('pa se igra: 2.'), findsNothing,
          reason: 'the line has run out — a move drawn here is a move the '
              'child never gets to see');

      await close(tester);
    });

    testWidgets('a sentence is drawn where there is one, and nowhere else',
        (tester) async {
      await open(tester, pgn: '1. e4 {Beli zauzima centar.} e5');

      expect(find.text('Beli zauzima centar.').hitTestable(), findsOneWidget,
          reason: "the comment travels in the pgn and belongs on its own beat");

      await close(tester);
    });
  });

  group('the board follows the panel', () {
    testWidgets('pressing a beat moves the board and the tree', (tester) async {
      await open(tester);
      final opening = placement(tester);

      await tapKey(tester, 'beat-2');

      expect(placement(tester), isNot(opening),
          reason: 'the panel drew a different position than the board shows');
      expect(tree(tester).activeNode.moveSan, 'e5',
          reason: 'the tree and the timeline are two views of one node and '
              'cannot be allowed to disagree');

      await close(tester);
    });

    testWidgets('exactly one card is the one the author stands on',
        (tester) async {
      await open(tester);

      expect(find.byKey(const Key('beat-current')), findsOneWidget);

      await tapKey(tester, 'beat-1');

      expect(find.byKey(const Key('beat-current')), findsOneWidget,
          reason: 'two marked cards is two answers to „where am I"');
      expect(
          find.descendant(
              of: find.byKey(const Key('beat-1')),
              matching: find.byKey(const Key('beat-current'))),
          findsOneWidget,
          reason: 'the mark stayed on the card the author left');

      await close(tester);
    });
  });

  group('a fork is offered, and taking it re-projects', () {
    testWidgets('every reply at a fork is a chip on the beat it leaves from',
        (tester) async {
      await open(tester, pgn: '1. e4 e5 (1... c5 2. Nf3) 2. Nc3');

      expect(find.text('1... e5').hitTestable(), findsOneWidget);
      expect(find.text('1... c5').hitTestable(), findsOneWidget,
          reason: 'a sideline the author wrote is unreachable from the '
              'timeline unless the fork names it');

      await close(tester);
    });

    testWidgets('pressing the other reply draws the other line',
        (tester) async {
      await open(tester, pgn: '1. e4 e5 (1... c5 2. Nf3) 2. Nc3');

      await tester.tap(find.text('1... c5').first);
      await tester.pumpAndSettle();

      expect(find.text('posle 1... c5').hitTestable(), findsOneWidget);
      expect(find.text('posle 2. Nf3').hitTestable(), findsOneWidget,
          reason: 'the timeline did not follow the branch that was pressed');
      expect(find.text('posle 2. Nc3'), findsNothing,
          reason: 'the line that was left is still being drawn beside the one '
              'that was chosen');

      await close(tester);
    });
  });

  group('the other tab', () {
    testWidgets('„Stablo" shows the tree, and „Tok" comes back',
        (tester) async {
      await open(tester);

      await tapKey(tester, 'stablo-tab');
      expect(find.byType(AnalysisMoveTreeWidget).hitTestable(), findsOneWidget);
      expect(find.text('Polazna pozicija').hitTestable(), findsNothing);

      await tapKey(tester, 'tok-tab');
      expect(find.text('Polazna pozicija').hitTestable(), findsOneWidget);

      await close(tester);
    });

    testWidgets('the tree is not rebuilt by the switch', (tester) async {
      // It carries a zoom that `PLAN-TABLA-I-STABLO` phase 2 fought to keep
      // across a layout change. A tab that throws the widget away and builds a
      // new one throws that away with it, and nothing else in this file would
      // notice.
      await open(tester);
      await tapKey(tester, 'stablo-tab');
      final first = tester
          .state(find.byType(AnalysisMoveTreeWidget, skipOffstage: false));

      await tapKey(tester, 'tok-tab');
      await tapKey(tester, 'stablo-tab');

      expect(
          tester.state(
              find.byType(AnalysisMoveTreeWidget, skipOffstage: false)),
          same(first),
          reason: 'the tree lost its state on a tab switch');

      await close(tester);
    });
  });

  group('what the panel must not become', () {
    test('it walks no tree and counts no move of its own', () {
      final source = File('lib/features/tutorial_studio/widgets/'
              'tutorial_flow_panel.dart')
          .readAsStringSync();

      expect(source.contains('beatsOf('), isTrue,
          reason: 'the panel renders the projection; it does not compute one');
      for (final copy in const [
        'moveNumberLabel {',
        'fullmove',
        '.children.first',
        'MoveTree(',
      ]) {
        expect(source.contains(copy), isFalse,
            reason: '$copy is a second copy of something `beatsOf` and '
                '`AnalysisNode` already do, and two of them disagree sooner or '
                'later — the family of bug this codebase keeps paying for');
      }
    });
  });
}
