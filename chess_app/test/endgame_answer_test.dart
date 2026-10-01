// endgame_answer_test.dart — the gate of docs/PLAN-TRENER-ZAVRSNICA.md,
// phase 4: `Show solution` (D3), the opponent's reply from the server after a
// correct answer (D8), the engine's estimate said as one (D9), and the
// ending's name on the chip (D12, the app half).
//
// Fake the client, not the method (rule 7): the real `EndgameApiService` and
// the real `PuzzleAttemptApi`, each over a `MockClient`, so every case reads
// what was sent. `/endgame/play` answers through a queue the case releases by
// hand, so „before the reply" and „after the board moved on" are moments a
// case can stand in.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// White to keep the win: Kd2, Kf1 and the underpromotion e8=N hold.
const _start = '8/4P3/8/8/8/8/1p6/4K2k w - - 0 1';
const _afterKd2 = '8/4P3/8/8/8/8/1p1K4/7k b - - 1 1';

/// The server's answer to Kd2: the reply underpromotes, b1=N+.
const _afterReply = '8/4P3/8/8/8/8/3K4/1n5k w - - 0 2';

Map<String, dynamic> _payload({
  String id = 'eg_answer',
  List<String> winning = const ['e1d2', 'e1f1', 'e7e8n'],
  String source = 'blunder',
  int pieces = 4,
  String? materialLabel = 'pawn versus pawn',
  String type = 'KPvKP',
}) =>
    {
      'puzzle_id': id,
      'fen': _start,
      'type': type,
      'mode': 'win',
      'winning_moves': winning,
      'piece_count': pieces,
      'pawn_count': 2,
      'source': source,
      'difficulty': 'medium',
      'material': materialLabel == null ? null : 'KPvKP',
      'material_label': materialLabel,
    };

Map<String, dynamic> _played(String uci, {bool held = true}) => {
      'playedSan': uci == 'e1d2' ? 'Kd2' : 'Kf1',
      'playedUci': uci,
      'goal': 'win',
      'outcome': held ? 'win' : 'draw',
      'held': held,
      'closer': null,
      'reply': held ? {'uci': 'b2b1n', 'san': 'b1=N+'} : null,
      'fen': held ? _afterReply : _afterKd2,
      'finished': null,
    };

/// The server, as far as this screen asks it.
class _Server {
  _Server({Map<String, dynamic>? first}) : first = first ?? _payload();

  final Map<String, dynamic> first;

  final nextRequests = <http.Request>[];
  final playRequests = <http.Request>[];
  final attempts = <Map<String, dynamic>>[];
  final _held = <Completer<void>>[];

  /// Answers every `/play` at once, unless [hold] is set.
  bool hold = false;
  http.Response Function(http.Request) playAnswer = (r) => http.Response(
      jsonEncode(_played(_moveOf(r))), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});

  static String _moveOf(http.Request r) =>
      (jsonDecode(r.body) as Map<String, dynamic>)['move'] as String;

  /// Lets the oldest held `/play` answer.
  void release() => _held.removeAt(0).complete();

  int get waiting => _held.length;

  late final endgameClient = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/endgame/next')) {
      nextRequests.add(request);
      final body = nextRequests.length == 1 ? first : _payload(id: 'eg_next');
      return http.Response(jsonEncode({'endgame': body}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (path.endsWith('/endgame/play')) {
      playRequests.add(request);
      if (!hold) return playAnswer(request);
      final gate = Completer<void>();
      _held.add(gate);
      await gate.future;
      return playAnswer(request);
    }
    return http.Response('{}', 404);
  });

  late final attemptClient = MockClient((request) async {
    attempts.add(jsonDecode(request.body) as Map<String, dynamic>);
    return http.Response('{"success":true}', 200);
  });
}

/// The real service over the fake client; only the Library write is caught,
/// because it goes through `LessonApiService` and not through this client.
class _Api extends EndgameApiService {
  _Api(http.Client client) : super(authToken: 't', client: client);

  final keptTitles = <String>[];

  @override
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async {
    keptTitles.add(title);
    return true;
  }
}

UserSession _session() =>
    UserSession(token: 't', id: 1, email: 'a@b', name: 'T', role: 'k');

