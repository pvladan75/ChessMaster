// Phase 4 of `docs/PLAN-SKELET.md`: how the game-to-tutorial flow is called.
//
// Read from source, for the reason `tutorial_studio_test.dart` gives: the
// Analysis screen does not build in a widget test (an engine and three network
// services start with it). The flow behind the door is driven for real in
// `game_tutorial_flow_test.dart`.
//
// Since phase 1 of `docs/PLAN-REORGANIZACIJA.md` (S2), the door itself is a
// row of the sheet in `chess_app/lib/features/analysis_studio/widgets/
// teach_menu.dart`, behind `studioAvailable` — proved in
// `analysis_teach_menu_test.dart` — and not a bar action behind its own
// predicate any more. `docs/gates/analysis_teach_door_test.dart` (copied to
// `test/analysis_teach_door_test.dart`) already reads this exact call for the
// same reason, so only that one assertion survives here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen =
      File('lib/features/analysis_studio/screens/analysis_studio_screen.dart')
          .readAsStringSync();

  test('the door runs the flow with the screen\'s session and engine settings',
      () {
    final start = screen.indexOf('Future<void> _makeTutorialFromGame()');
    expect(start, greaterThan(0));
    final body = screen.substring(start, screen.indexOf(');', start));
    expect(body, contains('makeTutorialFromGame('));
    expect(body, contains('session: widget.userSession'));
    expect(body, contains('root: _rootNode'));
    expect(body, contains('onOpenEngineSettings: _openEngineSettings'));
    // A tutorial made from a game opens with White at the bottom (the owner,
    // 14.9.2026). The orientation this screen was left in is not a decision
    // about the tutorial, so it must not travel.
    expect(body, isNot(contains('rientation')),
        reason: 'the Analysis board decided which way the tutorial faced');
  });
}
