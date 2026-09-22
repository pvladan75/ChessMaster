// „New session" starts one session, however fast it is pressed.
//
// Reported live on 22.9.2026: two taps a few milliseconds apart made two
// sessions. The server now queues a second start behind the first
// (`roomLifecycle.startSession`), so only one room stays live — but the app
// would still push a room screen for each answer. The button is the other half:
// while a start is on its way, another tap does nothing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/home/teach_tab.dart';

final _start = find.widgetWithText(ElevatedButton, 'Start');
final _busyStart = find.descendant(
  of: find.byType(ElevatedButton),
  matching: find.byType(CircularProgressIndicator),
);

Future<void> _pump(WidgetTester tester, Future<void> Function() onStart) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: TeachTab(
        onOpenPreparation: () {},
        onStartSession: onStart,
        onOpenLibrary: () {},
        studentsSection: const SizedBox(),
      ),
    ),
  ));
}

void main() {
  testWidgets('two taps inside one frame start one session', (tester) async {
    var started = 0;
    final pending = Completer<void>();
    await _pump(tester, () {
      started++;
      return pending.future;
    });

    // No pump between the taps: the second arrives before the disabled button
    // is drawn, which is what a quick double tap is.
    await tester.tap(_start);
    await tester.tap(_start);
    expect(started, 1);

    pending.complete();
    await tester.pump();
  });

  testWidgets('while a start is on its way the button says so and refuses',
      (tester) async {
    var started = 0;
    var pending = Completer<void>();
    await _pump(tester, () {
      started++;
      return pending.future;
    });

    await tester.tap(_start);
    await tester.pump();
    expect(_busyStart, findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(find.ancestor(
                of: _busyStart, matching: find.byType(ElevatedButton)))
            .onPressed,
        isNull);
    await tester.tap(
        find.ancestor(of: _busyStart, matching: find.byType(ElevatedButton)),
        warnIfMissed: false);
    expect(started, 1);

    // Once it is answered — here, as if the server refused — the button is a
    // button again, so a failed start can be tried a second time.
    pending.complete();
    await tester.pump();
    expect(_busyStart, findsNothing);
    pending = Completer<void>();
    await tester.tap(_start);
    expect(started, 2);
    pending.complete();
    await tester.pump();
  });

  testWidgets('a start that throws gives the button back', (tester) async {
    var started = 0;
    await _pump(tester, () async {
      started++;
      throw StateError('network');
    });

    await tester.tap(_start);
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(_busyStart, findsNothing);
    await tester.tap(_start);
    expect(started, 2);
    await tester.pump();
    tester.takeException();
  });
}
