import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// What the list says about each repertoire before you open it.
///
/// „N poteza u grafu" is how much was built. The reader asked for how much is
/// left, per repertoire — the drafts badge used to be per *colour*, so three
/// white repertoires wore the same number and none of them was about itself.
class _Api extends RepertoireApiService {
  _Api(this.progressBody)
      : super(
          client: MockClient((req) async {
            if (req.url.path.endsWith('/repertoire/progress')) {
              return http.Response(progressBody, 200);
            }
            return http.Response('{}', 200);
          }),
        );

  final String progressBody;

  @override
  Future<List<RepertoireSummary>> list() async => const [
        RepertoireSummary(
            id: 3, name: 'Benoni', color: 'w', rootFen: 'r3', moves: 98),
        RepertoireSummary(
            id: 7, name: 'Italijanka', color: 'w', rootFen: 'r7', moves: 98),
      ];
}

Future<void> _pump(WidgetTester tester, String body) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester
      .pumpWidget(MaterialApp(home: RepertoireListScreen(api: _Api(body))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('each card carries its own numbers', (tester) async {
    await _pump(
      tester,
      jsonEncode({
        'items': [
          {'id': 3, 'open': 5, 'draft': 4, 'decided': 10},
          {'id': 7, 'open': 0, 'draft': 0, 'decided': 12},
        ],
      }),
    );

    expect(find.text('5 neodgovorenih pozicija'), findsOneWidget);
    expect(find.text('sve odgovoreno'), findsOneWidget);
    // The badge is this repertoire's drafts, not the colour's.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a walk that could not be read says nothing at all',
      (tester) async {
    // Null, not zero. „Sve odgovoreno" on a repertoire nobody could count is
    // the failure this whole pass keeps turning up: a step that could not run,
    // reported as a step with nothing to do.
    await _pump(
      tester,
      jsonEncode({
        'items': [
          {'id': 3, 'open': null, 'draft': null, 'decided': null},
          {'id': 7, 'open': null, 'draft': null, 'decided': null},
        ],
      }),
    );

    expect(find.textContaining('neodgovorenih'), findsNothing);
    expect(find.text('sve odgovoreno'), findsNothing);
  });

  testWidgets('the cards are on screen before the counting answers',
      (tester) async {
    // The walk is a third of a second per repertoire. The list is what
    // somebody opens to choose where to work, so it must not wait for it.
    await tester.runAsync(() async {});
    await _pump(tester, jsonEncode({'items': []}));

    expect(find.text('Benoni'), findsOneWidget);
    expect(find.text('Italijanka'), findsOneWidget);
  });
}
