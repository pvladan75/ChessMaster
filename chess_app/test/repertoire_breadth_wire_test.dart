import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// The width is stored on the repertoire's row and means nothing until a
/// request carries it.
///
/// It was written by the spine dialog and read by nothing: `tree`, `frontier`
/// and both drill calls left it out, so the server fell back to `standard` and
/// a repertoire set to „Samo glavna linija" went on being drawn and queued at
/// 80%. Found by looking at a tree — the picture showed twenty-three of the
/// opponent's moves where the width asked for three — and invisible to every
/// test in the suite, because `MockClient` answers whatever it is handed and
/// never looks at the URL.
class _WireApi extends RepertoireApiService {
  _WireApi._(this.seen, http.Client client) : super(client: client);

  factory _WireApi() {
    final seen = <Uri>[];
    return _WireApi._(
      seen,
      MockClient((req) async {
        seen.add(req.url);
        return http.Response('{}', 200);
      }),
    );
  }

  final List<Uri> seen;

  Uri lastFor(String suffix) => seen.lastWhere((u) => u.path.endsWith(suffix));
}

void main() {
  const root = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  test('the tree and the walk are asked for at the chosen width', () async {
    final api = _WireApi();
    await api.repertoireTree(color: 'w', rootFen: root, breadth: 'main');
    expect(api.lastFor('/repertoire/tree').queryParameters['breadth'], 'main');

    await api.frontier(color: 'w', rootFen: root, breadth: 'broad');
    expect(api.lastFor('/repertoire/frontier').queryParameters['breadth'],
        'broad');
  });

  test('a width nobody set is not invented', () async {
    final api = _WireApi();
    await api.repertoireTree(color: 'w', rootFen: root);
    expect(
        api.lastFor('/repertoire/tree').queryParameters.containsKey('breadth'),
        isFalse);
  });

  test('the drill asks at the width too', () async {
    final api = _WireApi();
    await api.drillLine(color: 'w', rootFen: root, breadth: 'main');
    expect(api.lastFor('/repertoire/drill/line').queryParameters['breadth'],
        'main');

    await api.drillBranches(color: 'w', rootFen: root, breadth: 'main');
    expect(api.lastFor('/repertoire/drill/branches').queryParameters['breadth'],
        'main');
  });

  test('a combined session sends no width — the rows carry their own',
      () async {
    final api = _WireApi();
    await api.drillLine(color: 'w', ids: const [3, 7], breadth: 'main');
    final line = api.lastFor('/repertoire/drill/line');
    expect(line.queryParameters['ids'], '3,7');
    expect(line.queryParameters.containsKey('breadth'), isFalse);
  });

  testWidgets('the drill screen carries its repertoire width up the wire',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = _WireApi();
    await tester.pumpWidget(MaterialApp(
      home: RepertoireDrillScreen(
        name: 'Benoni',
        color: 'w',
        rootFen: root,
        breadth: 'main',
        api: api,
      ),
    ));
    await tester.pumpAndSettle();

    expect(api.lastFor('/repertoire/drill/line').queryParameters['breadth'],
        'main');
  });
}
