// The navigation strip is one row on a phone held upright.
//
// Reported live on 18.9.2026 against TODO-provera 180.3 and 180.5: on the room
// and the exercise screen the strip wrapped — arrows on the first row, flip and
// board-view alone on a second — and on Analysis the four move actions sat on a
// row of their own. „Moglo bi da se u portret modu navigaciona paleta svede na
// jedan red."
//
// The height is the measurement, not the eye: one row of dense buttons is 40 dp
// plus the container's margin, and a wrapped strip is that again plus 4.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

class _Cursor extends MoveCursor {
  @override
  bool get canGoBack => true;
  @override
  bool get canGoForward => true;
  @override
  String? get currentFen => null;
  @override
  void first() {}
  @override
  void previous() {}
  @override
  void next() {}
  @override
  void last() {}
}

void main() {
  /// The number of rows the Wrap actually laid out, read off the rendered
  /// height rather than counted from the source.
  Future<double> stripHeight(
    WidgetTester tester, {
    required double width,
    List<Widget> trailing = const [],
    String? centerLabel,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(
        body: Column(
          children: [
            MoveNavigationControls(
              cursor: _Cursor(),
              centerLabel: centerLabel,
              iconSize: 20,
              onFlipBoard: () {},
              trailing: trailing,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(MoveNavigationControls)).height;
  }

  /// What the room passes beside the flip button: its board-view menu.
  List<Widget> roomTrailing() =>
      [IconButton(onPressed: () {}, icon: const Icon(Icons.grid_on, size: 20))];

  testWidgets('the room strip is one row on a 360 dp phone', (tester) async {
    final h = await stripHeight(tester, width: 360, trailing: roomTrailing());
    expect(h, lessThanOrEqualTo(56.0),
        reason: 'one row of dense buttons plus the container margin');
  });

  testWidgets('the word Navigation was what pushed it onto two rows',
      (tester) async {
    final without =
        await stripHeight(tester, width: 360, trailing: roomTrailing());
    final withLabel = await stripHeight(tester,
        width: 360, trailing: roomTrailing(), centerLabel: 'Navigation');
    expect(withLabel, greaterThan(without),
        reason: 'six buttons and that word do not fit 360 dp - which is what '
            'the room and the exercise screen were drawing');
  });

  testWidgets('what the Analysis strip actually measures at 360 dp',
      (tester) async {
    // Four nav buttons, flip, and the four move actions Analysis hangs off the
    // same row: comment, AI comment, NAG, delete.
    final analysis = <Widget>[
      const SizedBox(width: 8),
      for (var i = 0; i < 4; i++)
        IconButton(onPressed: () {}, icon: const Icon(Icons.circle, size: 18)),
    ];
    final h = await stripHeight(tester, width: 360, trailing: analysis);
    // Not an assertion of one row: nine 40 dp targets need 360 dp before the
    // container's own padding, so they cannot fit and this records what they
    // do instead. Changing the number of buttons is a decision, not a fix.
    expect(h, greaterThan(56.0),
        reason: 'nine buttons still wrap at 360 dp - written down so the next '
            'reader does not think this row was left alone by accident');
  });

  testWidgets('a wide window is not made dense', (tester) async {
    final narrow = await stripHeight(tester, width: 360);
    final wide = await stripHeight(tester, width: 1000);
    expect(wide, greaterThan(narrow),
        reason: '48 dp targets where there is room for them');
  });
}
