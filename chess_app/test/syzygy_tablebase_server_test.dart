// The app asks the server for a tablebase answer, and Lichess only when the
// server cannot be reached — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1t.
//
// The server answers five men or fewer from the owner's own tables and the
// rest from Lichess, paced and cached for everybody. So a signed-in device asks
// `GET /api/tablebase`; it goes to `tablebase.lichess.ovh` itself only with no
// sign-in, no network, or a server without the route (401, 404). A server that
// was reached and could not answer (503) is an answer — null — and Lichess is
// not asked behind its back. Asserted on the client seam (rule 7).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';

const _fen = '8/8/5k2/p7/P1K5/2N5/8/8 b - - 0 52';

const _answer = {
  'category': 'loss',
  'dtz': -4,
  'checkmate': false,
  'stalemate': false,
  'insufficient_material': false,
  'moves': [
    {
      'uci': 'f6e5',
      'san': 'Ke5',
      'category': 'win',
      'dtz': 3,
      'zeroing': false,
      'checkmate': false,
      'stalemate': false,
    },
  ],
};

/// Every request kept; the server's replies by [server], Lichess's always the
/// answer.
({MockClient client, List<http.Request> seen}) _net(
  Future<http.Response> Function(http.Request request) server,
) {
  final seen = <http.Request>[];
  return (
    client: MockClient((request) async {
      seen.add(request);
      if (request.url.host == 'server.test') return server(request);
      return http.Response(jsonEncode(_answer), 200);
    }),
    seen: seen,
  );
}

List<String> _hosts(List<http.Request> seen) => [
      for (final r in seen) r.url.host == 'server.test' ? 'server' : r.url.host,
    ];

SyzygyTablebaseService _service(http.Client client, {String token = 'tok'}) =>
    SyzygyTablebaseService.forTesting(
      client: client,
      token: token,
      sleep: (_) async {},
    );

void main() {
  test('signed in, the server is asked, with the account, and Lichess is not',
      () async {
    final net = _net((_) async => http.Response(jsonEncode(_answer), 200));
    final tb = _service(net.client);
    final result = await tb.lookup(_fen);

    expect(_hosts(net.seen), ['server']);
    final request = net.seen.single;
    expect(request.url.path, '/api/tablebase');
    expect(request.url.queryParameters['fen'], _fen);
    expect(request.headers['Authorization'], 'Bearer tok');
    expect(result!.category, SyzygyCategory.loss);
    expect(result.moves.single.uci, 'f6e5');

    await tb.lookup(_fen);
    expect(net.seen, hasLength(1), reason: 'an answer is kept');
  });

  test('a server that cannot be reached sends the question to Lichess',
      () async {
    final net = _net((_) async => throw const SocketException('down'));
    final result = await _service(net.client).lookup(_fen);
    expect(_hosts(net.seen), ['server', 'tablebase.lichess.ovh']);
    expect(result!.category, SyzygyCategory.loss);
  });

  for (final status in [401, 404]) {
    test('a server without the route ($status) sends it to Lichess', () async {
      final net = _net((_) async => http.Response('{}', status));
      final result = await _service(net.client).lookup(_fen);
      expect(_hosts(net.seen), ['server', 'tablebase.lichess.ovh']);
      expect(result, isNotNull);
    });
  }

  test(
      'a server that answers „unavailable" is an answer: null, and Lichess '
      'is not asked', () async {
    final net = _net((_) async => http.Response(
        jsonEncode({'error': 'Lichess is blocked', 'reason': 'rate-limited'}),
        503));
    final tb = _service(net.client);
    expect(await tb.lookup(_fen), isNull);
    expect(_hosts(net.seen), ['server']);
    await tb.lookup(_fen);
    expect(_hosts(net.seen), ['server', 'server'],
        reason: 'no answer is not kept as one');
  });

  test('with no sign-in the server is never asked', () async {
    final net = _net((_) async => http.Response(jsonEncode(_answer), 200));
    final result = await _service(net.client, token: '').lookup(_fen);
    expect(_hosts(net.seen), ['tablebase.lichess.ovh']);
    expect(result, isNotNull);
  });
}
