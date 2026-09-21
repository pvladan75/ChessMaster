// `docs/PLAN-POCETNI-TABOVI.md`, phase 3 — the Home tab uses the width it is
// given: sections stack, their contents flow.
//
// Every layout claim is read from where things are painted. The Trainer panel
// is pumped with fourteen rows under one heading, because „the rows flow" is a
// claim about a count of lines, and a fixture with two rows fits one line at
// every width that has two columns — it could not tell three columns from
// four (rule 6).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/home/dashboard_tab.dart';

const _reviewCount = 14;

final _panel = TrainerPanel(
  awaitingReview: [
    for (var i = 0; i < _reviewCount; i++)
      PanelAssignment(
        id: 100 + i,
        title: 'Set $i',
        studentId: 10 + i,
        studentName: 'Student $i',
        totalItems: 12,
        attemptedItems: 12,
        solvedItems: 9,
        completedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
  ],
);

final _recordings = [
  for (var i = 0; i < 4; i++)
    {
      'id': 500 + i,
      'title': 'Recording $i',
      'created_at': '2026-09-2${i}T10:00:00Z',
      'duration': 600,
    },
];

/// The tab inside a box exactly [width] wide, in a window of [window] — the
/// two differ in one case, which is how reading the window gets caught.
Future<void> _pump(WidgetTester tester, double width,
    {Size window = const Size(1920, 3000)}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: HomeDashboardTab(
            userName: 'Trainer',
            codeController: TextEditingController(),
            recordings: _recordings,
            isLoadingRecordings: false,
            panel: _panel,
            onEnterLesson: (_) {},
            onOpenPanelAssignment: (_) {},
            onOpenStudent: (_, __) {},
            hasTrainer: true,
            onOpenAssignments: () {},
            onOpenReviews: () {},
            dueReviewCount: 3,
            onJoinRoom: (_) {},
            onRefreshRecordings: () {},
            onOpenReplay: (_) {},
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The card a heading sits in — the nearest `Card` above it.
Rect _card(WidgetTester tester, String heading) => tester.getRect(
    find.ancestor(of: find.text(heading), matching: find.byType(Card)).first);

/// Every „Review" button of the panel, one per row.
List<Rect> _reviewButtons(WidgetTester tester) => [
      for (final e
          in find.widgetWithText(ElevatedButton, 'Review').evaluate().toList())
        tester.getRect(find.byWidget(e.widget)),
    ];

/// Every „Play" button of the recordings, one per recording.
List<Rect> _playButtons(WidgetTester tester) => [
      for (final e in find.text('Play').evaluate().toList())
        tester.getRect(find.byWidget(e.widget)),
    ];

int _distinct(Iterable<double> xs) => xs.map((x) => x.round()).toSet().length;

const _shortcuts = ['Set for me', 'Due for review', 'Join a session'];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the three shortcut cards share one row on a wide screen',
      (tester) async {
    await _pump(tester, 1400);
    final s = _card(tester, 'Set for me');
    final d = _card(tester, 'Due for review');
    final j = _card(tester, 'Join a session');
    expect(d.top, s.top, reason: '„Due for review" is not beside „Set for me"');
    expect(j.top, s.top, reason: '„Join a session" is not in the same row');
    expect(d.left, greaterThan(s.right));
    expect(j.left, greaterThan(d.right));
    // „Join a session" holds a field and a button, its neighbours one line of
    // text; the row still ends on one line.
    expect(d.height, s.height, reason: 'the row ends at two heights');
    expect(j.height, s.height, reason: 'the row ends at two heights');
    // No line of prose wider than a card — the reason the cap existed.
    for (final r in [s, d, j]) {
      expect(r.width, lessThanOrEqualTo(AdaptiveCardGrid.maxTileWidth));
    }
  });

  testWidgets('fourteen review rows take ⌈14 / columns⌉ lines', (tester) async {
    await _pump(tester, 1400);
    final flow = tester.getRect(find.byKey(const Key('panel-flow-To review')));
    final columns = AdaptiveCardGrid.columnsFor(flow.width);
    expect(columns, greaterThan(1), reason: 'the fixture proves nothing at 1');

    final rows = _reviewButtons(tester);
    expect(rows, hasLength(_reviewCount));
    expect(_distinct(rows.map((r) => r.left)), columns,
        reason: 'the rows are not in as many columns as fit');
    expect(_distinct(rows.map((r) => r.top)), (_reviewCount / columns).ceil(),
        reason: 'the rows do not fill line after line');
  });

  testWidgets('the recordings are cards in columns', (tester) async {
    await _pump(tester, 1400);
    final plays = _playButtons(tester);
    expect(plays, hasLength(_recordings.length));
    expect(plays[1].top, plays[0].top,
        reason: 'the second recording is not beside the first');
    expect(plays[1].left, greaterThan(plays[0].right));
  });

  testWidgets('a phone gets one card per line, in today\'s order',
      (tester) async {
    await _pump(tester, 360, window: const Size(360, 3000));
    for (var i = 1; i < _shortcuts.length; i++) {
      final above = _card(tester, _shortcuts[i - 1]);
      final below = _card(tester, _shortcuts[i]);
      expect(below.top, greaterThanOrEqualTo(above.bottom),
          reason: '„${_shortcuts[i]}" is not under „${_shortcuts[i - 1]}"');
      expect(below.left, above.left);
    }
    final rows = _reviewButtons(tester);
    expect(_distinct(rows.map((r) => r.left)), 1);
    expect(_distinct(rows.map((r) => r.top)), _reviewCount);
    final plays = _playButtons(tester);
    expect(_distinct(plays.map((r) => r.left)), 1);
    expect(_distinct(plays.map((r) => r.top)), _recordings.length);
  });

  testWidgets('decided from the box the tab is given, not the window',
      (tester) async {
    // A 1920 window with the tab in a 420 box: one column is all that fits.
    await _pump(tester, 420);
    final s = _card(tester, 'Set for me');
    final d = _card(tester, 'Due for review');
    expect(d.top, greaterThanOrEqualTo(s.bottom),
        reason: 'the tab read the window and put two cards in 420 px');
    expect(_distinct(_reviewButtons(tester).map((r) => r.left)), 1);
  });

  testWidgets('nothing overflows at 360, 900 and 1920', (tester) async {
    for (final w in [360.0, 900.0, 1920.0]) {
      await _pump(tester, w, window: Size(w, 3000));
      expect(tester.takeException(), isNull, reason: 'at $w');
      for (final heading in [..._shortcuts, 'Trainer panel', 'Recordings']) {
        expect(find.text(heading), findsOneWidget, reason: 'at $w');
      }
    }
  });
}
