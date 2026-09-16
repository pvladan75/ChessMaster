// A board screen held sideways, at the sizes a phone actually has.
//
// A release build clips an overflow without a word, so the strip's last buttons
// or the bottom of the board could simply be missing on a phone. A test build
// throws instead, which is what these lean on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

const _toolbar = LandscapeBoardLayout.compactToolbarHeight;

const _board = Key('board');
const _aside = Key('aside');
const _footer = Key('footer');
const _strip = Key('strip');

Future<void> _setScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The widest strip in the app, the Analysis Studio's: four moves, flip, and
/// the four buttons that act on the current move. A shorter one would fit in a
/// row where the real one does not.
Widget _navigation() {
  final root = AnalysisNode(
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
  return MoveNavigationControls(
    key: _strip,
    cursor: AnalysisNodeCursor(currentNode: root, onSelect: (_) {}),
    centerLabel: null,
    iconSize: 20,
    onFlipBoard: () {},
    trailing: [
      const SizedBox(width: AppSpacing.sm),
      for (final icon in [
        Icons.comment,
        Icons.auto_awesome,
        Icons.style,
        Icons.delete_outline,
      ])
        IconButton(icon: Icon(icon, size: 18), onPressed: () {}),
    ],
  );
}

Widget _host({
  bool aside = false,
  double scale = 1.0,
  double footerHeight = 40,
}) =>
    MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
            title: const Text('Analysis'),
          ),
          body: LandscapeBoardLayout(
            boardScale: scale,
            board: (side) => Container(key: _board, color: Colors.brown),
            boardAside: aside
                ? (height) => Container(key: _aside, color: Colors.white)
                : null,
            panels: Column(
              children: [
                for (var i = 0; i < 30; i += 1)
                  SizedBox(height: 40, child: Text('panel $i')),
              ],
            ),
            footer: [
              SizedBox(key: _footer, height: footerHeight),
              _navigation(),
            ],
          ),
        ),
      ),
    );

