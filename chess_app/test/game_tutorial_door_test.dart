// Phase 4 of `docs/PLAN-SKELET.md`: where the door to a tutorial made from a
// game is drawn.
//
// Read from source, for the reason `tutorial_studio_test.dart` gives: the
// Analysis screen does not build in a widget test (an engine and three network
// services start with it). The flow behind the door is driven for real in
// `game_tutorial_flow_test.dart`; this only asks that the door exists, is
// behind the studio's predicate, and hands the flow the screen's own engine
// settings.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen =
      File('lib/features/analysis_studio/screens/analysis_studio_screen.dart')
          .readAsStringSync();

  test('the door is in the Analysis toolbar', () {
    expect(screen.contains("'Make a tutorial from this game'"), isTrue);
  });

  test('the door is behind the studio\'s own predicate, not a neighbour\'s',
      () {
    final at = screen.indexOf("'Make a tutorial from this game'");
    final before = screen.substring(0, at);
    final guard = before.lastIndexOf('if (isTutorialStudioAvailable)');
    expect(guard, greaterThan(0), reason: 'no predicate in front of the door');
    // Exactly one action between the guard and the label: this door. A guard
    // that belongs to the action before it would put two here.
    expect('_ToolAction('.allMatches(before.substring(guard)).length, 1,
        reason: 'the nearest predicate guards a different action');
  });

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
