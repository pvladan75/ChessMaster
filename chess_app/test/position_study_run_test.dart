// A position study from beginning to end, and the way its words are asked
// for — docs/PLAN-STUDIJA-POZICIJE.md, §3 and D5.
//
// The client is faked, not the method (rule 7): every case reads the request
// that was sent. The engine is the real one's recorded answers.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/position_study.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_board.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words_client.dart'
    show kStudyWordsTimeout;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;

import 'support/recorded_engine.dart';

const _owner2 =
    'rn2kbnr/pp2pppp/2p5/3PN3/4b3/1P4P1/1P1PPP1P/RNB1KB1R w KQkq - 1 8';

/// A server that answers every slot it is offered with a sentence naming it,
/// and remembers what it was sent.
class _Server {
  final List<http.Request> requests = [];
  int status = 200;
  Map<String, dynamic> Function(Map<String, dynamic> sent)? answer;

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final sent = jsonDecode(request.body) as Map<String, dynamic>;
    final body = answer?.call(sent) ??
        {
          'slots': {
            for (final item in sent['items'] as List)
              for (final slot in (item as Map)['slots'] as List)
                (slot as Map)['id']: 'Words for ${slot['id']}.',
          },
        };
    return http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });

  StudyWordsAsker get ask =>
      (request, {required comment}) => requestStudyWords(request,
          token: 'a-token',
          comment: comment,
          client: client,
          baseUrl: 'http://server.test');
}

/// What the server answers to a request in [sent]'s language: every offered
/// slot in English, and its translation — except the slots in [lost], which
/// the translation refused, and every slot when [translate] is false.
Map<String, dynamic> _translating(
  Map<String, dynamic> sent, {
  Set<String> lost = const {},
  Map<String, String> english = const {},
  bool translate = true,
  String? language,
}) {
  final ids = [
    for (final item in sent['items'] as List)
      for (final slot in (item as Map)['slots'] as List)
        (slot as Map)['id'] as String,
  ];
  final slots = {for (final id in ids) id: english[id] ?? 'Words for $id.'};
  return {
    'slots': slots,
    if (translate)
      'translated': {
        'language': language ?? sent['language'],
        'slots': {
          for (final id in ids)
            if (!lost.contains(id)) id: 'Reči za $id.',
        },
        'refused': [...lost],
      },
  };
}

