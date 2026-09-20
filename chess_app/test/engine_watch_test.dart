// engine_watch_test.dart — the engine is told to quit when the app is torn
// down, and at no other time (owner's report of 20.9.2026: an engine that
// printed its banner and never another line, on a phone whose process had
// outlived the app's previous run).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/engine_watch.dart';

void main() {
  testWidgets(
      'detached shuts the engine down; going to the background does not',
      (tester) async {
    var shutdowns = 0;
    await tester.pumpWidget(EngineWatch(
      onDetached: () => shutdowns++,
      child: const SizedBox.shrink(),
    ));

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(shutdowns, 0,
        reason: 'an engine killed on every glance at another app would have '
            'to be started again on every return');

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(shutdowns, 1);
    // Leave the binding as the next test expects to find it.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('a watch that is gone no longer listens', (tester) async {
    var shutdowns = 0;
    await tester.pumpWidget(EngineWatch(
      onDetached: () => shutdowns++,
      child: const SizedBox.shrink(),
    ));
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    expect(shutdowns, 0);
    // Leave the binding as the next test expects to find it.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
