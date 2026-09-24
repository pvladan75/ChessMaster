// What `ArchiveApiService` actually sends for §9.3 of
// `docs/PLAN-MOJE-PARTIJE.md` — the nodes the device judges, and the
// judgements it sends back. Faked at the client, not the method (rule 7 in
// `CLAUDE.md`): a fake that replaces `getOpeningNodes`/`sendJudgements`
// outright cannot see the path, the query parameters or the body go wrong.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';

void main() {
  (ArchiveApiService, List<http.Request>) service(
      http.Response Function(http.Request) answer) {
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      return answer(request);
    });
    return (ArchiveApiService.withClient(client), sent);
  }

  group('getOpeningNodes', () {
    test('asks the route with the subject and color as query parameters',
        () async {
      final (api, sent) = service((_) => http.Response(
            jsonEncode({
              'subject': 'ana',
              'color': 'w',
              'window': {'fromPly': 6, 'toPly': 20},
              'minGames': 8,
              'book': {'available': true},
              'nodes': [],
            }),
            200,
          ));
      final report = await api.getOpeningNodes(subject: 'ana', color: 'white');
      final request = sent.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/games/openings/nodes');
      expect(request.url.queryParameters, {'subject': 'ana', 'color': 'w'});
      expect(report.subject, 'ana');
      expect(report.fromPly, 6);
      expect(report.toPly, 20);
      expect(report.book.available, isTrue);
    });

    test('a color left out is left out of the request', () async {
      final (api, sent) = service((_) => http.Response(
            jsonEncode({
              'subject': 'ana',
              'window': {'fromPly': 6, 'toPly': 20},
              'minGames': 8,
              'book': {'available': false, 'reason': 'no-token'},
              'nodes': [],
            }),
            200,
          ));
      final report = await api.getOpeningNodes(subject: 'ana');
      expect(sent.single.url.queryParameters, {'subject': 'ana'});
      expect(report.book.available, isFalse);
      expect(report.book.reason, 'no-token');
    });

    test('reads a node with a habit move and its judgement', () async {
      final (api, _) = service((_) => http.Response(
            jsonEncode({
              'subject': 'ana',
              'window': {'fromPly': 6, 'toPly': 20},
              'minGames': 8,
              'book': {'available': true},
              'nodes': [
                {
                  'fenKey':
                      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -',
                  'fen':
                      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
                  'ply': 2,
                  'games': 40,
                  'score': 0.4,
                  'moves': [
                    {
                      'san': 'Nc6',
                      'uci': 'b8c6',
                      'games': 12,
                      'score': 0.2,
                      'share': 0.3,
                      'habit': true,
                      'bookGames': 30,
                      'judgement': {
                        'verdict': 'mistake',
                        'reason': 'lostChances',
                        'lostChances': 15.0,
                        'bestUci': 'g8f6',
                        'bestSan': 'Nf6',
                        'bestLine': ['Nf6'],
                        'moveLine': ['Nc6'],
                        'bookGames': 30,
                        'depth': 20,
                        'engine': 'sf19-123',
                      },
                    },
                  ],
                },
              ],
            }),
            200,
          ));
      final report = await api.getOpeningNodes(subject: 'ana');
      final move = report.nodes.single.moves.single;
      expect(move.habit, isTrue);
      expect(move.uci, 'b8c6');
      expect(move.bookGames, 30);
      expect(move.judgement!.isMistake, isTrue);
      expect(move.judgement!.bestSan, 'Nf6');
    });
  });

  group('sendJudgements', () {
    test('posts the judgements as a JSON body and reads back the tally',
        () async {
      final (api, sent) = service((_) => http.Response(
            jsonEncode({
              'read': 1,
              'stored': 1,
              'replaced': 0,
              'kept_deeper': 0,
              'rejected': 0,
              'rejected_by_reason': {},
            }),
            200,
          ));
      final items = [
        {
          'fenKey': 'fen b - -',
          'moveUci': 'b8c6',
          'wBest': 60.0,
          'wMove': 45.0,
          'bestUci': 'g8f6',
          'bestLine': ['Nf6'],
          'moveLine': ['Nc6'],
          'verdict': 'mistake',
          'reason': 'lostChances',
          'bookGames': 30,
          'engine': 'sf19-123',
          'depth': 20,
        },
      ];
      final tally = await api.sendJudgements(items);
      final request = sent.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/games/openings/judgements');
      expect(request.headers['Content-Type'], 'application/json');
      expect(jsonDecode(request.body), {'judgements': items});
      expect(tally.read, 1);
      expect(tally.stored, 1);
    });
  });

  group('drillLosingHabits (§9.4)', () {
    test('posts the subject and the wire colour, and reads back the answer',
        () async {
      final (api, sent) = service((_) => http.Response(
            jsonEncode({
              'habits': 3,
              'alreadyInDrill': 1,
              'withoutLoss': 0,
              'read': 2,
              'stored': 2,
              'duplicate': 0,
              'rejected': 0,
              'rejected_by_reason': {},
            }),
            200,
          ));
      // The screen may hold „white"; the server takes only a letter.
      final answer =
          await api.drillLosingHabits(subject: 'test_user', color: 'white');
      final request = sent.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/games/openings/habits/drill');
      expect(jsonDecode(request.body), {'subject': 'test_user', 'color': 'w'});
      expect(answer.stored, 2);
      expect(answer.alreadyInDrill, 1);
    });

    test('a refusal is loud, not an empty answer', () async {
      final (api, _) = service((_) => http.Response('{"error":"x"}', 500));
      await expectLater(
          api.drillLosingHabits(subject: 'test_user'), throwsException);
    });
  });

  group('what the drill answer says', () {
    HabitDrillAnswer answer(
            {int stored = 0,
            int already = 0,
            int without = 0,
            int rejected = 0}) =>
        HabitDrillAnswer(
            habits: stored + already + without + rejected,
            stored: stored,
            alreadyInDrill: already,
            withoutLoss: without,
            rejected: rejected);

    test('every part that was not added is said', () {
      expect(answer(stored: 2, already: 1).summary,
          'Added 2 habits to My mistakes. 1 was already there.');
      expect(answer(stored: 1).summary, 'Added 1 habit to My mistakes.');
      expect(
          answer(without: 2).summary,
          '2 were judged before the drill could rank it — judge with the '
          'engine again to add it.');
      expect(answer(rejected: 1).summary, '1 was refused.');
      expect(answer().summary, 'No losing habit to add.');
    });

    test('complete only when nothing was left out', () {
      expect(answer(stored: 2, already: 3).complete, isTrue);
      expect(answer(stored: 2, without: 1).complete, isFalse);
      expect(answer(stored: 2, rejected: 1).complete, isFalse);
    });
  });
}
