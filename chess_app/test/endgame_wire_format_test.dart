import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';

/// What the endgame trainer actually sends.
///
/// Found by the architecture audit on 16.9.2026 (`docs/audit/tests.md`, 8).
/// Every endgame test subclassed `EndgameApiService` and overrode its methods,
/// which proves the screen and nothing about the wire: a path, a query parameter
/// or a body field could change on either end with both suites green, and a
/// student would find out on the board. This fakes the client and reads the
/// requests — rule 7 in `CLAUDE.md`. The server half is
/// `chess_backend/test/endgame_routes_auth.test.js`.
void main() {
  const fen = '8/8/8/4k3/8/8/4K3/4R3 w - - 0 1';

  (EndgameApiService, List<http.Request>) service() {
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      return http.Response('{}', 500);
    });
    return (EndgameApiService(authToken: 'tok', client: client), sent);
  }

  test('the next position asks the route the server serves, with its filters',
      () async {
    final (api, sent) = service();
    await api.fetchNext(
      mode: EndgameMode.win,
      maxPieces: 5,
      material: 'KRvK',
      oppositeOnly: true,
    );
    final request = sent.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/api/puzzles/endgame/next');
    expect(request.url.queryParameters, {
      'mode': 'win',
      'maxPieces': '5',
      'material': 'KRvK',
      'oppositeBishops': 'true',
    });
    expect(request.headers['Authorization'], 'Bearer tok');
  });

  test('the catalogue', () async {
    final (api, sent) = service();
    await api.fetchCatalog(mode: EndgameMode.win);
    expect(sent.single.url.path, '/api/puzzles/endgame/catalog');
    expect(sent.single.url.queryParameters, {'mode': 'win'});
  });

  test('the next game', () async {
    final (api, sent) = service();
    await api.fetchNextGame(minBlunders: 1, includeOnline: true);
    expect(sent.single.url.path, '/api/puzzles/endgame/game/next');
    expect(sent.single.url.queryParameters,
        {'minBlunders': '1', 'includeOnline': 'true'});
  });

  test('the best line', () async {
    final (api, sent) = service();
    await api.fetchBestLine(fen: fen, plies: 6);
    expect(sent.single.url.path, '/api/puzzles/endgame/line');
    expect(sent.single.url.queryParameters, {'fen': fen, 'plies': '6'});
  });

  test('the readout', () async {
    final (api, sent) = service();
    await api.fetchReadout(fen: fen, goal: EndgameMode.win);
    expect(sent.single.url.path, '/api/puzzles/endgame/probe');
    expect(sent.single.url.queryParameters, {'fen': fen, 'goal': 'win'});
  });

  test('a drill move is judged by the server, sent as a body', () async {
    final (api, sent) = service();
    await api.judgeDrillMove(fen: fen, move: 'Ra1');
    final request = sent.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/puzzles/endgame/play');
    expect(jsonDecode(request.body), {'fen': fen, 'move': 'Ra1'});
  });
}
