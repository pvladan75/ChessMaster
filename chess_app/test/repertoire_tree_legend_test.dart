import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

/// The picture says what it was drawn at.
///
/// Two settings decide the shape of the tree — the rating band the book answers
/// from, and the width taken out of that answer — and neither was on screen.
/// A repertoire set to „Samo glavna linija" and one read at a band it was never
/// fetched in both look thin, and until this legend the only way to tell them
/// apart was to open a popup menu and hunt for a tick.
AnalysisNode _root() => AnalysisNode(
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );

Future<void> _pump(WidgetTester tester,
    {int? minRating, String? breadth, VoidCallback? onChangeBreadth}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final root = _root();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: RepertoireTreePanel(
          root: root,
          active: root,
          onSelect: (_) {},
          minRating: minRating,
          breadth: breadth,
          onChangeBreadth: onChangeBreadth,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('the legend names the band and the width', (tester) async {
    await _pump(tester, minRating: 1600, breadth: 'main');

    expect(find.text('Knjiga: partije od 1600+'), findsOneWidget);
    // The stored word is not what a reader is shown.
    expect(find.text('Koliko odgovora: samo glavni odgovor'), findsOneWidget);
  });

  testWidgets('each width is written out', (tester) async {
    await _pump(tester, minRating: 2000, breadth: 'standard');
    expect(find.text('Koliko odgovora: uobičajeno 80%'), findsOneWidget);
    expect(find.text('Knjiga: partije od 2000+'), findsOneWidget);

    await _pump(tester, minRating: 2000, breadth: 'broad');
    expect(find.text('Koliko odgovora: široko 95%'), findsOneWidget);
  });

  testWidgets('nothing is invented when nothing is known', (tester) async {
    await _pump(tester);

    expect(find.textContaining('Knjiga:'), findsNothing);
    // The label without a value, so the table's `Širina: ${...}` row does not
    // reach it — the twenty-first assertion, and the one the automated pass
    // over the table could not do.
    expect(find.textContaining('Koliko odgovora:'), findsNothing);
  });

  group('the width is turned where it is named', () {
    // The legend is the line that says what the drawing was made at, so it is
    // the honest place to change it — the same rule the cut branches follow,
    // counted next to the switch that brings them back. Reported live
    // 5.9.2026: the only door to this dial was the spine dialog, which writes
    // moves.
    testWidgets('a caller that can change it gets a button', (tester) async {
      var opened = 0;
      await _pump(tester,
          breadth: 'standard', onChangeBreadth: () => opened += 1);

      // The same sentence as without it — a reader must not have to learn two
      // wordings for one fact.
      expect(find.text('Koliko odgovora: uobičajeno 80%'), findsOneWidget);
      await tester.tap(find.text('Koliko odgovora: uobičajeno 80%'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('a caller that cannot leaves plain text', (tester) async {
      // The walkthrough draws this panel too, and a tour is not the place to
      // change a repertoire-wide setting.
      await _pump(tester, breadth: 'standard');

      expect(find.text('Koliko odgovora: uobičajeno 80%'), findsOneWidget);
      expect(
          find.ancestor(
            of: find.text('Koliko odgovora: uobičajeno 80%'),
            matching: find.byType(TextButton),
          ),
          findsNothing);
    });
  });

  group('finding the node a position stands on', () {
    // The tree's FENs come from the server; the one the board is standing on is
    // computed locally by the chess engine after a move. Those two agree about
    // the position and can disagree about the halfmove clock and the move
    // number, which are arithmetic and not position. Compared whole, the search
    // then finds nothing and the caller falls back to the root: the picture
    // silently highlights the opening instead of where you are.
    //
    // Every other position comparison in this codebase goes through `fenKeyOf`.
    // This one did not, which is the whole defect.
    AnalysisNode treeFromServer() {
      final root = AnalysisNode(
        fen: 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3',
      );
      final c5 = AnalysisNode(
        fen: 'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4',
        moveSan: 'c5',
        moveUci: 'c7c5',
      )..parent = root;
      root.children.add(c5);
      return root;
    }

    test('the same position with different move counters is the same node', () {
      final root = treeFromServer();

      // The board's arithmetic: same placement, same side to move, same
      // castling and en-passant — a different halfmove clock and move number.
      final found = findNodeByFen(root,
          'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 7 12');

      expect(found?.moveSan, 'c5', reason: 'brojači poteza nisu pozicija');
    });

    test('a genuinely different position is still not found', () {
      // The half that would be lost by comparing too little. The en-passant
      // square is inside the key on purpose: two positions that differ only in
      // it are different positions, and one of them allows a capture.
      final root = treeFromServer();

      expect(
          findNodeByFen(root,
              'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4'),
          isNull,
          reason: 'en passant jeste deo pozicije');
      expect(
          findNodeByFen(
              root, 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
          isNull);
    });
  });
}
