// A lesson recorded in Preparation — phase 5b.1 of docs/PLAN-SESIJA.md.
//
// **The audio is the clock.** Every event is stamped with how much audio has
// been recorded when it happens — bytes ÷ byte rate, the narration's clock —
// never with `DateTime.now()`: phase 0 of docs/PLAN-SNIMANJE.md measured a wall
// clock 2.6–3.1 s ahead of the audio after a single pause, and the room's
// recorder, which used one, needed a server step to cut the drift back out.
//
// A fake microphone hands over chunks of a known size, so every position below
// is arithmetic the reader can redo: 16 kHz mono 16-bit is 32 bytes per ms.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/lesson_take.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';

class _Mic implements PcmSource {
  final controller = StreamController<Uint8List>();
  bool paused = false;
  bool stopped = false;
  bool allowed = true;

  @override
  Future<bool> hasPermission() async => allowed;
  @override
  Future<Stream<Uint8List>> start() async => controller.stream;
  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => paused = false;
  @override
  Future<void> stop() async => stopped = true;
  @override
  Future<void> dispose() async {}

  /// [ms] of audio, loud enough to count as a live microphone.
  Future<void> speak(int ms) async {
    final bytes = Uint8List(ms * 32);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      data.setInt16(i, 8000, Endian.little);
    }
    controller.add(bytes);
    await Future<void>.delayed(Duration.zero);
  }
}

class _Sink implements NarrationSink {
  int bytes = 0;
  bool finished = false;
  bool discarded = false;
  @override
  void add(Uint8List chunk) => bytes += chunk.length;
  @override
  Future<void> finish() async => finished = true;
  @override
  Future<void> discard() async => discarded = true;
}

const _opening = {'fen': 'startpos-fen', 'pgn': ''};

LessonTake _take(_Mic mic, _Sink sink, {int maxMs = 60000}) => LessonTake(
      source: mic,
      sink: sink,
      maxMs: maxMs,
    );

List<int> _times(LessonRecording r) =>
    [for (final e in r.events) e.timestampMs];

void main() {
  test('the board as it stands is the event at zero', () async {
    final mic = _Mic();
    final take = _take(mic, _Sink());
    await take.start(opening: _opening);
    await mic.speak(100);
    final recording = (await take.stop())!;
    expect(recording.events.first.eventType, 'init');
    expect(recording.events.first.timestampMs, 0);
    expect(recording.events.first.data, _opening);
  });

  test('an event is stamped with the audio recorded so far', () async {
    final mic = _Mic();
    final take = _take(mic, _Sink());
    await take.start(opening: _opening);
    await mic.speak(250);
    expect(take.mark('move', {'fen': 'a'}), LessonMark.marked);
    await mic.speak(80);
    await mic.speak(80);
    take.mark('arrow_drawn', {'arrows': []});
    final recording = (await take.stop())!;
    expect(_times(recording), [0, 250, 410]);
    expect(recording.durationMs, 410);
  });

  test('a pause takes no time, and a mark in it lands on the seam', () async {
    final mic = _Mic();
    final take = _take(mic, _Sink());
    await take.start(opening: _opening);
    await mic.speak(300);
    await take.pause();
    expect(mic.paused, isTrue);
    take.mark('move', {'fen': 'b'});
    // However long the pause lasts on the wall, no audio arrives in it.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await take.resume();
    await mic.speak(200);
    take.mark('move', {'fen': 'c'});
    final recording = (await take.stop())!;
    expect(_times(recording), [0, 300, 500]);
    expect(recording.durationMs, 500);
  });

  test('a move made while the microphone wakes up belongs to the start',
      () async {
    // The microphone took 100–750 ms to deliver its first sample in phase 0.
    // A move made in that time happened before the audio's zero; dropped, the
    // replay would open on a board the trainer had already changed.
    final mic = _Mic();
    final take = _take(mic, _Sink());
    await take.start(opening: _opening);
    expect(take.mark('move', {'fen': 'early'}), LessonMark.marked);
    await mic.speak(120);
    final recording = (await take.stop())!;
    expect(recording.events.map((e) => e.eventType), ['init', 'move']);
    expect(_times(recording), [0, 0]);
  });

  test('nothing is marked before start or after stop', () async {
    final mic = _Mic();
    final take = _take(mic, _Sink());
    expect(take.mark('move', {}), LessonMark.notListening);
    await take.start(opening: _opening);
    await mic.speak(100);
    final recording = (await take.stop())!;
    expect(take.mark('move', {}), LessonMark.notListening);
    expect(recording.events, hasLength(1));
  });

  test('the file and the clock are one number', () async {
    final mic = _Mic();
    final sink = _Sink();
    final take = _take(mic, sink);
    await take.start(opening: _opening);
    await mic.speak(333);
    final recording = (await take.stop())!;
    expect(sink.finished, isTrue);
    expect(audioMsOf(sink.bytes), recording.durationMs);
    expect(recording.heardAnything, isTrue);
  });

  test('the take stops itself a second before the cap', () async {
    final mic = _Mic();
    final sink = _Sink();
    final take = _take(mic, sink, maxMs: 5000);
    await take.start(opening: _opening);
    await mic.speak(3000);
    expect(take.state, NarrationState.recording);
    await mic.speak(1000); // reaches 4000 = 5000 − 1000
    // A deadline, not a bare await: a take that misses the cap never
    // completes `done`, and that must read as a failure, not a hang.
    final recording =
        await take.done.timeout(const Duration(seconds: 2), onTimeout: () {
      fail('the take did not stop itself at the cap');
    });
    expect(recording, isNotNull);
    expect(take.state, NarrationState.stopped);
    expect(mic.stopped, isTrue);
    expect(recording!.durationMs, lessThanOrEqualTo(5000));
    expect(recording.stoppedAtCap, isTrue);
  });

  test('a take stopped by hand is not said to have hit the cap', () async {
    final mic = _Mic();
    final take = _take(mic, _Sink(), maxMs: 5000);
    await take.start(opening: _opening);
    await mic.speak(3000);
    final recording = (await take.stop())!;
    expect(recording.stoppedAtCap, isFalse);
    expect(await take.done, same(recording));
  });

  test('no permission, no file', () async {
    final mic = _Mic()..allowed = false;
    final sink = _Sink();
    final take = _take(mic, sink);
    expect(await take.start(opening: _opening), NarrationStart.noPermission);
    expect(sink.discarded, isTrue);
  });

  test('discarding throws the file away', () async {
    final mic = _Mic();
    final sink = _Sink();
    final take = _take(mic, sink);
    await take.start(opening: _opening);
    await mic.speak(100);
    await take.cancel();
    expect(sink.discarded, isTrue);
    expect(await take.done, isNull);
  });

  test('a take that never heard a sample hands nothing over', () async {
    final mic = _Mic();
    final sink = _Sink();
    final take = _take(mic, sink);
    await take.start(opening: _opening);
    expect(await take.stop(), isNull);
    expect(sink.discarded, isTrue);
  });
}
