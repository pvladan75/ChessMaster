// endgame_open_in_analysis_test.dart — docs/PLAN-TRENER-ZAVRSNICA.md, phase 5:
// `Open in Analysis` (D1, D2, D14) and the way back (D5).
//
// The door is read through `debugOpenTreeInAnalysis`, as the opening report's
// test reads its own. The way back is walked with the **real** Analysis,
// pushed by the real `openTreeInAnalysis` and left by its own back arrow: a
// stand-in pushed by the test's hook would not see the product push the
// screen another way (`pushReplacement`), which is exactly the fault the way
// back must not have. The plan named a stand-in; the real screen is the
// stronger instrument and costs nothing here.
//
// Fake the client (rule 7): the real `EndgameApiService` and
// `PuzzleAttemptApi` over `MockClient`s, and the requests are what is read.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_analysis_tree.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Black to hold the draw: Kd7, Kf7 and the underpromotion e1=N hold. Black
/// to move, so a board that faces the reader faces Black.
const _start = '4k2K/1P6/8/8/8/8/4p3/8 b - - 0 1';
const _holding = ['e2e1n', 'e8d7', 'e8f7'];

Map<String, dynamic> _payload(String id) => {
      'puzzle_id': id,
      'fen': _start,
      'type': 'KPvKP',
      'mode': 'draw',
      'winning_moves': _holding,
      'piece_count': 4,
      'pawn_count': 2,
      'source': 'blunder',
      'material': 'KPvKP',
      'material_label': 'pawn versus pawn',
      'played_move': 'Kd8',
    };

const _json = {'content-type': 'application/json; charset=utf-8'};

class _Server {
  final nextQueries = <Map<String, String>>[];
  final byIds = <String>[];
  final plays = <Map<String, dynamic>>[];
  List<String> retry = const [];

  late final endgame = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/endgame/next')) {
      nextQueries.add(request.url.queryParameters);
      return http.Response(
          jsonEncode({'endgame': _payload('eg_${nextQueries.length}')}), 200,
          headers: _json);
    }
    if (path.contains('/puzzles/by-id/')) {
      final id = path.split('/').last;
      byIds.add(id);
      return http.Response(jsonEncode({'endgame': _payload(id)}), 200,
          headers: _json);
    }
    if (path.endsWith('/endgame/play')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      plays.add(body);
      final fen = body['fen'] as String;
      final move = body['move'] as String;
      // A held answer to the puzzle gets the reply; anything else loses.
      final held = fen == _start && _holding.contains(move);
      final after = _after(fen, [move, if (held) 'b7b8n']);
      return http.Response(
          jsonEncode({
            'playedSan': move,
            'playedUci': move,
            'goal': 'draw',
            'outcome': held ? 'draw' : 'loss',
            'held': held,
            'reply': held ? {'uci': 'b7b8n', 'san': 'b8=N'} : null,
            'fen': after,
            'finished': null,
          }),
          200,
          headers: _json);
    }
    return http.Response('{}', 404);
  });

  late final attempts = MockClient((request) async {
    if (request.url.path.endsWith('/puzzles/retry')) {
      return http.Response(jsonEncode({'source': 'endgame', 'ids': retry}), 200,
          headers: _json);
    }
    return http.Response('{"success":true}', 200, headers: _json);
  });
}

String _after(String fen, List<String> ucis) {
  var node = AnalysisNode(fen: fen);
  for (final uci in ucis) {
    node = _play(node, uci);
  }
  return node.fen;
}

AnalysisNode _play(AnalysisNode from, String uci) {
  final tree = endgameAnalysisTree(EndgameTreeInput(
    fen: from.fen,
    holding: [uci],
  ));
  return tree.root.children.single;
}

UserSession _session() =>
    UserSession(token: 't', id: 1, email: 'a@b', name: 'T', role: 'k');

