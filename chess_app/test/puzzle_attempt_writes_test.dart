// A read of the attempt log does not overtake a write still in flight.
//
// Reported live on 18.9.2026 (TODO-provera 176.2): solve, miss, skip, come
// back to the hub, and the mates card is one attempt behind. Waiting does not
// mend it — nothing re-reads on a wait — but pushing any other screen and
// popping straight back does, because that is a second read.
// `hub_refresh_after_drill_test` proves the client does re-read; what was
// missing is that the read waits for the write.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';

void main() {
  setUp(PuzzleAttemptWrites.reset);

  test('with nothing in flight, settled() does not make anybody wait',
      () async {
    var done = false;
    // ignore: unawaited_futures
    PuzzleAttemptWrites.settled().then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
  });

  test('settled() waits for a write that has not finished', () async {
    final write = Completer<void>();
    PuzzleAttemptWrites.track(write.future);

    var read = false;
    // ignore: unawaited_futures
    PuzzleAttemptWrites.settled().then((_) => read = true);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(read, isFalse, reason: 'the read overtook the write');

    write.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(read, isTrue);
  });

  test('a write that failed still releases the read', () async {
    final write = Completer<void>();
    PuzzleAttemptWrites.track(write.future);
    var read = false;
    // ignore: unawaited_futures
    PuzzleAttemptWrites.settled().then((_) => read = true);

    write.completeError(StateError('the server refused it'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(read, isTrue,
        reason: 'this barrier is about when a write is over, not whether it '
            'worked — a refused row must not freeze the hub');
  });

  test('a write that never finishes releases the read at the limit', () async {
    fakeAsync((async) {
      PuzzleAttemptWrites.track(Completer<void>().future);
      var read = false;
      // ignore: unawaited_futures
      PuzzleAttemptWrites.settled(limit: const Duration(seconds: 5))
          .then((_) => read = true);

      async.elapse(const Duration(seconds: 4));
      expect(read, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(read, isTrue, reason: 'a stuck write must not stop the screen');
    });
  });

  test('a finished write is forgotten rather than piling up', () async {
    final write = Completer<void>()..complete();
    PuzzleAttemptWrites.track(write.future);
    await PuzzleAttemptWrites.settled();
    // Nothing observable but the absence of a leak; settled() returning at all
    // is the assertion, and the next one must not wait on the last one.
    await PuzzleAttemptWrites.settled();
  });
}
