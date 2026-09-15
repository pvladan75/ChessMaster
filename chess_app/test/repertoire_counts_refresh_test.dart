import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// A number on screen is a claim about now, not about when the screen opened.
///
/// The walk was once read in `initState` and nowhere else, so the counts under
/// the board went on describing a repertoire that had since changed. Playing a
/// move is what changes them now, so playing one has to read them again.
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class _CountingApi extends RepertoireApiService {
  _CountingApi()
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  int walks = 0;
  int decided = 2;

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
  }) async {
    walks += 1;
    return RepertoireFrontier(
      decided: decided,
      open: const [FrontierNode(fen: _start, path: [])],
    );
  }

  @override
  Future<({bool saved, ({String uci, String san, String fen})? topReply})>
      keepMove({
    required String color,
    required String fen,
    required String uci,
    required String san,
    String? verdict,
  }) async {
    // The server agreed, so one decision more from here on.
    decided += 1;
    return (saved: true, topReply: null);
  }
}

class _SilentJudge implements OpeningJudgeService {
  @override
  Future<OpeningJudgeLookup> judge(String fen, String move) async =>
      const OpeningJudgeLookup.unavailable('not-configured');

  @override
  Future<OpponentRepliesLookup> replies(String fen) async =>
      const OpponentRepliesLookup.unavailable('not-configured');

  @override
  void clearCache() {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('playing a move re-reads the counts under the board',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = _CountingApi();
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'Benoni',
        id: 3,
        color: 'w',
        rootFen: _start,
        api: api,
        judge: _SilentJudge(),
        explore: (fen) async =>
            const OpeningExplorerLookup.unavailable('not-configured'),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('decided 2 · open 1'), findsOneWidget);
    final walksBefore = api.walks;

    Offset squareAt(String name) {
      final finder = find.byType(ChessBoardWithOverlay);
      final widget = tester.widget<ChessBoardWithOverlay>(finder);
      final rect = tester.getRect(finder);
      final size = widget.boardSize / 8;
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * size, (row + 0.5) * size);
    }

    await tester.tapAt(squareAt('e2'));
    await tester.pumpAndSettle();
    await tester.tapAt(squareAt('e4'));
    await tester.pumpAndSettle();

    // The walk was read again, and the line says what it says now.
    expect(api.walks, greaterThan(walksBefore));
    expect(find.text('decided 3 · open 1'), findsOneWidget);
  });
}