void main() {
  group('applies', () {
    Future<bool> appliesAt(WidgetTester tester, Size size) async {
      await _setScreen(tester, size);
      late bool result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          result = LandscapeBoardLayout.applies(context);
          return const SizedBox();
        }),
      ));
      return result;
    }

    testWidgets('to a phone on its side, however wide', (tester) async {
      expect(await appliesAt(tester, const Size(640, 360)), isTrue);
      expect(await appliesAt(tester, const Size(800, 360)), isTrue);
      expect(await appliesAt(tester, const Size(932, 430)), isTrue);
    });

    testWidgets('not to a phone upright, a tablet or a desktop',
        (tester) async {
      expect(await appliesAt(tester, const Size(360, 800)), isFalse);
      expect(await appliesAt(tester, const Size(1280, 800)), isFalse);
      expect(await appliesAt(tester, const Size(1920, 1080)), isFalse);
      // Exactly the threshold is not compact.
      expect(await appliesAt(tester, const Size(1000, 480)), isFalse);
    });
  });

  const phones = [Size(800, 360), Size(932, 430), Size(640, 360)];

  for (final size in phones) {
    final label = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets(
        'at $label the board takes the whole height and the strip '
        'is on screen', (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final screen = Offset.zero & size;
      final board = tester.getRect(find.byKey(_board));
      expect(board.width, board.height, reason: 'the board is square');
      // Bound by the height: the body under the compact app bar, less padding.
      expect(board.height, size.height - _toolbar - 2 * AppSpacing.sm);

      final buttons = find.descendant(
          of: find.byKey(_strip), matching: find.byType(IconButton));
      expect(buttons, findsNWidgets(9));
      for (final element in buttons.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue,
            reason: 'every strip button is reachable at $label');
      }
      // The strip sits to the right of the board, not under it.
      expect(tester.getRect(find.byKey(_strip)).left, greaterThan(board.right));
    });
  }

  for (final size in const [Size(800, 360), Size(932, 430)]) {
    testWidgets(
        'at ${size.width.toInt()}×${size.height.toInt()} the strip is one row',
        (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final rows = find
          .descendant(of: find.byKey(_strip), matching: find.byType(IconButton))
          .evaluate()
          .map((e) => tester.getCenter(find.byWidget(e.widget)).dy)
          .toSet();
      expect(rows, hasLength(1));
    });
  }

  testWidgets('scrolling the panels moves neither the board nor the footer',
      (tester) async {
    await _setScreen(tester, const Size(800, 360));
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final board = tester.getTopLeft(find.byKey(_board));
    final footer = tester.getTopLeft(find.byKey(_footer));
    final strip = tester.getTopLeft(find.byKey(_strip));
    final panel = tester.getTopLeft(find.text('panel 0'));

    await tester.drag(find.text('panel 1'), const Offset(0, -200));
    await tester.pumpAndSettle();

    // Without this the test would pass on a layout that does not scroll at all.
    expect(tester.getTopLeft(find.text('panel 0')).dy, lessThan(panel.dy));
    expect(tester.getTopLeft(find.byKey(_board)), board);
    expect(tester.getTopLeft(find.byKey(_footer)), footer);
    expect(tester.getTopLeft(find.byKey(_strip)), strip);
  });

  testWidgets('a drag on the board scrolls nothing', (tester) async {
    await _setScreen(tester, const Size(800, 360));
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final board = tester.getTopLeft(find.byKey(_board));
    final panel = tester.getTopLeft(find.text('panel 0'));
    await tester.drag(find.byKey(_board), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(_board)), board);
    expect(tester.getTopLeft(find.text('panel 0')), panel);
  });

  testWidgets('the aside is as tall as the board, and left of it',
      (tester) async {
    // 640 wide: the width binds once the aside takes its 26 dp.
    await _setScreen(tester, const Size(640, 360));
    await tester.pumpWidget(_host(aside: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final board = tester.getRect(find.byKey(_board));
    final bar = tester.getRect(find.byKey(_aside));
    expect(board.width, board.height);
    expect(board.width, lessThan(360 - _toolbar - 2 * AppSpacing.sm));
    expect(bar.height, board.height);
    expect(bar.top, board.top);
    expect(bar.right, lessThanOrEqualTo(board.left));
    // The panel column keeps its minimum.
    final strip = tester.getRect(find.byKey(_strip));
    expect(640 - AppSpacing.sm - strip.left,
        greaterThanOrEqualTo(LandscapeBoardLayout.minPanelWidth));
  });

  testWidgets('the board size setting shrinks the board', (tester) async {
    await _setScreen(tester, const Size(800, 360));
    await tester.pumpWidget(_host(scale: 0.6));
    await tester.pumpAndSettle();

    final full = 360 - _toolbar - 2 * AppSpacing.sm;
    expect(tester.getSize(find.byKey(_board)).width, closeTo(full * 0.6, 0.01));
  });

  testWidgets('with a keyboard up it scrolls as a whole instead of overflowing',
      (tester) async {
    // 360 tall with a 200 dp keyboard: the body is 116 dp.
    await _setScreen(tester, const Size(800, 360));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final side = tester.getSize(find.byKey(_board)).width;
    expect(side, LandscapeBoardLayout.minHeight - 2 * AppSpacing.sm,
        reason: 'the board keeps the size of the shortest layout');
  });

  testWidgets('a footer taller than the column scrolls inside itself',
      (tester) async {
    await _setScreen(tester, const Size(800, 360));
    await tester.pumpWidget(_host(footerHeight: 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The panels keep what the footer may not take.
    final column = 360 - _toolbar - 2 * AppSpacing.sm;
    // The nearest scroll view around the panels, not the layout's outer one.
    final panels = tester.getRect(find
        .ancestor(
            of: find.text('panel 0'),
            matching: find.byType(SingleChildScrollView))
        .first);
    expect(panels.height,
        closeTo(column * (1 - LandscapeBoardLayout.footerShare), 0.01));
  });

  testWidgets('a field being typed into keeps its focus as the keyboard opens',
      (tester) async {
    await _setScreen(tester, const Size(800, 360));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LandscapeBoardLayout(
          board: (side) => Container(key: _board, color: Colors.brown),
          panels: const TextField(key: Key('field')),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    final state = tester.state(find.byType(EditableText));
    expect(tester.testTextInput.isVisible, isTrue);

    // The keyboard arrives: the body shrinks below the layout's minimum.
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(tester.state(find.byType(EditableText)), same(state),
        reason:
            'the field was rebuilt, so its focus and the keyboard are gone');
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
