import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';

/// What the drill says about itself before it asks anything.
///
/// The owner's ask: „drill mora da bude jasno šta pokriva, koje linije" — over
/// a screen that put up a board and a question with nothing saying which of
/// your openings it had chosen or how much of it was in scope.
const _root = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class _Api extends RepertoireApiService {
  _Api({this.todayBody})
      : super(
          client: MockClient((req) async {
            if (req.url.path.endsWith('/practice/today')) {
              return http.Response(
                  todayBody ?? '{}', todayBody == null ? 500 : 200);
            }
            return http.Response('{}', 200);
          }),
        );

  final String? todayBody;

  @override
  Future<DrillLine?> drillLine({
    required String color,
    String? rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? fromFen,
    String? viaFen,
    String? viaUci,
    List<String> exclude = const [],
    bool ahead = false,
    String? gateUci,
    String? breadth,
    List<int>? ids,
  }) async =>
      const DrillLine(
        startFen: _root,
        question: DrillItem(
          fen: _root,
          fresh: true,
          repetitions: 0,
          moves: 1,
        ),
        stats: DrillStats(positions: 18, due: 4, known: 9, fresh: 5),
      );
}

Future<void> _pump(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(
    home: RepertoireDrillScreen(
      name: 'Benoni',
      color: 'w',
      rootFen: _root,
      api: api,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  testWidgets('the session says which opening and how much of it',
      (tester) async {
    await _pump(tester, _Api(todayBody: jsonEncode({'positions': 0})));

    expect(find.textContaining('Drilling: Benoni'), findsOneWidget);
    expect(find.textContaining('entire repertoire'), findsOneWidget);
    expect(find.textContaining('18 positions'), findsOneWidget);
    expect(find.textContaining('due 4'), findsOneWidget);
  });

  testWidgets('the day is counted in what was done, not in what is left',
      (tester) async {
    await _pump(tester, _Api(todayBody: jsonEncode({'positions': 4})));

    // A number that goes up is worth finishing; one that counts down is a debt.
    expect(find.text('today 4 of 10'), findsOneWidget);
  });

  testWidgets('a finished target says so', (tester) async {
    await _pump(tester, _Api(todayBody: jsonEncode({'positions': 12})));
    expect(find.text('today 12 — goal reached'), findsOneWidget);
  });

  testWidgets('a server that did not answer says nothing about today',
      (tester) async {
    // Null, not zero. „Danas niste odvežbali nijednu poziciju" is a hard
    // enough sentence to be told when it is true.
    await _pump(tester, _Api());

    expect(find.textContaining('today'), findsNothing);
    expect(find.textContaining('Drilling: Benoni'), findsOneWidget);
  });

  testWidgets('a target of zero switches the whole idea off', (tester) async {
    await AppSettingsService.instance.setDailyTarget(0);
    await _pump(tester, _Api(todayBody: jsonEncode({'positions': 4})));

    expect(find.textContaining('today'), findsNothing);
  });
}
