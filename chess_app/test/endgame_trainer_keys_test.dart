import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// One position, no network. Counts how many times the next one was asked for,
/// which is what the N key has to prove.
class _FakeEndgameApi extends EndgameApiService {
  _FakeEndgameApi(this.result) : super(authToken: '');

  final EndgameFetchResult result;
  int fetches = 0;

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
  }) async {
    fetches++;
    return result;
  }

  @override
  Future<TablebaseReadout?> fetchReadout({
    required String fen,
    required EndgameMode goal,
  }) async =>
      TablebaseReadout.fromJson(const {
        'goal': 'draw',
        'outcome': 'draw',
        'holding': 1,
        'total': 1,
        'pawnless': false,
        'deadDraw': false,
        'dtz': 0,
        'moves': [
          {
            'san': 'Rf1+',
            'uci': 'a1f1',
            'outcome': 'draw',
            'holds': true,
            'zeroing': false,
            'dtz': 0
          },
        ],
      });
}

EndgamePuzzle drawPuzzle() => EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_keys',
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

/// The letters in the endgame trainer.
///
/// Two rules are being kept here, and only the first is about the keys working
/// at all. The second is the one that decides whether the list of shortcuts
/// stays true: a key stands for a button that is on the screen, and it does
/// nothing whenever that button is not offered. A key that works while its
/// button is gone is a second way in, and nobody can see it to check it.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  late _FakeEndgameApi api;

  Future<void> pump(WidgetTester tester) async {
    // Wide enough that every control is visible without scrolling; the phone
    // layout has its own test.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeEndgameApi(
      EndgameFetchResult(EndgameFetchOutcome.ok, drawPuzzle()),
    );
    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('H asks for help without anything being clicked first',
      (tester) async {
    // The whole point of the wrapper claiming the focus: a freshly opened
    // screen leaves it on the route, and a binding below the focused node is
    // never asked.
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();

    expect(find.textContaining('Potez vodi na polje'), findsOneWidget);
  });

  testWidgets('N asks for the next position', (tester) async {
    await pump(tester);
    expect(api.fetches, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();

    expect(api.fetches, 2);
  });

  testWidgets('H says nothing once the position is solved', (tester) async {
    await pump(tester);

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

    // Rf1 holds the draw.
    await tester.tapAt(at('a1'));
    await tester.pumpAndSettle();
    await tester.tapAt(at('f1'));
    await tester.pumpAndSettle();
    expect(find.text('Pomoć'), findsNothing, reason: 'rešeno, pa nema dugmeta');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();

    expect(find.textContaining('Potez vodi na polje'), findsNothing,
        reason: 'taster bez dugmeta ne sme da radi');
  });

  testWidgets('U takes a move back only after there is one to take back',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();
    expect(find.text('Vrati potez'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.pumpAndSettle();

    expect(find.textContaining('Vraćeno na položaj'), findsNothing,
        reason: 'nema greške da se vrati, pa taster ćuti');
    expect(find.textContaining('Igrate do kraja'), findsOneWidget);
  });

  testWidgets('T opens the tables, and only while the drill is on',
      (tester) async {
    await pump(tester);

    // In solve mode there is no such button: the tables are the drill's, and a
    // position solved with the answer in front of you is not solved.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
    expect(find.text('Sakrij nalaz'), findsNothing);

    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();

    // A wide window puts the finding beside the board, so the button renames
    // itself; that rename is the proof the key pressed it.
    expect(find.text('Sakrij nalaz'), findsOneWidget);
    expect(find.text('Rf1+'), findsOneWidget);
  });

  testWidgets('R starts the drill over', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();
    expect(find.text('Ispočetka'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();

    // Still the drill, and back at its opening sentence.
    expect(find.textContaining('Igrate do kraja'), findsOneWidget);
    expect(find.textContaining('Protivnik'), findsOneWidget);
    expect(api.fetches, 1, reason: 'ispočetka je ova pozicija, ne sledeća');
  });
}
