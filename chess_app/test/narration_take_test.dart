// The trainer's own voice — phase 1 of `docs/PLAN-SNIMANJE.md`, the pure core,
// gated before the recording screen is written.
//
// The rules worth breaking a build over:
//
//   * a marker is the byte count of the audio, never a clock — so a chunk that
//     arrives late moves nothing, and a pause leaves no gap;
//   * every byte counted is a byte written, including the chunk Android sends
//     after a pause is asked for;
//   * two beats can never share a moment, because the film would show one;
//   * the film and the recording walk one projection, so marker `i` names
//     event `i`;
//   * a take's index is replaced before its old audio is deleted, and is read
//     back against the audio before it is trusted.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 80 ms of audio — the chunk Android delivers.
const _chunkBytes = 2560;

/// A chunk of audio whose loudest sample is [peak] (0–32767).
Uint8List chunkOf({int peak = 8000, int bytes = _chunkBytes}) {
  final data = ByteData(bytes);
  for (var i = 0; i + 1 < bytes; i += 2) {
    data.setInt16(i, (i ~/ 2).isEven ? peak : -peak, Endian.little);
  }
  return data.buffer.asUint8List();
}

class FakeSource implements PcmSource {
  FakeSource({this.permitted = true});

  final bool permitted;
  final controller = StreamController<Uint8List>();
  final calls = <String>[];

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<Stream<Uint8List>> start() async {
    calls.add('start');
    return controller.stream;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async => calls.add('dispose');

  /// Hands [chunk] to the listener and lets it run.
  Future<void> deliver(Uint8List chunk) async {
    controller.add(chunk);
    await Future<void>.delayed(Duration.zero);
  }
}

class MemorySink implements NarrationSink {
  final written = BytesBuilder();
  bool finished = false;
  bool discarded = false;

  @override
  void add(Uint8List chunk) => written.add(chunk);

  @override
  Future<void> finish() async => finished = true;

  @override
  Future<void> discard() async => discarded = true;
}

({NarrationRecorder recorder, FakeSource source, MemorySink sink}) rig(
    {int eventCount = 4, bool permitted = true}) {
  final source = FakeSource(permitted: permitted);
  final sink = MemorySink();
  return (
    recorder:
        NarrationRecorder(source: source, sink: sink, eventCount: eventCount),
    source: source,
    sink: sink,
  );
}

TutorialSection partFrom({
  String fen = _start,
  String? pgn,
  LessonStepKind kind = LessonStepKind.show,
  String? instruction,
}) {
  final read = readStepTree(fen: fen, pgn: pgn);
  return TutorialSection(
    root: read.root,
    title: 'Deo',
    kind: kind,
    instruction: instruction,
  );
}

void main() {
  group('the clock is the audio', () {
    test('a marker is the byte count, however late the audio arrived',
        () async {
      final r = rig();
      await r.recorder.start();
      // The warm-up happens here, in real time, and must cost the take nothing.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      for (var i = 0; i < 10; i++) {
        await r.source.deliver(chunkOf());
      }

      expect(r.recorder.next(), NarrationNext.advanced);
      expect(r.recorder.markersMs, [0, 800],
          reason: 'ten 80 ms chunks are 800 ms of audio — a wall clock here '
              'would read the 120 ms warm-up and nothing else');
    });

    test('beat 0 begins at the first sample', () async {
      final r = rig();
      await r.recorder.start();
      expect(r.recorder.state, NarrationState.warmingUp);
      expect(r.recorder.markersMs, isEmpty);

      await r.source.deliver(chunkOf());
      expect(r.recorder.state, NarrationState.recording);
      expect(r.recorder.markersMs, [0]);
      expect(r.recorder.beat, 0);
    });

    test('„Next" before the microphone has woken up is refused', () async {
      final r = rig();
      await r.recorder.start();
      expect(r.recorder.next(), NarrationNext.notListening,
          reason: 'there is no audio yet, so there is no moment to name');
      expect(r.recorder.beat, 0);
    });

    test('a pause stops the clock, and a beat advanced in it lands on the seam',
        () async {
      final r = rig();
      await r.recorder.start();
      for (var i = 0; i < 5; i++) {
        await r.source.deliver(chunkOf()); // 400 ms
      }
      await r.recorder.pause();
      // Android's one chunk after the pause: in the audio, so on the clock.
      await r.source.deliver(chunkOf()); // 480 ms
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(r.recorder.next(), NarrationNext.advanced);
      expect(r.recorder.next(), NarrationNext.clockHasNotMoved,
          reason: 'a second beat inside one pause would share its moment');

      await r.recorder.resume();
      for (var i = 0; i < 5; i++) {
        await r.source.deliver(chunkOf()); // 880 ms
      }
      expect(r.recorder.next(), NarrationNext.advanced);
      expect(r.recorder.markersMs, [0, 480, 880],
          reason: 'no time passes in the audio while it is paused');
      expect(r.source.calls, containsAllInOrder(['pause', 'resume']));
    });
  });

