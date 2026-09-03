import 'dart:io';
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
  mainArrowSwitchGuard();
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

/// Every screen that draws engine arrows must also offer the switch.
///
/// Added 3.9.2026, after the owner found the AI Studio drawing engine arrows
/// over a board whose menu offered only „Koordinate": the arrows were there and
/// nothing could turn them off. Phase 1's brief said the switches belonged on
/// „exactly three screens" and named them, so the batch that built the menu was
/// right to leave this one alone — the brief was wrong, and a list written in
/// prose cannot notice a fourth screen appearing.
///
/// The rule, checked instead of the list: a file that *passes* engine arrows to
/// the painter has to read `showEngineArrows` and has to mount the menu with
/// `arrows: true`. Passing `const []` is not drawing them, and the two widgets
/// that merely receive the parameter are not screens.
///
/// **What this proves and what it does not.** The menu half is strong: every
/// `BoardViewMenu` on such a screen is checked, paren-matched, and stripping
/// the switches off one of the AI Studio's two menus turns this red — the first
/// version searched the whole file, and that mutation walked straight past it.
/// The reading half is weak by construction: it asks only that the file mention
/// `showEngineArrows` somewhere, so replacing one of two uses with `true` still
/// passes. The property itself — arrows stop being drawn — is proved by the
/// widget tests above, and only for the build screen. A screen added tomorrow
/// gets the loud half of this check and not the quiet one.
void mainArrowSwitchGuard() {
  const receivers = [
    'widgets/board_overlay_painter.dart',
    'widgets/game_screen/chess_board_with_overlay.dart',
  ];

  test('a screen that draws engine arrows offers the engine switch', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final rel = f.path.replaceAll(r'\', '/').split('lib/').last;
      if (receivers.contains(rel)) continue;
      final flat = f.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      if (!RegExp(r'engineArrows: (?!const \[\])').hasMatch(flat)) continue;
      final reads = flat.contains('showEngineArrows');
      // Every menu on the screen, not "the file mentions it somewhere". The
      // first version of this guard checked the whole file, and passed a
      // mutation that stripped the switches off one of the AI Studio's two
      // menus, because the other one still carried the words. Paren-matched
      // rather than sliced, for the reason CLAUDE.md gives.
      final menus = <String>[];
      for (var i = flat.indexOf('BoardViewMenu(');
          i >= 0;
          i = flat.indexOf('BoardViewMenu(', i + 1)) {
        final open = flat.indexOf('(', i);
        var depth = 0, end = -1;
        for (var j = open; j < flat.length; j++) {
          if (flat[j] == '(') depth++;
          if (flat[j] == ')') {
            depth--;
            if (depth == 0) {
              end = j;
              break;
            }
          }
        }
        if (end > open) menus.add(flat.substring(open, end));
      }
      final bare = menus.where((m) => !m.contains('arrows: true')).length;
      if (!reads || menus.isEmpty || bare > 0) {
        offenders.add('$rel: '
            '${reads ? '' : 'never reads showEngineArrows; '}'
            '${menus.isEmpty ? 'no BoardViewMenu at all' : ''}'
            '${bare > 0 ? '$bare of ${menus.length} menus without '
                'arrows: true' : ''}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'engine arrows on a board with no way to turn them off:\n'
            '${offenders.join('\n')}');
  });
}
