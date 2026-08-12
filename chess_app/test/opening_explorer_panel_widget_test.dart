import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';

// Shape matches the documented lila-openingexplorer /lichess response for
// the starting position after 1. e4 (white to move next).
const _e4Json = '''
{"white":1200,"draws":300,"black":900,
"opening":{"eco":"B00","name":"King's Pawn Game"},
"moves":[
  {"uci":"e7e5","san":"e5","white":650,"draws":180,"black":420,"averageOpponentRating":2100},
  {"uci":"c7c5","san":"c5","white":400,"draws":90,"black":380,"averageOpponentRating":2200},
  {"uci":"e7e6","san":"e6","white":150,"draws":30,"black":100,"averageOpponentRating":2050}
]}
''';

void main() {
  testWidgets('OpeningExplorerPanelWidget shows opening name and moves, tap invokes callback', (tester) async {
    final result = OpeningExplorerResult.fromJson(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      jsonDecode(_e4Json) as Map<String, dynamic>,
    );

    String? tappedUci;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpeningExplorerPanelWidget(
            hasToken: true,
            isLoading: false,
            result: result,
            onMoveSelected: (uci) => tappedUci = uci,
          ),
        ),
      ),
    );

    expect(find.textContaining("King's Pawn Game"), findsOneWidget);
    expect(find.textContaining('e5 (52%)'), findsOneWidget);
    expect(find.textContaining('c5 (36%)'), findsOneWidget);

    // Most popular move (e5, 1250 games) should be ranked first.
    expect(result.moves.first.san, 'e5');

    await tester.tap(find.textContaining('e5 (52%)'));
    await tester.pumpAndSettle();

    expect(tappedUci, 'e7e5');
  });

  testWidgets('OpeningExplorerPanelWidget rating dropdown reports the selected bucket', (tester) async {
    final result = OpeningExplorerResult.fromJson(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      jsonDecode(_e4Json) as Map<String, dynamic>,
    );

    int? changedTo = -1; // sentinel distinct from any valid value including null
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpeningExplorerPanelWidget(
            hasToken: true,
            isLoading: false,
            result: result,
            minRating: null,
            onMinRatingChanged: (r) => changedTo = r,
          ),
        ),
      ),
    );

    expect(find.text('Svi rejtinzi'), findsOneWidget);

    await tester.tap(find.text('Svi rejtinzi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2500+').last);
    await tester.pumpAndSettle();

    expect(changedTo, 2500);
  });

  testWidgets('OpeningExplorerPanelWidget renders nothing without a token', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OpeningExplorerPanelWidget(hasToken: false, isLoading: false, result: null),
        ),
      ),
    );

    expect(find.byType(OpeningExplorerPanelWidget), findsOneWidget);
    expect(find.text('Lichess Opening Explorer'), findsNothing);
  });
}