Future<_Server> _open(WidgetTester tester,
    {Size size = const Size(1280, 1000), bool retry = false}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server();
  if (retry) server.retry = const ['r1', 'r2', 'r3'];
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: EndgameTrainerScreen(
      session: _session(),
      mode: EndgameMode.draw,
      material: 'KPvKP,KRvKR',
      band: '1800-2199',
      oppositeOnly: true,
      retry: retry,
      api: EndgameApiService(authToken: 't', client: server.endgame),
      attemptApi: PuzzleAttemptApi(authToken: 't', client: server.attempts),
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

ChessBoardWithOverlay _board(WidgetTester tester) =>
    tester.widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

Future<void> _move(WidgetTester tester, String from, String to) async {
  Offset at(String name) {
    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final square = widget.boardSize / 8;
    final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
    final black = widget.boardOrientation == PlayerColor.black;
    return rect.topLeft +
        Offset(((black ? 7 - file : file) + 0.5) * square,
            ((black ? rank : 7 - rank) + 0.5) * square);
  }

  await tester.tapAt(at(from));
  await tester.pumpAndSettle();
  await tester.tapAt(at(to));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

const _door = 'Open in Analysis';

/// Solves with Kd7 and plays a drill to a losing move, which ends it.
Future<void> _drillToALoss(WidgetTester tester) async {
  await _tap(tester, 'Play to the end');
  await _move(tester, 'e8', 'd8');
  expect(find.text('Take back'), findsOneWidget);
}

void main() {
  group('the door', () {
    late List<(AnalysisNode, AnalysisNode, bool?)> opened;
    setUp(() {
      opened = [];
      debugOpenTreeInAnalysis = (context, root, standOn, black) async {
        opened.add((root, standOn, black));
      };
    });
    tearDown(() => debugOpenTreeInAnalysis = null);

    testWidgets('absent while solving, and while a drill runs', (tester) async {
      await _open(tester);
      expect(find.text('Save for later'), findsOneWidget);
      expect(find.text(_door), findsNothing);
      await _tap(tester, 'Play to the end');
      expect(find.text('Start over'), findsOneWidget);
      expect(find.text(_door), findsNothing);
    });

    testWidgets(
        'present when solved, when the answer is shown, and when the '
        'drill is over', (tester) async {
      await _open(tester);
      await _move(tester, 'e8', 'd7');
      expect(find.text(_door), findsOneWidget, reason: 'solved');

      await _tap(tester, 'Next');
      await _tap(tester, 'Show solution');
      expect(find.text(_door), findsOneWidget, reason: 'answer shown');

      await _drillToALoss(tester);
      expect(find.text(_door), findsOneWidget, reason: 'drill over');
    });

    testWidgets('hands over the tree the builder makes, standing on the root',
        (tester) async {
      final server = await _open(tester);
      await _move(tester, 'e8', 'd7');
      expect(server.plays, hasLength(1));
      await _tap(tester, _door);

      final (root, standOn, black) = opened.single;
      final expected = endgameAnalysisTree(EndgameTreeInput(
        fen: _start,
        found: const ['e8d7'],
        replies: const {'e8d7': 'b7b8n'},
        holding: _holding,
        gameMoveSan: 'Kd8',
      ));
      List<String?> ucis(AnalysisNode n) =>
          n.children.map((c) => c.moveUci).toList();
      expect(root.fen, _start);
      expect(ucis(root), ucis(expected.root));
      expect(ucis(root), ['e8d7', 'e2e1n', 'e8f7', 'e8d8']);
      expect(ucis(root.children.first), ['b7b8n']);
      expect(standOn, same(root));
      expect(black, isTrue);
    });

    testWidgets(
        'from a drill that ended on the reader\'s losing move: stands '
        'after it, facing the reader', (tester) async {
      await _open(tester);
      await _drillToALoss(tester);
      // White is to move after the loss; the reader played Black.
      await _tap(tester, _door);

      final (root, standOn, black) = opened.single;
      expect(standOn.moveUci, 'e8d8');
      expect(standOn.parent, same(root));
      expect(standOn.fen.split(' ')[1], 'w');
      expect(black, isTrue);
    });
  });

  group('the way back, through the real Analysis', () {
    testWidgets('1. the same position, state, chips and lock', (tester) async {
      await _open(tester);
      await _move(tester, 'e8', 'd7');
      final fen = _board(tester).controller.getFen();
      final allowed = _board(tester).isAllowedToMove;
      expect(find.text('Solved: 1/1'), findsOneWidget);
      expect(find.text('Find the rest (1/3)'), findsOneWidget);

      await _tap(tester, _door);
      expect(find.byType(AnalysisStudioScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AnalysisStudioScreen), findsNothing);
      expect(_board(tester).controller.getFen(), fen);
      expect(_board(tester).isAllowedToMove, allowed);
      expect(find.text('Solved: 1/1'), findsOneWidget);
      expect(find.text('Find the rest (1/3)'), findsOneWidget);
      expect(find.text('Solved. The draw is held.'), findsOneWidget);
    });

    testWidgets('2. Next asks for the same selection, past this position',
        (tester) async {
      final server = await _open(tester);
      await _move(tester, 'e8', 'd7');
      await _tap(tester, _door);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Next');

      expect(server.nextQueries, hasLength(2));
      expect(server.nextQueries.last,
          {...server.nextQueries.first, 'excludeId': 'eg_1'});
      expect(server.nextQueries.first, {
        'mode': 'draw',
        'material': 'KPvKP,KRvKR',
        'band': '1800-2199',
        'oppositeBishops': 'true',
      });
    });

    testWidgets('3. in a retry run, Next asks for the queue\'s next id',
        (tester) async {
      final server = await _open(tester, retry: true);
      expect(server.byIds, ['r1']);
      await _move(tester, 'e8', 'd7');
      await _tap(tester, _door);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Next');
      expect(server.byIds, ['r1', 'r2']);
    });

    testWidgets('4. N does nothing under Analysis, and works after Back',
        (tester) async {
      final server = await _open(tester);
      await _move(tester, 'e8', 'd7');
      await _tap(tester, _door);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pumpAndSettle();
      expect(server.nextQueries, hasLength(1));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pumpAndSettle();
      expect(server.nextQueries, hasLength(2));
    });

    testWidgets('5. a drill that was over is still over', (tester) async {
      await _open(tester);
      await _drillToALoss(tester);
      final said = find.textContaining('loses the draw');
      expect(said, findsOneWidget);

      await _tap(tester, _door);
      // Analysis faces the reader (Black), though White is to move where it
      // stands (D14).
      expect(
          tester
              .widget<SkinnedChessBoard>(find.byType(SkinnedChessBoard))
              .boardOrientation,
          PlayerColor.black);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.textContaining('loses the draw'), findsOneWidget);
      expect(find.text('Take back'), findsOneWidget);
      expect(_board(tester).isAllowedToMove, isFalse);
    });

    testWidgets(
        '6. on a 360 x 640 phone the pushed bar fits, back arrow and all',
        (tester) async {
      await _open(tester, size: const Size(360, 640));
      await _move(tester, 'e8', 'd7');
      await _tap(tester, _door);
      expect(tester.takeException(), isNull);

      final bar = find.descendant(
          of: find.byType(AnalysisStudioScreen), matching: find.byType(AppBar));
      final back = find.descendant(of: bar, matching: find.byType(BackButton));
      expect(back, findsOneWidget);
      final screen = Offset.zero & const Size(360, 640);
      for (final target in [
        back,
        find.descendant(of: bar, matching: find.byType(IconButton)),
        find.descendant(of: bar, matching: find.byType(TextButton)),
      ]) {
        for (final element in target.evaluate()) {
          final box = element.renderObject! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          expect(
              screen.contains(rect.topLeft) &&
                  screen.contains(rect.bottomRight - const Offset(0.01, 0.01)),
              isTrue,
              reason: '$rect is off the 360 x 640 screen');
        }
      }

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Find the rest (1/3)'), findsOneWidget);
    });
  });
}
