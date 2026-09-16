// What every board screen owes a phone held sideways, as expectations a
// screen's own test can call — so a screen whose fakes live in its own test file
// is checked by the same rule as the rest.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

/// A small phone and a large one, on their sides.
const landscapePhones = [Size(800, 360), Size(932, 430)];

String sizeLabel(Size size) => '${size.width.toInt()}×${size.height.toInt()}';

/// Sets the window to [size] and pumps [screen] as a whole app.
Future<void> pumpAt(WidgetTester tester, Size size, Widget screen) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: screen,
  ));
  await tester.pumpAndSettle();
}

/// A square board beside the rest, whole on screen, and a move strip — where
/// the screen has one — to the right of the board with every button reachable.
void expectBoardBeside(WidgetTester tester, Size size) {
  expect(tester.takeException(), isNull);
  expect(find.byType(LandscapeBoardLayout), findsOneWidget,
      reason: 'the screen must reach the landscape layout');

  final screen = Offset.zero & size;
  // The outermost board widget: a framed board where there is a frame, and the
  // board itself where a screen draws it bare.
  final board = tester.getRect(find
      .byWidgetPredicate(
          (w) => w is BoardWithCoordinates || w is ChessBoardWithOverlay)
      .first);
  expect(board.width, closeTo(board.height, 0.01));
  expect(screen.contains(board.bottomRight - const Offset(1, 1)), isTrue);

  final strip = find.byType(MoveNavigationControls);
  if (strip.evaluate().isEmpty) return;
  expect(tester.getRect(strip.first).left, greaterThan(board.right));
  expectOnScreen(tester, size,
      find.descendant(of: strip.first, matching: find.byType(IconButton)));
}

/// Every widget [finder] matches lies wholly inside the window.
void expectOnScreen(WidgetTester tester, Size size, Finder finder) {
  expect(finder, findsWidgets);
  final screen = Offset.zero & size;
  for (final element in finder.evaluate()) {
    final rect = tester.getRect(find.byWidget(element.widget));
    expect(screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue,
        reason: '${element.widget} is off screen at ${sizeLabel(size)}');
    expect(rect.left >= 0 && rect.top >= 0, isTrue,
        reason: '${element.widget} is off screen at ${sizeLabel(size)}');
  }
}