  group('two beats never share a moment', () {
    test('a key held down advances once per chunk, not once per repeat',
        () async {
      final r = rig(eventCount: 10);
      await r.recorder.start();
      await r.source.deliver(chunkOf());
      await r.source.deliver(chunkOf());

      expect(r.recorder.next(), NarrationNext.advanced);
      expect(r.recorder.next(), NarrationNext.clockHasNotMoved);
      expect(r.recorder.next(), NarrationNext.clockHasNotMoved);
      expect(r.recorder.beat, 1);
    });

    test('the last beat does not advance', () async {
      final r = rig(eventCount: 2);
      await r.recorder.start();
      await r.source.deliver(chunkOf());
      await r.source.deliver(chunkOf());
      expect(r.recorder.next(), NarrationNext.advanced);
      await r.source.deliver(chunkOf());
      expect(r.recorder.isLastBeat, isTrue);
      expect(r.recorder.next(), NarrationNext.atEnd);
      expect(r.recorder.markersMs, hasLength(2));
    });
  });

  group('the file and the markers are one number', () {
    test('every byte counted is written, the chunk after a pause included',
        () async {
      final r = rig();
      await r.recorder.start();
      await r.source.deliver(chunkOf());
      await r.recorder.pause();
      await r.source.deliver(chunkOf(bytes: 1280));
      await r.recorder.resume();
      await r.source.deliver(chunkOf());

      final take = await r.recorder.stop();
      expect(r.sink.written.length, 2560 + 1280 + 2560);
      expect(take!.durationMs, audioMsOf(r.sink.written.length));
      expect(r.sink.finished, isTrue);
    });

    test('a chunk after stop is neither written nor counted', () async {
      final r = rig();
      await r.recorder.start();
      await r.source.deliver(chunkOf());
      final take = await r.recorder.stop();
      r.source.controller.add(chunkOf());
      await Future<void>.delayed(Duration.zero);

      expect(take!.durationMs, 80);
      expect(r.sink.written.length, _chunkBytes);
    });

    test('a take that never heard its first sample is no take', () async {
      final r = rig();
      await r.recorder.start();
      expect(await r.recorder.stop(), isNull);
      expect(r.sink.discarded, isTrue);
      expect(r.sink.finished, isFalse);
    });

    test('cancel throws the audio away', () async {
      final r = rig();
      await r.recorder.start();
      await r.source.deliver(chunkOf());
      await r.recorder.cancel();
      expect(r.sink.discarded, isTrue);
      expect(r.recorder.state, NarrationState.stopped);
    });
  });

