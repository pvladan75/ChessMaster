import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/shortcuts_screen.dart';
import 'package:chess_app/screens/usage_screen.dart';

import 'support/landscape.dart' show loadRoboto;

/// Keyboard Shortcuts and Usage this month laid out the way Settings is
/// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md` §8): their cards flow into columns,
/// and a phone keeps one.
void main() {
  setUpAll(loadRoboto);

  final client = MockClient((request) async {
    final body = switch (request.url.path) {
      '/billing/entitlements' => {
          'tier': 'pro',
          'quotas': {
            'ai_tutorials': {'limit': 100, 'used': 19},
            'assignments': {'limit': -1, 'used': 4},
          },
          'periodStart': '2026-09-01T00:00:00.000Z',
        },
      _ => {
          'periodStart': '2026-09-01T00:00:00.000Z',
          'metrics': {
            'agora_seconds': 840,
            'mp4_renders': 83,
            'tts_azure_characters': 25206,
            'scanned_pages': 972,
            'ai_tutorial_tokens': 267745,
            'some_new_thing': 9,
          },
          'agoraMinutes': 14,
        },
    };
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });

  Future<void> open(WidgetTester tester, Size size, Widget screen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: screen,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget usage() => UsageScreen(
        session: UserSession(
            token: 't', id: 1, email: 'a@example.com', name: 'A', role: 'k'),
        client: client,
      );

  /// The distinct left edges the cards are painted at.
  Set<double> cardLefts(WidgetTester tester) => {
        for (final e in find.byType(Card).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dx.roundToDouble(),
      };

  for (final (size, columns) in const [
    (Size(1536, 792), 4),
    (Size(900, 700), 3),
    (Size(360, 640), 1),
  ]) {
    testWidgets('shortcuts at ${size.width.toInt()}: $columns column(s)',
        (tester) async {
      await open(tester, size, const ShortcutsScreen());
      expect(cardLefts(tester), hasLength(columns));
    });

    testWidgets('usage at ${size.width.toInt()}: $columns column(s)',
        (tester) async {
      await open(tester, size, usage());
      expect(cardLefts(tester), hasLength(columns));
    });
  }

  for (final size in const [
    Size(360, 640),
    Size(900, 700),
    Size(1536, 792),
    Size(1920, 1080),
  ]) {
    testWidgets('nothing overflows at ${size.width.toInt()}', (tester) async {
      await open(tester, size, const ShortcutsScreen());
      expect(tester.takeException(), isNull);
      await open(tester, size, usage());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the tab keys name the tabs the app has', (tester) async {
    await open(tester, const Size(1536, 792), const ShortcutsScreen());
    // Literals, not the list they are read from: a test that reads the
    // constant it tests follows it wherever it moves.
    for (final name in ['Home.', 'Practise.', 'Analyse.', 'Teach.']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Training.'), findsNothing);
  });

  testWidgets('a sentence stays inside its own card, whatever the window',
      (tester) async {
    await open(tester, const Size(1536, 792), const ShortcutsScreen());
    for (final what in [
      'Closes whatever is open over current work.',
      'Tablebase findings, or Hide findings, while playing out the position.',
    ]) {
      final text = tester.getRect(find.text(what));
      final card = tester.getRect(
          find.ancestor(of: find.text(what), matching: find.byType(Card)));
      expect(text.right, lessThanOrEqualTo(card.right), reason: what);
    }
  });

  testWidgets(
      'what is counted is two cards by kind, and a counter nobody named goes '
      'with the second', (tester) async {
    await open(tester, const Size(1536, 792), usage());

    Finder inCard(String title, String key) => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
        matching: find.byKey(Key(key)));

    const media = 'Also counted: sessions and video';
    const other = 'Also counted: AI and scanning';
    expect(inCard(media, 'usage-metric-agora_seconds'), findsOneWidget);
    expect(inCard(media, 'usage-metric-mp4_renders'), findsOneWidget);
    expect(inCard(media, 'usage-metric-tts_characters'), findsOneWidget);
    expect(inCard(other, 'usage-metric-scanned_pages'), findsOneWidget);
    expect(inCard(other, 'usage-metric-ai_tutorial_tokens'), findsOneWidget);
    expect(inCard(other, 'usage-metric-some_new_thing'), findsOneWidget);
  });
}
