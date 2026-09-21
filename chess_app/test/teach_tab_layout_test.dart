// `docs/PLAN-POCETNI-TABOVI.md`, phase 2 — the Teach tab uses the width it is
// given: sections stack, their contents flow.
//
// Every layout claim is read from where the cards are painted. The tab is
// pumped with its real cards — the tutorial card, the homework card and the
// people card — because the claim is about those cards lining up, and a
// placeholder of one height could not fail the „as tall as its neighbours"
// check (rule 6).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/homework/widgets/homework_library_card.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/home/friends_tab.dart';
import 'package:chess_app/widgets/home/teach_tab.dart';

UserSession _session() => UserSession(
      token: 'tok',
      id: 1,
      email: 't@example.com',
      name: 'Trainer',
      role: 'trener',
    );

const _students = [
  {'id': 11, 'name': 'Ana', 'status': 'accepted'},
  {'id': 12, 'name': 'Boris', 'status': 'accepted'},
  {'id': 13, 'name': 'Cvijeta', 'status': 'accepted'},
  {'id': 14, 'name': 'Dušan', 'status': 'pending', 'i_asked': true},
];

/// The tab inside a box exactly [width] wide, in a window of [window] — the
/// two differ in one case, which is how reading the window gets caught.
Future<void> _pump(WidgetTester tester, double width,
    {Size window = const Size(1920, 1400)}) async {
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
          child: TeachTab(
            tutorialCard: TutorialLibraryCard(session: _session()),
            homeworkCard: HomeworkLibraryCard(session: _session()),
            onOpenPreparation: () {},
            onStartSession: () {},
            onOpenLibrary: () {},
            studentsSection: HomeFriendsTab(
              embedded: true,
              studentEmailController: TextEditingController(),
              isLoadingStudents: false,
              students: _students,
              trainers: const [],
              iAmTrainerInRequest: true,
              onRoleChanged: (_) {},
              onRefresh: () async {},
              onAddStudent: () {},
              onDeleteStudent: (_) {},
              onOpenProgress: (_) {},
              onFixParentEmail: () {},
            ),
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

Rect _row(WidgetTester tester, String name) => tester.getRect(
    find.ancestor(of: find.text(name), matching: find.byType(ListTile)));

const _order = [
  'Tutorials',
  'Homework',
  'Library',
  'Preparation',
  'New session',
];

void main() {
  testWidgets('what a trainer makes and keeps shares one row on a wide screen',
      (tester) async {
    await _pump(tester, 1400);
    final t = _card(tester, 'Tutorials');
    final h = _card(tester, 'Homework');
    final l = _card(tester, 'Library');
    expect(h.top, t.top, reason: 'Homework is not beside Tutorials');
    expect(l.top, t.top, reason: 'Library is not beside Homework');
    expect(h.left, greaterThan(t.right));
    expect(l.left, greaterThan(h.right));
    // The tutorial card has three buttons and its neighbours one; they still
    // end on one line.
    expect(h.height, t.height, reason: 'the row ends at two heights');
    expect(l.height, t.height, reason: 'the row ends at two heights');
  });

  testWidgets('the two live cards share the next row', (tester) async {
    await _pump(tester, 1400);
    final p = _card(tester, 'Preparation');
    final s = _card(tester, 'New session');
    expect(s.top, p.top);
    expect(s.left, greaterThan(p.right));
    expect(p.top, greaterThan(_card(tester, 'Tutorials').bottom),
        reason: 'the live cards are not a row of their own under the first');
  });

  testWidgets('a phone gets one card per line, Library beside what it keeps',
      (tester) async {
    await _pump(tester, 360, window: const Size(360, 1400));
    for (var i = 1; i < _order.length; i++) {
      final above = _card(tester, _order[i - 1]);
      final below = _card(tester, _order[i]);
      expect(below.top, greaterThanOrEqualTo(above.bottom),
          reason: '„${_order[i]}" is not under „${_order[i - 1]}"');
      expect(below.left, above.left);
    }
  });

  testWidgets('decided from the box the tab is given, not the window',
      (tester) async {
    // A 1920 window with the tab in a 400 box. The tab before this plan read
    // `Breakpoints.isWide` — the window — and drew the live cards side by
    // side at 190 px each.
    await _pump(tester, 400);
    final p = _card(tester, 'Preparation');
    final s = _card(tester, 'New session');
    expect(s.top, greaterThanOrEqualTo(p.bottom),
        reason: 'the tab read the window and put two cards in 400 px');
  });

  testWidgets('the request form sits beside the people on a wide screen',
      (tester) async {
    await _pump(tester, 1400);
    final form = tester.getRect(find.byKey(const Key('people-request-form')));
    final lists = tester.getRect(find.byKey(const Key('people-lists')));
    expect(lists.top, form.top, reason: 'the form is not beside the lists');
    expect(lists.left, greaterThan(form.right));
    expect(form.width, lessThan(lists.width),
        reason: 'the form took more than its one column');
  });

  testWidgets('and above them on a phone', (tester) async {
    await _pump(tester, 360, window: const Size(360, 1400));
    final form = tester.getRect(find.byKey(const Key('people-request-form')));
    final lists = tester.getRect(find.byKey(const Key('people-lists')));
    expect(lists.top, greaterThan(form.bottom));
  });

  testWidgets('the people flow into columns where there is room',
      (tester) async {
    await _pump(tester, 1400);
    final a = _row(tester, 'Ana');
    final b = _row(tester, 'Boris');
    expect(b.top, a.top, reason: 'the second student is not beside the first');
    expect(b.left, greaterThan(a.right));
  });

  testWidgets('nothing overflows at 360, 900 and 1920', (tester) async {
    for (final w in [360.0, 900.0, 1920.0]) {
      await _pump(tester, w, window: Size(w, 1400));
      expect(tester.takeException(), isNull, reason: 'at $w');
      for (final heading in _order) {
        expect(find.text(heading), findsOneWidget, reason: 'at $w');
      }
    }
  });
}