void main() {
  group('in the reader\'s language', () {
    Future<(StudyResult, AnalysisNode, _Server)> study(
      Map<String, dynamic> Function(Map<String, dynamic> sent) answer, {
      String? language = 'sr-Latn',
    }) async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server()..answer = answer;
      final start = AnalysisNode(fen: engine.fen);
      final result = await runPositionStudy(
        start: start,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
        language: language,
      );
      return (result, start, server);
    }

    test('the language is sent, and the tree holds the translation', () async {
      final (result, start, server) = await study(_translating);
      final body =
          jsonDecode(server.requests.single.body) as Map<String, dynamic>;
      expect(body.keys, ['position', 'side', 'items', 'language']);
      expect(body['language'], 'sr-Latn');
      expect(start.comment, 'Reči za s.position.');
      expect(result.language, 'sr-Latn');
      expect(result.kept, 11);
      expect(result.untranslated, 0);
      expect(result.written.sentences, 11);
    });

    test('English, said or not, sends no language', () async {
      for (final language in [null, 'en']) {
        final (result, start, server) =
            await study(_translating, language: language);
        final body =
            jsonDecode(server.requests.single.body) as Map<String, dynamic>;
        expect(body.keys, ['position', 'side', 'items'], reason: '$language');
        expect(start.comment, 'Words for s.position.');
        expect(result.untranslated, 0);
      }
    });

    test('a slot the translation refused is left out — never the English',
        () async {
      final (result, start, _) =
          await study((sent) => _translating(sent, lost: {'s.position'}));
      // The position's sentence is gone and nothing stands in its place: the
      // threat's sentence, the next beat, is the first now.
      expect([for (final b in start.beats) b.comment], ['Reči za s.threat.']);
      expect(result.untranslated, 1);
      expect(result.kept, 11);
      expect(result.written.sentences, 10);
      expect(result.refusal, isNull);
    });

    test('a slot the check refused is not written, whatever its translation',
        () async {
      final (result, start, _) = await study((sent) => _translating(sent,
          english: {'w1.capture': 'Taking the rook loses to Qh5.'}));
      final trap =
          start.children.first.children.firstWhere((c) => c.moveSan == 'Bxh1');
      expect(trap.comment, isEmpty);
      expect(result.kept, 10);
      expect(result.untranslated, 0);
    });

    test(
        'no translation, or one in another language, is no comment at all — '
        'and the lines are written', () async {
      for (final answer in [
        (Map<String, dynamic> sent) => _translating(sent, translate: false),
        (Map<String, dynamic> sent) => _translating(sent, language: 'de'),
      ]) {
        final (result, start, _) = await study(answer);
        expect(result.refusal?.reason, 'untranslated');
        expect(start.comment, isEmpty);
        expect(result.written.sentences, 0);
        expect(start.children.first.moveSan, 'dxc6');
      }
    });

    test('a comment on a move is sent in the language and comes back in it',
        () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server()..answer = _translating;
      final root = AnalysisNode(fen: _owner2);
      final dxc6 = playSan(_owner2, 'dxc6')!;
      final node =
          root.addChild(childFen: dxc6.fenAfter, san: dxc6.san, uci: dxc6.uci);
      final said = await commentOnMove(
        node: node,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
        language: 'de',
      );
      expect(said.text, 'Reči za m1.move.');
      final body =
          jsonDecode(server.requests.single.body) as Map<String, dynamic>;
      expect(body['language'], 'de');
    });

    test('a comment on a position keeps what was translated, and only that',
        () async {
      final engine = RecordedEngine.read('owner2');
      final half = _Server()
        ..answer = (sent) => _translating(sent, lost: {'s.threat'});
      final said = await commentOnPosition(
        fen: _owner2,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: half.ask,
        language: 'sr-Latn',
      );
      expect(said.comment.text, 'Reči za s.position.');

      final none = _Server()
        ..answer =
            (sent) => _translating(sent, lost: {'s.position', 's.threat'});
      final nothing = await commentOnPosition(
        fen: _owner2,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: none.ask,
        language: 'sr-Latn',
      );
      expect(nothing.comment.text, isNull);
      expect(nothing.comment.refusal?.reason, 'untranslated');
    });

    test('the note names the language and where it is chosen', () {
      expect(studyLanguageNote(null), isNull);
      expect(studyLanguageNote('en'), isNull);
      expect(studyLanguageNote('xx'), isNull);
      expect(
          studyLanguageNote('sr-Latn'),
          'Written in Serbian (Latin), the language chosen in „Study this '
          'position".');
    });
  });

  group('a study', () {
    test('asks once, at /study-words, and the tree holds what came back',
        () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server();
      final start = AnalysisNode(fen: engine.fen);
      final result = await runPositionStudy(
        start: start,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
      );
      expect(engine.unanswered, isEmpty);

      expect(server.requests, hasLength(1));
      final sent = server.requests.single;
      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://server.test/study-words');
      expect(sent.headers['Authorization'], 'Bearer a-token');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body.keys, ['position', 'side', 'items']);
      expect(body['side'], 'White');
      expect(sent.body, isNot(contains('rn2kbnr')), reason: 'never a FEN');

      expect(result.refusal, isNull);
      expect(result.offered, 11);
      expect(result.kept, 11);
      expect(start.comment, 'Words for s.position.');
      expect(start.children.first.moveSan, 'dxc6');
      expect(result.written.sentences, 11);
    });

    test('without words nothing is asked and the lines are written', () async {
      final engine = RecordedEngine.read('owner2');
      final start = AnalysisNode(fen: engine.fen);
      final result = await runPositionStudy(
        start: start,
        analyzer: engine.analyzer,
        depth: engine.depth,
      );
      expect(result.offered, 0);
      expect(result.refusal, isNull);
      expect(result.written.sentences, 0);
      expect(start.children, isNotEmpty);
    });

    test('a refusal costs the comments and nothing else', () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server()
        ..status = 403
        ..answer = (_) => {'error': 'Premium', 'entitlement': 'ai_studies'};
      final start = AnalysisNode(fen: engine.fen);
      final result = await runPositionStudy(
        start: start,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
      );
      expect(result.refusal?.reason, 'upgrade-required');
      expect(result.kept, 0);
      expect(start.children.first.moveSan, 'dxc6',
          reason: 'the engine\'s work is in the tree');
      expect(start.comment, isEmpty);
    });

    test(
        'a sentence the analysis does not bear out is left out, and the '
        'rest is kept', () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server()
        ..answer = (sent) => {
              'slots': {
                's.position': 'White is a pawn up.',
                'w1.capture': 'Taking the rook loses to Qh5.',
              },
            };
      final start = AnalysisNode(fen: engine.fen);
      final result = await runPositionStudy(
        start: start,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
      );
      expect(result.kept, 1);
      expect(result.refusedClaims.single, contains('Qh5'));
      expect(start.comment, 'White is a pawn up.');
      final trap =
          start.children.first.children.firstWhere((c) => c.moveSan == 'Bxh1');
      expect(trap.comment, isEmpty);
      expect(trap.nag, '?',
          reason: 'the mark is the engine\'s, not the model\'s');
    });

    test('a position that cannot be studied writes nothing and asks nothing',
        () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server();
      final start = AnalysisNode(fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      await expectLater(
        runPositionStudy(
          start: start,
          analyzer: engine.analyzer,
          depth: 20,
          ask: server.ask,
        ),
        throwsA(isA<StudyRefused>()),
      );
      expect(start.children, isEmpty);
      expect(server.requests, isEmpty);
    });

    test('cancelled while the words are being written, nothing is written',
        () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server();
      final start = AnalysisNode(fen: engine.fen);
      var cancelled = false;
      await expectLater(
        runPositionStudy(
          start: start,
          analyzer: engine.analyzer,
          depth: engine.depth,
          ask: server.ask,
          isCancelled: () => cancelled,
          onWriting: () => cancelled = true,
        ),
        throwsA(isA<StudyCancelled>()),
      );
      expect(start.children, isEmpty);
      expect(start.comment, isEmpty);
    });
  });

  group('one comment', () {
    test(
        'on a move: /study-words/comment, one item, and the words as one '
        'text', () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server();
      final root = AnalysisNode(fen: _owner2);
      final dxc6 = playSan(_owner2, 'dxc6')!;
      final after =
          root.addChild(childFen: dxc6.fenAfter, san: dxc6.san, uci: dxc6.uci);
      final bxh1 = playSan(dxc6.fenAfter, 'Bxh1')!;
      final node =
          after.addChild(childFen: bxh1.fenAfter, san: bxh1.san, uci: bxh1.uci);

      final said = await commentOnMove(
        node: node,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
      );
      expect(engine.unanswered, isEmpty);
      expect(said.text, 'Words for m1.move.');
      final sent = server.requests.single;
      expect(sent.url.toString(), 'http://server.test/study-words/comment');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['items'], hasLength(1));
      expect((body['items'] as List).single['kind'], 'move');
      expect((body['items'] as List).single['label'], '8... Bxh1');
      expect(node.comment, isEmpty,
          reason: 'the reader reads it before it is theirs');
    });

    test('on a position: one item, and the engine\'s move beside the words',
        () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server();
      final said = await commentOnPosition(
        fen: _owner2,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
      );
      expect(engine.asked, hasLength(2));
      expect(said.comment.text, 'Words for s.position. Words for s.threat.');
      expect(said.bestMove, 'dxc6');
      final body =
          jsonDecode(server.requests.single.body) as Map<String, dynamic>;
      expect((body['items'] as List).single['kind'], 'position');
      expect(server.requests.single.url.path, '/study-words/comment');
    });

    test('words the analysis does not bear out are no comment at all',
        () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server()
        ..answer = (_) => {
              'slots': {'s.position': 'White wins with Qh5.'},
            };
      final said = await commentOnPosition(
        fen: _owner2,
        analyzer: engine.analyzer,
        depth: engine.depth,
        ask: server.ask,
      );
      expect(said.comment.text, isNull);
      expect(said.comment.refusal?.reason, 'untrue');
    });

    test('the root has no move to comment on, and nothing is asked', () async {
      final engine = RecordedEngine.read('owner2');
      final server = _Server();
      final said = await commentOnMove(
        node: AnalysisNode(fen: _owner2),
        analyzer: engine.analyzer,
        depth: 20,
        ask: server.ask,
      );
      expect(said.refusal?.reason, 'no-move');
      expect(engine.asked, isEmpty);
      expect(server.requests, isEmpty);
    });
  });

  group('every refusal is a reason and a sentence', () {
    Future<WordsRefusal?> refusalFor(int status,
        [Map<String, dynamic> body = const {}]) async {
      final server = _Server()
        ..status = status
        ..answer = (_) => body;
      final outcome = await server.ask({'items': const []}, comment: false);
      expect(outcome.slots, isNull);
      return outcome.refusal;
    }

    test('by status', () async {
      expect((await refusalFor(401))?.reason, 'signed-out');
      expect((await refusalFor(403))?.reason, 'upgrade-required');
      expect((await refusalFor(403, {'quotaExceeded': true}))?.reason,
          'quota-spent');
      expect((await refusalFor(400, {'error': 'items must be'}))?.message,
          'items must be');
      expect((await refusalFor(422))?.reason, 'bad-answer');
      expect((await refusalFor(429, {'reason': 'already-writing'}))?.reason,
          'already-writing');
      expect((await refusalFor(503, {'reason': 'no-balance'}))?.reason,
          'no-balance');
      expect((await refusalFor(500))?.reason, 'http-500');
    });

    test('the app waits longer than the server may take', () {
      // Two attempts of 100 s each on the server (`ATTEMPTS`, the client\'s
      // `timeoutMs`), and for a study in another language the translation,
      // which ends by 285 s (`LAST_START_S` 240 + 45 s a request,
      // `services/studyTranslation.js`) — under the proxy\'s 300.
      expect(kStudyWordsTimeout, greaterThan(const Duration(seconds: 285)));
      expect(kStudyWordsTimeout, lessThan(const Duration(seconds: 300)));
    });

    test('a guest is told to sign in, and nothing is sent', () async {
      final server = _Server();
      final outcome = await requestStudyWords(
        const {'items': []},
        token: '',
        client: server.client,
        baseUrl: 'http://server.test',
      );
      expect(outcome.refusal?.reason, 'signed-out');
      expect(server.requests, isEmpty);
    });

    test('an answer with no slots is no answer', () async {
      final server = _Server()..answer = (_) => {'slots': 'none'};
      final outcome = await server.ask({'items': const []}, comment: false);
      expect(outcome.refusal?.reason, 'bad-answer');
    });

    test('a server that cannot be reached is said, not thrown', () async {
      final client = MockClient(
          (_) async => throw http.ClientException('connection refused'));
      final outcome = await requestStudyWords(
        const {'items': []},
        token: 't',
        client: client,
        baseUrl: 'http://server.test',
      );
      expect(outcome.refusal?.reason, 'network');
    });
  });
}
