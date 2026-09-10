import 'dart:typed_data';

import 'package:record/record.dart';

import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';

/// The microphone, through `record` 7.1.1 — the only file that names the
/// plugin, so the core in `narration_take.dart` can be tested without one.
///
/// `startStream` with `AudioEncoder.pcm16bits` is phase 0's answer: the package
/// has no position API, and raw PCM is what lets bytes ÷ byte rate be the clock.
/// No gain control, echo cancellation or noise suppression is asked for — each
/// is a processing step between the voice and the byte count, and the default
/// of all three is off on every target.
class RecordPcmSource implements PcmSource {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: narrationSampleRate,
        numChannels: narrationChannels,
      ));

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