  group('the take', () {
    test('complete when every beat has a place in the audio', () async {
      final r = rig(eventCount: 2);
      await r.recorder.start();
      await r.source.deliver(chunkOf());
      final partial = await r.recorder.stop();
      expect(partial!.isComplete, isFalse,
          reason:
              'stopped on beat 0 of 2 — nothing to export the rest against');

      final whole = rig(eventCount: 2);
      await whole.recorder.start();
      await whole.source.deliver(chunkOf());
      await whole.source.deliver(chunkOf());
      whole.recorder.next();
      await whole.source.deliver(chunkOf());
      final take = await whole.recorder.stop();
      expect(take!.isComplete, isTrue);
      expect(take.lastBeatMs, 80);
    });

    test('which beat is on screen at a point in the audio', () {
      final take = NarrationTake(
        markersMs: [0, 1000, 2500],
        durationMs: 4000,
        eventCount: 3,
        peakDbfs: -20,
        recordedAt: DateTime(2026, 9, 10),
      );
      expect([0, 999, 1000, 2499, 2500, 3999].map(take.beatAt),
          [0, 0, 1, 1, 2, 2]);
    });

    test('survives its own json', () {
      final take = NarrationTake(
        markersMs: [0, 480, 880],
        durationMs: 1200,
        eventCount: 3,
        peakDbfs: -22.3,
        recordedAt: DateTime(2026, 9, 10, 14, 2),
      );
      final back = NarrationTake.fromJson(take.toJson());
      expect(back.markersMs, take.markersMs);
      expect(back.durationMs, 1200);
      expect(back.eventCount, 3);
      expect(back.peakDbfs, -22.3);
      expect(back.recordedAt, take.recordedAt);
    });
  });

  group('a muted microphone is not a quiet trainer', () {
    test('digital silence is heard as nothing', () async {
      final r = rig();
      await r.recorder.start();
      for (var i = 0; i < 5; i++) {
        await r.source.deliver(chunkOf(peak: 1)); // ±1, the −90 dB of a mute
      }
      expect(r.recorder.heardAnything, isFalse);
      expect(r.recorder.silentMs, 400);
      final take = await r.recorder.stop();
      expect(take!.heardAnything, isFalse);
    });

    test('a live microphone between sentences is not silence', () async {
      final r = rig();
      await r.recorder.start();
      await r.source.deliver(chunkOf(peak: 8000)); // speech, about −12 dB
      await r.source.deliver(chunkOf(peak: 20)); // a quiet room, about −64 dB
      expect(r.recorder.heardAnything, isTrue);
      expect(r.recorder.silentMs, 0,
          reason: 'a room noise floor is a live microphone');
    });

    test('the level is read from the samples', () {
      expect(peakDbfsOf(Uint8List(64)), silenceFloorDbfs);
      expect(peakDbfsOf(chunkOf(peak: 32767)), closeTo(0, 0.01));
      expect(peakDbfsOf(chunkOf(peak: 1)), closeTo(-90.3, 0.1));
      expect(peakDbfsOf(chunkOf(peak: 1)), lessThan(liveMicrophoneDbfs));
      expect(peakDbfsOf(chunkOf(peak: 20)), greaterThan(liveMicrophoneDbfs));
    });
  });

  test('without permission nothing is asked of the microphone', () async {
    final r = rig(permitted: false);
    expect(await r.recorder.start(), NarrationStart.noPermission);
    expect(r.source.calls, isNot(contains('start')));
    expect(r.recorder.state, NarrationState.idle);
    expect(r.sink.discarded, isTrue,
        reason: 'the sink made its file before the question was asked');
  });

  group('the film and the recording walk one projection', () {
    test('beat i of the recording is event i of the film', () {
      final draft = TutorialDraft(title: 'Film', sections: [
        partFrom(pgn: '{ Otvaranje. } 1. e4 e5 2. Nf3'),
        partFrom(
          fen: '4k3/8/5K2/4P3/8/8/8/8 w - - 0 12',
          pgn: '1. e6',
          kind: LessonStepKind.askMove,
          instruction: 'Nađi potez.',
        ),
      ]);
      final stops = filmBeatsOf(draft);
      final events = tutorialVideoOf(draft).events;

      expect(stops, hasLength(events.length));
      for (var i = 0; i < stops.length; i++) {
        final data = events[i]['data'] as Map;
        expect(data['fen'], stops[i].beat.node.fen, reason: 'beat $i');
        expect(data['text'] ?? '', stops[i].caption, reason: 'beat $i');
      }
    });
  });

