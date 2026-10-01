// analysis_draft_owner_test.dart — docs/PLAN-TRENER-ZAVRSNICA.md, phase 3 (D7).
//
// The device keeps one analysis draft, and it belongs to the Analyse tab: the
// screen handed no position, game or tree. Until 1.10.2026 every Analysis
// wrote it — on each change and in `dispose` — so after any pushed Analysis
// (the Library, Preparation, the opening report, a game from the archive or a
// homework, and now the endgame trainer) the next start showed that tree in
// the Analyse tab in place of the tab's own work.
//
// One condition answers it, read in three places: restoring, `_saveDraft` and
// the `dispose` flush. The cases below are built so each writer is caught on
// its own: a move with the screen still up can be written only by
// `_saveDraft` (the flush runs at `dispose`), and a pop with no move can be
// written only by the flush.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

const _key = 'analysis_studio_draft';
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

UserSession _session() =>
    UserSession(token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'k');

/// The three ways a caller hands Analysis something of its own.
final Map<String, AnalysisStudioScreen Function()> _pushed = {
  'initialFen': () =>
      AnalysisStudioScreen(userSession: _session(), initialFen: _start),
  'initialGame': () => AnalysisStudioScreen(
        userSession: _session(),
        initialGame: analysisGameFromSans(
            startFen: _start,
            sans: const ['Nf3', 'Nf6'],
            blackOrientation: false)!,
      ),
  'initialTree': () => AnalysisStudioScreen(
      userSession: _session(), initialTree: AnalysisNode(fen: _start)),
};

/// A draft of the tab's own work, written straight into the key so the case
/// does not depend on the writer it is testing.
String _seed() {
  final root = AnalysisNode(fen: _start);
  root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4');
  return jsonEncode({
    'tree': root.toJson(),
    'path': [0],
    'blackOrientation': false,
    'savedAt': DateTime(2026, 10, 1).toIso8601String(),
  });
}

Future<String?> _raw() async =>
    (await SharedPreferences.getInstance()).getString(_key);

Future<void> _pumpUnder(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: home,
  ));
  await tester.pumpAndSettle();
}

/// Pushes [screen] over a plain page, the way every door pushes Analysis.
Future<void> _push(WidgetTester tester, AnalysisStudioScreen screen) async {
  await _pumpUnder(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(AnalysisStudioScreen), findsOneWidget);
}

Future<void> _pop(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(AnalysisStudioScreen))).pop();
  await tester.pumpAndSettle();
  expect(find.byType(AnalysisStudioScreen), findsNothing);
  expect(find.text('open'), findsOneWidget);
}

/// e2-e4 by two taps, then past the draft's 600 ms debounce.
Future<void> _playE4(WidgetTester tester) async {
  final board = tester.getRect(find.byType(SkinnedChessBoard));
  Offset at(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
    final side = board.width / 8;
    return board.topLeft + Offset((file + 0.5) * side, (7 - rank + 0.5) * side);
  }

  await tester.tapAt(at('e2'));
  await tester.pumpAndSettle();
  await tester.tapAt(at('e4'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('the Analyse tab\'s own screen writes the draft after a move',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpUnder(tester, AnalysisStudioScreen(userSession: _session()));
    expect(await _raw(), isNull);

    await _playE4(tester);

    final raw = await _raw();
    expect(raw, isNotNull, reason: 'the tab keeps its work on the device');
    expect(raw, contains('e2e4'));
  });

  for (final entry in _pushed.entries) {
    testWidgets('a screen given ${entry.key} writes nothing after a move',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _push(tester, entry.value());

      await _playE4(tester);

      // Still on screen, so only `_saveDraft` could have written.
      expect(find.byType(AnalysisStudioScreen), findsOneWidget);
      expect(await _raw(), isNull);
    });

    testWidgets('a screen given ${entry.key} writes nothing when it is popped',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _push(tester, entry.value());

      // No move: only the `dispose` flush could write now.
      await _pop(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(await _raw(), isNull);
    });

    testWidgets(
        'a draft stored before a visit to a screen given ${entry.key} is the '
        'same byte for byte after it', (tester) async {
      final seeded = _seed();
      SharedPreferences.setMockInitialValues({_key: seeded});
      await _push(tester, entry.value());

      await _playE4(tester);
      await _pop(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(await _raw(), seeded);
    });
  }
}
