// usage_screen_test.dart — the account's month, as a screen.
//
// Added 26.9.2026 with the server's metering of voice characters and Lichess
// requests: the meter had existed since August and nobody could look at it
// from the app (docs/TODO-provera.md [183.3] noted the missing screen on
// 18.9.2026). The rules held here:
//
//   1. two requests, both with the account's token — the plan's limits and the
//      account's own counters — and nothing else (rule 7: the client is faked,
//      the request asserted);
//   2. a limit reads „used / limit", no limit reads the count and says so;
//   3. what has no limit is said in the reader's units — voice in minutes,
//      rendered video in minutes, every voice provider's characters in one
//      row, tokens as tokens — and a counter the screen has no words for is
//      still shown, never dropped;
//   4. a server that does not answer says so, and „Try again" asks again;
//   5. nothing overflows on a 360 dp phone or a 1200 px window;
//   6. Settings has the door, and only for a signed-in account.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/screens/usage_screen.dart';
import 'package:chess_app/services/usage_service.dart';
import 'package:chess_app/theme/app_colors.dart';

final _session = UserSession(
  token: 'tok',
  id: 4,
  email: 'a@b.c',
  name: 'Trener',
  role: 'korisnik',
);

const _entitlements = {
  'tier': 'premium',
  'entitlements': ['mp4_export', 'ai_tutorials'],
  'quotas': {
    'ai_tutorials': {'limit': 30, 'used': 2},
    'ai_review_words': {'limit': -1, 'used': 5},
    'assignments': {'limit': 5, 'used': 12},
  },
  'periodStart': '2026-09-01T00:00:00.000Z',
};

const _own = {
  'periodStart': '2026-09-01T00:00:00.000Z',
  'metrics': {
    'agora_seconds': 3700,
    'mp4_renders': 3,
    'mp4_render_seconds': 130,
    'tts_azure_characters': 2000,
    'tts_piper_characters': 500,
    'ai_tutorials': 2,
    'scanned_pages': 7,
    'ai_tutorial_tokens': 12345,
    'some_new_thing': 9,
  },
  'agoraMinutes': 62,
};

/// A server that answers the two routes, records every request, and can be
/// told to refuse the first [failFirst] of them.
class FakeBillingServer {
  FakeBillingServer({this.failFirst = 0});
  final int failFirst;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    if (requests.length <= failFirst) {
      return http.Response('{"error":"down"}', 500);
    }
    final body = switch (request.url.path) {
      '/billing/entitlements' => _entitlements,
      '/billing/usage/me' => _own,
      _ => null,
    };
    if (body == null) return http.Response('{"error":"Not found"}', 404);
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Future<FakeBillingServer> pumpUsage(WidgetTester tester,
    {Size size = const Size(360, 640), int failFirst = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = FakeBillingServer(failFirst: failFirst);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    // A fresh State per pump: the same widget type would keep the last one.
    home:
        UsageScreen(key: UniqueKey(), session: _session, client: server.client),
  ));
  await tester.pumpAndSettle();
  return server;
}

