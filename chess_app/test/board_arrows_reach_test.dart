import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// A switch is judged by the board, not by the setting.
///
/// The batch that built the menu proved this in a scratch script that is not in
/// the suite, so what shipped was a test of the menu's *contents* — four labels
/// and their absence — over a screen nobody had watched lose an arrow.
///
/// The first version of this file was worse than that: it asserted "no arrows"
/// on a screen where the arrow it named is null anyway, so it passed with the
/// switch ripped out. Proved by mutation, which is the only reason that was
/// found. The board it uses now is one that really draws.
const _root = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class _Api extends RepertoireApiService {
  _Api() : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// Two decisions in the root position, which is what `_keptArrows` draws.
  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      const [
        RepertoireMove(uci: 'e2e4', san: 'e4', role: 'primary'),
        RepertoireMove(uci: 'd2d4', san: 'd4', role: 'alternate'),
      ];

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
  }) async =>
      const RepertoireFrontier(
        decided: 1,
        open: [FrontierNode(fen: _root, path: [], reach: 1, kind: 'undecided')],
      );
}

ChessBoardWithOverlay _board(WidgetTester tester) =>
    tester.widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(
    home: RepertoireBuildScreen(
      name: 'Test',
      id: 1,
      color: 'w',
      rootFen: _root,
      api: _Api(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  testWidgets(
      'your own moves are drawn, and stop being drawn when switched off',
      (tester) async {
    await _pump(tester);

    // The board really has something on it. Without this the assertion below
    // would hold on an empty board forever.
    expect(_board(tester).engineArrows, isNotEmpty,
        reason:
            'nothing was drawn, so nothing can be proved about removing it');

    await AppSettingsService.instance.setShowChosenMoveArrow(false);
    await tester.pumpAndSettle();

    expect(_board(tester).engineArrows, isEmpty,
        reason: 'the setting was written and the board kept the arrows');
  });

  testWidgets('and they come back, without the screen being left',
      (tester) async {
    await _pump(tester);
    await AppSettingsService.instance.setShowChosenMoveArrow(false);
    await tester.pumpAndSettle();
    expect(_board(tester).engineArrows, isEmpty);

    await AppSettingsService.instance.setShowChosenMoveArrow(true);
    await tester.pumpAndSettle();

    expect(_board(tester).engineArrows, isNotEmpty,
        reason: 'a switch that only ever removes is one nobody can undo');
  });

  testWidgets('one switch does not turn off what another one owns',
      (tester) async {
    // `_boardArrows` is a chain of early returns and all three sources arrive
    // as the same class. A switch that returned an empty list instead of
    // skipping its own source would take everything below it with it.
    await AppSettingsService.instance.setShowStatisticsArrows(false);
    await AppSettingsService.instance.setShowEngineArrows(false);

    await _pump(tester);

    expect(_board(tester).engineArrows, isNotEmpty,
        reason: 'turning off statistics and the engine took the reader\'s own '
            'moves with them');
  });
}
