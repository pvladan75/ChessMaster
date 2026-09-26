// The map beside the board, and the title in the bar — phase 4 of
// `docs/PLAN-MAPA-DELOVA.md`.
//
// **Widths from the band, not round numbers.** The board is
// `min(W − 496, H − 120)` of the body (the formula this phase leaves alone),
// and the map gets its own column when the board pane has room beyond the
// board for it and the gap: 380 + 12 (`AppSpacing.md` is 12 — the plan wrote
// 16 and was wrong). At the owner's body height of 736 the board is 616, so the
// column appears from W = 1504, and 1503 is one pixel short. Every case asks
// that the board is exactly the formula's size, so no window buys the map a
// column with the board.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

import 'support/landscape.dart' show loadRoboto;
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

  setUpAll(loadRoboto);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  var nextLessonId = 900;

  /// The bar's height, which the window's height pays before the body.
  const bar = kToolbarHeight;

  Future<void> open(WidgetTester tester, Size body, {String? title}) async {
    tester.view.physicalSize = Size(body.width, body.height + bar);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved({
          'id': nextLessonId++,
          'title': title ?? 'Broken Pawns',
          'position_list': sketchDraft().positionList,
        }),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The board card's side — what the formula sizes. (The board inside it is
  /// the card less its frame and coordinates, which is not linear in it.)
  double boardSide(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('board-card'))).width;

  /// The board's formula, as the screen writes it.
  double formula(Size body) {
    final pane = body.width - 460 - 12 * 3;
    return pane.clamp(280.0, (body.height - 120).clamp(280.0, double.infinity));
  }

  final cases = <({Size body, bool column, String why})>[
    (body: const Size(1536, 736), column: true, why: "the owner's window"),
    (body: const Size(1504, 736), column: true, why: 'the narrowest with it'),
    (body: const Size(1503, 736), column: false, why: 'one pixel short'),
    (body: const Size(1366, 768 - bar), column: false, why: '1366 × 768'),
    (body: const Size(900, 700 - bar), column: false, why: '900 × 700'),
  ];

  for (final c in cases) {
    testWidgets(
        '${c.body.width.toInt()} × ${c.body.height.toInt()} body, ${c.why}: '
        '${c.column ? 'the map beside the board' : 'the map in the pane'}',
        (tester) async {
      await open(tester, c.body);

      expect(find.byKey(const Key('map-column')),
          c.column ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('sections-half')),
          c.column ? findsNothing : findsOneWidget,
          reason: 'the map is in exactly one place');
      if (c.column) {
        expect(tester.getSize(find.byKey(const Key('map-column'))).width, 380);
      }
      // The formula's size, the same with the column and without.
      expect(boardSide(tester), formula(c.body),
          reason: 'the board is not the size its own formula gives');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('at the owner\'s window the board is 616', (tester) async {
    // The number the plan was written from, held so a change to the formula
    // cannot quietly move the band this file stands on.
    expect(formula(const Size(1536, 736)), 616);
    await open(tester, const Size(1536, 736));
    expect(boardSide(tester), 616);
  });

  testWidgets('a 60-character title is whole in the bar at 1536',
      (tester) async {
    const title =
        'Broken Pawns and the Bishop Pair: a Game Against Kramnik 123';
    expect(title.length, 60);
    await open(tester, const Size(1536, 736), title: title);

    final field = find.descendant(
        of: find.byKey(const Key('tutorial-title')),
        matching: find.byType(EditableText));
    final editable = tester.widget<EditableText>(field);
    // Rule 8: the family the width was measured in. Roboto travels with the
    // tests; the app draws in Segoe UI on Windows, which is wider by a few per
    // cent, so the title must fit with a fifth to spare.
    expect(editable.style.fontFamily, 'Roboto');
    final painter = TextPainter(
      text: TextSpan(text: title, style: editable.style),
      textDirection: TextDirection.ltr,
    )..layout();
    final room = tester.getSize(field).width;
    expect(painter.width * 1.2, lessThan(room),
        reason: 'the title is ${painter.width} px wide in a $room px field');
    expect(editable.controller.text, title);
  });

  testWidgets('the strip under the board says which part', (tester) async {
    await open(tester, const Size(1536, 736));
    await tester.tap(find.byKey(const Key('part-row-2')));
    await tester.pumpAndSettle();

    final strip = tester.widget<MoveNavigationControls>(
        find.byType(MoveNavigationControls).first);
    expect(strip.centerLabel, 'Part 3 of 8');
  });

  testWidgets('the open part\'s header names it and acts on it',
      (tester) async {
    await open(tester, const Size(1536, 736));
    await tester.tap(find.byKey(const Key('part-row-3')));
    await tester.pumpAndSettle();

    expect(find.text('Part 4 of 8 · back to after 18. Rfe1'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('open-part-name'))).data,
        'Black can also defend with h6.');
    final header = find.byKey(const Key('open-part-header'));
    // Down, not up: moved above part 3 it would open before the position it
    // goes back to was ever shown, and be a new board.
    await tester.tap(
        find.descendant(of: header, matching: find.byTooltip('Move down')));
    await tester.pumpAndSettle();
    expect(find.text('Part 5 of 8 · back to after 18. Rfe1'), findsOneWidget,
        reason: 'the header\'s own button moved the part it names');
  });
}
