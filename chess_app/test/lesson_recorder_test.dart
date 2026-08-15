// lesson_recorder_test.dart
//
// The arithmetic under test decides whether a recorded lesson's board stays in
// step with the trainer's voice. It fails silently: a timestamp that forgets to
// subtract paused time still saves, still replays, and only comes apart in the
// exported video. Until this file existed, none of it was covered.

import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/services/lesson_recorder.dart';

/// A clock the test moves by hand, so pause boundaries are exact.
class FakeClock {
  DateTime _now = DateTime.utc(2026, 8, 15, 12);

  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

LessonRecorder started(FakeClock clock) {
  final recorder = LessonRecorder(clock: clock.call)
    ..start(initialEventType: 'init', initialData: {'fen': 'startpos'});
  return recorder;
}

void main() {
  group('before recording starts', () {
    test('is inactive and stamps nothing', () {
      final recorder = LessonRecorder(clock: FakeClock().call);

      expect(recorder.isActive, isFalse);
      expect(recorder.elapsedMs(), 0);

      recorder.record('move', {'san': 'e4'});
      expect(recorder.eventCount, 0, reason: 'events before start must be dropped');
    });
  });

  group('start', () {
    test('seeds the initial state at zero', () {
      final recorder = started(FakeClock());

      expect(recorder.isActive, isTrue);
      expect(recorder.eventCount, 1);
      expect(recorder.events.first.timestampMs, 0);
      expect(recorder.events.first.eventType, 'init');
    });

    test('discards anything left over from a previous recording', () {
      final clock = FakeClock();
      final recorder = started(clock);
      clock.advance(const Duration(seconds: 5));
      recorder.record('move', {'san': 'e4'});
      expect(recorder.eventCount, 2);

      recorder.start(initialEventType: 'init', initialData: {'fen': 'other'});
      expect(recorder.eventCount, 1, reason: 'a new recording must not inherit old events');
      expect(recorder.totalPausedMs, 0);
    });
  });

  group('timestamps', () {
    test('follow wall time while running', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 10));
      recorder.record('move', {'san': 'e4'});

      expect(recorder.events.last.timestampMs, 10000);
    });

