// engine_silence_test.dart — an engine that answers nothing is said on the
// screen (owner's report of 20.9.2026: a board with no evaluation and no
// reason, while every wait „proceeded anyway").
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/engine_silence.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/engine_notice.dart';

/// `hasListeners` is protected; a subclass may ask.
class _Probe extends EngineSilence {
  bool get listenedTo => hasListeners;
}

void main() {
  group('EngineSilence', () {
    test(
        'uci that earns no uciok in time is a problem; the banner is not an '
        'answer', () {
      fakeAsync((async) {
        final silence = EngineSilence();
        silence.expectAnswer(const Duration(seconds: 5));
        // The first log of the report, line for line: the banner, then nothing.
        silence.heard(
            'Stockfish 18 by the Stockfish developers (see AUTHORS file)');
        async.elapse(const Duration(seconds: 4));
        expect(silence.value, isNull, reason: 'not yet');
        async.elapse(const Duration(seconds: 2));
        expect(silence.value, EngineSilence.notAnswering);
      });
    });

    test('an engine that answers in time is never accused', () {
      fakeAsync((async) {
        final silence = EngineSilence();
        silence.expectAnswer(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 1));
        silence.heard('id name Stockfish 18');
        async.elapse(const Duration(seconds: 30));
        expect(silence.value, isNull);
      });
    });

    test('a wait that ran out is a problem, and the next line takes it back',
        () {
      final silence = EngineSilence();
      silence.unansweredSince(silence.mark);
      expect(silence.value, EngineSilence.notAnswering);
      silence.heard('readyok');
      expect(silence.value, isNull);
    });

    test('a timeout beside a talking engine is not silence', () {
      // Two drains at once: the second takes the first one's waiter, and the
      // first times out although `readyok` came.
      final silence = EngineSilence();
      final asked = silence.mark;
      silence.heard('readyok');
      silence.unansweredSince(asked);
      expect(silence.value, isNull);
      // The banner is not talking.
      final again = silence.mark;
      silence.heard('Stockfish 18 by the Stockfish developers');
      silence.unansweredSince(again);
      expect(silence.value, EngineSilence.notAnswering);
    });

    test('an engine that refuses a write has stopped, in its own sentence', () {
      final silence = EngineSilence()..exited();
      expect(silence.value, EngineSilence.stopped);
      expect(EngineSilence.stopped, isNot(EngineSilence.notAnswering));
    });

    test('a shutdown on purpose owes nothing, not even a pending answer', () {
      fakeAsync((async) {
        final silence = EngineSilence()
          ..expectAnswer(const Duration(seconds: 5))
          ..unansweredSince(0)
          ..clear();
        async.elapse(const Duration(seconds: 10));
        expect(silence.value, isNull);
      });
    });
  });

  group('EngineNotice', () {
    Future<_Probe> pump(WidgetTester tester) async {
      final silence = _Probe();
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        // Where main.dart puts it: above the router, below the messenger.
        builder: (context, child) =>
            EngineNotice(silence: silence, child: child!),
        home: const Scaffold(body: Text('a screen with a board')),
      ));
      return silence;
    }

    testWidgets('says the sentence once per fault, not once per timeout',
        (tester) async {
      final silence = await pump(tester);
      expect(find.text(EngineSilence.notAnswering), findsNothing);

      silence.unansweredSince(silence.mark);
      silence.unansweredSince(silence.mark);
      silence.unansweredSince(silence.mark);
      await tester.pump();
      expect(find.text(EngineSilence.notAnswering), findsOneWidget);

      // Read, gone, and the same fault does not speak again.
      // In, its six seconds, out: the bar's clock starts once it has arrived.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.text(EngineSilence.notAnswering), findsNothing);
      silence.unansweredSince(silence.mark);
      await tester.pumpAndSettle();
      expect(find.text(EngineSilence.notAnswering), findsNothing);

      // Answered, then silent again: a new fault, said again.
      silence.heard('readyok');
      silence.unansweredSince(silence.mark);
      await tester.pump();
      expect(find.text(EngineSilence.notAnswering), findsOneWidget);
    });

    testWidgets('an engine coming back says nothing', (tester) async {
      final silence = await pump(tester);
      // From a fault, not from nothing: a change the notice really hears.
      silence.exited();
      await tester.pumpAndSettle();
      expect(find.text(EngineSilence.stopped), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      silence.heard('readyok');
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a notice that is gone no longer listens', (tester) async {
      final silence = await pump(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      silence.exited();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(silence.listenedTo, isFalse);
    });
  });
}
