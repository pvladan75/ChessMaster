/// A RIFF/WAVE clip read from its own bytes — the app's reader of the speech
/// clips, and the gate's (`test/speech_clips_test.dart`).
///
/// Walks the chunk list rather than assuming the canonical 44-byte header,
/// as the server's `wav.js` does, and reads 16-bit PCM only, which is what
/// every clip is (`kSpeechBitsPerSample`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

class WavClip {
  const WavClip({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.pcm,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  /// The samples, little-endian 16-bit, as they are in the file.
  final Uint8List pcm;

  int get frameBytes => (bitsPerSample ~/ 8) * channels;
  int get frames => pcm.length ~/ frameBytes;
  double get seconds => frames / sampleRate;

  /// Null when [bytes] is not a RIFF/WAVE file with a `fmt ` and a `data`
  /// chunk, or not 16-bit PCM.
  static WavClip? parse(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final data = ByteData.sublistView(bytes);
    if (String.fromCharCodes(bytes, 0, 4) != 'RIFF' ||
        String.fromCharCodes(bytes, 8, 12) != 'WAVE') {
      return null;
    }
    int? sampleRate;
    int? channels;
    int? bits;
    int? format;
    var at = 12;
    while (at + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes, at, at + 4);
      final length = data.getUint32(at + 4, Endian.little);
      final body = at + 8;
      if (id == 'fmt ' && length >= 16 && body + 16 <= bytes.length) {
        format = data.getUint16(body, Endian.little);
        channels = data.getUint16(body + 2, Endian.little);
        sampleRate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        if (format != 1 ||
            bits != 16 ||
            channels == null ||
            sampleRate == null) {
          return null;
        }
        final end = math.min(bytes.length, body + length);
        return WavClip(
          sampleRate: sampleRate,
          channels: channels,
          bitsPerSample: bits!,
          pcm: Uint8List.sublistView(bytes, body, end),
        );
      }
      at = body + length + (length.isOdd ? 1 : 0);
    }
    return null;
  }

  /// The loudest sample, in dBFS, over the frames between two times. −∞ when
  /// the range is empty or silent. The gate uses it with the server's speech
  /// floor (−40 dBFS over 20 ms) to see where a clip's voice is.
  double peakDbfs({required double fromSeconds, required double toSeconds}) {
    final data = ByteData.sublistView(pcm);
    final from = (fromSeconds * sampleRate).round().clamp(0, frames);
    final to = (toSeconds * sampleRate).round().clamp(0, frames);
    var peak = 0;
    for (var frame = from; frame < to; frame++) {
      final sample = data.getInt16(frame * frameBytes, Endian.little).abs();
      if (sample > peak) peak = sample;
    }
    if (peak == 0) return double.negativeInfinity;
    return 20 * math.log(peak / 32768) / math.ln10;
  }
}
