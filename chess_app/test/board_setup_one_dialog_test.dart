// Setting up a position is one act, so it is one dialog.
//
// Phase 1a of `docs/PLAN-ZAVRSNICA.md`. There were two, and they were two files
// with the same name: `lib/widgets/board_setup_dialog.dart`, a piece-placement
// editor that could only ever open on the standard opening, and
// `lib/features/analysis_studio/widgets/board_setup_dialog.dart`, five tabs
// around an editor of its own. The owner met the difference before the code
// admitted it: „u svim delovima aplikacije treba uvesti iste dijaloge za
// postavljanje pozicije".
//
// The one that survived is the one that can be opened on the position in front
// of you. The room's could not, so a trainer setting up a study from the board
// they were looking at had to build it again from nothing.
//
// Three things are gated here, and the third is the one that will rot first.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  const endgameFen = '4k3/8/5K2/4P3/8/8/8/8 w - - 0 12';

  Future<void> open(WidgetTester tester, Widget dialog) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(body: dialog),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('it opens on the position it was handed', (tester) async {
    await open(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: endgameFen,
        onPositionSet: (_) {},
      ),
    );

    expect(find.widgetWithText(TextField, endgameFen), findsOneWidget,
        reason: 'the dialog came up on the standard opening instead of the '
            'board the caller is looking at — which is the whole reason this '
            'is the dialog that survived');
  });

  testWidgets('a caller that cannot take a PGN is not offered one',
      (tester) async {
    // „Otvaranja", „PGN Uvoz" and „Chess.com/Lichess" all hand their result
    // over through `onPgnLoaded`. Without it they closed the dialog and
    // dropped what was asked for — the tutorial studio's trainer picked an
    // opening and watched nothing happen.
    await open(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: endgameFen,
        onPositionSet: (_) {},
      ),
    );

    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('FEN String'), findsOneWidget);
    expect(find.text('Piece Placement'), findsOneWidget);
  });

  testWidgets('and one that can is offered all five', (tester) async {
    await open(
      tester,
      AnalysisBoardSetupDialog(
        initialFen: endgameFen,
        onPositionSet: (_) {},
        onPgnLoaded: (_) {},
      ),
    );

    expect(find.byType(Tab), findsNWidgets(5));
  });

  test('there is one setup dialog in the app, and one caller shape', () {
    // A source-reading gate, and the kind that has to be read carefully: it is
    // about **imports**, because an import is what says a file reaches for a
    // class. Asking for the class name over the whole directory matches this
    // file's own prose, and asking `contains` over a directory has already
    // failed once here on a doc comment explaining why something was *not*
    // used.
    final lib = Directory('lib');
    final offenders = <String>[];
    final callers = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      final unixPath = entity.path.replaceAll(r'\', '/');

      // A second dialog would be a second widget class whose name says what it
      // is. The survivor is allowed to declare itself.
      if (RegExp(r'class \w*BoardSetupDialog\b').hasMatch(source) &&
          !unixPath.endsWith(
              'features/analysis_studio/widgets/board_setup_dialog.dart')) {
        offenders.add(unixPath);
      }

      // The file that declares it is not a caller of it.
      if (unixPath.endsWith(
          'features/analysis_studio/widgets/board_setup_dialog.dart')) {
        continue;
      }
      if (source.contains('AnalysisBoardSetupDialog(')) {
        callers.add(unixPath);
      }
    }

    expect(offenders, isEmpty,
        reason: 'a second board-setup dialog is back. There were two until '
            '8.9.2026 and the difference was visible to the user before it was '
            'visible here');

    // Every screen that sets up a position reaches the same one, and every one
    // of them says which position it is starting from. A caller that opens it
    // on nothing is the fault this phase closed.
    expect(callers, isNotEmpty);
    for (final path in callers) {
      for (final call in _callsIn(File(path).readAsStringSync())) {
        expect(call, contains('initialFen:'),
            reason: '$path opens the setup dialog without telling it which '
                'position the reader is looking at');
      }
    }
  });
}

/// Every `AnalysisBoardSetupDialog( … )` in [source], read by matching
/// parentheses rather than by taking a fixed number of characters.
///
/// A slice runs into whatever follows it, and a source-reading test that reads
/// the wrong region is a test that passes for the wrong reason — this
/// repository has paid for that once already, with a guard that read 1600
/// characters from the start of a function and matched the next one.
List<String> _callsIn(String source) {
  const needle = 'AnalysisBoardSetupDialog(';
  final calls = <String>[];
  var from = 0;
  while (true) {
    final start = source.indexOf(needle, from);
    if (start < 0) return calls;
    var depth = 0;
    var i = start + needle.length - 1;
    for (; i < source.length; i++) {
      if (source[i] == '(') depth++;
      if (source[i] == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    calls.add(source.substring(start, i + 1));
    from = i + 1;
  }
}
