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

  // Rewritten 1.10.2026 (docs/PLAN-TRENER-ZAVRSNICA.md, phase 1): this case
  // sent `maxPieces: 5`, a parameter fed only by a screen field the router
  // never passed, and deleted with it. The filters are the picker's.
  test('the next position asks the route the server serves, with its filters',
      () async {
    final (api, sent) = service();
    await api.fetchNext(
      mode: EndgameMode.win,
      material: 'KRvK',
      oppositeOnly: true,
    );
    final request = sent.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/api/puzzles/endgame/next');
    expect(request.url.queryParameters, {
      'mode': 'win',
      'material': 'KRvK',
      'oppositeBishops': 'true',
    });
    expect(request.headers['Authorization'], 'Bearer tok');
  });

  test('the catalogue', () async {
    final (api, sent) = service();
    await api.fetchCatalog(mode: EndgameMode.win);
    expect(sent.single.url.path, '/api/puzzles/endgame/catalog');
    // `includeOnline` joined this request on 20.9.2026 and is sent even when
    // false. The route answers „how many are there" and `/next` answers „give
    // me one of them"; until that day only the second one knew about the
    // online base, so the picker's total was bigger than anything the drill
    // could serve. Leaving the flag out would mean the same to the server —
    // but a request that states what it counts is the one that can be read,
    // and `the next game` below has always stated it.
    expect(sent.single.url.queryParameters,
        {'mode': 'win', 'includeOnline': 'false'});
  });

  test('the catalogue, with the online base asked for', () async {
    final (api, sent) = service();
    await api.fetchCatalog(mode: EndgameMode.win, includeOnline: true);
    expect(sent.single.url.queryParameters,
        {'mode': 'win', 'includeOnline': 'true'});
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

  // docs/PLAN-TRENER-ZAVRSNICA.md, phases 2 and 4: the server's names for the
  // fields the trainer reads off a position and off a judged move. Shaped as
  // `buildEndgamePayload` and `judgeMove` write them.
  test("a position carries the picker's name for its ending", () {
    final withLabel = EndgamePuzzle.fromJson({
      'puzzle_id': 'p',
      'fen': fen,
      'mode': 'win',
      'winning_moves': ['e1e2'],
      'material': 'KRvK',
      'material_label': 'rook versus bare king',
    });
    expect(withLabel.materialLabel, 'rook versus bare king');
    final mined = EndgamePuzzle.fromJson({
      'puzzle_id': 'm',
      'fen': fen,
      'mode': 'win',
      'winning_moves': ['e1e2'],
      'material': null,
      'material_label': null,
    });
    expect(mined.materialLabel, isNull);
  });

  test('a judged move carries the move and the reply as UCI', () {
    final step = DrillStep.fromJson({
      'playedSan': 'Kd2',
      'playedUci': 'e1d2',
      'goal': 'win',
      'outcome': 'win',
      'held': true,
      'reply': {'uci': 'b2b1n', 'san': 'b1=N+'},
      'fen': '8/4P3/8/8/8/8/3K4/1n5k w - - 0 2',
    });
    expect(step.playedUci, 'e1d2');
    expect(step.replyUci, 'b2b1n');
    expect(step.replySan, 'b1=N+');
    final lost = DrillStep.fromJson({
      'playedSan': 'Ke2',
      'playedUci': 'e1e2',
      'held': false,
      'reply': null,
      'fen': fen,
    });
    expect(lost.replyUci, isNull);
  });
}
