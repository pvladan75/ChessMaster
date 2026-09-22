// The tactical and positional motifs are not shown on the Analysis board, and
// are not computed because the board changed (owner, 22.9.2026): they exist
// to feed the AI comment and a tutorial, and are worked out only for that.
//
// Until then a played move got a comment built from them, two panels listed
// them for every position, and the comment editor offered them as a
// checklist. This file holds the three halves of the rule: what the reader
// no longer sees, what a move no longer gets, and where the screen may still
// ask the detectors at all.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/widgets/analysis_panels_sheet.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

import 'support/dart_source.dart';

Future<void> _open(WidgetTester tester, String fen) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: AnalysisStudioScreen(
      userSession: UserSession(
          token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik'),
      initialFen: fen,
    ),
  ));
  await tester.pumpAndSettle();
  expect(
      tester
          .widget<SkinnedChessBoard>(find.byType(SkinnedChessBoard))
          .boardOrientation,
      PlayerColor.white);
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  final board = tester.getRect(find.byType(SkinnedChessBoard));
  Offset at(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
    final side = board.width / 8;
    return board.topLeft + Offset((file + 0.5) * side, (7 - rank + 0.5) * side);
  }

  await tester.tapAt(at(from));
  await tester.pumpAndSettle();
  await tester.tapAt(at(to));
  await tester.pumpAndSettle();
}

/// The node the screen stands on, read off its move tree.
AnalysisNode _active(WidgetTester tester) => tester
    .widget<AnalysisMoveTreeWidget>(
        find.byType(AnalysisMoveTreeWidget, skipOffstage: false))
    .activeNode;

void main() {
  setUp(() async {
    // Every panel at its default: were the motif panels still there, they
    // would be drawn.
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  testWidgets('a move played on the board gets no comment of its own',
      (tester) async {
    // Qd5 forks the king and the rook: until 22.9.2026 the move was written
    // up as „forks the black king" the moment it was played.
    await _open(tester, '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1');
    await _play(tester, 'd1', 'd5');

    final node = _active(tester);
    expect(node.moveSan, 'Qd5+', reason: 'the move was played');
    expect(node.comment, isEmpty);
    expect(find.textContaining('forks', findRichText: true), findsNothing);
  });

  testWidgets('the board shows no motif panel, and the sheet offers none',
      (tester) async {
    // The rook on d8 hangs and the pawn on a2 is isolated: the old panels
    // drew nothing for a position with no finding, so this one has both.
    await _open(tester, '3r2k1/8/8/8/8/8/P7/3Q2K1 w - - 0 1');
    expect(find.text('Tactical motifs'), findsNothing,
        reason: 'the tactical panel');
    expect(find.text('Positional factors'), findsNothing,
        reason: 'the positional panel');

    expect(
        [for (final (label, _) in analysisPanels) label],
        isNot(anyOf(
            contains('Tactical motifs'), contains('Positional factors'))));
    expect(
        [for (final (_, key) in analysisPanels) key],
        isNot(anyOf(
            contains('tactical_motifs'), contains('positional_factors'))));
  });

  test('the screen asks the detectors only for what it sends to the AI', () {
    final code = codeOf(
        File('lib/features/analysis_studio/screens/analysis_studio_screen.dart')
            .readAsStringSync());
    final uses = RegExp(r'_(tacticalDetector|positionalEvaluator)\s*\.');
    final all = uses.allMatches(code).length;

    // The body of `_findingsPairFor`, by its braces: it is the one function
    // that turns two positions into what the AI endpoint is sent.
    final name = code.indexOf('_findingsPairFor(');
    expect(name, greaterThan(0), reason: 'the function is still there');
    final open = code.indexOf('{', name);
    var depth = 0;
    var close = open;
    for (var i = open; i < code.length; i++) {
      if (code[i] == '{') depth++;
      if (code[i] == '}' && --depth == 0) {
        close = i;
        break;
      }
    }
    final inside = uses.allMatches(code.substring(open, close)).length;

    expect(inside, greaterThan(0), reason: 'the check found the calls');
    expect(all, inside,
        reason: 'a detector called anywhere else runs on a board change or '
            'feeds something the reader sees');
  });
}
