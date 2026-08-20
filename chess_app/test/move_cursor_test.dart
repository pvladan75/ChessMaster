import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

MoveNode _treeChain(MoveNode root, List<String> sans) {
  var node = root;
  for (final san in sans) {
    final child =
        MoveNode(san: san, fen: node.fen, from: '', to: '', parent: node);
    node.children.add(child);
    node = child;
  }
  return node;
}

AnalysisNode _analysisChain(AnalysisNode root, List<String> sans) {
  var node = root;
  for (final san in sans) {
    node = node.addChild(childFen: root.fen, san: san, uci: san);
  }
  return node;
}

void main() {
  group('LinearMoveCursor', () {
    late List<int> seeks;
    LinearMoveCursor cursorAt(int index,
            {List<String>? fens, List<String> movesSan = const []}) =>
        LinearMoveCursor(
          fens: fens ?? const ['a', 'b', 'c'],
          movesSan: movesSan,
          index: index,
          onSeek: seeks.add,
        );

    setUp(() => seeks = []);

    test('the ends of the line disable the buttons that would leave it', () {
      expect(cursorAt(0).canGoBack, isFalse);
      expect(cursorAt(0).canGoForward, isTrue);
      expect(cursorAt(2).canGoBack, isTrue);
      expect(cursorAt(2).canGoForward, isFalse);
    });

    test('an empty line can go nowhere and has no position', () {
      final cursor = cursorAt(0, fens: const []);
      expect(cursor.canGoBack, isFalse);
      expect(cursor.canGoForward, isFalse);
      expect(cursor.currentFen, isNull);
    });

    test('the end is the last position, not the last label', () {
      // The two come from one parse and normally agree. If they ever did not,
      // taking the bound off the labels would walk past the last position the
      // screen can show — the whole point of reading it from the FENs.
      final cursor = cursorAt(0, movesSan: const ['e4']);
      cursor.last();
      expect(seeks, [2]);
    });

    test('walking asks the screen for the neighbouring position', () {
      cursorAt(1)
        ..first()
        ..previous()
        ..next()
        ..last();
      expect(seeks, [0, 0, 2, 2]);
    });

    test('chips are numbered from the starting position', () {
      final cursor = cursorAt(
        1,
        fens: const [_startFen, _startFen, _startFen],
        movesSan: const ['e4', 'e5'],
      );
      expect(cursor.line.map((s) => s.label), ['Početak', '1. e4', 'e5']);
      expect(cursor.line.map((s) => s.isCurrent), [false, true, false]);
    });

    test('without labels there are no chips, even though walking works', () {
      expect(cursorAt(1).line, isEmpty);
      expect(cursorAt(1).canGoForward, isTrue);
    });
  });

  group('MoveTreeCursor', () {
    test('the end of the line follows first children, not variations', () {
      final tree = MoveTree(startingFen: _startFen);
      final first = _treeChain(tree.root, ['e4']);
      _treeChain(first, ['e5', 'Nf3']);
      // A second answer to 1. e4, which "go to end" must not wander into.
      final sideline =
          MoveNode(san: 'c5', fen: first.fen, from: '', to: '', parent: first);
      first.children.add(sideline);

      MoveNode? selected;
      MoveTreeCursor(
        moveTree: tree,
        currentNode: first,
        onSelect: (node) => selected = node,
      ).last();

      expect(selected!.san, 'Nf3');
    });

    test('the start of the line is the root of the whole tree', () {
      final tree = MoveTree(startingFen: _startFen);
      final last = _treeChain(tree.root, ['e4', 'e5', 'Nf3']);

      MoveNode? selected;
      MoveTreeCursor(
        moveTree: tree,
        currentNode: last,
        onSelect: (node) => selected = node,
      ).first();

      expect(selected, same(tree.root));
    });

    test('the root can go forward but not back', () {
      final tree = MoveTree(startingFen: _startFen);
      _treeChain(tree.root, ['e4']);
      final cursor = MoveTreeCursor(
        moveTree: tree,
        currentNode: tree.root,
        onSelect: (_) {},
      );
      expect(cursor.canGoBack, isFalse);
      expect(cursor.canGoForward, isTrue);
    });
  });

  group('AnalysisNodeCursor', () {
    test('the start of the line is where it branched off, not move one', () {
      // The studio's "<<" has always meant this. Sharing one strip must not
      // quietly turn it into "back to the beginning of the game", which would
      // throw away the variation the user is standing in.
      final root = AnalysisNode(fen: _startFen);
      final branchPoint = _analysisChain(root, ['e4', 'e5', 'Nf3']);
      branchPoint.addChild(childFen: _startFen, san: 'Nc6', uci: 'b8c6');
      final inVariation =
          branchPoint.addChild(childFen: _startFen, san: 'd6', uci: 'd7d6');

      AnalysisNode? selected;
      AnalysisNodeCursor(
        currentNode: inVariation,
        onSelect: (node) => selected = node,
      ).first();

      expect(selected, same(branchPoint));
      expect(selected!.moveSan, 'Nf3');
    });

    test('with no branch on the way out, the start is the root', () {
      final root = AnalysisNode(fen: _startFen);
      final last = _analysisChain(root, ['e4', 'e5']);

      AnalysisNode? selected;
      AnalysisNodeCursor(
        currentNode: last,
        onSelect: (node) => selected = node,
      ).first();

      expect(selected, same(root));
    });
  });

  group('MoveNavigationControls', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a seat that may not drive the board gets dead buttons',
        (tester) async {
      var seeks = 0;
      await pump(
        tester,
        MoveNavigationControls(
          cursor: LinearMoveCursor(
            fens: const ['a', 'b', 'c'],
            index: 1,
            onSeek: (_) => seeks++,
          ),
          canNavigate: false,
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.first_page));
      expect(seeks, 0);
    });

    testWidgets('every button is still on screen on a narrow phone',
        (tester) async {
      // Nine buttons at a 48 dp touch target need more width than a phone has,
      // and the Analysis Studio has nine. A Row clips the rest — silently, in a
      // release build, where Flutter paints no overflow stripes and logs
      // nothing. Two of its buttons were simply unreachable on a phone.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pump(
        tester,
        MoveNavigationControls(
          cursor: LinearMoveCursor(
            fens: const ['a', 'b', 'c'],
            index: 1,
            onSeek: (_) {},
          ),
          centerLabel: null,
          onFlipBoard: () {},
          trailing: const [
            Icon(Icons.comment),
            Icon(Icons.auto_awesome),
            Icon(Icons.style),
            Icon(Icons.delete_outline),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      for (final icon in [
        Icons.first_page,
        Icons.chevron_left,
        Icons.chevron_right,
        Icons.last_page,
        Icons.comment,
        Icons.auto_awesome,
        Icons.style,
        Icons.delete_outline,
      ]) {
        final box = tester.getRect(find.byIcon(icon));
        expect(box.right, lessThanOrEqualTo(360.0),
            reason: '$icon runs off the right edge');
        expect(box.left, greaterThanOrEqualTo(0.0),
            reason: '$icon runs off the left edge');
      }
    });

    testWidgets('a sentence-long label is shown whole, not clipped',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pump(
        tester,
        MoveNavigationControls(
          cursor: LinearMoveCursor(
            fens: const ['a', 'b', 'c'],
            index: 1,
            onSeek: (_) {},
          ),
          centerLabel: 'Potez 12 od 24',
          onFlipBoard: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      // Shown in full: the strip wraps rather than squeezing the label, so
      // "Navigacija" no longer reads as "Naviga…" on a phone.
      expect(find.text('Potez 12 od 24'), findsOneWidget);
      final label = tester.widget<Text>(find.text('Potez 12 od 24'));
      expect(label.overflow, isNot(TextOverflow.ellipsis));
    });
  });
}