    test('exclude time spent paused', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 10));
      recorder.pause();
      clock.advance(const Duration(minutes: 5)); // trainer takes a break
      recorder.resume();
      clock.advance(const Duration(seconds: 3));
      recorder.record('move', {'san': 'e4'});

      // 13 seconds of lesson happened; the five-minute break is not part of it,
      // and the audio track does not contain it either.
      expect(recorder.events.last.timestampMs, 13000);
    });

    test('stay continuous across several pauses', () {
      final clock = FakeClock();
      final recorder = started(clock);

      for (var i = 0; i < 3; i++) {
        clock.advance(const Duration(seconds: 4));
        recorder.record('move', {'n': i});
        recorder.pause();
        clock.advance(const Duration(minutes: 2));
        recorder.resume();
      }

      final stamps = recorder.events.map((e) => e.timestampMs).toList();
      expect(stamps, [0, 4000, 8000, 12000]);
    });

    test('never move backwards', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 30));
      recorder.record('a', {});
      recorder.pause();
      clock.advance(const Duration(hours: 1));
      recorder.resume();
      clock.advance(const Duration(seconds: 1));
      recorder.record('b', {});

      final stamps = recorder.events.map((e) => e.timestampMs).toList();
      for (var i = 1; i < stamps.length; i++) {
        expect(stamps[i], greaterThanOrEqualTo(stamps[i - 1]),
            reason: 'a timestamp going backwards desyncs the whole replay');
      }
    });

    test('the elapsed clock is frozen while paused', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 8));
      recorder.pause();
      final atPause = recorder.elapsedMs();

      clock.advance(const Duration(minutes: 10));
      expect(recorder.elapsedMs(), atPause, reason: 'paused time must not accrue');
    });
  });

  group('pause and resume', () {
    test('events during a pause are dropped', () {
      final clock = FakeClock();
      final recorder = started(clock);

      recorder.pause();
      recorder.record('move', {'san': 'e4'});

      expect(recorder.eventCount, 1, reason: 'only the init event should remain');
    });

    test('a repeated pause does not move the boundary', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 10));
      recorder.pause();
      clock.advance(const Duration(seconds: 30));
      // A second tap on an already-paused recording must be inert; taking the
      // later timestamp would swallow 30s of real recorded time on resume.
      recorder.pause();
      recorder.resume();

      recorder.record('move', {});
      expect(recorder.events.last.timestampMs, 10000);
    });

    test('a resume without a pause changes nothing', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 10));
      recorder.resume();

      expect(recorder.totalPausedMs, 0);
      recorder.record('move', {});
      expect(recorder.events.last.timestampMs, 10000);
    });

    test('pausing before starting does nothing', () {
      final recorder = LessonRecorder(clock: FakeClock().call);
      recorder.pause();
      expect(recorder.isPaused, isFalse);
    });
  });

  group('stop', () {
    test('hands over the timeline and resets', () {
      final clock = FakeClock();
      final recorder = started(clock);
      clock.advance(const Duration(seconds: 5));
      recorder.record('move', {'san': 'e4'});

      final timeline = recorder.stop().events;

      expect(timeline.length, 2);
      expect(timeline.last.timestampMs, 5000);
      expect(recorder.isActive, isFalse);
      expect(recorder.eventCount, 0, reason: 'the recorder must be ready to record again');
    });

    test('the returned timeline is not emptied by the reset', () {
      final clock = FakeClock();
      final recorder = started(clock);
      clock.advance(const Duration(seconds: 2));
      recorder.record('move', {});

      final timeline = recorder.stop().events;
      recorder.start(initialEventType: 'init', initialData: {});

      // A view onto the internal list would have been cleared underneath the
      // caller before they finished uploading it.
      expect(timeline.length, 2);
    });
  });

  // Pauses are reported on the microphone's clock, not the timeline's. Agora
  // cannot pause a recording, so the audio file still contains these stretches
  // and the server cuts them out using exactly these numbers. Measuring them in
  // timeline time — which already has pauses subtracted — would cut the wrong
  // seconds out, and each further pause would compound the error.
  group('pause intervals for the audio', () {
    test('a pause is reported in time since recording started', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 5));
      recorder.pause();
      clock.advance(const Duration(seconds: 30));
      recorder.resume();

      expect(recorder.pauses.single.startMs, 5000);
      expect(recorder.pauses.single.endMs, 35000);
      expect(recorder.pauses.single.durationMs, 30000);
    });

    test('a second pause is measured against the same origin, not the first', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 5));
      recorder.pause();
      clock.advance(const Duration(seconds: 30));
      recorder.resume();

      clock.advance(const Duration(seconds: 10));
      recorder.pause();
      clock.advance(const Duration(seconds: 20));
      recorder.resume();

      // 5+30+10 = 45s of wall clock have passed when the second pause begins.
      expect(recorder.pauses[1].startMs, 45000);
      expect(recorder.pauses[1].endMs, 65000);
    });

    test('an in-progress pause is closed by stop', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 5));
      recorder.pause();
      clock.advance(const Duration(seconds: 12));

      // Pausing and then deciding to end the lesson still leaves that stretch
      // in the audio, so it has to be accounted for.
      final recorded = recorder.stop();
      expect(recorded.pauses.single.startMs, 5000);
      expect(recorded.pauses.single.endMs, 17000);
    });

    test('a recording without pauses reports none', () {
      final clock = FakeClock();
      final recorder = started(clock);
      clock.advance(const Duration(seconds: 5));
      recorder.record('move', {});

      expect(recorder.stop().pauses, isEmpty);
    });

    test('cut audio and timeline end up the same length', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 5));
      recorder.record('move', {});
      recorder.pause();
      clock.advance(const Duration(seconds: 30));
      recorder.resume();
      clock.advance(const Duration(seconds: 7));
      recorder.record('move', {});

      final recorded = recorder.stop();
      const wallClockMs = 42000; // 5 + 30 + 7
      final cutMs = recorded.pauses.fold<int>(0, (sum, p) => sum + p.durationMs);

      // This is the whole point of the exercise: whatever is left of the audio
      // after the cut has to match the timeline the board plays against.
      expect(wallClockMs - cutMs, recorded.events.last.timestampMs);
    });

    test('a repeated pause does not record a second interval', () {
      final clock = FakeClock();
      final recorder = started(clock);

      clock.advance(const Duration(seconds: 5));
      recorder.pause();
      clock.advance(const Duration(seconds: 3));
      recorder.pause(); // double tap
      clock.advance(const Duration(seconds: 7));
      recorder.resume();

      expect(recorder.pauses.length, 1);
      expect(recorder.pauses.single.startMs, 5000);
      expect(recorder.pauses.single.endMs, 15000);
    });

    test('starting again clears the previous recording pauses', () {
      final clock = FakeClock();
      final recorder = started(clock);
      clock.advance(const Duration(seconds: 5));
      recorder.pause();
      clock.advance(const Duration(seconds: 10));
      recorder.resume();

      recorder.start(initialEventType: 'init', initialData: {});
      expect(recorder.pauses, isEmpty);
    });
  });

  group('reset', () {
    test('drops the timeline without producing one', () {
      final clock = FakeClock();
      final recorder = started(clock);
      clock.advance(const Duration(seconds: 5));
      recorder.record('move', {});

      recorder.reset();

      expect(recorder.isActive, isFalse);
      expect(recorder.eventCount, 0);
      expect(recorder.elapsedMs(), 0);
    });
  });

  test('the exposed event list cannot be mutated from outside', () {
    final recorder = started(FakeClock());
    expect(
      () => recorder.events.add(recorder.events.first),
      throwsUnsupportedError,
    );
  });
}
