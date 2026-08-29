import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// The rule this file defends: **a message must never be able to take down the
/// action it reports on.**
///
/// It has cost this project twice — playback that never started because a
/// failing audio call sat in front of the timer, and a recording that would not
/// stop for a child whose parent had refused it, because `showSnackBar` threw
/// first. `AppFeedback` is the answer, but an answer nobody is obliged to use
/// is not an answer: on 25.8.2026 there were still 82 hand-written
/// `ScaffoldMessenger.of(context).showSnackBar` calls in `lib/`, every one of
/// them the same bug waiting for a popped screen.
void main() {
  group('nothing in lib/ shows a message on its own', () {
    final sources = <String, String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('lib/widgets/app_feedback.dart')) continue;
      sources[path] = entity.readAsStringSync();
    }

    test('the walk actually read the app, or the rest proves nothing', () {
      expect(sources.length, greaterThan(100));
      final callers =
          sources.values.where((s) => s.contains('AppFeedback.')).length;
      expect(callers, greaterThan(20),
          reason: 'ako niko ne zove AppFeedback, ovaj test ništa ne čuva');
    });

    test('no file reaches for ScaffoldMessenger itself', () {
      final offenders = [
        for (final entry in sources.entries)
          if (entry.value.contains('ScaffoldMessenger.of(') ||
              entry.value.contains('ScaffoldMessenger.maybeOf('))
            entry.key,
      ];
      expect(offenders, isEmpty,
          reason: 'poruka mora da ide kroz AppFeedback, jer ona ne može da '
              'obori radnju koju javlja; ovde je zaobiđena: '
              '${offenders.join(', ')}');
    });

    test('no file hides a message directly either', () {
      // Taking a message back has the same shape as showing one: it runs on a
      // messenger that outlives the screen, and it can throw at exactly the
      // moment the screen is going away. AppFeedback.dismiss swallows that;
      // a direct call does not.
      final offenders = [
        for (final entry in sources.entries)
          if (entry.value.contains('.hideCurrentSnackBar(')) entry.key,
      ];
      expect(offenders, isEmpty,
          reason: 'poruka se sklanja kroz AppFeedback.dismiss: '
              '${offenders.join(', ')}');
    });

    test('no file calls showSnackBar directly', () {
      // Separate from the check above on purpose: a messenger captured into a
      // local variable (`final m = ScaffoldMessenger.of(context);`) would slip
      // past a search for the lookup alone.
      final offenders = [
        for (final entry in sources.entries)
          if (entry.value.contains('.showSnackBar(')) entry.key,
      ];
      expect(offenders, isEmpty,
          reason: 'ovde se SnackBar prikazuje mimo AppFeedback: '
              '${offenders.join(', ')}');
    });
  });

  group('AppFeedback survives the contexts a room actually produces', () {
    testWidgets('shows the message when there is a messenger to show it in',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        })),
      ));

      AppFeedback.success(context, 'Snimak je sačuvan.');
      await tester.pump();

      expect(find.text('Snimak je sačuvan.'), findsOneWidget);
    });

    testWidgets('a popped screen does not throw', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        })),
      ));
      // The socket callback arrives after the screen is gone. Looking anything
      // up on this context now — the messenger, but equally `context.colors`,
      // which is `Theme.of` — throws "Looking up a deactivated widget's
      // ancestor is unsafe". That is why the SnackBar is built inside the
      // guard rather than passed in already built.
      await tester.pumpWidget(const Placeholder());

      expect(() => AppFeedback.error(context, 'Nije uspelo.'), returnsNormally);
      expect(() => AppFeedback.success(context, 'Uspelo je.'), returnsNormally);
      expect(() => AppFeedback.info(context, 'Nešto.'), returnsNormally);
      expect(() => AppFeedback.warning(context, 'Pažnja.'), returnsNormally);
      expect(
          () => AppFeedback.show(
              context, () => const SnackBar(content: Text('Ručno.'))),
          returnsNormally);
    });

    testWidgets('a tree with no messenger in it does not throw',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ));

      expect(() => AppFeedback.error(context, 'Nije uspelo.'), returnsNormally);
    });

    testWidgets('the caller keeps running when the message cannot be shown',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        })),
      ));
      await tester.pumpWidget(const Placeholder());

      // The shape of the recording bug: the message first, the thing that
      // matters second.
      var recordingStopped = false;
      AppFeedback.warning(context, 'Roditelj nije dao saglasnost.');
      recordingStopped = true;

      expect(recordingStopped, isTrue);
    });
  });
}
