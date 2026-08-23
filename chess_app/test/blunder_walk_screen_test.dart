import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/screens/blunder_walk_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Serves one game without a network.
class _FakeApi extends EndgameApiService {
  _FakeApi(this.result) : super(authToken: '');

  final GameFetchResult result;

  @override
  Future<GameFetchResult> fetchNextGame({
    int? minBlunders,
    int? maxBlunders,
    int? minElo,
    int? maxElo,
    String? material,
    String? excludeId,
    bool includeOnline = false,
  }) async =>
      result;

  @override
  Future<List<String>?> fetchBestLine({
    required String fen,
    int plies = 10,
  }) async =>
      const ['Kf1', 'Ra1+'];
  @override
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async =>
      true;
}

/// Seger - Lambert 2005: three mistakes in six moves, alternating sides.
BlunderGame game() => BlunderGame.fromJson({
      'game_id': 'bg_test',
      'white': 'Seger, Ruediger',
      'black': 'Lambert, Andreas',
      'white_elo': 2416,
      'black_elo': 2204,
      'date': '2005.03.13',
      'start_fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
      'moves': ['Rd3', 'h4', 'Rd1', 'Rh6', 'Kxa5', 'Rc4'],
      'blunders': [
        {
          'ply': 0,
          'fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
          'side': 'black',
          'played': 'Rd3',
          'played_uci': 'f3d3',
          'should_play': ['Rb3', 'Rf2'],
          'should_play_uci': ['f3b3', 'f3f2'],
          'outcome_before': 'draw',
          'outcome_after': 'loss',
          'material': 'KRPPvKR',
        },
        {
          'ply': 1,
          'fen': '8/8/k1K5/P6R/8/3r4/7P/8 w - - 2 60',
          'side': 'white',
          'played': 'h4',
          'played_uci': 'h2h4',
          'should_play': ['Kc5'],
          'should_play_uci': ['c6c5'],
          'outcome_before': 'win',
          'outcome_after': 'draw',
          'material': 'KRPPvKR',
        },
      ],
    });

Widget wrap(Widget child) => MaterialApp(home: child);

Widget screen({BlunderGame? withGame, EndgameFetchOutcome? failing}) =>
    BlunderWalkScreen(
      session: UserSession(
          token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
      api: _FakeApi(failing != null
          ? GameFetchResult(failing)
          : GameFetchResult(EndgameFetchOutcome.ok, withGame ?? game())),
    );

void main() {
  testWidgets('opens on the first mistake and says whose it was',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pumpAndSettle();

    // A release build paints no overflow stripes, so this is the only cheap
    // place to catch a row that outgrows the phone.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Crni je ovde odigrao Rd3'), findsOneWidget);
    expect(find.textContaining('Odigrajte na tabli potez koji drži remi'),
        findsOneWidget);
    expect(find.textContaining('Seger, Ruediger (2416)'), findsOneWidget);
    expect(find.text('Greške: 0/2'), findsOneWidget);
  });

  testWidgets('the mistake is drawn on the board, and takes itself off again',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pumpAndSettle();

    ChessBoardWithOverlay board() => tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

    // Rd3 is the move that lost the draw, so the arrow runs f3 to d3. Saying
    // "White played Rd3" is a sentence to decode; this is the same thing
    // already decoded.
    expect(board().arrows, hasLength(1));
    expect(board().arrows.single.from, 'f3');
    expect(board().arrows.single.to, 'd3');

    // And it goes away on its own, before the reader starts trying moves on
    // the squares it is drawn over.
    await tester.pump(const Duration(seconds: 5));
    expect(board().arrows, isEmpty);
  });

  testWidgets('the board takes moves while a mistake is standing on it',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pumpAndSettle();

    final board = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
    expect(board.isAllowedToMove, isTrue);
  });

  testWidgets('a move played on the board is judged', (tester) async {
    // The flag being true is not the same as the board answering a finger.
    // Everything between the two - the coordinate frame, the overlay stack, the
    // orientation - is what this walks through.
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pumpAndSettle();

    final board = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(board);
    final rect = tester.getRect(board);
    final square = widget.boardSize / 8;

    // Black is to move, so the board is turned: file h is on the left and rank
    // 1 at the top.
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    // Rb3 is one of the two moves that held.
    await tester.tapAt(at('f3'));
    await tester.pumpAndSettle();
    await tester.tapAt(at('b3'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tačno'), findsOneWidget);
  });

  testWidgets('a wrong try does not lock the board against the right one',
      (tester) async {
    // Reported from the desktop build: after one wrong move the piece lifts and
    // falls back, and the move that holds is refused too.
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
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

    // Rf8 holds nothing here.
    await tester.tapAt(at('f3'));
    await tester.pumpAndSettle();
    await tester.tapAt(at('f8'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ne drži remi'), findsOneWidget);

    // And now the one that does.
    await tester.tapAt(at('f3'));
    await tester.pumpAndSettle();
    await tester.tapAt(at('b3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tačno'), findsOneWidget);
  });

  testWidgets('a dragged piece is judged the same as a tapped one',
      (tester) async {
    // Tap-to-move and drag take different paths through the board: one goes
    // through the overlay's gesture detector, the other through the package's
    // own draggable. Only one of them was ever covered.
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
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

    final gesture = await tester.startGesture(at('f3'));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(at('b3'));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('Tačno'), findsOneWidget);
  });

  testWidgets('the strip cannot walk past an unanswered mistake',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pumpAndSettle();

    // The wall is at the opening board, so every navigation button is dead:
    // there is nothing behind the cursor and nothing open ahead of it.
    final forward = find.byIcon(Icons.chevron_right);
    expect(forward, findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.ancestor(
              of: forward,
              matching: find.byType(IconButton),
            ))
            .onPressed,
        isNull);
  });

  testWidgets(
      'a game the filters cannot match is said differently from one '
      'the server could not send', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final entry in {
      EndgameFetchOutcome.noneMatch: 'odgovara traženim uslovima',
      EndgameFetchOutcome.unavailable: 'nije moguće dobaviti',
    }.entries) {
      await tester.pumpWidget(wrap(Container(
        key: ValueKey(entry.key),
        child: screen(failing: entry.key),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining(entry.value), findsOneWidget,
          reason: 'ishod ${entry.key}');
    }
  });
}
