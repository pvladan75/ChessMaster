// Does the Practise hub read the attempt log again when a drill hands it back?
//
// Reported live on 18.9.2026: solve, miss, skip, come back, and the card still
// shows the numbers from before. Waiting does nothing — ten seconds changed
// nothing — but pushing any *other* screen and popping straight back corrects
// it. That is the shape of a read that either never happened or happened too
// early, and the only way to tell the two apart is to watch the calls.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/training/screens/training_hub_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

/// Counts reads and answers a different tally each time, so a card that never
/// re-read and a card that re-read are told apart by what they say, not only
/// by a counter this test keeps.
class _CountingApi extends PuzzleAttemptApi {
  _CountingApi() : super(authToken: 'token');

  int reads = 0;

  @override
  Future<Map<String, SourceProgress>?> progress() async {
    reads++;
    return {
      PuzzleSource.matePuzzle: SourceProgress(
        seen: reads,
        solved: reads,
        firstTry: reads,
        failed: 0,
        skipped: 0,
        toRetry: 0,
      ),
    };
  }
}

void main() {
  testWidgets('popping a pushed drill makes the cards read again',
      (tester) async {
    final api = _CountingApi();
    final session = UserSession(
        token: 'token', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik');

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => TrainingHubScreen(
            session: session,
            attemptApi: api,
          ),
        ),
        GoRoute(
          path: '/training/drill',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('leave the drill'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    ));
    await tester.pumpAndSettle();

    expect(api.reads, 1, reason: 'the first read is initState');
    expect(find.text('Solved 1'), findsOneWidget);

    // Into a drill the way the mates card goes, and back the way the drill's
    // own arrow goes.
    await tester.ensureVisible(find.text('Mate in 2'));
    await tester.tap(find.text('Mate in 2'));
    await tester.pumpAndSettle();
    expect(find.text('leave the drill'), findsOneWidget);

    await tester.tap(find.text('leave the drill'));
    await tester.pumpAndSettle();

    expect(api.reads, 2,
        reason: 'coming back from a drill must read the log again');
    expect(find.text('Solved 2'), findsOneWidget,
        reason: 'and what it read must reach the card');
  });

  testWidgets('the read on the way back waits for the attempt still in flight',
      (tester) async {
    // The bug itself: the drill fires its last row and does not wait for it,
    // the pop resolves at once, and the read that follows is answered with the
    // log as it was one attempt ago.
    PuzzleAttemptWrites.reset();
    addTearDown(PuzzleAttemptWrites.reset);

    final api = _CountingApi();
    final session = UserSession(
        token: 'token', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik');
    final lastAttempt = Completer<void>();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              TrainingHubScreen(session: session, attemptApi: api),
        ),
        GoRoute(
          path: '/training/drill',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  // What a drill does on „Next Position": fire the row, do not
                  // wait for it, and let the reader leave.
                  PuzzleAttemptWrites.track(lastAttempt.future);
                  context.pop();
                },
                child: const Text('skip and leave'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    ));
    await tester.pumpAndSettle();
    expect(api.reads, 1);

    await tester.ensureVisible(find.text('Mate in 2'));
    await tester.tap(find.text('Mate in 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('skip and leave'));
    await tester.pumpAndSettle();

    expect(api.reads, 1,
        reason: 'the log was read before the attempt had been written');

    lastAttempt.complete();
    await tester.pumpAndSettle();

    expect(api.reads, 2, reason: 'and read once the write was done');
    expect(find.text('Solved 2'), findsOneWidget);
  });
}
