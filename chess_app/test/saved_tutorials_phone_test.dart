// The Saved tutorials dialog on a phone — the owner's report of 17.9.2026:
// on a phone the list was empty while the same account on Windows showed
// every tutorial.
//
// The tutorials had loaded; the dialog gave them no height. Its content was
// capped at 400 dp, and the label chips drawn above the list take 48 dp each
// on Android (Flutter pads a chip to a touch target there, and not on a
// desktop). Fourteen labels wrapped into seven rows on a 411 dp phone, the
// search box and the chips overflowed the cap by 288 px, and the list got
// zero. A release build draws no overflow warning; it simply clips.
//
// Measured red on master at ce4998d with the owner's own fourteen labels.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_theme.dart';

/// The labels on the owner's screen, in the order it showed them.
const _labels = [
  'bishop pair',
  'calculation',
  'endgame',
  'forks',
  'French Defense',
  'king safety',
  'kingside attack',
  'mate',
  'missed chances',
  'opening',
  'pins',
  'Scandinavian Defense',
  'tactics',
  'turning point',
];

LessonApiService _api() => LessonApiService(
      authToken: 't',
      client: MockClient(
        (req) async => http.Response(
          jsonEncode([
            for (var i = 0; i < 10; i++)
              {
                'id': i + 1,
                'title': 'Tutorial $i',
                'tags': [
                  _labels[i % _labels.length],
                  _labels[(i + 4) % _labels.length],
                  _labels[(i + 9) % _labels.length],
                ],
                'position_list': [
                  {'id': 's$i', 'fen': '8/8/8/8/8/8/8/K6k w - - 0 1'},
                ],
              },
          ]),
          200,
        ),
      ),
    );

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    Size size,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TutorialLibraryCard(
              session: UserSession(
                token: 't',
                id: 1,
                email: 'e',
                name: 'n',
                role: 'x',
              ),
              api: _api(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Saved tutorials'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Inside the test: the binding checks the override before a tearDown runs.
    debugDefaultTargetPlatformOverride = null;
  }

  for (final (name, size) in [
    ('411 × 914', const Size(411, 914)),
    ('360 × 640', const Size(360, 640)),
  ]) {
    testWidgets('on a $name phone the tutorials are there to tap',
        (tester) async {
      await openDialog(tester, size, TargetPlatform.android);

      expect(tester.takeException(), isNull,
          reason: 'a release build clips this without a word');
      expect(find.text('Tutorial 0').hitTestable(), findsOneWidget,
          reason: 'the first tutorial must be on screen, not under the chips');
      final list = tester.getSize(find.byType(ListView));
      expect(list.height, greaterThanOrEqualTo(3 * 48.0),
          reason: 'room for at least three rows');
      // The chips are still offered, and still filter.
      expect(find.byType(FilterChip), findsWidgets);
      await tester.tap(find.widgetWithText(FilterChip, 'bishop pair'));
      await tester.pumpAndSettle();
      expect(find.text('Tutorial 0').hitTestable(), findsOneWidget);
      expect(find.text('Tutorial 1'), findsNothing);

      await close(tester);
    });
  }

  testWidgets('on Windows the dialog keeps its list as before', (tester) async {
    await openDialog(tester, const Size(1400, 900), TargetPlatform.windows);

    expect(tester.takeException(), isNull);
    expect(find.text('Tutorial 0').hitTestable(), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(_labels.length));

    await close(tester);
  });
}
