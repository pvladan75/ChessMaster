// The map of parts on the screen — phase 3 of `docs/PLAN-MAPA-DELOVA.md`.
//
// `tutorial_part_map_test.dart` holds what the map says; this holds the screen
// to it: what each row's painter is given, the open part followed wherever the
// selection goes, the two ways across a dashed edge (the chip in Flow and the
// header's link), and a phone at 360 × 640 measured with the real font —
// clipping is not overflow, so a line that must be read is asked whether it
// ran out of room.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_part_map.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_parts_map.dart';
import 'package:chess_app/models/user_session.dart';

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

  var nextLessonId = 700;

  Map<String, dynamic> lessonOf(TutorialDraft draft) => {
        'id': nextLessonId++,
        'title': 'Broken Pawns',
        'position_list': draft.positionList,
      };

  Future<void> open(WidgetTester tester, TutorialDraft draft, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lessonOf(draft)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// What row [row]'s painter was given — scrolled to first, because the
  /// desktop's list builds only the rows on screen.
  Future<PartGutter> gutterOf(WidgetTester tester, int row) async {
    final gutter = find.byKey(Key('part-gutter-$row'));
    final list = find.descendant(
        of: find.byType(TutorialPartsMap), matching: find.byType(Scrollable));
    // From the top every time: the search only scrolls down.
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(gutter, 40, scrollable: list);
    return (tester.widget<CustomPaint>(gutter).painter! as PartGutterPainter)
        .gutter;
  }

  /// Whether row [row] of the map is on screen inside the map.
  bool rowInView(WidgetTester tester, int row) {
    final rows = find.byKey(Key('part-row-$row'));
    if (rows.evaluate().isEmpty) return false;
    final map = tester.getRect(find.byType(TutorialPartsMap));
    final rect = tester.getRect(rows);
    return rect.top >= map.top - 0.5 && rect.bottom <= map.bottom + 0.5;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('what each row\'s painter is given', () {
    testWidgets('the sketch: squares, circles, solid and dashed',
        (tester) async {
      await open(tester, sketchDraft(), const Size(1600, 1400));

      expect([for (var r = 0; r < 8; r++) (await gutterOf(tester, r)).square],
          [true, false, false, false, false, false, false, true]);
      expect((await gutterOf(tester, 1)).arriving, [(lane: 0, dashed: false)],
          reason: 'part 2 continues part 1: a solid edge');
      expect((await gutterOf(tester, 3)).arriving, [(lane: 1, dashed: true)],
          reason: 'part 4 goes back: a dashed edge, one lane to the right');
      expect((await gutterOf(tester, 0)).open, isTrue);
      expect((await gutterOf(tester, 1)).open, isFalse);
      expect(tester.widget<Text>(find.byKey(const Key('part-kind-0'))).data,
          '1 · new board · you are here');
    });
  });

  group('across a dashed edge', () {
    /// Part 1 is a line; parts 2–30 are boards of their own, except part 27,
    /// which goes back to after 1. e4 in part 1.
    TutorialDraft thirty() {
      const others = [
        'a3', 'a4', 'b3', 'b4', 'c3', 'c4', 'd3', 'd4', 'f3', 'f4', 'g3', //
        'g4', 'h3', 'h4', 'Na3', 'Nc3', 'Nh3', 'a3 a6', 'a3 a5', 'a3 b6', //
        'a3 b5', 'a3 c6', 'a3 c5', 'a3 d6', 'a3 d5', 'a3 h6', 'a3 g6', //
        'a3 g5',
      ];
      final parts = [
        partOf(standardStart, '1. e4 e5 2. Nf3 *'),
        for (final line in others.take(25))
          partOf(fenAfter(standardStart, '1. $line *')),
        partOf(fenAfter(standardStart, '1. e4 *'), '1... c5 *'),
        for (final line in others.skip(25))
          partOf(fenAfter(standardStart, '1. $line *')),
      ];
      expect(parts, hasLength(30));
      return TutorialDraft(sections: parts);
    }

    testWidgets('the chip in Flow opens part 27, and its row comes into view',
        (tester) async {
      await open(tester, thirty(), const Size(840, 700));
      expect(rowInView(tester, 26), isFalse,
          reason: 'the case needs part 27 out of view to begin with');

      expect(find.text('Part 27 starts here · 1... c5'), findsOneWidget,
          reason: 'the beat part 27 goes back to says so');
      await tapKey(tester, 'part-starts-here-27');

      expect(tester.widget<Text>(find.byKey(const Key('part-kind-26'))).data,
          '27 · back to after 1. e4 · you are here',
          reason: 'the chip did not open part 27');
      expect(rowInView(tester, 26), isTrue,
          reason: 'the open part is out of view in the list of parts');
    });

    testWidgets('the header names where the part came from, and opens it',
        (tester) async {
      await open(tester, thirty(), const Size(840, 700));
      await tapKey(tester, 'part-starts-here-27');

      expect(find.text('Part 27 of 30 · back to after 1. e4'), findsOneWidget);
      expect(find.text('in part 1'), findsOneWidget);
      await tapKey(tester, 'part-header-source');

      expect(find.text('Part 1 of 30 · new board'), findsOneWidget,
          reason: 'the link did not open part 1');
      expect(rowInView(tester, 0), isTrue);
    });

    testWidgets('a part that continues links the part before it',
        (tester) async {
      final draft = sketchDraft()..selected = 2;
      await open(tester, draft, const Size(1600, 1400));
      // A saved tutorial opens on its first part; open part 3 by its row.
      await tester.tap(find.byKey(const Key('part-row-2')));
      await tester.pumpAndSettle();

      expect(find.text('Part 3 of 8 · continues from'), findsOneWidget);
      await tapKey(tester, 'part-header-source');
      expect(find.text('Part 2 of 8 · continues from'), findsOneWidget);
    });
  });

  group('on a phone, 360 × 640', () {
    testWidgets('every row reads whole, and nothing overflows', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await open(tester, sketchDraft(), const Size(360, 640));
        await tapKey(tester, 'phone-tab-parts');

        // Rule 8: say which font the lines were measured in.
        final family = tester
            .renderObject<RenderParagraph>(find.descendant(
                of: find.byKey(const Key('part-kind-0')),
                matching: find.byType(RichText)))
            .text
            .style
            ?.fontFamily;
        expect(family, 'Roboto');

        for (var i = 0; i < 8; i++) {
          for (final key in ['part-kind-$i', 'part-moves-$i']) {
            await tester.ensureVisible(find.byKey(Key(key)));
            await tester.pumpAndSettle();
            final line = tester.renderObject<RenderParagraph>(find.descendant(
                of: find.byKey(Key(key)), matching: find.byType(RichText)));
            expect(line.didExceedMaxLines, isFalse,
                reason: '$key: „${line.text.toPlainText()}" is cut short');
          }
        }
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
