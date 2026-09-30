// Phase 1 of docs/PLAN-REORGANIZACIJA.md — one door in Analysis.
//
// The gate of the phase. Copied into chess_app/test/ by the implementer as the
// first step and left there green; the sheet itself is already tested in
// test/analysis_teach_menu_test.dart. Written 17.9.2026 and proved red on
// `master` at bd64f9c: the four tooltips survive and the screen never calls
// showTeachMenu.
//
// Read by structure (test/support/dart_source.dart): a comment quoting a
// retired label does not count, and the checks on the screen look at its code.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_source.dart';

const _screenPath =
    'lib/features/analysis_studio/screens/analysis_studio_screen.dart';

Set<String> _literalsOfLib() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          ...literalsIn(file.readAsStringSync()),
    };

void main() {
  final screen = File(_screenPath).readAsStringSync();

  test('the four tooltips and the transfer dialog are gone from lib/', () {
    final literals = _literalsOfLib();
    for (final gone in [
      'Create step from this position',
      'Edit tutorial steps',
      'Create interactive tutorial',
      'What are we transferring to the tutorial?',
      'Position only',
      'Whole line',
    ]) {
      expect(literals, isNot(contains(gone)), reason: '„$gone" survives');
    }
  });

  // Rewritten 30.9.2026 (docs/PLAN-ANALIZA-TRAKA.md, D4). It used to count
  // the literal „Use in a tutorial" in the screen — one icon, named once. The
  // bar has words now: „Tutorial" in a window, with the sheet's rows under it
  // as a menu, and the sheet itself behind ⋮ on a phone. The rule is the same
  // one — a single door, its rows written down once — so what is held is that
  // both ways in read the sheet's own list and end in one switch.
  test('the bar has one tutorial door, as a menu and as the sheet', () {
    final code = codeOf(screen);
    final literals = literalsIn(screen);
    expect(literals.where((s) => s.contains('Use in a tutorial')), isEmpty,
        reason: 'the door is named by TeachMenuSheet.title, not spelled again');
    for (final row in [
      'New tutorial from this position',
      'New tutorial from this line',
      'New tutorial from this game',
      'Add this position to a tutorial…',
      'Add this line to a tutorial…',
      'Open a tutorial to edit…',
    ]) {
      expect(literals, isNot(contains(row)),
          reason: '„$row" is spelled a second time, in the screen');
    }
    expect(code, contains('showTeachMenu('),
        reason: 'the screen never opens the sheet');
    expect(code, contains('teachMenuEntries('),
        reason: '„Tutorial" in the bar does not read the rows of the sheet');
    expect('_onTeachRow('.allMatches(code).length, greaterThanOrEqualTo(7),
        reason: 'the six rows of the sheet and the menu end in one switch');
    // Since phase 6c the rows are drawn on every platform, behind nothing.
    expect(code, isNot(contains('studioAvailable')));
    // The game flow keeps its session and engine settings, and no orientation
    // (the owner, 14.9.2026) — same rule game_tutorial_door_test held.
    // The call itself, not `_makeTutorialFromGame()` in the switch above it.
    final start = code.indexOf('=> makeTutorialFromGame(');
    expect(start, greaterThan(0));
    final call = code.substring(start, code.indexOf(');', start));
    expect(call, contains('session: widget.userSession'));
    expect(call, contains('root: _rootNode'));
    expect(call, contains('onOpenEngineSettings: _openEngineSettings'));
    expect(call, isNot(contains('rientation')));
  });

  test('the two old ways in are not drawn any more', () {
    final code = codeOf(screen);
    // Four `_ToolAction`s became one row each in the sheet: none of the old
    // methods is a bar action now.
    for (final method in [
      '_createStepFromPosition)',
      '_editLessonSteps)',
      '_openTutorialStudio)',
      '_makeTutorialFromGame)',
    ]) {
      expect(code, isNot(contains(method)),
          reason: '$method is still a bar action');
    }
  });

  test('the manual names the door the app has', () {
    final page =
        File('../site/mislisha/manual/analysis.html').readAsStringSync();
    expect(page, contains('<span class="ui">Use in a tutorial</span>'));
    expect(page, isNot(contains('What are we transferring')));
  });
}
