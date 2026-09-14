// Phase 2 of `docs/PLAN-SKELET.md`: the app's half of the masters walk.
//
// The server's reply is not written here. It is read from
// `chess_backend/test/fixtures/masters_walk_answer.json`, which the server's own
// test builds a database from and must answer exactly — so a change of shape on
// either end turns one of the two suites red.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';

final _fixture = jsonDecode(
    File('../chess_backend/test/fixtures/masters_walk_answer.json')
        .readAsStringSync()) as Map<String, dynamic>;
final _fens = (_fixture['fens'] as List).cast<String>();
final _start = _fens[0];
final _afterE4 = _fens[1];

void main() {
  test('the walk asks for at most the positions the database can know',
      () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(_fixture['answer']), 200);
    });
    final many = List.generate(80, (i) => i.isEven ? _start : _afterE4);
    await walkMastersBook(many,
        client: client, baseUrl: 'http://server', sessionToken: 'jwt');

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://server/opening-explorer/masters-walk');
    expect(sent.headers['Authorization'], 'Bearer jwt');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['fens'], hasLength(kMastersBookPlies + 1));
  });

  test('the server\'s reply is kept by position, with names from the app',
      () async {
    final client = MockClient(
        (_) async => http.Response(jsonEncode(_fixture['answer']), 200));
    final walk = await walkMastersBook(_fens,
        client: client,
        baseUrl: 'http://server',
        sessionToken: 'jwt',
        openingNameOf: (fen) => fen == _afterE4 ? "King's Pawn Game" : null);

    expect(walk.unavailable, isNull);
    expect(walk.known.keys, [_start, _afterE4]);
    expect(walk.known[_start]!.containsKey('opening'), isFalse,
        reason: 'a position the ECO data does not name gets no name');
    expect(walk.known[_afterE4]!['opening'], {'name': "King's Pawn Game"});
    expect(walk.known[_start]!.containsKey('fen'), isFalse);
  });

  test('what the server answers is what the builder reads', () async {
    final client = MockClient(
        (_) async => http.Response(jsonEncode(_fixture['answer']), 200));
    final walk = await walkMastersBook(_fens,
        client: client,
        baseUrl: 'http://server',
        sessionToken: 'jwt',
        openingNameOf: (fen) => fen == _afterE4 ? "King's Pawn Game" : null);

    final rows = <Map<String, dynamic>>[
      {
        'label': 'start',
        'fen': _start,
        'played': {'move': 'e4', 'label': '1. e4'}
      },
      {
        'label': '1. e4',
        'fen': _afterE4,
        'played': {'move': 'e5', 'label': '1... e5'}
      },
      {
        'label': '1... e5',
        'fen': _fens[2],
        'played': {'move': 'Nf3', 'label': '2. Nf3'}
      },
    ];
    expect(applyMastersBook(rows, walk.known), 2);
    expect(rows[0]['book'], {
      'games': 230,
      'played': {'move': 'e4', 'games': 130, 'share': 0.5652},
      'alternatives': [
        {'move': 'd4', 'games': 100, 'share': 0.4348}
      ],
    });
    expect((rows[1]['book'] as Map)['opening'], "King's Pawn Game");
    expect((rows[1]['book'] as Map)['played'],
        {'move': 'e5', 'games': 30, 'share': 0.4});
    expect(rows[2].containsKey('book'), isFalse);
  });

  group('a refusal is a reason, never an exception', () {
    Future<MastersWalk> walkWith(MockClient client, {String token = 'jwt'}) =>
        walkMastersBook(_fens,
            client: client, baseUrl: 'http://server', sessionToken: token);

    test('a guest asks nothing', () async {
      var asked = false;
      final walk = await walkWith(MockClient((_) async {
        asked = true;
        return http.Response('{}', 200);
      }), token: '');
      expect(asked, isFalse);
      expect(walk.unavailable, 'guest');
      expect(walk.known, isEmpty);
    });

    test('a server without the database says not-configured', () async {
      final walk = await walkWith(MockClient((_) async => http.Response(
          jsonEncode({'error': 'x', 'reason': 'not-configured'}), 503)));
      expect(walk.unavailable, 'not-configured');
      expect(walk.known, isEmpty);
    });

    test('a status with no reason is named by its code', () async {
      final walk =
          await walkWith(MockClient((_) async => http.Response('oops', 502)));
      expect(walk.unavailable, 'http-502');
    });

    test('no connection is network', () async {
      final walk = await walkWith(
          MockClient((_) async => throw const SocketException('down')));
      expect(walk.unavailable, 'network');
    });

    test('an answer that is not the walk is bad-answer', () async {
      final walk = await walkWith(
          MockClient((_) async => http.Response('{"moves": []}', 200)));
      expect(walk.unavailable, 'bad-answer');
    });
  });
}
