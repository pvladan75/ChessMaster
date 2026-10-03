/// The gate of `docs/PLAN-GOVOR-IZ-KLIPOVA.md`, phase 1: the speech clips on
/// disk are the ones the Dart vocabulary asks for.
///
/// Three files under `assets/speech/` are held together here: the vocabulary
/// (`lib/core/speech/vocabulary.dart`, the home), `manifest.json` (written
/// from it by `tool/speech_manifest.dart`), and `rendered.json` (the lock
/// `tools/speech_clips/render.js` leaves: for every id, the carrier, the words
/// and the voice its clip was cut from). A text edited in the vocabulary
/// without a regeneration fails the first case; a carrier or voice changed
/// without a re-render fails the second; a clip missing, empty, silent, in
/// another format or cut with silence hanging off an edge fails the third.
///
/// What this gate cannot see is a clip cut at the wrong word that still holds
/// a word: „bishop" where „d7" was asked is speech of the right length in the
/// right format. The recipe (which words of which carrier) is held here, the
/// midpoint arithmetic in `tools/speech_clips/test/`, and the clip itself is
/// for the owner's ear in phase 3.
///
/// The numbers are measured on the first render (2.10.2026, Andrew, 277
/// clips): a phrase has at most 20 ms of silence at either edge (the trim's
/// margin plus one block); a cut clip has at most 200 ms at its head — the
/// midpoint of a pause before „Check." or „promotes to" — and 19 ms at its
/// tail; the longest clip is 4.26 s.
library;

import 'dart:convert';
import 'dart:io';

import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/core/speech/wav_clip.dart';
import 'package:flutter_test/flutter_test.dart';

const _speechFloorDbfs = -40.0;
const _blockSeconds = 0.020;

final _assets = Directory('assets/speech');

/// Seconds of silence at the head and the tail of [clip], in 20 ms blocks
/// against the server's speech floor.
({double head, double tail}) _silentEdges(WavClip clip) {
  final blocks = (clip.seconds / _blockSeconds).ceil();
  int first = -1;
  int last = -1;
  for (var b = 0; b < blocks; b++) {
    final peak = clip.peakDbfs(
      fromSeconds: b * _blockSeconds,
      toSeconds: (b + 1) * _blockSeconds,
    );
    if (peak >= _speechFloorDbfs) {
      if (first < 0) first = b;
      last = b;
    }
  }
  if (first < 0) return (head: clip.seconds, tail: clip.seconds);
  return (
    head: first * _blockSeconds,
    tail: clip.seconds - (last + 1) * _blockSeconds,
  );
}

void main() {
  final tokens = SpeechVocabulary.tokens;

  test('the vocabulary is what it was designed to be', () {
    expect(tokens.length, 284);
    expect(tokens.map((t) => t.id).toSet().length, tokens.length,
        reason: 'ids are unique');
    for (final f in kFiles.split('')) {
      for (var r = 1; r <= 8; r++) {
        expect(SpeechVocabulary.square('$f$r').isSquare, isTrue);
        expect(
            SpeechVocabulary.square('$f$r', afterTakes: true).isSquare, isTrue);
      }
    }
    expect(SpeechVocabulary.number(0).text, '0');
    expect(SpeechVocabulary.number(99).text, '99');
    expect(SpeechVocabulary.piece('knight').text, 'knight');
    expect(SpeechVocabulary.fileLetter('a').carrier, 'White plays rook a a8.');
    expect(SpeechVocabulary.whitePlays.carrierWordCount, 4);
    expect(SpeechVocabulary.check.carrierWordCount, 5);
    expect(SpeechVocabulary.promotesTo.carrierWordCount, 7);
    for (final t in tokens) {
      if (t.kind == SpeechTokenKind.cut) {
        expect(t.wordFrom, isNotNull);
        expect(t.wordTo, inInclusiveRange(t.wordFrom!, t.carrierWordCount),
            reason: '${t.id} asks for words outside its carrier');
      } else {
        expect(t.carrier, t.text);
        expect(t.text, endsWith('.'), reason: '${t.id} is a sentence');
      }
    }
  });

  test('manifest.json is the vocabulary, regenerated', () {
    final onDisk = File('${_assets.path}/manifest.json').readAsStringSync();
    expect(onDisk, SpeechVocabulary.manifestText(),
        reason: 'run `dart run tool/speech_manifest.dart`');
  });

  test(
      'rendered.json says every clip was cut from the carrier, the words '
      'and the voice the vocabulary asks for', () {
    final lock =
        jsonDecode(File('${_assets.path}/rendered.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final t in tokens) {
      final entry = lock[t.id] as Map<String, dynamic>?;
      expect(entry, isNotNull, reason: '${t.id} was never rendered');
      expect(entry!['kind'], t.kind.name, reason: t.id);
      expect(entry['carrier'], t.carrier,
          reason: '${t.id}: the carrier changed; run the renderer');
      expect(entry['wordFrom'], t.wordFrom, reason: t.id);
      expect(entry['wordTo'], t.wordTo, reason: t.id);
      expect(entry['voice'], kSpeechVoice, reason: t.id);
    }
    expect(
        lock.keys.toSet().difference(tokens.map((t) => t.id).toSet()), isEmpty,
        reason: 'the lock names ids the vocabulary does not have');
  });

  test('every clip is there, in the one format, with its voice at the edges',
      () {
    for (final t in tokens) {
      final file = File('${_assets.path}/${t.id}.wav');
      expect(file.existsSync(), isTrue, reason: '${t.id}.wav is missing');
      final clip = WavClip.parse(file.readAsBytesSync());
      expect(clip, isNotNull, reason: '${t.id}.wav is not 16-bit PCM');
      expect(clip!.sampleRate, kSpeechSampleRate, reason: t.id);
      expect(clip.channels, kSpeechChannels, reason: t.id);
      expect(clip.bitsPerSample, kSpeechBitsPerSample, reason: t.id);
      expect(clip.seconds, greaterThan(0.1), reason: '${t.id} is empty');
      expect(clip.seconds, lessThan(4.5), reason: '${t.id} is too long');
      final edges = _silentEdges(clip);
      expect(edges.head, lessThan(clip.seconds),
          reason: '${t.id} has no speech above the floor');
      final headLimit = t.kind == SpeechTokenKind.phrase ? 0.045 : 0.25;
      expect(edges.head, lessThanOrEqualTo(headLimit),
          reason: '${t.id}: ${(edges.head * 1000).round()} ms of silence at '
              'the head — cut in the wrong place or not trimmed');
      expect(edges.tail, lessThanOrEqualTo(0.06),
          reason: '${t.id}: ${(edges.tail * 1000).round()} ms of silence at '
              'the tail');
    }
  });

  test('no clip on disk belongs to no token', () {
    final ids = tokens.map((t) => '${t.id}.wav').toSet();
    final stray = _assets
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.wav') && !ids.contains(name))
        .toList();
    expect(stray, isEmpty);
  });
}
