// Playing a mate on the Analysis board writes no comment under it.
//
// The path the report came from (16.9.2026): Rh5# played on the board, and a
// comment about a skewer under the move. `core/mating_move_comment_test.dart`
// proves the rule; this proves the screen goes through it.

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

const _before = 'r1n2N1K/3p4/2pp1pP1/1nbb1k2/7R/2N1Bp1P/3P4/q7 w - - 0 1';

void main() {
  setUp(() async {
    // The live panels read the position, not the move, and would name the
    // skewer on their own; they are not what is under test.
    SharedPreferences.setMockInitialValues({
      'app_hidden_panels': ['tactical_motifs', 'positional_factors'],
    });
    await AppSettingsService.instance.init();
  });

  Future<void> play(WidgetTester tester, String from, String to) async {
    final board = tester.getRect(find.byType(SkinnedChessBoard));
    Offset at(String square) {
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
      final side = board.width / 8;
      return board.topLeft +
          Offset((file + 0.5) * side, (7 - rank + 0.5) * side);
    }

    await tester.tapAt(at(from));
    await tester.pumpAndSettle();
    await tester.tapAt(at(to));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String fen) async {
    tester.view.physicalSize = const Size(400, 900);
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

  testWidgets('Rh5# is played and nothing is written under it', (tester) async {
    await open(tester, _before);
    await play(tester, 'h4', 'h5');

    expect(find.textContaining('Rh5#', findRichText: true), findsWidgets,
        reason: 'the move was not played');
    expect(find.textContaining('skewers', findRichText: true), findsNothing);
    expect(find.textContaining('checkmated', findRichText: true), findsNothing);
  });

  testWidgets('a move that is not mate still gets its comment', (tester) async {
    // Without this the test above would pass on a screen that never comments.
    await open(tester, '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1');
    await play(tester, 'd1', 'd5');

    expect(find.textContaining('forks the black king', findRichText: true),
        findsWidgets);
  });
}
