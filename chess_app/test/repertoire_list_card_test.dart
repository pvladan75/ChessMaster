import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// What a repertoire's card says before you open it.
///
/// It said how much was **left** until 16.9.2026 — „5 unanswered positions" —
/// and that number is gone, on the owner's decision and for the reason the
/// build screen's own count went: since 15.9.2026 a move of the student's own
/// is kept with the book's top reply beside it, so carrying a line further is
/// a choice rather than a debt, and a count of what has no answer describes a
/// model the app no longer works by.
///
/// This file was `repertoire_progress_card_test.dart` and held three tests
/// about that number. Two of them asserted the sentence itself and went with
/// it; what is left is what the card does say, and an anchor saying the count
/// has not come back. The third — the cards are drawn before the counting
/// answers — went with the counting: there is no second request to wait for
/// any more, which `the card is drawn from the list alone` says instead.
class _Api extends RepertoireApiService {
  /// The server still answers about progress, and answers with real numbers —
  /// otherwise „nothing on the card counts" would pass for the wrong reason.
  /// A fake that cannot supply the number cannot show the number coming back,
  /// and an assertion that cannot fail is not an assertion. Proved by putting
  /// the whole feature back: with this body, both tests below go red.
  _Api()
      : super(
          client: MockClient((req) async {
            calls.add(req.url.path);
            if (req.url.path.endsWith('/repertoire/progress')) {
              return http.Response(
                jsonEncode({
                  'items': [
                    {'id': 3, 'open': 5, 'decided': 10},
                    {'id': 7, 'open': 0, 'decided': 12},
                  ],
                }),
                200,
              );
            }
            return http.Response('{}', 200);
          }),
        );

  /// Every path this screen asked the server for.
  static final List<String> calls = [];

  @override
  Future<List<RepertoireSummary>> list() async => const [
        RepertoireSummary(
            id: 3, name: 'Benoni', color: 'w', rootFen: 'r3', moves: 98),
        RepertoireSummary(
            id: 7,
            name: 'Italijanka',
            color: 'b',
            rootFen: 'r7',
            moves: 1,
            viaSan: 'Bc4'),
      ];
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  _Api.calls.clear();
  await tester.pumpWidget(MaterialApp(home: RepertoireListScreen(api: _Api())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the card says which side it is for and how much is built',
      (tester) async {
    await _pump(tester);

    expect(find.text('White · 98 moves in graph'), findsOneWidget);
    // The gate, where there is one: two repertoires from the same position are
    // otherwise two identical rows with different names.
    expect(find.text('Black · via Bc4 · 1 move in graph'), findsOneWidget);
  });

  testWidgets('nothing on the card counts what has no answer', (tester) async {
    await _pump(tester);

    expect(find.textContaining('unanswered'), findsNothing);
    expect(find.textContaining('all answered'), findsNothing);
    // No draft badge either: nothing writes a draft any more.
    expect(find.byIcon(Icons.edit_note), findsNothing);
  });

  testWidgets('the card is drawn from the list alone', (tester) async {
    // The count was a walk per repertoire — about a third of a second each —
    // asked for on every open of this screen. With nothing drawing it, asking
    // would be work the server does for a number nobody reads.
    await _pump(tester);

    expect(find.text('Benoni'), findsOneWidget);
    expect(_Api.calls.where((path) => path.contains('progress')), isEmpty);
  });
}
