// The order of variations — phase 1 of `docs/PLAN-REDOSLED-GRANA.md`.
//
// A move's variations were kept in the order they were played, and the only
// way to change it was „Promote to Main Line". „Move variation earlier / later"
// is now in the one menu both views of the tree open: by a long press on a
// phone, and by a right click on the desktop, where it is a menu at the
// pointer. Nothing passes the main line (D4), and an item that cannot do
// anything is not drawn (rule 15).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/tutorial_part_fixtures.dart';

/// 1. e4 and, after it, e5 (the main line), then c5 and e6 in the order they
/// were played.
AnalysisNode _tree() =>
    partOf(standardStart, '1. e4 e5 (1... c5 2. Nf3) (1... e6) *').root;

AnalysisNode _e4(AnalysisNode root) => root.children.single;

List<String> _replies(AnalysisNode root) =>
    [for (final c in _e4(root).children) c.moveSan!];

AnalysisNode _reply(AnalysisNode root, String san) =>
    _e4(root).children.singleWhere((c) => c.moveSan == san);

void main() {
  group('the tree', () {
    test('a variation moves one place, and nothing else changes', () {
      final root = _tree();
      final c5 = _reply(root, 'c5');
      final nf3 = c5.children.single;

      expect(_e4(root).moveVariation(c5, earlier: false), isTrue);
      expect(_replies(root), ['e5', 'e6', 'c5']);
      expect(identical(_reply(root, 'c5'), c5), isTrue);
      expect(identical(c5.children.single, nf3), isTrue,
          reason: 'the variation moves with everything under it');

      expect(_e4(root).moveVariation(c5, earlier: true), isTrue);
      expect(_replies(root), ['e5', 'c5', 'e6']);
    });

    test('nothing passes the main line, and the ends stay ends', () {
      final root = _tree();
      final e4 = _e4(root);
      expect(e4.canMoveVariation(_reply(root, 'e5'), earlier: true), isFalse);
      expect(e4.canMoveVariation(_reply(root, 'e5'), earlier: false), isFalse,
          reason: 'only „Promote to Main Line" changes which line is main');
      expect(e4.canMoveVariation(_reply(root, 'c5'), earlier: true), isFalse);
      expect(e4.canMoveVariation(_reply(root, 'e6'), earlier: false), isFalse);
      expect(e4.moveVariation(_reply(root, 'c5'), earlier: true), isFalse);
      expect(_replies(root), ['e5', 'c5', 'e6']);
    });

    test('the PGN writes the variations in the new order', () {
      final root = _tree();
      String pgn() => PgnExporterService.exportToPgn(root);
      expect(pgn().indexOf('c5'), lessThan(pgn().indexOf('e6')));
      _e4(root).moveVariation(_reply(root, 'e6'), earlier: true);
      expect(pgn().indexOf('e6'), lessThan(pgn().indexOf('c5')));
    });

    test('and the saved tree keeps it', () {
      final root = _tree();
      _e4(root).moveVariation(_reply(root, 'e6'), earlier: true);
      final back = AnalysisNode.fromJson(root.toJson());
      expect(_replies(back), ['e5', 'e6', 'c5']);
    });
  });

  group('the menu', () {
    Future<void> pumpTree(WidgetTester tester, AnalysisNode root,
        {bool withCommands = true, bool notation = false}) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AnalysisMoveTreeWidget(
              rootNode: root,
              activeNode: root,
              onSelectNode: (_) {},
              onMoveVariation: withCommands
                  ? (node, {required earlier}) => setState(() {
                        node.parent!.moveVariation(node, earlier: earlier);
                      })
                  : null,
              onPromoteNode: withCommands
                  ? (node) => setState(() {
                        node.parent!.promoteToMainLine(node);
                      })
                  : null,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      if (notation) {
        await tester.tap(find.text('PGN'));
        await tester.pumpAndSettle();
      }
    }

    Finder move(String san) =>
        find.textContaining(san, findRichText: true).first;

    Finder item(String key) => find.byKey(Key('move-menu-$key'));

    for (final notation in [false, true]) {
      final view = notation ? 'the notation' : 'the graph';

      testWidgets('$view: a long press on a phone offers what applies',
          (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final root = _tree();
          await pumpTree(tester, root, notation: notation);

          await tester.longPress(move('c5'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget,
              reason: 'a long press opens the sheet');
          expect(item('earlier'), findsNothing,
              reason: 'c5 is the first variation; the main line is not passed');
          expect(item('later'), findsOneWidget);
          await tester.tap(item('later'));
          await tester.pumpAndSettle();
          expect(_replies(root), ['e5', 'e6', 'c5']);

          await tester.longPress(move('e5'));
          await tester.pumpAndSettle();
          expect(item('earlier'), findsNothing);
          expect(item('later'), findsNothing,
              reason: 'the main line does not move this way');
          expect(item('promote'), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets(
          '$view: a right click on the desktop is a menu at the pointer',
          (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          final root = _tree();
          await pumpTree(tester, root, notation: notation);

          await tester.tap(move('e6'), buttons: kSecondaryButton);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing,
              reason: 'a desktop menu is not a sheet from the bottom');
          expect(item('earlier'), findsOneWidget);
          expect(item('later'), findsNothing,
              reason: 'e6 is the last variation');
          final at = tester.getTopLeft(item('earlier'));
          final clicked = tester.getCenter(move('e6'));
          expect((at - clicked).distance, lessThan(200),
              reason: 'the menu opens where the click was');

          await tester.tap(item('earlier'));
          await tester.pumpAndSettle();
          expect(_replies(root), ['e5', 'e6', 'c5']);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('a tree given no commands opens no menu with dead items',
        (tester) async {
      // The graph's menu drew „Promote to Main Line" and „Delete this
      // variation" whether or not the screen had given it anything to do —
      // the 7.9.2026 fault, one caller away.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpTree(tester, _tree(), withCommands: false);
        await tester.longPress(move('c5'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Promote to Main Line'), findsNothing);
        expect(find.text('Delete this variation'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('Analysis keeps the new order in its draft', (tester) async {
    SharedPreferences.setMockInitialValues({
      'analysis_studio_draft': jsonEncode({
        'tree': _tree().toJson(),
        'path': [0],
        'blackOrientation': false,
        'savedAt': DateTime(2026, 9, 26).toIso8601String(),
      }),
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: AnalysisStudioScreen(
          userSession: UserSession(
              token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik'),
        ),
      ));
      await tester.pumpAndSettle();

      // The notation view: in the graph, a pan-and-zoom canvas, e6 can lie
      // outside the visible part of the board's panel.
      final tree = find.byType(AnalysisMoveTreeWidget);
      await tester.tap(find.descendant(of: tree, matching: find.text('PGN')));
      await tester.pumpAndSettle();
      final e6 = find
          .descendant(
              of: tree, matching: find.textContaining('e6', findRichText: true))
          .first;
      await tester.ensureVisible(e6);
      await tester.pumpAndSettle();
      await tester.longPress(e6);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('move-menu-earlier')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      final kept = await tester.runAsync(AnalysisDraftService.instance.load);
      expect(_replies(kept!.rootNode), ['e5', 'e6', 'c5'],
          reason: 'the order was changed on screen and not kept');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