  group('on disk', () {
    late Directory temp;
    late NarrationTakeStore store;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('narration_');
      store = NarrationTakeStore(() async => temp);
    });
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Future<StoredNarration> record(int lessonId, int chunks) async {
      final path = await store.newRecordingPath(lessonId);
      final sink = WavFileSink(path);
      final source = FakeSource();
      final recorder =
          NarrationRecorder(source: source, sink: sink, eventCount: 1);
      await recorder.start();
      for (var i = 0; i < chunks; i++) {
        await source.deliver(chunkOf());
      }
      final take = await recorder.stop();
      return store.keep(lessonId, take!, path);
    }

    test('the wav says how much audio it holds, and the markers agree',
        () async {
      final stored = await record(7, 25);
      final bytes = File(stored.audioPath).readAsBytesSync();
      final length = wavDataLengthOf(bytes.sublist(0, 44));

      expect(length, 25 * _chunkBytes);
      expect(bytes.length, 44 + 25 * _chunkBytes);
      expect(audioMsOf(length!), stored.take.durationMs);
      expect(stored.take.durationMs, 2000);
    });

    test('a take is read back as it was kept', () async {
      final kept = await record(7, 10);
      final loaded = await store.load(7);
      expect(loaded.unreadable, isFalse);
      expect(loaded.stored!.audioPath, kept.audioPath);
      expect(loaded.stored!.take.markersMs, kept.take.markersMs);
    });

    test('a retake replaces the old one and leaves one wav behind', () async {
      final first = await record(7, 10);
      final second = await record(7, 30);

      expect(File(first.audioPath).existsSync(), isFalse);
      final loaded = await store.load(7);
      expect(loaded.stored!.audioPath, second.audioPath);
      expect(loaded.stored!.take.durationMs, 2400);
      final wavs = Directory('${temp.path}${Platform.pathSeparator}lesson_7')
          .listSync()
          .where((e) => e.path.endsWith('.wav'));
      expect(wavs, hasLength(1));
    });

    test('markers for a different length of audio are unreadable, not none',
        () async {
      final kept = await record(7, 10);
      // The audio replaced underneath the index — what a crash between the two
      // writes would leave if they were done in the other order.
      final other = WavFileSink(kept.audioPath)
        ..add(chunkOf())
        ..add(chunkOf());
      await other.finish();

      final loaded = await store.load(7);
      expect(loaded.unreadable, isTrue);
      expect(loaded.stored, isNull);
    });

    test('an index naming missing audio is unreadable', () async {
      final kept = await record(7, 10);
      File(kept.audioPath).deleteSync();
      expect((await store.load(7)).unreadable, isTrue);
    });

    test('no take is none', () async {
      final loaded = await store.load(8);
      expect(loaded.unreadable, isFalse);
      expect(loaded.stored, isNull);
    });

    test('an abandoned recording is never mistaken for a take', () async {
      final path = await store.newRecordingPath(9);
      WavFileSink(path)
        ..add(chunkOf())
        ..finish();
      expect(path, endsWith('.partial'));
      expect((await store.load(9)).stored, isNull);
    });

    test('two recordings are never given one name', () async {
      final a = await store.newRecordingPath(7);
      final b = await store.newRecordingPath(7);
      expect(a, isNot(b));
    });

    test('discard removes the file', () async {
      final path = await store.newRecordingPath(7);
      final sink = WavFileSink(path)..add(chunkOf());
      await sink.discard();
      expect(File(path).existsSync(), isFalse);
    });

    test('delete takes the whole take with it', () async {
      await record(7, 10);
      await store.delete(7);
      expect((await store.load(7)).stored, isNull);
    });
  });
}
