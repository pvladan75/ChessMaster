// The difficulty range as two numbers (lib/widgets/rating_range_stepper.dart),
// which replaced a RangeSlider on 22.9.2026.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/rating_range_stepper.dart';

class _Host extends StatefulWidget {
  const _Host(this.start);
  final RangeValues start;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late RangeValues values = widget.start;
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(
          body: RatingRangeStepper(
            values: values,
            onChanged: (v) => setState(() => values = v),
          ),
        ),
      );
}

RangeValues _values(WidgetTester t) =>
    t.state<_HostState>(find.byType(_Host)).values;

Future<void> _press(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pump();
}

bool _enabled(WidgetTester t, String key) =>
    t.widget<IconButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  testWidgets('each end steps by 100 and shows its number', (tester) async {
    await tester.pumpWidget(const _Host(RangeValues(1200, 1800)));
    await _press(tester, 'rating-from-plus');
    await _press(tester, 'rating-to-minus');
    expect(_values(tester), const RangeValues(1300, 1700));
    expect(find.text('1300'), findsOneWidget);
    expect(find.text('1700'), findsOneWidget);
    await _press(tester, 'rating-from-minus');
    await _press(tester, 'rating-to-plus');
    expect(_values(tester), const RangeValues(1200, 1800));
  });

  testWidgets('the ends stop at 400 and 2800', (tester) async {
    await tester.pumpWidget(const _Host(RangeValues(400, 2800)));
    expect(_enabled(tester, 'rating-from-minus'), isFalse);
    expect(_enabled(tester, 'rating-to-plus'), isFalse);
    expect(_enabled(tester, 'rating-from-plus'), isTrue);
    expect(_enabled(tester, 'rating-to-minus'), isTrue);
  });

  testWidgets('from never passes to, and they may meet', (tester) async {
    await tester.pumpWidget(const _Host(RangeValues(1500, 1600)));
    await _press(tester, 'rating-from-plus');
    expect(_values(tester), const RangeValues(1600, 1600));
    expect(_enabled(tester, 'rating-from-plus'), isFalse);
    expect(_enabled(tester, 'rating-to-minus'), isFalse);
    expect(_enabled(tester, 'rating-to-plus'), isTrue);
    expect(_enabled(tester, 'rating-from-minus'), isTrue);
  });

  testWidgets('a screen reader hears what each button does and can press it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(RangeValues(400, 1800)));
    expect(
      tester.getSemantics(find.bySemanticsLabel('From: raise to 500')),
      matchesSemantics(
        label: 'From: raise to 500',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('From: lower to 300')),
      matchesSemantics(
        label: 'From: lower to 300',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    final raise =
        tester.getSemantics(find.bySemanticsLabel('To: raise to 1900'));
    raise.owner!.performAction(raise.id, SemanticsAction.tap);
    await tester.pump();
    expect(_values(tester), const RangeValues(400, 1900));
    handle.dispose();
  });
}
