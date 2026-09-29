// A tutorial made from a game, translated whole before it opens —
// docs/PLAN-JEZIK-STUDIJE.md, §8. The client is faked, not the method (rule 7):
// every case reads the request that was sent.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/translate_client.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

final _fixture = jsonDecode(
    File('test/fixtures/game_tutorial/g01_scandinavian-defense.json')
        .readAsStringSync()) as Map<String, dynamic>;

/// The Key moments tutorial, as the run hands it over.
ImportedTutorial _tutorial() => readTutorialJson(jsonEncode(
    (_fixture['expected'] as Map<String, dynamic>)['tutorial']
        as Map<String, dynamic>));

class _Server {
  final List<http.Request> requests = [];
  int status = 200;
  Map<String, dynamic> Function(Map<String, dynamic> sent)? answer;

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final sent = jsonDecode(request.body) as Map<String, dynamic>;
    final t = sent['tutorial'] as Map<String, dynamic>;
    final body = answer?.call(sent) ??
        {
          'tutorial': {
            'title': 'SR ${t['title']}',
            'description': 'SR ${t['description']}',
            'steps': t['steps'],
            'language': sent['language'],
          },
        };
    return http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });

  Future<TutorialTranslation> ask(ImportedTutorial tutorial, String language,
          {String token = 'a-token'}) =>
      translateGameTutorial(tutorial, language,
          token: token, client: client, baseUrl: 'http://server.test');
}

void main() {
  test('it sends the tutorial and the language, and opens what came back',
      () async {
    final server = _Server();
    final source = _tutorial();
    final out = await server.ask(source, 'sr-Latn');

    final sent = server.requests.single;
    expect(sent.method, 'POST');
    expect(
        sent.url.toString(), 'http://server.test/lessons/from-game/translate');
    expect(sent.headers['Authorization'], 'Bearer a-token');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body.keys, ['language', 'tutorial']);
    expect(body['language'], 'sr-Latn');
    final t = body['tutorial'] as Map<String, dynamic>;
    expect(t['title'], source.title);
    expect(t['steps'], hasLength(source.partCount));
    expect((t['steps'] as List).first['pgn'], source.positionList.first['pgn']);

    expect(out.refusal, isNull);
    final translated = out.tutorial!;
    expect(translated.language, 'sr-Latn');
    expect(translated.title, 'SR ${source.title}');
    expect(translated.tags, source.tags);
    expect(translated.asLesson['language'], 'sr-Latn',
        reason: 'the studio reads the language from the lesson');
  });

  test('an answer that is not the tutorial asked for is no answer', () async {
    for (final answer in <Map<String, dynamic> Function(Map<String, dynamic>)>[
      (sent) => {'tutorial': 'none'},
      (sent) => {
            'tutorial': {
              'title': 'x',
              'steps': [],
              'language': sent['language'],
            },
          },
      (sent) => {
            'tutorial': {
              'title': 'x',
              'steps': (sent['tutorial'] as Map)['steps'],
              'language': 'de',
            },
          },
    ]) {
      final server = _Server()..answer = answer;
      final out = await server.ask(_tutorial(), 'sr-Latn');
      expect(out.tutorial, isNull);
      expect(out.refusal?.reason, 'bad-answer');
    }
  });

  test('every refusal is a reason and a sentence', () async {
    Future<String?> reasonFor(int status, [Map<String, dynamic>? body]) async {
      final server = _Server()
        ..status = status
        ..answer = (_) => body ?? {'error': 'no'};
      final out = await server.ask(_tutorial(), 'de');
      expect(out.tutorial, isNull);
      expect(out.refusal!.message, isNotEmpty);
      return out.refusal!.reason;
    }

    expect(await reasonFor(401), 'signed-out');
    expect(await reasonFor(403), 'upgrade-required');
    expect(await reasonFor(400), 'bad-request');
    expect(await reasonFor(422), 'bad-translation');
    expect(await reasonFor(429, {'reason': 'already-translating'}),
        'already-translating');
    expect(await reasonFor(503, {'reason': 'no-balance'}), 'no-balance');
    expect(await reasonFor(500), 'http-500');
  });

  test('a guest is told to sign in, and nothing is sent', () async {
    final server = _Server();
    final out = await server.ask(_tutorial(), 'de', token: '');
    expect(out.refusal?.reason, 'signed-out');
    expect(server.requests, isEmpty);
  });

  test('the app waits longer than the server may take, under the proxy', () {
    // Two requests of 100 s at the most on the server, under nginx's 300.
    expect(
        kTutorialTranslateTimeout, greaterThan(const Duration(seconds: 200)));
    expect(kTutorialTranslateTimeout, lessThan(const Duration(seconds: 300)));
  });
}
