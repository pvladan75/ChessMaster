import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/syzygy_panel_widget.dart';

// Real response captured from https://tablebase.lichess.ovh/standard for the
// KQ vs KR position 7r/8/4k3/8/3K4/8/8/3Q4 w - - 0 1 (White to move, Qg4+ wins).
const _kqVsKrJson = '''
{"checkmate":false,"stalemate":false,"variant_win":false,"variant_loss":false,"insufficient_material":false,"dtz":29,"precise_dtz":29,"dtm":41,"category":"win",
"moves":[
  {"uci":"d1g4","san":"Qg4+","zeroing":false,"checkmate":false,"stalemate":false,"insufficient_material":false,"dtz":-28,"dtm":-40,"category":"loss"},
  {"uci":"d1d2","san":"Qd2","zeroing":false,"checkmate":false,"stalemate":false,"insufficient_material":false,"dtz":0,"dtm":0,"category":"draw"},
  {"uci":"d1a4","san":"Qa4","zeroing":false,"checkmate":false,"stalemate":false,"insufficient_material":false,"dtz":3,"dtm":25,"category":"win"}
]}
''';

void main() {
  testWidgets('SyzygyPanelWidget shows the tablebase verdict and best move, and taps invoke the callback', (tester) async {
    final result = SyzygyResult.fromJson(
      '7r/8/4k3/8/3K4/8/8/3Q4 w - - 0 1',
      jsonDecode(_kqVsKrJson) as Map<String, dynamic>,
    );

    String? tappedUci;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyzygyPanelWidget(
            isEligible: true,
            isLoading: false,
            result: result,
            onMoveSelected: (uci) => tappedUci = uci,
          ),
        ),
      ),
    );

    // Best move for the mover is ranked first (Qg4+, since the API reports
    // it as a "loss" for Black, the side to move after it).
    expect(result.moves.first.san, 'Qg4+');

    expect(find.textContaining('Pobeda'), findsWidgets); // verdict chip: "Pobeda · DTZ 29"
    expect(find.textContaining('Qg4+'), findsOneWidget);
    expect(find.textContaining('Qa4'), findsOneWidget);

    await tester.tap(find.textContaining('Qg4+'));
    await tester.pumpAndSettle();

    expect(tappedUci, 'd1g4');
  });

  testWidgets('SyzygyPanelWidget renders nothing when not eligible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SyzygyPanelWidget(isEligible: false, isLoading: false, result: null),
        ),
      ),
    );

    expect(find.byType(SyzygyPanelWidget), findsOneWidget);
    expect(find.text('Syzygy Tablebase'), findsNothing);
  });
}
