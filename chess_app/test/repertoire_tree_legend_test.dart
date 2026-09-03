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
    {int? minRating, String? breadth}) async {
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
    expect(find.text('Širina: samo glavna linija'), findsOneWidget);
  });

  testWidgets('each width is written out', (tester) async {
    await _pump(tester, minRating: 2000, breadth: 'standard');
    expect(find.text('Širina: standardno 80%'), findsOneWidget);
    expect(find.text('Knjiga: partije od 2000+'), findsOneWidget);

    await _pump(tester, minRating: 2000, breadth: 'broad');
    expect(find.text('Širina: široko 95%'), findsOneWidget);
  });

  testWidgets('nothing is invented when nothing is known', (tester) async {
    await _pump(tester);

    expect(find.textContaining('Knjiga:'), findsNothing);
    expect(find.textContaining('Širina:'), findsNothing);
  });
}
