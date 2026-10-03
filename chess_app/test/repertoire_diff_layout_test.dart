// The gate of phase 10 of docs/PLAN-EKRANI.md: the repertoire comparison as
// the owner chose from `docs/skice/ekrani/compare_diff.png` — on a window the
// deviations a list one glance wide and the chosen one's position drawn on a
// board beside it (pattern B, rule R7), with two doors to screens that already
// exist. Every row already carries its FEN, so the pane asks the server for
// nothing: the gate counts the requests (the Repertoire pane's lesson of
// 21.9.2026). On a phone a tap shows the position.
//
// The app's own theme with real Roboto, as phase 1 taught.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/position_games_screen.dart';
import 'package:chess_app/features/archive/screens/repertoire_diff_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'features/archive/repertoire_diff_screen_test.dart'
    show FakeArchiveApiService;
import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _phone = Size(360, 640);

/// After 3...Bc5 in the Italian, and after 2...Nc6 — two real positions, so a
/// board drawn for one is not the board of the other.
const _italian =
    'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';
const _afterNc6 =
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';

class _Api extends FakeArchiveApiService {
  int diffs = 0;

  @override
  Future<RepertoireDiff> getRepertoireDiff(
      {required String username, String? color, int? limit}) async {
    diffs++;
    return RepertoireDiff(
      subject: username,
      color: color ?? 'white',
      coveredGames: 214,
      followedGames: 158,
      leftGames: 56,
      positions: [
        RepertoireDiffPosition(
          fenKey: 'k1',
          fen: _italian,
          ply: 6,
          color: 'white',
          games: 17,
          prepared: [RepertoireDiffMove(san: 'O-O', games: 0)],
          played: [
            RepertoireDiffMove(san: 'c3', games: 12),
            RepertoireDiffMove(san: 'd3', games: 5),
          ],
          leftGames: 17,
        ),
        RepertoireDiffPosition(
          fenKey: 'k2',
          fen: _afterNc6,
          ply: 4,
          color: 'white',
          games: 11,
          prepared: [RepertoireDiffMove(san: 'Bb5', games: 0)],
          played: [RepertoireDiffMove(san: 'Bc4', games: 9)],
          leftGames: 11,
        ),
      ],
    );
  }
}

Future<_Api> _pump(WidgetTester tester, Size size) async {
  final api = _Api();
  ArchiveApiService.setMock(api);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: RepertoireDiffScreen(key: UniqueKey(), subject: 'pvladan'),
  ));
  await tester.pumpAndSettle();
  return api;
}

Finder _button<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

/// The FEN the one board on screen draws.
String _boardFen(WidgetTester tester) {
  final boards = find.byType(BoardThumbnail);
  expect(boards, findsOneWidget, reason: 'one board: the chosen position');
  return tester.widget<BoardThumbnail>(boards).fen;
}

void main() {
  setUpAll(loadRoboto);

  testWidgets(
      'on a window: the first deviation is drawn beside the list, with its '
      'two doors', (tester) async {
    final api = await _pump(tester, _window);
    expect(tester.takeException(), isNull);
    expect(_boardFen(tester), _italian);
    final row = tester.getRect(find.text('O-O').first);
    final board = tester.getRect(find.byType(BoardThumbnail));
    expect(board.left, greaterThan(row.right),
        reason: 'the position stands beside the list (pattern B)');
    expect(board.width, closeTo(board.height, 0.01));
    expectOnScreen(tester, _window, find.byType(BoardThumbnail));
    expect(_button<TextButton>('Open in Analysis'), findsOneWidget);
    expect(_button<TextButton>('Games through this position'), findsOneWidget);
    expect(api.diffs, 1, reason: 'the pane asked for nothing');
  });

  testWidgets(
      'choosing another deviation draws its position, and asks the server '
      'nothing', (tester) async {
    final api = await _pump(tester, _window);
    await tester.tap(find.text('Bb5').first);
    await tester.pumpAndSettle();
    expect(_boardFen(tester), _afterNc6);
    expect(api.diffs, 1);
  });

  testWidgets('on a 360 dp phone: a tap shows the position, nothing overflows',
      (tester) async {
    await _pump(tester, _phone);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Bb5').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_boardFen(tester), _afterNc6);
  });

  // Grading, 3.10.2026: the worker's report said no test tapped the doors.
  group('the two doors open the chosen position', () {
    Future<void> pumpRouted(WidgetTester tester) async {
      ArchiveApiService.setMock(_Api());
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const RepertoireDiffScreen(subject: 'pvladan')),
        GoRoute(
            path: AppRoutes.analysis,
            builder: (_, state) => Scaffold(
                body: Text('analysis ${state.uri.queryParameters['fen']}'))),
      ]);
      await tester.pumpWidget(MaterialApp.router(
          theme: robotoTheme(AppTheme.dark), routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('Open in Analysis opens Analysis on the chosen position',
        (tester) async {
      await pumpRouted(tester);
      await tester.tap(find.text('Bb5').first);
      await tester.pumpAndSettle();
      await tester.tap(_button<TextButton>('Open in Analysis'));
      await tester.pumpAndSettle();
      expect(find.text('analysis $_afterNc6'), findsOneWidget);
    });

    testWidgets('Games through this position opens that position, for White',
        (tester) async {
      await pumpRouted(tester);
      await tester.tap(_button<TextButton>('Games through this position'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final games =
          tester.widget<PositionGamesScreen>(find.byType(PositionGamesScreen));
      expect(games.fenKey, 'k1');
      expect(games.fen, _italian);
      expect(games.color, 'w');
    });
  });
}
