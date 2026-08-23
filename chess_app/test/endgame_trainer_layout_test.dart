import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Serves one position without a network.
class _FakeEndgameApi extends EndgameApiService {
  _FakeEndgameApi(this.result) : super(authToken: '');

  final EndgameFetchResult result;

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
      result;
  @override
  Future<TablebaseReadout?> fetchReadout({
    required String fen,
    required EndgameMode goal,
  }) async =>
      TablebaseReadout.fromJson(const {
        'goal': 'draw',
        'outcome': 'draw',
        'holding': 2,
        'total': 3,
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
          {
            'san': 'Re1',
            'uci': 'a1e1',
            'outcome': 'draw',
            'holds': true,
            'zeroing': false,
            'dtz': 0
          },
          {
            'san': 'Kg6',
            'uci': 'g7g6',
            'outcome': 'loss',
            'holds': false,
            'zeroing': false,
            'dtz': -8
          },
        ],
      });

  @override
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async =>
      true;
}

/// The longest labels the screen can be handed, all at once: a long type name,
/// a long pair of player names, and the tablebase chip. If anything overflows a
/// phone, it overflows here.
EndgamePuzzle worstCasePuzzle() => EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_test',
      'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
      'type': 'DoubleBishopVsBishopKnight',
      'mode': 'draw',
      'winning_moves': ['a1f1', 'a1e1'],
      'solution': ['a1f1', 'g2g3'],
      'piece_count': 5,
      'pawn_count': 1,
      'source': 'syzygy',
      'difficulty': 'hard',
      'difficulty_score': 9,
      'game': {
        'white': 'Chiburdanidze, Maia',
        'black': 'Gaprindashvili, Nona',
        'date': '1978.09.14',
      },
    });

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  // A release build paints no overflow stripes and throws no assertion - it
  // just clips. In a test build it does throw, which is the only cheap way to
  // catch it. 360x640 is the phone this project has actually been bitten on.
  testWidgets('lays out on a 360x640 phone without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('održite remi'), findsOneWidget);
  });

  testWidgets('says "nothing matches" and "unavailable" differently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final entry in {
      EndgameFetchOutcome.noneMatch: 'odgovara traženim uslovima',
      EndgameFetchOutcome.unavailable: 'nije moguće dobaviti',
    }.entries) {
      await tester.pumpWidget(
        wrap(
          EndgameTrainerScreen(
            // A distinct key per outcome. Without it Flutter reuses the same
            // State across the two pumps, initState never runs again, and the
            // second case quietly asserts against the first one's message.
            key: ValueKey(entry.key),
            session: UserSession(
                token: 't',
                id: 1,
                email: 'a@b',
                name: 'Test',
                role: 'korisnik'),
            api: _FakeEndgameApi(EndgameFetchResult(entry.key)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(entry.value),
        findsOneWidget,
        reason: 'ishod ${entry.key} mora imati svoju poruku',
      );
    }
  });

  testWidgets('the drill can be entered, and its controls fit a phone too',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Five pieces and an exact source, so it can be played out.
    expect(find.text('Odigraj do kraja'), findsOneWidget);

    // The controls sit below the board on a 360 dp phone, so the button has
    // to be scrolled to before it can be tapped.
    await tester.ensureVisible(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();

    // The whole row of drill buttons has to fit the same 360 dp phone.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Igrate do kraja'), findsOneWidget);
    expect(find.text('Ispočetka'), findsOneWidget);
    expect(find.text('Nazad na zadatak'), findsOneWidget);
    // The solve-mode controls step aside; hunting for other moves makes no
    // sense once the position is being played out.
    expect(find.text('Pomoć'), findsNothing);

    await tester.ensureVisible(find.text('Nazad na zadatak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nazad na zadatak'));
    await tester.pumpAndSettle();
    expect(find.textContaining('održite remi'), findsOneWidget);
  });

  testWidgets('leaving the drill goes back to the task, hunt and all',
      (tester) async {
    // Reported from the desktop build: found the move, played it out, made a
    // mistake, took it back, pressed "Nazad na zadatak" - and could not move.
    // The board was right (the position is solved) and silent, and the way on
    // was a button the reader had no reason to look for. So the button that
    // says "back to the task" goes back to the task: one of two moves found is
    // an unfinished task.
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
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

    // Rf1 holds the draw; Re1 also does, and stays unfound.
    await tester.tapAt(at('a1'));
    await tester.pumpAndSettle();
    await tester.tapAt(at('f1'));
    await tester.pumpAndSettle();
    // "Tačno" alone also matches the "Tačno iz tablica" chip, and the heading
    // says "Rešeno — remi je održan" beside the verdict.
    expect(find.textContaining('remi je održan'), findsWidgets);
    // The button by its exact label: the panel's explanation names it too.
    expect(find.text('Nađi i ostale (1/2)'), findsOneWidget);
    expect(find.textContaining('Tabla je zatvorena'), findsOneWidget);

    await tester.ensureVisible(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Nazad na zadatak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nazad na zadatak'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ChessBoardWithOverlay>(board).isAllowedToMove,
      isTrue,
      reason: 'zadatak nije gotov, pa tabla mora da prima potez',
    );
    expect(find.textContaining('nađite još jedan'), findsOneWidget);
  });

  testWidgets('on a wide window the finding sits beside the board, not over it',
      (tester) async {
    // Asked for after using it: the dialog had to be closed before the next
    // move, which is exactly the moment the reader wants it in view. Beside the
    // board it stays, and the drill goes on being played under it.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nalaz tablica'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'na širokom prozoru nema prozorčića');
    expect(find.text('Nalaz tablica'), findsOneWidget,
        reason: 'naslov panela; dugme se u tom stanju zove drugačije');
    expect(find.text('Sakrij nalaz'), findsOneWidget);
    expect(find.text('Rf1+'), findsOneWidget);

    // And the drill is still playable underneath it.
    expect(
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .isAllowedToMove,
      isTrue,
    );

    await tester.tap(find.text('Sakrij nalaz'));
    await tester.pumpAndSettle();
    expect(find.text('Rf1+'), findsNothing);
  });

  testWidgets('a move from the finding is played, and the board stays open',
      (tester) async {
    // Asked for after a losing move: rather than take it back and learn
    // nothing, play the refutation from the list and answer it on the board.
    // So the tap plays the move, the drill steps aside, and nothing is judged
    // or counted while it lasts.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nalaz tablica'));
    await tester.pumpAndSettle();

    final board = find.byType(ChessBoardWithOverlay);
    final before =
        tester.widget<ChessBoardWithOverlay>(board).controller.game.fen;

    // Rf1+ is one of the moves the fake finding offers.
    await tester.tap(find.text('Rf1+'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ChessBoardWithOverlay>(board).controller.game.fen,
      isNot(before),
      reason: 'potez iz nalaza mora da se odigra na tabli',
    );
    expect(find.text('Istraživanje'), findsOneWidget);
    expect(find.text('Nazad na poziciju'), findsOneWidget);
    expect(
      tester.widget<ChessBoardWithOverlay>(board).isAllowedToMove,
      isTrue,
      reason: 'tabla ostaje slobodna da se odgovori',
    );
    // Nothing was judged, so nothing is counted against the reader.
    expect(find.textContaining('Greške:'), findsNothing);

    await tester.tap(find.text('Nazad na poziciju'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChessBoardWithOverlay>(board).controller.game.fen,
      before,
      reason: 'povratak vraca tacno onu poziciju odakle se krenulo',
    );
    expect(find.text('Istraživanje'), findsNothing);
  });

  testWidgets('on a phone the finding is still a window', (tester) async {
    // There is no column to spare under the board on 360 dp, and a panel there
    // would push the board off the screen.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odigraj do kraja'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Nalaz tablica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nalaz tablica'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a position too big for any tablebase is not offered as a drill',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tooBig = EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_big',
      'fen': '8/4k3/8/1p2Pp2/p7/P1K1P3/1P6/8 w - - 1 42',
      'type': 'PawnEnding',
      'mode': 'win',
      'winning_moves': ['c3d3'],
      'piece_count': 9,
      'source': 'engine',
    });

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          key: const ValueKey('big'),
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
              EndgameFetchResult(EndgameFetchOutcome.ok, tooBig)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Odigraj do kraja'), findsNothing);
  });

  testWidgets('a thrown-away draw can be punished, and the board turns round',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Alexopoulos - Grigorov 1979, as the detector found it: White to move in a
    // drawn rook ending, played Ra2+ and lost it. Two moves held.
    final blunder = EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_blunder',
      'fen': '8/8/8/8/8/4rp2/5k1K/R7 w - - 2 71',
      'type': 'KRPvKR',
      'material': 'KRPvKR',
      'mode': 'draw',
      'winning_moves': ['h2h3', 'a1b1'],
      'piece_count': 5,
      'source': 'blunder',
      'played_move': 'Ra2+',
      'blunder_elo': 2270,
    });

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          key: const ValueKey('punish'),
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
              EndgameFetchResult(EndgameFetchOutcome.ok, blunder)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The story, and the rating of whoever got it wrong.
    expect(find.textContaining('U partiji je odigrano Ra2+'), findsOneWidget);
    expect(find.text('Pogrešio: 2270'), findsOneWidget);

    await tester.ensureVisible(find.text('Kazni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kazni'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Kaznite grešku'), findsOneWidget);
    // The mistake is already on the board and the win belongs to the other
    // side, so the exercise is played from there.
    expect(find.textContaining('remi je izgubljen'), findsOneWidget);

    await tester.ensureVisible(find.text('Nazad na zadatak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nazad na zadatak'));
    await tester.pumpAndSettle();
    expect(find.textContaining('održite remi'), findsOneWidget);
  });

  testWidgets('a position with nothing to punish does not offer it',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A win that slipped to a draw leaves nothing to convert, and a position
    // that never came from a mistake has no move to punish in the first place.
    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          key: const ValueKey('nopunish'),
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Odigraj do kraja'), findsOneWidget);
    expect(find.text('Kazni'), findsNothing);
  });
}
