/// The voice that plays a [SpokenLine] from the shipped clips —
/// `docs/PLAN-GOVOR-IZ-KLIPOVA.md` §2. No decoder, no network, no file
/// written: the PCM of the tokens is joined under one RIFF header, with 50 ms
/// of silence before a square (D6) and nothing between any other pair, and
/// handed to the player as bytes.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show AssetBundle;

import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/core/speech/wav_clip.dart';

/// Where the bytes go. A seam, so a test records them instead of playing.
abstract class ClipPlayer {
  /// Plays [wav] and completes when it has been played to the end, or [stop]
  /// cut it off.
  Future<void> play(Uint8List wav);
  Future<void> stop();
}

/// The `audioplayers` package, which the app already has.
class AudioplayersClipPlayer implements ClipPlayer {
  AudioplayersClipPlayer();

  AudioPlayer? _player;
  Completer<void>? _playing;

  AudioPlayer get _p => _player ??= AudioPlayer();

  @override
  Future<void> play(Uint8List wav) async {
    final player = _p;
    final done = Completer<void>();
    _playing = done;
    late final StreamSubscription<void> sub;
    sub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await player.play(BytesSource(wav));
      // The clip's own length plus a margin: a platform that never reports the
      // end must not hold the line's queue for ever.
      final clip = WavClip.parse(wav);
      final seconds = clip == null ? 5.0 : clip.seconds;
      await done.future.timeout(
        Duration(milliseconds: (seconds * 1000).round() + 2000),
        onTimeout: () {},
      );
    } finally {
      await sub.cancel();
      if (identical(_playing, done)) _playing = null;
    }
  }

  @override
  Future<void> stop() async {
    final done = _playing;
    if (done != null && !done.isCompleted) done.complete();
    await _player?.stop();
  }
}

/// A clip the bundle does not have, or has but cannot be read (D10). Names the
/// token, so Settings can say which one.
class SpeechClipLoadError implements Exception {
  SpeechClipLoadError(this.tokenId, this.detail);

  final String tokenId;
  final String detail;

  @override
  String toString() => 'Speech clip "$tokenId" cannot be loaded: $detail';
}

class ClipVoice {
  ClipVoice({ClipPlayer? player}) : _player = player;

  ClipPlayer? _player;
  ClipPlayer get _p => _player ??= AudioplayersClipPlayer();

  final Map<String, WavClip> _clips = {};

  bool get isLoaded => _clips.length == SpeechVocabulary.tokens.length;

  /// Reads `assets/speech/<id>.wav` for every token of the vocabulary. Completes
  /// with a [SpeechClipLoadError] naming the first token whose clip is missing
  /// or is not a 16-bit PCM WAVE file in the clips' own format.
  Future<void> load(AssetBundle bundle) async {
    final loaded = <String, WavClip>{};
    for (final token in SpeechVocabulary.tokens) {
      final ByteData data;
      try {
        data = await bundle.load('assets/speech/${token.id}.wav');
      } catch (e) {
        throw SpeechClipLoadError(token.id, 'not in the bundle ($e)');
      }
      final clip = WavClip.parse(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      if (clip == null) {
        throw SpeechClipLoadError(token.id, 'not a 16-bit PCM WAVE file');
      }
      loaded[token.id] = clip;
    }
    _clips
      ..clear()
      ..addAll(loaded);
  }

  /// Stitches [line] and plays it. Completes when it has been heard.
  Future<void> speak(SpokenLine line) {
    final wav = stitch(line, (token) {
      final clip = _clips[token.id];
      if (clip == null) {
        throw StateError('speech clip "${token.id}" was not loaded');
      }
      return clip;
    });
    return _p.play(wav);
  }

  /// Never creates the player just to stop it: nothing has played if there is
  /// none.
  Future<void> stop() async => await _player?.stop();

  /// One RIFF file from the clips of [line]. Pure: [clipOf] is the only way in.
  ///
  /// All clips must be in the format of the first; a clip in another is
  /// refused rather than resampled, because a wrong rate plays as a wrong
  /// voice, not as an error.
  static Uint8List stitch(
      SpokenLine line, WavClip Function(SpeechToken) clipOf) {
    if (line.tokens.isEmpty) {
      throw StateError('an empty line has nothing to stitch');
    }
    WavClip? first;
    final body = BytesBuilder(copy: false);
    for (final token in line.tokens) {
      final clip = clipOf(token);
      if (first == null) {
        first = clip;
      } else if (clip.sampleRate != first.sampleRate ||
          clip.channels != first.channels ||
          clip.bitsPerSample != first.bitsPerSample) {
        throw StateError('speech clip "${token.id}" is '
            '${clip.sampleRate} Hz / ${clip.channels} ch / '
            '${clip.bitsPerSample} bit, the line is '
            '${first.sampleRate} Hz / ${first.channels} ch / '
            '${first.bitsPerSample} bit');
      }
      if (token.isSquare) {
        final frames = first.sampleRate * kPauseBeforeSquareMs ~/ 1000;
        body.add(Uint8List(frames * first.frameBytes));
      }
      body.add(clip.pcm);
    }
    final pcm = body.takeBytes();
    final f = first!;
    final out = ByteData(44 + pcm.length);
    void tag(int at, String s) {
      for (var i = 0; i < 4; i++) {
        out.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    out.setUint32(4, 36 + pcm.length, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little);
    out.setUint16(22, f.channels, Endian.little);
    out.setUint32(24, f.sampleRate, Endian.little);
    out.setUint32(28, f.sampleRate * f.frameBytes, Endian.little);
    out.setUint16(32, f.frameBytes, Endian.little);
    out.setUint16(34, f.bitsPerSample, Endian.little);
    tag(36, 'data');
    out.setUint32(40, pcm.length, Endian.little);
    final bytes = out.buffer.asUint8List();
    bytes.setRange(44, 44 + pcm.length, pcm);
    return bytes;
  }
}
