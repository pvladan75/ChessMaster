// Phase 4 of `docs/PLAN-SKELET.md`: the app's call to the words route, and a
// reason and a sentence for every way it can come back without words.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart';

const _request = {'game': '1. e4 e5', 'opening': null, 'moments': []};

Future<WordsOutcome> _ask(MockClient client, {String token = 'jwt'}) =>
    requestTutorialWords(_request,
        token: token, client: client, baseUrl: 'http://server');

MockClient _answering(int status, Object body) =>
    MockClient((_) async => http.Response(jsonEncode(body), status));

void main() {
  test('the request is the skeleton, signed in, to the words route', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(
          jsonEncode({
            'answer': {
              'title': 'T',
              'chosen': ['m1', 'm2'],
              'slots': {}
            },
            'attempts': 2,
            'tokens': {'total': 12000},
          }),
          200);
    });
    final outcome = await _ask(client);
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://server/lessons/from-game/words');
    expect(sent.headers['Authorization'], 'Bearer jwt');
    expect(jsonDecode(sent.body), _request);
    expect(outcome.refusal, isNull);
    expect(jsonDecode(outcome.answerText!)['title'], 'T');
    expect(outcome.attempts, 2);
    expect(outcome.tokens, 12000);
  });

  test('no sign-in asks nothing', () async {
    var asked = false;
    final outcome = await _ask(MockClient((_) async {
      asked = true;
      return http.Response('{}', 200);
    }), token: '');
    expect(asked, isFalse);
    expect(outcome.refusal!.reason, 'signed-out');
  });

  test('each refusal is its own reason', () async {
    final cases = <(MockClient, String)>[
      (_answering(403, {'upgradeRequired': true}), 'upgrade-required'),
      (
        _answering(403, {'quotaExceeded': true, 'error': 'Used up.'}),
        'quota-spent'
      ),
      (
        _answering(400, {'error': 'game must be the moves only'}),
        'bad-request'
      ),
      (_answering(422, {'reason': 'bad-answer', 'problems': []}), 'bad-answer'),
      (_answering(429, {'reason': 'already-writing'}), 'already-writing'),
      (
        _answering(503, {'reason': 'no-balance', 'error': 'No balance.'}),
        'no-balance'
      ),
      (_answering(401, {}), 'signed-out'),
      (_answering(500, {}), 'http-500'),
      (_answering(200, {'nothing': true}), 'bad-answer'),
      (MockClient((_) async => throw const SocketException('down')), 'network'),
      (
        MockClient((_) async => throw http.ClientException('closed')),
        'network'
      ),
      (MockClient((_) async => throw TimeoutException('slow')), 'timeout'),
    ];
    for (final (client, reason) in cases) {
      final outcome = await _ask(client);
      expect(outcome.answerText, isNull, reason: reason);
      expect(outcome.refusal!.reason, reason);
      expect(outcome.refusal!.message, isNotEmpty, reason: reason);
    }
  });

  test('the server\'s own sentence is kept where it sent one', () async {
    final outcome = await _ask(
        _answering(403, {'quotaExceeded': true, 'error': 'Used up.'}));
    expect(outcome.refusal!.message, 'Used up.');
    expect(outcome.refusal!.upgradeRequired, isFalse);
  });

  test('a refusal that did not spend a credit says so', () async {
    for (final status in [422]) {
      final outcome = await _ask(_answering(status, {}));
      expect(outcome.refusal!.message, contains('did not count'));
    }
    final slow =
        await _ask(MockClient((_) async => throw TimeoutException('x')));
    expect(slow.refusal!.message, contains('Nothing was charged'));
  });
}
