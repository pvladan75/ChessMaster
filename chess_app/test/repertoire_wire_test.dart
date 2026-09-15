import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// What the repertoire client actually puts on the wire.
///
/// `MockClient` answers whatever it is handed and never looks at the URL, so a
/// parameter that goes missing — or one that should have gone and did not — is
/// invisible to every test that only reads the answer. These read the request.
class _WireApi extends RepertoireApiService {
  _WireApi._(this.seen, http.Client client) : super(client: client);

  factory _WireApi() {
    final seen = <http.Request>[];
    return _WireApi._(
      seen,
      MockClient((req) async {
        seen.add(req);
        return http.Response('{}', 200);
      }),
    );
  }

  final List<http.Request> seen;

  Uri lastFor(String suffix) =>
      seen.lastWhere((r) => r.url.path.endsWith(suffix)).url;
}

void main() {
  const root = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  test('no walk is asked for at a breadth any more', () async {
    // Breadth decided which of the book's replies were part of a repertoire.
    // Every entry is a move the student played now, and a width sent to a
    // server that no longer reads it is a setting that looks alive.
    final api = _WireApi();
    await api.repertoireTree(color: 'w', rootFen: root);
    await api.frontier(color: 'w', rootFen: root);
    await api.drillLine(color: 'w', rootFen: root);
    await api.drillBranches(color: 'w', rootFen: root);

    for (final request in api.seen) {
      expect(request.url.queryParameters.containsKey('breadth'), isFalse,
          reason: request.url.path);
      expect(request.url.queryParameters.containsKey('alongPath'), isFalse,
          reason: request.url.path);
    }
  });

  test('every query value the client sends has something in it', () async {
    // `'minRating': ''` shipped and hid: the key was there, the value was not,
    // and the server read `Number('') || 0`. Asserting on keys would have
    // passed. This asserts on values.
    final api = _WireApi();
    await api.drillLine(
      color: 'w',
      rootFen: root,
      rootPath: const ['e4'],
      fromFen: root,
      gateUci: 'e1g1',
      exclude: const ['k1'],
    );
    final asked = api.lastFor('/repertoire/drill/line').queryParameters;
    expect(
        asked.entries.where((e) => e.value.isEmpty).map((e) => e.key), isEmpty);
  });

  test('a combined session sends its ids and no root', () async {
    final api = _WireApi();
    await api.drillLine(color: 'w', ids: const [3, 7]);
    final line = api.lastFor('/repertoire/drill/line');
    expect(line.queryParameters['ids'], '3,7');
    expect(line.queryParameters.containsKey('rootFen'), isFalse);
  });

  test('keeping a move reads the top reply the server entered with it',
      () async {
    final api = _TopReplyApi(
        '{"uci":"e2e4","inserted":true,"topReply":{"uci":"c7c5","san":"c5",'
        '"fen":"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"}}');
    final kept =
        await api.keepMove(color: 'w', fen: root, uci: 'e2e4', san: 'e4');
    expect(kept.saved, isTrue);
    expect(kept.topReply?.san, 'c5');
    expect(kept.topReply?.uci, 'c7c5');

    final none = await _TopReplyApi('{"uci":"e2e4","topReply":null}')
        .keepMove(color: 'w', fen: root, uci: 'e2e4', san: 'e4');
    expect(none.saved, isTrue);
    expect(none.topReply, isNull);
  });

  test('a book the server could not read carries its reason', () {
    final book = StoredBook.fromJson({
      'fen': root,
      'opened': false,
      'replies': const [],
      'unavailable': 'not-configured',
    });
    expect(book.opened, isFalse);
    expect(book.unavailable, 'not-configured');
  });

  test('an entered opponent move is added and removed at the reply route',
      () async {
    final api = _WireApi();
    await api.addOpponentMove(color: 'w', fen: root, uci: 'e7e5', san: 'e5');
    await api.removeOpponentMove(color: 'w', fen: root, uci: 'e7e5');
    expect(api.seen.map((r) => '${r.method} ${r.url.path}'), [
      'POST /repertoire/node/reply',
      'DELETE /repertoire/node/reply',
    ]);
  });
}

class _TopReplyApi extends RepertoireApiService {
  _TopReplyApi(String body)
      : super(client: MockClient((_) async => http.Response(body, 200)));
}