Future<_Api> _open(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = _Api(server.endgameClient);
  await tester.pumpWidget(MaterialApp(
    home: EndgameTrainerScreen(
      session: _session(),
      api: api,
      attemptApi:
          PuzzleAttemptApi(authToken: 't', client: server.attemptClient),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

ChessBoardWithOverlay _board(WidgetTester tester) =>
    tester.widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

String _placement(WidgetTester tester) =>
    _board(tester).controller.getFen().split(' ').first;

String _placementOf(String fen) => fen.split(' ').first;

Future<void> _play(WidgetTester tester, String from, String to) async {
  Offset at(String name) {
    final board = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(board);
    final rect = tester.getRect(board);
    final square = widget.boardSize / 8;
    final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
    final black = widget.boardOrientation == PlayerColor.black;
    final col = black ? 7 - file : file;
    final row = black ? rank : 7 - rank;
    return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
  }

  await tester.tapAt(at(from));
  await tester.pumpAndSettle();
  await tester.tapAt(at(to));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  group('1. where Show solution is offered', () {
    testWidgets('while solving, beside Hint', (tester) async {
      await _open(tester, _Server());
      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('Show solution'), findsOneWidget);
    });

    testWidgets('not after a solve — where it would be, the row is there',
        (tester) async {
      await _open(tester, _Server());
      await _play(tester, 'e1', 'd2');
      expect(find.text('Save for later'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Show solution'), findsNothing);
    });

    testWidgets('not after the answer was shown', (tester) async {
      await _open(tester, _Server());
      await _tap(tester, 'Show solution');
      expect(find.text('Save for later'), findsOneWidget);
      expect(find.text('Show solution'), findsNothing);
    });

    testWidgets('not while a drill runs', (tester) async {
      await _open(tester, _Server());
      await _tap(tester, 'Play to the end');
      expect(find.text('Start over'), findsOneWidget);
      expect(find.text('Show solution'), findsNothing);
    });
  });

  group('2. what it shows', () {
    testWidgets('every holding move, in SAN, and the board is closed',
        (tester) async {
      await _open(tester, _Server());
      await _tap(tester, 'Show solution');
      expect(find.text('These moves keep the win: Kd2, Kf1, e8=N.'),
          findsOneWidget);
      expect(_board(tester).isAllowedToMove, isFalse);
      expect(_placement(tester), _placementOf(_start));
      // The doors after a solve, without the hunt for the rest.
      expect(find.text('Play to the end'), findsOneWidget);
      expect(find.textContaining('Find the rest ('), findsNothing);
      expect(find.text('Show'), findsNothing);
    });

    testWidgets('one holding move gets the „only move" sentence',
        (tester) async {
      await _open(tester, _Server(first: _payload(winning: const ['e1d2'])));
      await _tap(tester, 'Show solution');
      expect(
          find.text('The only move that keeps the win: Kd2.'), findsOneWidget);
    });
  });

  group('3. what it records', () {
    testWidgets('one attempt, not solved, and Next adds no skip',
        (tester) async {
      final server = _Server();
      await _open(tester, server);
      await _tap(tester, 'Show solution');
      expect(server.attempts, hasLength(1));
      expect(server.attempts.single['solved'], isFalse);
      expect(server.attempts.single['skipped'], isFalse);
      expect(server.attempts.single['hinted'], isFalse);
      expect(server.attempts.single['puzzleId'], 'eg_answer');

      await _tap(tester, 'Next');
      expect(server.nextRequests, hasLength(2));
      expect(server.attempts, hasLength(1));
    });

    testWidgets('after a hint the record is hinted', (tester) async {
      final server = _Server();
      await _open(tester, server);
      await _tap(tester, 'Hint');
      await _tap(tester, 'Show solution');
      expect(server.attempts, hasLength(1));
      expect(server.attempts.single['hinted'], isTrue);
    });

    testWidgets('after a wrong move there is still one record', (tester) async {
      final server = _Server();
      await _open(tester, server);
      await _play(tester, 'e1', 'e2');
      expect(
          find.text('That move drops the win. Try another.'), findsOneWidget);
      await _tap(tester, 'Show solution');
      expect(server.attempts, hasLength(1));
      expect(server.attempts.single['solved'], isFalse);
    });
  });

  group('4. the reply comes from the server', () {
    testWidgets(
        'the verdict first, the reader\'s move on the board, then the '
        'server\'s position; a second found move asks again', (tester) async {
      final server = _Server()..hold = true;
      await _open(tester, server);

      await _play(tester, 'e1', 'd2');
      expect(server.playRequests, hasLength(1));
      expect(server.playRequests.single.url.path, '/api/puzzles/endgame/play');
      expect(
          _bodyOf(server.playRequests.single), {'fen': _start, 'move': 'e1d2'});
      // Before the reply: said, and the board shows the reader's move.
      expect(find.textContaining('Correct — win kept.'), findsOneWidget);
      expect(_placement(tester), _placementOf(_afterKd2));

      server.release();
      await tester.pumpAndSettle();
      expect(_placement(tester), _placementOf(_afterReply),
          reason: 'the board takes the server\'s position, knight and all');

      await tester.tap(find.text('Find the rest (1/3)'));
      await tester.pumpAndSettle();
      await _play(tester, 'e1', 'f1');
      expect(server.playRequests, hasLength(2));
      expect(
          _bodyOf(server.playRequests.last), {'fen': _start, 'move': 'e1f1'});
      server.release();
      await tester.pumpAndSettle();
    });

    testWidgets('4b. held: false — the verdict stands, nothing is played',
        (tester) async {
      final server = _Server()
        ..playAnswer = (r) => http.Response(
            jsonEncode(_played('e1d2', held: false)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      await _open(tester, server);

      await _play(tester, 'e1', 'd2');
      await tester.pumpAndSettle();
      expect(server.playRequests, hasLength(1));
      expect(find.textContaining('Correct — win kept.'), findsOneWidget);
      expect(_placement(tester), _placementOf(_afterKd2));
      expect(find.textContaining('lets the win go'), findsNothing);
      expect(find.textContaining('drops the win'), findsNothing);
    });
  });

  group('5–6. an engine position says so', () {
    testWidgets('5. engine: no request, the chip, the engine\'s sentence',
        (tester) async {
      final server = _Server(first: _payload(source: 'engine', pieces: 10));
      await _open(tester, server);
      expect(find.text('Engine estimate'), findsOneWidget);
      expect(find.text('Exact from tablebases'), findsNothing);

      await _play(tester, 'e1', 'e2');
      expect(
          find.text('The engine judges that this move drops the win. '
              'Try another.'),
          findsOneWidget);

      await _play(tester, 'e1', 'd2');
      expect(find.textContaining('Correct — win kept.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(server.playRequests, isEmpty);
    });

    testWidgets('6. exact: no estimate, and the tablebase\'s sentence',
        (tester) async {
      await _open(tester, _Server());
      expect(find.text('Exact from tablebases'), findsOneWidget);
      expect(find.text('Engine estimate'), findsNothing);
      await _play(tester, 'e1', 'e2');
      expect(
          find.text('That move drops the win. Try another.'), findsOneWidget);
    });
  });

  group('7. a late reply never reaches a board that has moved on', () {
    testWidgets('after Find the rest', (tester) async {
      final server = _Server()..hold = true;
      await _open(tester, server);
      await _play(tester, 'e1', 'd2');
      await tester.tap(find.text('Find the rest (1/3)'));
      await tester.pumpAndSettle();
      expect(_placement(tester), _placementOf(_start));

      server.release();
      await tester.pumpAndSettle();
      expect(_placement(tester), _placementOf(_start));
    });

    testWidgets('after Next', (tester) async {
      final server = _Server()..hold = true;
      await _open(tester, server);
      await _play(tester, 'e1', 'd2');
      await _tap(tester, 'Next');
      expect(server.nextRequests, hasLength(2));
      expect(_placement(tester), _placementOf(_start));

      server.release();
      await tester.pumpAndSettle();
      expect(_placement(tester), _placementOf(_start));
    });
  });

  testWidgets('8. a 503 costs only the reply', (tester) async {
    final server = _Server()
      ..playAnswer = (r) => http.Response('{"error":"down"}', 503);
    await _open(tester, server);
    await _play(tester, 'e1', 'd2');
    await tester.pumpAndSettle();
    expect(server.playRequests, hasLength(1));
    expect(find.textContaining('Correct — win kept.'), findsOneWidget);
    expect(_placement(tester), _placementOf(_afterKd2));
    expect(find.textContaining('Tablebase is currently unavailable'),
        findsNothing);
    expect(find.text('down'), findsNothing);
  });

  group('10. the ending\'s name', () {
    testWidgets('the picker\'s words on the chip and in the kept title',
        (tester) async {
      final api = await _open(
          tester,
          _Server(
              first: _payload(
                  materialLabel: 'rook and pawn versus rook', type: 'KRPvKR')));
      expect(find.text('Rook and pawn versus rook'), findsOneWidget);
      await _tap(tester, 'Save for later');
      expect(api.keptTitles, ['Rook and pawn versus rook — unclear']);
    });

    testWidgets('no label: the mined category\'s name, both places',
        (tester) async {
      final api = await _open(
          tester,
          _Server(
              first: _payload(materialLabel: null, type: 'RookPawnVsRook')));
      expect(find.text('Rook and pawn vs rook'), findsOneWidget);
      await _tap(tester, 'Save for later');
      expect(api.keptTitles, ['Rook and pawn vs rook — unclear']);
    });
  });
}
