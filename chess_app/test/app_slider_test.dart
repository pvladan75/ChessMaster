// AppSlider does what the app used Flutter's Slider for — without the overlay
// that crashed Windows (see lib/widgets/app_slider.dart). Each case pins one
// thing a reader does with a slider.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/app_slider.dart';

/// A slider 400 wide whose value lives here, so every case reads what the
/// widget reported rather than what it was given.
class _Host extends StatefulWidget {
  const _Host({
    required this.start,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.enabled = true,
  });

  final double start;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? label;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double value = widget.start;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('value=$value'),
                  AppSlider(
                    value: value,
                    min: widget.min,
                    max: widget.max,
                    divisions: widget.divisions,
                    label: widget.label?.call(value),
                    onChanged: widget.enabled
                        ? (v) => setState(() => value = v)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

double _valueOf(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host)).value;

/// A point on the track, [t] of the way from its left end to its right.
Offset _at(WidgetTester tester, double t) {
  final r = tester.getRect(find.byType(AppSlider));
  const pad = 24.0;
  return Offset(r.left + pad + (r.width - 2 * pad) * t, r.center.dy);
}

void main() {
  testWidgets('a tap moves the thumb to where it landed', (tester) async {
    await tester.pumpWidget(const _Host(start: 0.2));
    await tester.tapAt(_at(tester, 0.75));
    await tester.pump();
    expect(_valueOf(tester), closeTo(0.75, 0.01));
  });

  testWidgets('divisions snap to the nearest step', (tester) async {
    await tester.pumpWidget(const _Host(start: 0, divisions: 4));
    await tester.tapAt(_at(tester, 0.6));
    await tester.pump();
    expect(_valueOf(tester), 0.5);
  });

  testWidgets('min and max map to the ends of the track', (tester) async {
    await tester.pumpWidget(
      const _Host(start: 20, min: 5, max: 50, divisions: 9),
    );
    await tester.tapAt(_at(tester, 1.0));
    await tester.pump();
    expect(_valueOf(tester), 50);
    await tester.tapAt(_at(tester, 0.0));
    await tester.pump();
    expect(_valueOf(tester), 5);
  });

  testWidgets('a drag follows the pointer and shows the label meanwhile', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(start: 0, label: (v) => 'L${(v * 100).round()}'),
    );
    final g = await tester.startGesture(_at(tester, 0.1));
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.moveTo(_at(tester, 0.9));
    await tester.pump();
    expect(_valueOf(tester), closeTo(0.9, 0.01));
    expect(
      find.byType(AppSlider),
      paints
        ..something((method, args) {
          if (method != #drawParagraph) return false;
          return true;
        }),
      reason: 'the bubble is drawn while dragging',
    );
    await g.up();
    await tester.pump();
    expect(
      find.byType(AppSlider),
      isNot(paints..something((m, _) => m == #drawParagraph)),
      reason: 'and gone when the drag ends',
    );
  });

  testWidgets('arrow keys move it one division', (tester) async {
    await tester.pumpWidget(const _Host(start: 0.5, divisions: 10));
    // Focus it the way a keyboard user does.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_valueOf(tester), closeTo(0.6, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_valueOf(tester), closeTo(0.4, 1e-9));
  });

  testWidgets('a screen reader sees a slider and can move it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _Host(
          start: 20,
          min: 5,
          max: 50,
          divisions: 9,
          label: (v) => '${v.round()}'),
    );
    final node = tester.getSemantics(find.byType(AppSlider));
    expect(
      node,
      matchesSemantics(
        isSlider: true,
        hasEnabledState: true,
        isEnabled: true,
        // 20 of 5..50 is a third of the way; one division is 5.
        value: '33%',
        increasedValue: '44%',
        decreasedValue: '22%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(_valueOf(tester), 25);
    handle.dispose();
  });

  testWidgets('without onChanged it is disabled and ignores the pointer', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(start: 0.3, enabled: false));
    await tester.tapAt(_at(tester, 0.9));
    await tester.pump();
    expect(_valueOf(tester), 0.3);
    expect(
      tester.getSemantics(find.byType(AppSlider)),
      matchesSemantics(
        isSlider: true,
        hasEnabledState: true,
        isEnabled: false,
        value: '30%',
        increasedValue: '35%',
        decreasedValue: '25%',
      ),
    );
    handle.dispose();
  });
}
