// The wire of docs/PLAN-NAPREDAK-VEZBI.md, from the app's side.
//
// Fake the client, assert the request (rule 7): every test reads what the
// app sent — path, method, body — not what a stub answered. Mutations tried
// when written (17.9.2026): mates sent to /attempt → "a mate goes to
// /submit"; `source` dropped from the body → "an endgame goes to /attempt";
// `skipped` written as false → "a skip is a skip"; a 500 answered true →
// "a refusal is not a success".

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';

void main() {
  final sent = <http.Request>[];
  setUp(sent.clear);

  PuzzleAttemptApi api({int status = 200, String body = '{"success":true}'}) =>
      PuzzleAttemptApi(
        authToken: 'tok',
        client: MockClient((request) async {
          sent.add(request);
          return http.Response(body, status);
        }),
      );

  Map<String, dynamic> bodyOf(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  test('the sources are the server\'s, and four of them can be retried', () {
    expect(PuzzleSource.all, [
      'lichess',
      'mate_puzzle',
      'winning_position',
      'endgame',
      'blunder_game',
      'basic_mate',
    ]);
    expect(PuzzleSource.retryable,
        ['lichess', 'mate_puzzle', 'winning_position', 'endgame']);
    expect(PuzzleSource.basicMateId('easy', '8/8/8/8/8/8/8/K6k w - - 0 1'),
        'basic:easy:8/8/8/8/8/8/8/K6k w - -');
    expect(PuzzleSource.blunderGameId('42', 17), '42:17');
    expect(PuzzleSource.blunderGameId('bg_test', 3), 'bg_test:3');
  });

  test('a mate goes to /submit with its outcome and no source', () async {
    final ok = await api().record(
        source: PuzzleSource.matePuzzle,
        puzzleId: 'm2-1',
        solved: true,
        hinted: true);
    expect(ok, isTrue);
    expect(sent.single.method, 'POST');
    expect(sent.single.url.path, endsWith('/api/puzzles/submit'));
    expect(sent.single.headers['Authorization'], 'Bearer tok');
    expect(bodyOf(sent.single), {
      'puzzleId': 'm2-1',
      'solved': true,
      'skipped': false,
      'hinted': true,
    });
  });

  test('a winning position goes to /submit too', () async {
    await api().record(
        source: PuzzleSource.winningPosition, puzzleId: 'w-7', solved: false);
    expect(sent.single.url.path, endsWith('/api/puzzles/submit'));
    expect(bodyOf(sent.single)['solved'], false);
  });

  test('an endgame goes to /attempt with its source', () async {
    await api().record(
        source: PuzzleSource.endgame,
        puzzleId: 'eg-91',
        solved: true,
        msTaken: 900);
    expect(sent.single.url.path, endsWith('/api/puzzles/attempt'));
    expect(bodyOf(sent.single), {
      'puzzleId': 'eg-91',
      'solved': true,
      'skipped': false,
      'hinted': false,
      'source': 'endgame',
      'msTaken': 900,
    });
  });

  test('a skip is a skip', () async {
    await api().record(
        source: PuzzleSource.basicMate,
        puzzleId: 'basic:easy:x',
        solved: false,
        skipped: true);
    final body = bodyOf(sent.single);
    expect(body['skipped'], true);
    expect(body['solved'], false);
    expect(body['source'], 'basic_mate');
  });

  test('a source the plan does not name is refused before any request',
      () async {
    expect(() => api().record(source: 'tactics', puzzleId: 'x', solved: true),
        throwsArgumentError);
    expect(sent, isEmpty);
  });

  test('a refusal is not a success, and a dead server does not throw',
      () async {
    expect(
        await api(status: 500)
            .record(source: PuzzleSource.endgame, puzzleId: 'eg', solved: true),
        isFalse);
    final dead = PuzzleAttemptApi(
        authToken: 'tok',
        client: MockClient((_) async => throw Exception('down')));
    expect(
        await dead.record(
            source: PuzzleSource.endgame, puzzleId: 'eg', solved: true),
        isFalse);
  });

  test('progress is read from /progress and folded per source', () async {
    final a = api(
        body: jsonEncode({
      'mate_puzzle': {
        'seen': 61,
        'solved': 48,
        'firstTry': 40,
        'failed': 9,
        'skipped': 4,
        'toRetry': 13,
        'buckets': {
          '2': {
            'seen': 30,
            'solved': 25,
            'firstTry': 20,
            'failed': 3,
            'skipped': 2,
            'toRetry': 5
          }
        },
      },
      'endgame': {
        'seen': 3,
        'solved': 1,
        'firstTry': 1,
        'failed': 2,
        'skipped': 0,
        'toRetry': 2
      },
    }));
    final progress = await a.progress();
    expect(sent.single.method, 'GET');
    expect(sent.single.url.path, endsWith('/api/puzzles/progress'));
    expect(progress!.keys.toSet(), {'mate_puzzle', 'endgame'});
    expect(progress['mate_puzzle']!.solved, 48);
    expect(progress['mate_puzzle']!.toRetry, 13);
    expect(progress['mate_puzzle']!.buckets['2']!.toRetry, 5);
    expect(progress['endgame']!.seen, 3);
    expect(progress.containsKey('lichess'), isFalse,
        reason: 'a source with nothing seen is absent, not zero');
  });

  test('a progress the server could not give is null, not empty', () async {
    expect(await api(status: 503).progress(), isNull);
  });

  test('retry ids ask for one source and come back in order', () async {
    final ids = await api(body: '{"source":"endgame","ids":["late","early"]}')
        .retryIds(PuzzleSource.endgame);
    expect(sent.single.url.path, endsWith('/api/puzzles/retry'));
    expect(sent.single.url.queryParameters, {'source': 'endgame'});
    expect(ids, ['late', 'early']);
  });

  test('a source with no retry queue is refused before any request', () async {
    expect(() => api().retryIds(PuzzleSource.basicMate), throwsArgumentError);
    expect(sent, isEmpty);
  });
}
