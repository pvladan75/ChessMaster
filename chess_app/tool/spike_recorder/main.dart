// Phase 0 of docs/PLAN-SNIMANJE.md — the throwaway spike.
//
// One question, on both targets: **can the recorder tell us where it is in its
// own recording?** `record` 7.1.1 exposes no position at all — no getter, no
// stream, nothing — so the answer has to come from the audio itself:
// `startStream` hands out raw PCM, and bytes ÷ byte rate *is* the audio clock.
//
// What this measures:
//   1. warm-up — from `startStream` returning to the first sample arriving;
//   2. drift — wall clock against the byte clock, sampled every second;
//   3. pause — whether the byte clock stops when the recorder does;
//   4. the file — a wav written from the stream, for ffprobe to cross-check.
//
// It drives itself and exits, so it needs no clicking on either platform.
//
// Run:
//   flutter run -d windows -t tool/spike_recorder/main.dart
//   flutter run -d <android-id> -t tool/spike_recorder/main.dart
//
// This file is thrown away when phase 0 is answered. Nothing imports it.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

const int sampleRate = 16000;
const int channels = 1;
const int bytesPerSample = 2; // pcm16bits
const int byteRate = sampleRate * channels * bytesPerSample;

/// Where the byte clock says we are, in milliseconds.
int audioMsOf(int bytes) => (bytes * 1000) ~/ byteRate;

void log(String line) => debugPrint('[SPIKE] $line');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(body: Center(child: Text('recorder spike — see the console'))),
  ));
  // A frame first, so the platform channels are up on both targets.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await measure();
}

Future<void> measure() async {
  log('platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');

  final recorder = AudioRecorder();
  try {
    final allowed = await recorder.hasPermission();
    log('hasPermission: $allowed');
    if (!allowed) {
      log('RESULT: no microphone permission — nothing else can be measured here');
      await recorder.dispose();
      exit(2);
    }

    final devices = await recorder.listInputDevices();
    log('input devices: ${devices.map((d) => d.label).toList()}');

    var bytes = 0;
    int? firstChunkAtMs;
    final samples = <String>[];
    final wall = Stopwatch()..start();

    final chunks = <Uint8List>[];
    final config = const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: channels,
    );

    final askedAtMs = wall.elapsedMilliseconds;
    final stream = await recorder.startStream(config);
    final returnedAtMs = wall.elapsedMilliseconds;
    log('startStream returned after ${returnedAtMs - askedAtMs} ms');

    final sub = stream.listen((chunk) {
      firstChunkAtMs ??= wall.elapsedMilliseconds;
      bytes += chunk.length;
      chunks.add(chunk);
    });

    // 1. Warm-up: how long before the first sample lands. This is the whole
    //    reason a marker must not be a wall-clock reading.
    while (firstChunkAtMs == null && wall.elapsedMilliseconds < 5000) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (firstChunkAtMs == null) {
      log('RESULT: no audio arrived within 5 s — this machine has no usable input');
      await sub.cancel();
      await recorder.stop();
      await recorder.dispose();
      exit(3);
    }
    log('warm-up: first sample ${firstChunkAtMs! - returnedAtMs} ms after '
        'startStream returned, ${firstChunkAtMs! - askedAtMs} ms after asking');

    // 2. Drift: wall clock against byte clock, once a second.
    Future<void> sampleFor(int seconds, String phase) async {
      for (var i = 0; i < seconds; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final wallMs = wall.elapsedMilliseconds - firstChunkAtMs!;
        final audioMs = audioMsOf(bytes);
        samples.add('$phase wall=${wallMs}ms audio=${audioMs}ms '
            'delta=${wallMs - audioMs}ms');
      }
    }

    await sampleFor(6, 'run  ');

    // 3. Pause: the byte clock has to stop with the recorder, or „pausing also
    //    pauses the marker clock" is not something the client can implement.
    final beforePause = bytes;
    await recorder.pause();
    log('paused at audio=${audioMsOf(bytes)}ms');
    await Future<void>.delayed(const Duration(seconds: 3));
    final duringPause = bytes - beforePause;
    await recorder.resume();
    log('resumed; bytes that arrived while paused: $duringPause '
        '(${audioMsOf(duringPause)} ms of audio)');

    await sampleFor(6, 'after');

    await sub.cancel();
    await recorder.stop();

    for (final line in samples) {
      log(line);
    }

    // 4. The file, so ffprobe can be asked the same question independently.
    final all = BytesBuilder();
    for (final chunk in chunks) {
      all.add(chunk);
    }
    final pcm = all.takeBytes();
    final path = '${Directory.systemTemp.path}/spike_recording.wav';
    await File(path).writeAsBytes(wavOf(pcm));

    log('bytes: ${pcm.length}, byte clock says ${audioMsOf(pcm.length)} ms');
    log('wall clock from first sample to stop: '
        '${wall.elapsedMilliseconds - firstChunkAtMs!} ms');
    log('wav written: $path');
    log('RESULT: ok');
  } catch (e, st) {
    log('FAILED: $e');
    log('$st');
    await recorder.dispose();
    exit(1);
  }

  await recorder.dispose();
  exit(0);
}

/// A 16-bit PCM wav header in front of the samples.
Uint8List wavOf(Uint8List pcm) {
  final header = BytesBuilder();
  void ascii(String s) => header.add(s.codeUnits);
  void u32(int v) => header.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => header.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + pcm.length);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(channels);
  u32(sampleRate);
  u32(byteRate);
  u16(channels * bytesPerSample);
  u16(8 * bytesPerSample);
  ascii('data');
  u32(pcm.length);

  return Uint8List.fromList([...header.takeBytes(), ...pcm]);
}
