// What every board screen owes a phone held sideways, as expectations a
// screen's own test can call — so a screen whose fakes live in its own test file
// is checked by the same rule as the rest.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

/// A small phone and a large one, on their sides.
/// Loads the real Roboto, which the app draws in on Android, for tests that
/// measure whether a row fits.
///
/// A widget test otherwise draws every letter as a square a full em wide, so a
/// label like "Move 12 of 30" measures about twice its real width, and a strip
/// that fits on the phone "wraps" in the test. Loud when the files are not
/// there: a silent fallback would measure the squares and say nothing. Call it
/// from `setUpAll` — outside the fake clock a `testWidgets` body runs on.
Future<void> loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT is not set, so the real font cannot be '
        'found and every width would be measured in the test font.');
  }
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final name in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf'
  ]) {
    final file = File('$dir/$name');
    if (!file.existsSync()) {
      throw StateError('$name is not in $dir');
    }
    loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  }
  await loader.load();
}

/// A small phone and a large one on their sides, and the 760 dp width the owner
/// measured on theirs — once 360 tall, where the height binds the board, and
/// once 430, where the width does and the side column is at its narrowest.
const landscapePhones = [
  Size(760, 360),
  Size(760, 430),
  Size(800, 360),
  Size(932, 430),
];

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
  // One row, strictly. Two rows took half the side column on a real phone.
  final rows = find
      .descendant(of: strip.first, matching: find.byType(IconButton))
      .evaluate()
      .map((e) => tester.getCenter(find.byWidget(e.widget)).dy.round())
      .toSet();
  expect(rows, hasLength(1),
      reason: 'the move strip wrapped at ${sizeLabel(size)}');
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
