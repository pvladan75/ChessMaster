// „What to drill" counts the pool the drill will actually serve from.
//
// Reported live by the owner, 20.9.2026, against TODO-provera 206 point 5:
// „Ovo je tačno, ali sam očekivao da uključivanje/isključivanje online partija
// menja brojeve, ali ne menja brojeve."
//
// The switch was not merely inert. `GET /puzzles/endgame/next` leaves the
// online base out unless it is asked for, and the app's default is to leave it
// out — while `GET /puzzles/endgame/catalog` counted everything. So the total
// under the picker was **larger than what could be served**, and a selection
// whose only matches were online read as a healthy number with „Start" live.
//
// Both ends were wrong and both are fixed: the route takes the flag (see
// `chess_backend/test/endgame_catalog_online.test.js`) and the app sends it.
//
// Every case here reads **the request**, through the `client` seam the service
// already carries for exactly this reason — its own comment says every endgame
// test used to override the methods instead, „which proves the screen and
// nothing about the path, the query or the body" (audit of 16.9.2026). A fake
// that answered a question nobody asked could not have seen this bug at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart'
    show EndgameMode;
import 'package:chess_app/features/endgame_trainer/screens/endgame_picker_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';

/// Every catalogue request the screen made, newest last.
late List<Uri> requests;

/// A catalogue whose size depends on whether the online base was asked for,
/// which is the only way a case can tell that the flag travelled: a server
/// that answered the same numbers either way would make the screen look right
/// while the request was wrong.
String _catalogJson({required bool online}) {
  final count = online ? 250 : 100;
  return '''
{
  "families": [
    {
      "id": "rooks",
      "name": "Rook endings",
      "count": $count,
      "endings": [
        {"material": "KRPvKR", "label": "rook and pawn",
         "count": $count, "bands": {"b2000": $count}}
      ]
    }
  ],
  "bands": [{"id": "b2000", "name": "2000 - 2200"}],
  "oppositeBishops": 0
}
''';
}

http.Client _server() => MockClient((req) async {
      requests.add(req.url);
      final online = req.url.queryParameters['includeOnline'] == 'true';
      return http.Response(_catalogJson(online: online), 200);
    });

Future<void> _openPicker(WidgetTester tester, {required bool online}) async {
  SharedPreferences.setMockInitialValues({
    'app_endgame_include_online': online,
  });
  await AppSettingsService.instance.init();
  requests = [];

  tester.view.physicalSize = const Size(900, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: EndgamePickerScreen(
      session: UserSession(
          token: 't', id: 1, email: 'a@b', name: 'N', role: 'korisnik'),
      mode: EndgameMode.draw,
      api: EndgameApiService(authToken: 't', client: _server()),
      onStart: (_) {},
    ),
  ));
  await tester.pumpAndSettle();
}

Uri get _lastCatalogRequest {
  final hits = requests.where((u) => u.path.endsWith('/endgame/catalog'));
  expect(hits, isNotEmpty, reason: 'the catalogue was never asked for');
  return hits.last;
}

void main() {
  testWidgets('the catalogue is asked over the pool the drill serves from',
      (tester) async {
    await _openPicker(tester, online: false);

    expect(_lastCatalogRequest.queryParameters['includeOnline'], 'false',
        reason: 'the count is taken over every position, including the ones '
            'the drill will refuse to serve');
  });

  testWidgets('a reader who wants the online base says so in the request',
      (tester) async {
    await _openPicker(tester, online: true);

    expect(_lastCatalogRequest.queryParameters['includeOnline'], 'true');
  });

  testWidgets('flipping the switch asks again', (tester) async {
    await _openPicker(tester, online: false);
    final before = requests.length;

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(requests.length, greaterThan(before),
        reason: 'the switch changed a setting and nothing went to the server');
    expect(_lastCatalogRequest.queryParameters['includeOnline'], 'true');
  });

  testWidgets('and the number on the screen follows', (tester) async {
    // The owner's sentence, as a test: turning the switch must move the total.
    await _openPicker(tester, online: false);
    expect(find.text('Selected: 100 positions'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Selected: 250 positions'), findsOneWidget);
    expect(find.text('Selected: 100 positions'), findsNothing);
  });

  testWidgets('the reader does not lose their ticks to the switch',
      (tester) async {
    // A refetch is the easy way to write this and it throws the reader's work
    // away: the pool changed, but nobody asked to start over. Untick the one
    // family, flip the switch, and it is still unticked.
    await _openPicker(tester, online: false);

    await tester.tap(find.text('Rook endings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No positions match'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.textContaining('No positions match'), findsOneWidget,
        reason: 'the refetch ticked everything back on');
  });

  testWidgets('the mode still travels with it', (tester) async {
    // Guarding: the flag is added beside what the request already carried, not
    // instead of it. Converting and holding are counted separately.
    await _openPicker(tester, online: false);

    expect(_lastCatalogRequest.queryParameters['mode'], 'draw');
  });
}
