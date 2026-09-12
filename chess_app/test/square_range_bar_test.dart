import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';

/// The way in to a range of squares, on both kinds of machine.
///
/// The rule itself is proved in `square_range_test.dart` with no widget in
/// sight. What is left here is the half that a pure test cannot see: that the
/// control exists where it can be used and nowhere else, and that the desktop
/// shortcut reaches the same code rather than a second copy of it.
void main() {
  Widget bar({
    required AnnotationMode mode,
    required bool rangeMode,
    VoidCallback? onRange,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: BoardAnnotationBar(
            mode: mode,
            selectedColorCode: 'G',
            onArrowPressed: () {},
            onSquarePressed: () {},
            onColorSelected: (_) {},
            onClearPressed: () {},
            rangeMode: rangeMode,
            onRangePressed: onRange ?? () {},
          ),
        ),
      );

  testWidgets('the range button is drawn only where it can mean something',
      (tester) async {
    // A control drawn where it cannot act is this repository's most frequent
    // fault — a tree menu offering „Obriši ovu varijantu" with no callback
    // behind it, a dialog tab handing its result to nobody. An arrow already
    // takes two taps and means something else by them.
    await tester.pumpWidget(bar(mode: AnnotationMode.square, rangeMode: false));
    expect(find.byKey(const Key('annotate-range')), findsOneWidget);

    await tester.pumpWidget(bar(mode: AnnotationMode.arrow, rangeMode: false));
    expect(find.byKey(const Key('annotate-range')), findsNothing);

    await tester.pumpWidget(bar(mode: AnnotationMode.off, rangeMode: false));
    expect(find.byKey(const Key('annotate-range')), findsNothing);
  });

  testWidgets('pressing it reports, and it shows whether it is on',
      (tester) async {
    var pressed = 0;
    await tester.pumpWidget(bar(
      mode: AnnotationMode.square,
      rangeMode: false,
      onRange: () => pressed++,
    ));
    await tester.tap(find.byKey(const Key('annotate-range')));
    expect(pressed, 1);

    // The two states are two whole styles, so this asks for a difference
    // rather than for a particular colour — the palette is free to change and
    // `board_annotation_bar.dart` explains why the styles are written out.
    final off = tester
        .widget<OutlinedButton>(find.byKey(const Key('annotate-range')))
        .style;

    await tester.pumpWidget(bar(mode: AnnotationMode.square, rangeMode: true));
    final on = tester
        .widget<OutlinedButton>(find.byKey(const Key('annotate-range')))
        .style;

    expect(on, isNot(off),
        reason: 'a toggle that looks the same on and off is a toggle nobody '
            'can use — and this one changes what the next two taps mean');
  });

  group('SHIFT is the desktop shortcut for the same flag', () {
    // Asked of the controller through the same door the screen uses, because
    // what matters is that there is one door. The screen computes
    // `asRange: rangeMode || shiftHeld` and passes it here; a second
    // implementation of the range for keyboards is exactly what this avoids.
    late BoardAnnotationController controller;
    late List<SquareMark> squares;
    late List<ChessArrow> arrows;

    setUp(() {
      controller = BoardAnnotationController(mode: AnnotationMode.square)
        ..setColor('G');
      squares = [];
      arrows = [];
    });

    test('the button off and SHIFT held is a range', () {
      expect(controller.rangeMode, isFalse);
      for (final square in ['a2', 'a5']) {
        controller.tap(square,
            arrows: arrows,
            squares: squares,
            asRange: controller.rangeMode || true);
      }
      expect(squares.map((s) => s.square).toSet(), {'a2', 'a3', 'a4', 'a5'});
    });

    test('the button on and no keyboard at all is the same range', () {
      controller.rangeMode = true;
      for (final square in ['a2', 'a5']) {
        controller.tap(square,
            arrows: arrows,
            squares: squares,
            asRange: controller.rangeMode || false);
      }
      expect(squares.map((s) => s.square).toSet(), {'a2', 'a3', 'a4', 'a5'});
    });

    test('neither, and two taps are two squares', () {
      for (final square in ['a2', 'a5']) {
        controller.tap(square,
            arrows: arrows,
            squares: squares,
            asRange: controller.rangeMode || false);
      }
      expect(squares.map((s) => s.square).toSet(), {'a2', 'a5'});
    });
  });

  testWidgets('a phone reports no shift, which is why the button exists',
      (tester) async {
    // The assumption the whole design rests on, asserted rather than believed:
    // with nothing held, `HardwareKeyboard` says so, and that is every touch
    // device all of the time.
    expect(HardwareKeyboard.instance.isShiftPressed, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(HardwareKeyboard.instance.isShiftPressed, isTrue,
        reason: 'the screen reads this at the moment of the tap; if it stopped '
            'answering, the desktop shortcut would go quiet with no test '
            'anywhere going red');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(HardwareKeyboard.instance.isShiftPressed, isFalse);
  });
}