String rowValue(WidgetTester tester, String key) {
  final row = find.byKey(Key(key));
  expect(row, findsOneWidget, reason: key);
  final texts = tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((t) => t.data)
      .toList();
  return texts.last!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'asks the server for the plan and for its own usage, with the account\'s token',
      (tester) async {
    final server = await pumpUsage(tester);

    expect(server.requests.map((r) => r.url.path).toList(),
        ['/billing/entitlements', '/billing/usage/me']);
    for (final request in server.requests) {
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer tok',
          reason: request.url.path);
    }
  });

  testWidgets(
      'the plan card names the tier and the month the numbers count from',
      (tester) async {
    await pumpUsage(tester);
    expect(rowValue(tester, 'usage-tier'), 'Premium');
    expect(rowValue(tester, 'usage-since'), '1 September 2026');
  });

  testWidgets(
      'a limit reads used over limit; no limit reads the count and says so',
      (tester) async {
    await pumpUsage(tester);
    expect(rowValue(tester, 'usage-quota-ai_tutorials'), '2 / 30');
    expect(rowValue(tester, 'usage-quota-ai_review_words'), '5 · No limit');
    // Over the limit is still the truth, said as it is; only the bar clamps.
    expect(rowValue(tester, 'usage-quota-assignments'), '12 / 5');
    expect(find.text('Homework sent (per student)'), findsOneWidget);
    expect(find.text('AI tutorials'), findsOneWidget);

    final bars = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bars.map((b) => b.value).toList(), [2 / 30, 1.0],
        reason: 'one bar per limited quota, the unlimited one has none');
  });

  testWidgets(
      'what has no limit is said in the reader\'s units, and a quota metric is never listed twice',
      (tester) async {
    await pumpUsage(tester);
    expect(rowValue(tester, 'usage-metric-agora_seconds'), '62 min',
        reason: 'the server\'s rounded-up minutes, not seconds');
    expect(rowValue(tester, 'usage-metric-mp4_renders'), '3');
    expect(rowValue(tester, 'usage-metric-mp4_render_seconds'), '3 min',
        reason:
            '130 seconds is three minutes, rounded up as the provider bills');
    expect(rowValue(tester, 'usage-metric-tts_characters'), '2,500 characters',
        reason:
            'Azure and piper together — which voice spoke is not the reader\'s business');
    expect(rowValue(tester, 'usage-metric-scanned_pages'), '7');
    expect(
        rowValue(tester, 'usage-metric-ai_tutorial_tokens'), '12,345 tokens');
    // A counter this screen has no words for is still shown.
    expect(rowValue(tester, 'usage-metric-some_new_thing'), '9');
    expect(find.text('Some new thing'), findsOneWidget);
    // ai_tutorials is a quota: once under Monthly limits, never under Also counted.
    expect(find.byKey(const Key('usage-metric-ai_tutorials')), findsNothing);
    expect(find.byKey(const Key('usage-quota-ai_tutorials')), findsOneWidget);

    // The rows are in the fixed order, the unknown one last.
    final keys = tester
        .widgetList(find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('usage-metric-')))
        .map((w) => (w.key as ValueKey<String>).value)
        .toList();
    expect(keys, [
      'usage-metric-agora_seconds',
      'usage-metric-mp4_renders',
      'usage-metric-mp4_render_seconds',
      'usage-metric-tts_characters',
      'usage-metric-scanned_pages',
      'usage-metric-ai_tutorial_tokens',
      'usage-metric-some_new_thing',
    ]);
  });

  testWidgets('a server that does not answer says so, and Try again asks again',
      (tester) async {
    final server = await pumpUsage(tester, failFirst: 1);

    expect(find.byKey(const Key('usage-error')), findsOneWidget);
    expect(find.byKey(const Key('usage-tier')), findsNothing);
    expect(server.requests.length, 1,
        reason: 'the second request is not made once the first was refused');

    await tester.tap(find.byKey(const Key('usage-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('usage-error')), findsNothing);
    expect(rowValue(tester, 'usage-tier'), 'Premium');
    expect(server.requests.length, 3);
  });

  testWidgets('nothing overflows on a 360 dp phone or a 1200 px window',
      (tester) async {
    for (final size in const [Size(360, 640), Size(1200, 800)]) {
      await pumpUsage(tester, size: size);
      expect(find.byKey(const Key('usage-quota-assignments')), findsOneWidget,
          reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('an account with nothing counted is told so', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async => http.Response(
        jsonEncode(request.url.path == '/billing/entitlements'
            ? {'tier': 'free', 'entitlements': [], 'quotas': {}}
            : {'metrics': {}, 'agoraMinutes': 0}),
        200));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: UsageScreen(session: _session, client: client),
    ));
    await tester.pumpAndSettle();

    expect(rowValue(tester, 'usage-tier'), 'Free');
    expect(find.byKey(const Key('usage-nothing-counted')), findsOneWidget);
    expect(find.text('Monthly limits'), findsNothing,
        reason: 'a plan with no limits has no limits card');
  });

  test('the words for the wire: counts, names and units', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(1000), '1,000');
    expect(formatCount(1234567), '1,234,567');
    expect(humanise('ai_review_words'), 'Ai review words');
    expect(tierLabel('club'), 'Club');
    expect(monthStartLabel(DateTime.utc(2026, 1, 1)), '1 January 2026');
    expect(orderedMetrics(['zz_later', 'assignments', 'ai_tutorials']),
        ['ai_tutorials', 'assignments', 'zz_later']);

    final rows = countedRows(MonthlyUsage(
      tier: 'free',
      periodStart: DateTime.utc(2026, 9, 1),
      quotas: const {},
      metrics: const {'mp4_render_seconds': 60, 'tts_windows_characters': 40},
      voiceMinutes: 0,
    ));
    expect(rows.map((r) => '${r.label}: ${r.value}').toList(), [
      'Video rendered: 1 min',
      'Narration spoken by a voice: 40 characters'
    ]);
  });

  group('the door in Settings', () {
    Future<GoRouter> pumpSettings(
        WidgetTester tester, UserSession session) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: AppRoutes.preferences,
        routes: [
          GoRoute(
            path: AppRoutes.preferences,
            builder: (context, state) => SettingsScreen(session: session),
          ),
          GoRoute(
            path: AppRoutes.usage,
            builder: (context, state) => const Scaffold(
              body: Text('USAGE SCREEN MARKER'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      return router;
    }

    /// Settings is a lazy list: a row below the fold is not built at all, so
    /// „findsNothing" at the bottom of the list says nothing about a row that
    /// belongs in its middle. An absence claim stands where the row would be
    /// drawn: with the account card above its place and the engine header
    /// below it both built, the row between them is built too — if it exists.
    /// (The first draft scrolled to the end and let „draw it for guests too"
    /// survive.)
    Future<void> scrollToTheAccountCard(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.text('Account statistics'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(find.text('Account statistics'), findsOneWidget,
          reason: 'the card above the row\'s place is built');
      expect(find.text('STOCKFISH ENGINE'), findsOneWidget,
          reason: 'and the header below it');
    }

    testWidgets('a signed-in account has a row that opens the usage screen',
        (tester) async {
      await pumpSettings(tester, _session);
      await scrollToTheAccountCard(tester);
      final door = find.byKey(const Key('open-usage'));
      expect(door, findsOneWidget);
      expect(find.text('Usage this month'), findsOneWidget);

      await tester.tap(door);
      await tester.pumpAndSettle();

      expect(find.text('USAGE SCREEN MARKER'), findsOneWidget);
    });

    testWidgets('a guest has no such row: there is no account to have counted',
        (tester) async {
      final guest = UserSession(
          token: '', id: 0, email: '', name: 'Guest', role: 'korisnik');
      await pumpSettings(tester, guest);
      await scrollToTheAccountCard(tester);
      expect(find.byKey(const Key('open-usage')), findsNothing);
      expect(find.text('Usage this month'), findsNothing);
    });
  });
}
