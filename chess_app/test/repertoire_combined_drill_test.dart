import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// Two repertoires that both open 1.e4 c5: the branch **key** is the same pair
/// of moves in both, and only the `id` — the key with the repertoire in front
/// of it — tells them apart. A list keyed by `key` drops one of them silently.
final _twoAlikeBranches = {
  'branches': [
    {
      'id': '3:e2e4-c7c5',
      'key': 'e2e4-c7c5',
      'repertoire': {'id': 3, 'name': 'Sicilijanka, crni'},
      'root': {'fen': 'root-3', 'path': <String>[]},
      'san': 'e4 c5',
      'fen': 'fen-3',
      'path': ['e4', 'c5'],
      'due': 4,
      'positions': 18,
      'known': 9,
    },
    {
      'id': '7:e2e4-c7c5',
      'key': 'e2e4-c7c5',
      'repertoire': {'id': 7, 'name': 'Otvorena sicilijanka'},
      'root': {'fen': 'root-7', 'path': <String>[]},
      'san': 'e4 c5',
      'fen': 'fen-7',
      'path': ['e4', 'c5'],
      'due': 2,
      'positions': 6,
      'known': 1,
    },
  ],
};

/// The real service over a client that answers and records every URL.
///
/// The point of the batch is what goes up the wire, and `MockClient` never
/// looks at a URL by itself — so the URLs are kept here and asserted on.
class _WireApi extends RepertoireApiService {
  _WireApi._(this.seen, http.Client client) : super(client: client);

  factory _WireApi({Map<String, dynamic>? branches}) {
    final seen = <Uri>[];
    return _WireApi._(
      seen,
      MockClient((req) async {
        seen.add(req.url);
        if (req.url.path.endsWith('/drill/branches')) {
          return http.Response(
              jsonEncode(branches ?? const {'branches': []}), 200);
        }
        return http.Response('{}', 200);
      }),
    );
  }

  final List<Uri> seen;

  Uri lastFor(String suffix) => seen.lastWhere((u) => u.path.endsWith(suffix));
}

/// A drill screen for several repertoires at once, built the way the list
/// screen builds it: ids, and no root.
Widget _combined(RepertoireApiService api) => MaterialApp(
      home: RepertoireDrillScreen(
        name: 'Kombinovano',
        color: 'b',
        api: api,
        ids: const [3, 7],
      ),
    );

/// A list of three repertoires, two black and one white.
class _ListApi extends RepertoireApiService {
  _ListApi() : super(client: MockClient((_) async => http.Response('{}', 200)));

  @override
  Future<List<RepertoireSummary>> list() async => const [
        RepertoireSummary(
            id: 3,
            name: 'Sicilijanka, crni',
            color: 'b',
            rootFen: 'root-3',
            moves: 10),
        RepertoireSummary(
            id: 7,
            name: 'Otvorena sicilijanka',
            color: 'b',
            rootFen: 'root-7',
            moves: 5),
        RepertoireSummary(
            id: 8, name: 'Ruy Lopez', color: 'w', rootFen: 'root-8', moves: 5),
      ];

  @override
  Future<List<DrillBranch>> drillBranches({
    required String color,
    String? rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
    List<int>? ids,
  }) async =>
      const [];
}

void main() {
  group('a combined session asks by ids', () {
    testWidgets('the line request carries ids and no root', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _WireApi();
      await tester.pumpWidget(_combined(api));
      await tester.pumpAndSettle();

      final line = api.lastFor('/drill/line');
      expect(line.queryParameters['ids'], '3,7');
      expect(line.queryParameters.containsKey('rootFen'), isFalse);
      expect(line.queryParameters.containsKey('rootPath'), isFalse);
      expect(line.queryParameters.containsKey('gateUci'), isFalse);
      // The colour still goes, and must agree with the rows.
      expect(line.queryParameters['color'], 'b');
      // Absolute, not a bare path: a relative URL fails on the first tap on a
      // real device and no widget test can see it.
      expect(line.isAbsolute, isTrue);
    });

    testWidgets('two openings that open alike are two rows', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _WireApi(branches: _twoAlikeBranches);
      await tester.pumpWidget(_combined(api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Izaberi granu'));
      await tester.pumpAndSettle();

      final branches = api.lastFor('/drill/branches');
      expect(branches.queryParameters['ids'], '3,7');
      expect(branches.queryParameters.containsKey('rootFen'), isFalse);

      // Same SAN, same key — two rows, each tagged with where it came from.
      expect(find.text('e4 c5'), findsNWidgets(2));
      expect(find.text('Sicilijanka, crni'), findsOneWidget);
      expect(find.text('Otvorena sicilijanka'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      // And the one sentence about the shared schedule, before anything is
      // ticked rather than after.
      expect(find.text('Pozicija koju oba otvaranja dostižu pita se jednom.'),
          findsOneWidget);

      // Two rows on the screen is not yet two rows in the code: keyed by
      // `key`, both would tick together and one whole opening would vanish
      // into the other while the count still looked right.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(
          tester
              .widgetList<Checkbox>(find.byType(Checkbox))
              .where((c) => c.value == true)
              .length,
          1);
      expect(find.text('Vežbaj izabrane (1)'), findsOneWidget);
    });

    testWidgets('ticking two branches runs them as one sitting',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _WireApi(branches: _twoAlikeBranches);
      await tester.pumpWidget(_combined(api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Izaberi granu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();

      expect(find.text('Vežbaj izabrane (2)'), findsOneWidget);
      await tester.tap(find.text('Vežbaj izabrane (2)'));
      await tester.pumpAndSettle();

      // The first branch is asked for, and — nothing being due in it — the
      // second follows in the same sitting rather than ending it.
      final asked = api.seen
          .where((u) => u.path.endsWith('/drill/line'))
          .map((u) => u.queryParameters['fromFen'])
          .toList();
      expect(asked, containsAllInOrder(['fen-3', 'fen-7']));
    });

    testWidgets('a single tap still starts one branch', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _WireApi(branches: _twoAlikeBranches);
      await tester.pumpWidget(_combined(api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Izaberi granu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Otvorena sicilijanka'));
      await tester.pumpAndSettle();

      expect(api.lastFor('/drill/line').queryParameters['fromFen'], 'fen-7');
    });
  });

  testWidgets('the list refuses two colours in one sitting', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester
        .pumpWidget(MaterialApp(home: RepertoireListScreen(api: _ListApi())));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Sicilijanka, crni'));
    await tester.pumpAndSettle();
    expect(find.text('Vežbaj izabrane (1)'), findsOneWidget);

    await tester.tap(find.text('Otvorena sicilijanka'));
    await tester.pumpAndSettle();
    expect(find.text('Vežbaj izabrane (2)'), findsOneWidget);

    // The white one is refused with a sentence, and does not join the count.
    await tester.tap(find.text('Ruy Lopez'));
    await tester.pumpAndSettle();
    expect(find.text('Jedna sesija može da pita samo o jednoj strani.'),
        findsOneWidget);
    expect(find.text('Vežbaj izabrane (2)'), findsOneWidget);

    await tester.tap(find.text('Vežbaj izabrane (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Vežbanje — Kombinovano'), findsOneWidget);
  });
}
