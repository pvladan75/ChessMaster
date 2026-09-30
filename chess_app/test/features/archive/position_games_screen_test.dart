// The games that reached a position of the opening report (the owner,
// 30.9.2026), each openable in Analysis standing on that position.
//
// Real Roboto: the cards have a fixed height, and only real glyphs say
// whether three lines and a door fit in it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/screens/position_games_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';

import '../../support/landscape.dart' show loadRoboto;

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterNf3 = 'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -';

class _Api extends Fake implements ArchiveApiService {
  PositionGames games = const PositionGames(total: 0, games: []);
  Object? refusal;
  final asked = <({String subject, String? color, String fenKey})>[];
  final movesAsked = <String>[];

  @override
  Future<PositionGames> getPositionGames(
      {required String subject, String? color, required String fenKey}) async {
    asked.add((subject: subject, color: color, fenKey: fenKey));
    if (refusal != null) throw refusal!;
    return games;
  }

  @override
  Future<({String startFen, List<String> uciMoves, String? subjectColor})>
      fetchGameMoves(String gameId) async {
    movesAsked.add(gameId);
    return (
      startFen: _start,
      uciMoves: const ['e2e4', 'c7c5', 'g1f3', 'b8c6', 'd2d4'],
      subjectColor: 'b',
    );
  }
}

PositionGame _game(String id, String san, double score,
        {bool own = true, String? opponent = 'someone', int ply = 4}) =>
    PositionGame(
      id: id,
      playedAt: DateTime(2026, 9, 1, 12),
      opponent: opponent,
      opponentElo: 1810,
      result: score == 1
          ? '0-1'
          : score == 0
              ? '1-0'
              : '1/2-1/2',
      score: score,
      speed: 'blitz',
      timeControl: '180+2',
      own: own,
      san: san,
      ply: ply,
    );

void main() {
  late _Api api;
  final opened = <AnalysisGame>[];

  setUpAll(loadRoboto);

  setUp(() {
    api = _Api();
    ArchiveApiService.setMock(api);
    opened.clear();
    debugOpenGameInAnalysis = (context, game) async => opened.add(game);
  });
  tearDown(() => debugOpenGameInAnalysis = null);

  Future<void> pump(WidgetTester tester, Size size, {String? move}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: PositionGamesScreen(
        subject: 'me',
        color: 'b',
        fenKey: _afterNf3,
        fen: '$_afterNf3 0 1',
        move: move,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder card(String id) => find.byKey(ValueKey('position-game-$id'));

  for (final size in const [Size(360, 640), Size(1280, 800)]) {
    testWidgets(
        'every game says how it ended, when, against whom and what was '
        'played, in a card that holds it, on $size', (tester) async {
      api.games = PositionGames(total: 3, games: [
        _game('1', 'd6', 1),
        _game('2', 'Nc6', 0,
            opponent: 'a-very-long-opponent-handle-that-does-not-fit-anywhere'),
        _game('3', 'd6', 0.5),
      ]);
      await pump(tester, size);

      expect(api.asked.single, (subject: 'me', color: 'b', fenKey: _afterNf3));
      expect(find.text('3 games reached this position'), findsOneWidget);
      expect(find.text('Black to move'), findsOneWidget);
      for (final (id, words) in [('1', 'Won'), ('2', 'Lost'), ('3', 'Drew')]) {
        expect(find.descendant(of: card(id), matching: find.text(words)),
            findsOneWidget);
      }
      expect(
          find.descendant(
              of: card('1'), matching: find.text('vs someone (1810)')),
          findsOneWidget);
      expect(
          find.descendant(
              of: card('2'),
              matching: find.text('Played 2... Nc6 · blitz 180+2')),
          findsOneWidget);
      expect(find.descendant(of: card('1'), matching: find.text(' · 1.9.2026')),
          findsOneWidget);
      // Nothing overflows the fixed card height in real glyphs.
      expect(tester.takeException(), isNull);
      final door = find.byKey(const ValueKey('position-game-open-2'));
      expect(tester.getRect(door).bottom,
          lessThanOrEqualTo(tester.getRect(card('2')).bottom));
    });
  }

  testWidgets(
      'the moves played there filter the list, and a habit opens '
      'filtered to itself', (tester) async {
    api.games = PositionGames(total: 3, games: [
      _game('1', 'd6', 1),
      _game('2', 'Nc6', 0),
      _game('3', 'd6', 0),
    ]);
    await pump(tester, const Size(1280, 800), move: 'Nc6');

    expect(card('2'), findsOneWidget);
    expect(card('1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('position-games-move-d6')));
    await tester.pumpAndSettle();
    expect(card('1'), findsOneWidget);
    expect(card('3'), findsOneWidget);
    expect(card('2'), findsNothing);
    expect(find.text('d6 (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('position-games-all')));
    await tester.pumpAndSettle();
    for (final id in ['1', '2', '3']) {
      expect(card(id), findsOneWidget);
    }
  });

  testWidgets(
      'a game opens whole in Analysis standing on the position, from the '
      'player\'s side', (tester) async {
    api.games = PositionGames(total: 1, games: [_game('7', 'Nc6', 0, ply: 4)]);
    await pump(tester, const Size(1280, 800));

    await tester.tap(find.byKey(const ValueKey('position-game-open-7')));
    await tester.pumpAndSettle();
    expect(api.movesAsked, ['7']);
    expect(opened, hasLength(1));
    expect(opened.single.uciMoves, hasLength(5), reason: 'the whole game');
    expect(opened.single.cursorPly, 3,
        reason: 'ply 4 is the move played here, so three moves are behind');
    expect(opened.single.blackOrientation, isTrue);
  });

  testWidgets('Back from a game returns to the list as it was left',
      (tester) async {
    debugOpenGameInAnalysis = (context, game) async {
      opened.add(game);
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(key: Key('fake-analysis')),
      ));
    };
    api.games = PositionGames(total: 2, games: [
      _game('1', 'd6', 1),
      _game('2', 'Nc6', 0),
    ]);
    await pump(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const ValueKey('position-games-move-Nc6')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('position-game-open-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-analysis')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('fake-analysis')))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(PositionGamesScreen), findsOneWidget);
    expect(api.asked, hasLength(1), reason: 'nothing is asked again');
    expect(card('1'), findsNothing, reason: 'the filter is where it was');
    expect(card('2'), findsOneWidget);
  });

  testWidgets(
      'a longer list says it shows the latest, and another player\'s games '
      'have no door', (tester) async {
    api.games = PositionGames(total: 540, games: [
      _game('1', 'd6', 1, own: false),
      _game('2', 'd6', 0, own: false),
    ]);
    await pump(tester, const Size(1280, 800));

    expect(find.text('Showing the latest 2 of 540.'), findsOneWidget);
    expect(find.textContaining('only your own games open in Analysis'),
        findsOneWidget);
    expect(card('1'), findsOneWidget);
    expect(find.text('Open in Analysis'), findsNothing);
  });

  testWidgets('no game, and a server that refuses, are said in words',
      (tester) async {
    await pump(tester, const Size(360, 640));
    expect(
        find.text('No game of yours reached this position.'), findsOneWidget);

    api.refusal = Exception('The games of this position could not be loaded.');
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester, const Size(360, 640));
    expect(find.text('The games of this position could not be loaded.'),
        findsOneWidget);
  });
}
