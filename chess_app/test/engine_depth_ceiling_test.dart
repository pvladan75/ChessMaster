// Every depth a reader chooses goes to 50, and every value on the way.
//
// Owner, 17.9.2026: some pickers stopped at 24, 28 or 30, and the game
// tutorial offered 18, 20 and 22 only. The ceiling is one number,
// `AppSettingsService.kMaxEngineDepth`; the dials and the tutorial dialog
// have their own tests beside them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/auto_analysis_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/position_scanner/widgets/side_suggestions.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';

import 'support/device_only_puzzle_sets.dart';
import 'support/landscape.dart';
import 'package:chess_app/widgets/app_slider.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

AppSlider _depthSlider(WidgetTester tester) => tester
    .widgetList<AppSlider>(find.byType(AppSlider))
    .singleWhere((s) => s.max == AppSettingsService.kMaxEngineDepth);

void main() {
  // Real glyphs: the dialogs' title rows are measured, and squares overflow.
  setUpAll(loadRoboto);

  test('the ceiling is 50', () {
    expect(AppSettingsService.kMaxEngineDepth, 50);
  });

  // „Check with engine" lived on Saved Positions until 23.9.2026; the depth
  // list moved with it to the scanners (docs/PLAN-MATERIJAL.md, phase 2).
  test('Suggest sides with the engine offers every depth from 12 to 50', () {
    expect(SideSuggestions.depths, [for (var d = 12; d <= 50; d++) d]);
  });

  // The Review dialog opens at the depth the board remembers, and its slider
  // stopped at 30 — so a board left at 42 opened a slider past its own end.
  testWidgets('the Review dialog opens at a remembered 42 and reaches 50',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_analysis_depth': 42});
    await AppSettingsService.instance.init();
    addTearDown(() => AppSettingsService.instance.setAnalysisDepth(20));
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = AnalysisNode(fen: _start);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameReviewDialog(
          puzzleSets: deviceOnlyPuzzleSets(),
          rootNode: root,
          currentNode: root,
          stockfishService: StockfishService(),
          onCompleted: ({extractedPuzzles}) {},
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_depthSlider(tester).value, 42);
    expect(_depthSlider(tester).divisions, 45, reason: 'every depth from 5');
  });

  testWidgets('the Auto Analysis dialog reaches 50', (tester) async {
    SharedPreferences.setMockInitialValues({'app_analysis_depth': 50});
    await AppSettingsService.instance.init();
    addTearDown(() => AppSettingsService.instance.setAnalysisDepth(20));
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = AnalysisNode(fen: _start);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutoAnalysisDialog(
          startNode: root,
          stockfishService: StockfishService(),
          onAnalysisCompleted: (_) {},
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_depthSlider(tester).value, 50);
  });
}
