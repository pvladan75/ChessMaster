// Gate — `docs/PLAN-LISTE.md`, phase 3a: the two low-churn lists onto
// `AdaptiveCardGrid`.
//
// Written by the lead before the phase was briefed, and proved on master.
//
// The target goes through its real screen, with its real data path — a
// `MockClient` for the homework templates. The saved puzzle sets, this gate's
// other half, were deleted with the sets themselves on 23.9.2026
// (`docs/PLAN-MATERIJAL.md`, phase 4): a puzzle from a game review is an
// exercise now.
//
// Every layout claim is read from **where the cards are actually painted**.
// None of them is a width threshold: phase 1 learned that a width assertion on
// a dialog can pass on master while the fault stands, because `AlertDialog`
// lays its children out under an `IntrinsicWidth`. What the plan is actually
// about is how many items a wide window shows, so that is what is asserted —
// and a dialog that does not grow cannot fit two columns, so its width is
// gated by consequence rather than by a number.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/homework/screens/homework_list_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';

Widget _app(Widget home) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: home,
    );

Future<void> _at(WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home));
  await tester.pumpAndSettle();
}

/// How many of [keys] share the topmost row of whatever is on screen.
///
/// Reading the y-offsets is the whole method: it says nothing about which
/// widget draws a row, so the implementer is free about composition, and it
/// cannot be satisfied by a grid that was configured but never given the
/// width.
int _onFirstRow(WidgetTester tester, List<Key> keys) {
  final tops = <double>[];
  for (final key in keys) {
    final finder = find.byKey(key);
    if (finder.evaluate().isEmpty) continue;
    tops.add(tester.getTopLeft(finder).dy);
  }
  expect(tops, isNotEmpty, reason: 'none of those rows was built');
  final first = tops.reduce((a, b) => a < b ? a : b);
  return tops.where((t) => (t - first).abs() < 0.5).length;
}

// --------------------------------------------------------------- homework

class _Homeworks {
  _Homeworks(this.count);

  final int count;
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/homeworks' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'homeworks': [
                for (var i = 1; i <= count; i++)
                  {
                    'id': i,
                    'title': 'Homework $i',
                    'item_count': 3,
                    'sent_count': i.isEven ? 2 : 0,
                  },
              ],
            }),
            200,
          );
        }
        if (request.method == 'DELETE') {
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('{"error":"not found"}', 404);
      });
}

List<Key> _rowKeys(int count) =>
    [for (var i = 1; i <= count; i++) Key('homework-list-row-$i')];

void main() {
  // ================================================================ homework

  group('homework templates', () {
    testWidgets('a wide window puts templates side by side', (tester) async {
      final api =
          HomeworkApiService(authToken: 'tok', client: _Homeworks(6).client());
      await _at(tester, const Size(1400, 900), HomeworkListScreen(api: api));

      expect(_onFirstRow(tester, _rowKeys(6)), greaterThanOrEqualTo(3),
          reason: 'a 1400 px window still draws one template per line');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone still draws one template per line', (tester) async {
      // Green on master, and it must stay green: the plan changes the desktop
      // and leaves the phone exactly as it was.
      final api =
          HomeworkApiService(authToken: 'tok', client: _Homeworks(6).client());
      await _at(tester, const Size(360, 640), HomeworkListScreen(api: api));

      expect(_onFirstRow(tester, _rowKeys(6)), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row keys and their two actions survive', (tester) async {
      // Green on master. These keys are what `homework_side_and_delete_test`
      // and `homework_editor_doors_test` reach a row by; a grid that renames
      // them breaks tests this phase is not allowed to touch.
      final api =
          HomeworkApiService(authToken: 'tok', client: _Homeworks(2).client());
      await _at(tester, const Size(1400, 900), HomeworkListScreen(api: api));

      expect(find.byKey(const Key('homework-list-row-1')), findsOneWidget);
      expect(find.byKey(const Key('homework-list-send-1')), findsOneWidget);
      expect(find.byKey(const Key('homework-list-delete-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('homework-list-delete-1')));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Homework 1"?'), findsOneWidget,
          reason: 'the delete action no longer reaches its confirmation');
    });

    testWidgets('a template still says how many items and how many sent',
        (tester) async {
      // What the row says is not this phase's business to change.
      final api =
          HomeworkApiService(authToken: 'tok', client: _Homeworks(2).client());
      await _at(tester, const Size(1400, 900), HomeworkListScreen(api: api));

      expect(find.textContaining('3 items'), findsNWidgets(2));
      expect(find.textContaining('sent to 2'), findsOneWidget);
    });
  });
}
