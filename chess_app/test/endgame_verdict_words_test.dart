// What the endgame trainer says after a right answer: the verdict, and
// nothing more.
//
// Until 30.9.2026 a sentence about what the holding moves had in common
// followed it — „The Rook must stay on rank 1", „Only the king moves hold",
// „Only a check holds" — worked out from the board and the list of holding
// moves alone. The owner had them taken out everywhere as often wrong: true
// of the moves, they were said as rules, and a lone holding move made every
// property of that move into one. This position is one where the old code
// spoke: both holding moves keep the rook on the first rank.

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

class _FakeEndgameApi extends EndgameApiService {
  _FakeEndgameApi(this.puzzle) : super(authToken: '');

  final EndgamePuzzle puzzle;

  @override
  Future<EndgameFetchResult> fetchNext({
    String? type,
    EndgameMode? mode,
    String? difficulty,
    int? maxPieces,
    int? minPawns,
    String? excludeId,
    String? material,
    String? band,
    bool oppositeOnly = false,
    bool includeOnline = false,
  }) async =>
      EndgameFetchResult(EndgameFetchOutcome.ok, puzzle);
}

void main() {
  testWidgets('a right answer is told the verdict, with no rule after it',
      (tester) async {
    final puzzle = EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_words',
      'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
      'type': 'PawnEnding',
      'mode': 'draw',
      'winning_moves': ['a1f1', 'a1e1'],
      'solution': ['a1f1', 'g2g3'],
      'piece_count': 5,
      'pawn_count': 1,
      'source': 'syzygy',
      'difficulty': 'easy',
    });
    await tester.pumpWidget(MaterialApp(
      home: EndgameTrainerScreen(
        session: UserSession(
            token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
        api: _FakeEndgameApi(puzzle),
        attemptApi: PuzzleAttemptApi(
          authToken: 't',
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final board = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(board);
    final rect = tester.getRect(board);
    final square = widget.boardSize / 8;
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    await tester.tapAt(at('a1'));
    await tester.pumpAndSettle();
    await tester.tapAt(at('f1'));
    await tester.pumpAndSettle();

    // The whole message, so that anything said after the verdict is a red.
    expect(
        find.text('Correct — draw held. ${movesLeftText(1)}'), findsOneWidget);
    expect(find.textContaining('must stay'), findsNothing);
  });
}
