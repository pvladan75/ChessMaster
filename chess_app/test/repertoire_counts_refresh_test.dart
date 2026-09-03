import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// A number on screen is a claim about now, not about when the screen opened.
///
/// The walk was read in `initState` and after a spine, and nowhere else — so
/// confirming a draft left the banner advertising work that was already done,
/// and the only way to find out was to press it. The same staleness on the list
/// screen survived until the app was restarted.
class _CountingApi extends RepertoireApiService {
  _CountingApi()
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  int walks = 0;
  int drafts = 3;

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
  }) async {
    walks += 1;
    return RepertoireFrontier(
      decided: 2,
      draft: drafts,
      open: const [
        FrontierNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          path: [],
          reach: 1,
          kind: 'undecided',
        ),
      ],
    );
  }

  @override
  Future<bool> confirmNode({
    required String color,
    required String fen,
    String? uci,
  }) async {
    // The server agreed, so one draft fewer from here on.
    drafts -= 1;
    return true;
  }

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      const [
        RepertoireMove(uci: 'e2e4', san: 'e4', role: 'primary', source: 'auto')
      ];
}

void main() {
  testWidgets('confirming a draft re-reads the number above the board',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = _CountingApi();
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'Benoni',
        id: 3,
        color: 'w',
        rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        api: api,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('3 nepotvrđenih u grafu'), findsOneWidget);
    final walksBefore = api.walks;

    await tester.tap(find.text('Potvrdi'));
    await tester.pumpAndSettle();

    // The walk was read again, and the banner says what it says now.
    expect(api.walks, greaterThan(walksBefore));
    expect(find.text('2 nepotvrđenih u grafu'), findsOneWidget);
  });
}
