import 'dart:async';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/services/speech_service.dart';

/// The service's own rules, on the clips' voice alone.
///
/// Until 3.10.2026 this file also held the device synthesiser's rules — which
/// voice is picked out of what the machine has, a language that is listed but
/// not installed, the rate reaching the engine, the reading speed measured
/// sentence by sentence. The device voice is gone (phase 4 of
/// `docs/PLAN-GOVOR-IZ-KLIPOVA.md`, its last step), and those cases went with
/// the code they held. `git log -S FakeTts` finds them.

/// A clip voice that only remembers the lines it was asked to play.
class _Voice extends ClipVoice {
  _Voice({this.failToLoad, this.failOnSpeak = false});

  /// Thrown by `load`, as a broken bundle throws.
  final Object? failToLoad;
  final bool failOnSpeak;

  final List<SpokenLine> lines = [];
  int stops = 0;

  /// When set, a line does not finish until this completes.
  Completer<void>? hold;

  List<String> get said =>
      [for (final l in lines) l.tokens.map((t) => t.id).join(' ')];

  @override
  Future<void> load(AssetBundle bundle) async {
    final error = failToLoad;
    if (error != null) throw error;
  }

  @override
  Future<void> speak(SpokenLine line) async {
    if (failOnSpeak) throw StateError('cannot play');
    lines.add(line);
    await hold?.future;
  }

  @override
  Future<void> stop() async => stops += 1;
}

Future<SpeechService> _ready(_Voice voice, {bool enabled = true}) async {
  final service = SpeechService.forTesting();
  await service.init(enabled: enabled, clipVoice: voice);
  return service;
}

SpokenLine _line(SpeechToken token) => SpokenLine([token]);

void main() {
  final correct = _line(SpeechVocabulary.correct);
  final checkmate = _line(SpeechVocabulary.checkmate);
  final solved = _line(SpeechVocabulary.puzzleSolved);

  group('the state', () {
    test('on, with the clips loaded, it is ready; off is off', () async {
      final on = await _ready(_Voice());
      expect(on.state, SpeechState.ready);
      expect(on.canSpeakNow(), isTrue);
      final off = await _ready(_Voice(), enabled: false);
      expect(off.state, SpeechState.off);
      expect(off.canSpeakNow(), isFalse);
      await off.setEnabled(true);
      expect(off.state, SpeechState.ready);
    });

    test('a broken bundle is failed, with the reason, and says nothing',
        () async {
      final voice = _Voice(
          failToLoad: SpeechClipLoadError('file_c', 'not in the bundle'));
      final service = await _ready(voice);
      expect(service.state, SpeechState.failed);
      expect(service.failureReason, contains('file_c'));
      await service.speakLine(correct);
      expect(voice.lines, isEmpty);
      // Switching on cannot clear a broken build.
      await service.setEnabled(true);
      expect(service.state, SpeechState.failed);
    });

    test('switched off, it says nothing at all', () async {
      final voice = _Voice();
      final service = await _ready(voice, enabled: false);
      await service.speakLine(correct);
      expect(voice.lines, isEmpty);
    });

    test('a voice that cannot play is a log line, not a crash', () async {
      final voice = _Voice(failOnSpeak: true);
      final service = await _ready(voice);
      await service.speakLine(correct);
      expect(service.isSpeaking, isFalse);
    });
  });

  group('speaking', () {
    test('the same line twice in a row is said once, unless forced', () async {
      final voice = _Voice();
      final service = await _ready(voice);
      await service.speakLine(solved);
      await service.speakLine(solved);
      expect(voice.lines, hasLength(1));
      await service.speakLine(solved, force: true);
      expect(voice.lines, hasLength(2));
      service.forget();
      await service.speakLine(solved);
      expect(voice.lines, hasLength(3));
    });

    test('a line already started is heard out, and the next waits', () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      unawaited(service.speakLine(correct));
      await Future<void>.delayed(Duration.zero);
      expect(service.speaking, isTrue);
      unawaited(service.speakLine(checkmate));
      await Future<void>.delayed(Duration.zero);
      expect(voice.said, ['correct'], reason: 'it waits for the line');

      voice.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(voice.said, ['correct', 'checkmate']);
      await service.stop();
    });

    test('only the newest of the ones waiting is said', () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      unawaited(service.speakLine(correct));
      await Future<void>.delayed(Duration.zero);
      final first = service.speakLine(checkmate);
      final second = service.speakLine(solved);
      // The overwritten slot's future completes, so nothing waits for ever.
      await first.timeout(const Duration(milliseconds: 50));
      voice.hold!.complete();
      await second.timeout(const Duration(seconds: 1));
      expect(voice.said, ['correct', 'puzzle_solved']);
      await service.stop();
    });

    test('a queued line completes when it has been played, not when queued',
        () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      unawaited(service.speakLine(correct));
      await Future<void>.delayed(Duration.zero);
      var played = false;
      unawaited(service.speakLine(checkmate).then((_) => played = true));
      await Future<void>.delayed(Duration.zero);
      expect(played, isFalse);
      voice.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(played, isTrue);
    });

    test('what the reader does cuts it off, and drops what was waiting',
        () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      unawaited(service.speakLine(correct));
      await Future<void>.delayed(Duration.zero);
      final waiting = service.speakLine(checkmate);
      await service.stop();
      await waiting.timeout(const Duration(milliseconds: 50));
      expect(voice.stops, 1);
      expect(service.isSpeaking, isFalse);
      voice.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(voice.said, ['correct'], reason: 'the waiting line was dropped');
    });

    test('turning it off stops what is being said', () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      unawaited(service.speakLine(correct));
      await Future<void>.delayed(Duration.zero);
      await service.setEnabled(false);
      expect(voice.stops, 1);
      expect(service.state, SpeechState.off);
      voice.hold!.complete();
    });

    test('an empty line is not an utterance', () async {
      final voice = _Voice();
      final service = await _ready(voice);
      await service.speakLine(SpokenLine(const []));
      expect(voice.lines, isEmpty);
    });
  });

  test('speaking never marks a widget dirty', () async {
    // The panel asks for a sentence from initState and didUpdateWidget, which
    // run inside a build. A notification there is "setState() called during
    // build": the frame fails in layout, and what reaches the screen is a
    // board with no squares and the pieces floating over the background.
    final voice = _Voice();
    final service = await _ready(voice);
    var notifications = 0;
    service.addListener(() => notifications++);
    await service.speakLine(correct);
    expect(voice.lines, isNotEmpty);
    expect(notifications, 0);
  });

  group('waiting for the voice', () {
    test('it is speaking while the player has the line', () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      final speaking = service.speakLine(correct);
      expect(service.isSpeaking, isTrue);
      voice.hold!.complete();
      await speaking;
      expect(service.isSpeaking, isFalse);
    });

    test('a player that never reports the end does not freeze the board',
        () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      unawaited(service.speakLine(correct));
      expect(service.isSpeaking, isTrue);
      // The watchdog is measured from the sentence, so a one-word verdict
      // clears in a couple of seconds rather than waiting out the cap.
      await Future<void>.delayed(const Duration(milliseconds: 2400));
      expect(service.isSpeaking, isFalse);
      voice.hold!.complete();
    });

    test('stopping clears it at once', () async {
      final voice = _Voice()..hold = Completer<void>();
      final service = await _ready(voice);
      unawaited(service.speakLine(correct));
      expect(service.isSpeaking, isTrue);
      await service.stop();
      expect(service.isSpeaking, isFalse);
      voice.hold!.complete();
    });
  });
}
