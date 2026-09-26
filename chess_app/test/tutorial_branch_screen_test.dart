// A tutorial's branches on the screen — phase 2 of
// `docs/PLAN-REDOSLED-GRANA.md`. The rule is held in
// `tutorial_branch_order_test.dart`; this holds the doors to it: the Tree tab,
// which now draws the open part's whole family, and a map row, which is the
// phone's way in (it has no Tree tab).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_controller.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';

import 'support/tutorial_part_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  var nextLessonId = 1200;

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved({
          'id': nextLessonId++,
          'title': 'Broken Pawns',
          'position_list': sketchDraft().positionList,
        }),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String kind(WidgetTester tester, int row) =>
      tester.widget<Text>(find.byKey(Key('part-kind-$row'))).data!;

  /// The Tree tab, in its notation view — every move on the page, none of it
  /// out of a canvas's view.
  Future<Finder> treeMove(WidgetTester tester, String san) async {
    await tapKey(tester, 'stablo-tab');
    final tree = find.byType(AnalysisMoveTreeWidget);
    await tester.tap(find.descendant(of: tree, matching: find.text('PGN')));
    await tester.pumpAndSettle();
    final move = find
        .descendant(
            of: tree, matching: find.textContaining(san, findRichText: true))
        .first;
    await tester.ensureVisible(move);
    await tester.pumpAndSettle();
    return move;
  }

  group('the Tree tab', () {
    testWidgets('draws the family, and moves a branch from a move of it',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await open(tester, const Size(1700, 900));
        await tapKey(tester, 'part-row-2'); // part 3, the best line

        final be3 = await treeMove(tester, 'Be3');
        expect(find.textContaining('Bc1', findRichText: true), findsWidgets,
            reason: 'part 6 leaves 16... Nc4 too, and is drawn there');
        await tester.longPress(be3);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('move-menu-promote')), findsNothing,
            reason: 'between parts, order is the only thing to change');
        await tester.tap(find.byKey(const Key('move-menu-earlier')));
        await tester.pumpAndSettle();

        expect(kind(tester, 1), '2 · continues',
            reason: 'part 5 now opens where part 1 ended');
        expect(kind(tester, 2), '3 · back to after 16... Nc4');
        expect(kind(tester, 3), startsWith('4 · continues · you are here'),
            reason: 'the part that was open is open, one place on');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a move of another part opens that part', (tester) async {
      await open(tester, const Size(1700, 900));
      await tapKey(tester, 'part-row-2');

      final be3 = await treeMove(tester, 'Be3');
      await tester.tap(be3);
      await tester.pumpAndSettle();

      expect(
          find.text('Part 5 of 8 · back to after 16... Nc4'), findsOneWidget);
    });
  });

  testWidgets('on a phone, a map row\'s long press moves its branch',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await open(tester, const Size(360, 640));
      await tapKey(tester, 'phone-tab-parts');
      await tester.ensureVisible(find.byKey(const Key('phone-part-4')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('phone-part-4')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('move-menu-later')), findsOneWidget);
      await tester.tap(find.byKey(const Key('move-menu-earlier')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('part-kind-1')));
      await tester.pumpAndSettle();
      expect(kind(tester, 1), startsWith('2 · continues'));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('one undo takes a branch move back', () {
    final draft = sketchDraft();
    final before = [...draft.sections];
    final c = TutorialDraftController(draft: draft);

    c.moveBranch(4, earlier: true);
    expect(identical(c.draft.sections[1], before[4]), isTrue);
    c.undo();

    // A restore rebuilds the parts from a snapshot, so they are compared by
    // what they are: where each starts, and its first move if it has one.
    String what(p) =>
        '${p.root.fen} ${p.root.children.isEmpty ? '-' : p.root.children.first.moveSan}';
    expect([for (final p in c.draft.sections) what(p)],
        [for (final p in before) what(p)]);
  });
}
