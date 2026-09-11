// A sentence read by a voice for the tutorial's own language — phase 4 of
// docs/PLAN-JEZIK-GLASA.md.
//
// The machines below are the ones this ships to: a phone whose Google engine
// has Serbian, a Windows machine whose only voice for Serbian is the Croatian
// `Matej`, a machine with English and nothing else, and a Windows machine that
// lists Croatian without having it — `getLanguages` answers from the languages
// the system knows about, and setting such a voice throws.
//
// The rule every test here serves: **a tutorial in a language of its own is
// read by a voice for that language, or not at all.** Never by the Settings
// voice, which would read it in the wrong phonetics and sound as if it worked.
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/services/speech_service.dart';

/// An engine that remembers every voice it was put on and every sentence it
/// was handed, and refuses the voices it is told to.
class _Engine implements TtsEngine {
  _Engine(this.installed, {this.refuses = const {}});

  final List<String> installed;
  final Set<String> refuses;

  final voices = <String>[];
  final spoken = <({String voice, String text})>[];
  String? current;

  @override
  Future<List<String>> languages() async => installed;

  @override
  Future<void> setLanguage(String value) async {
    voices.add(value);
    if (refuses.contains(value)) throw StateError('no voice installed: $value');
    current = value;
  }

  @override
  Future<void> setSpeechRate(double value) async {}

  @override
  Future<void> speak(String text) async =>
      spoken.add((voice: current ?? '?', text: text));

  @override
  Future<void> stop() async {}
}

Future<SpeechService> _ready(_Engine engine) async {
  final service = SpeechService.forTesting(engine);
  await service.init(enabled: true, rate: 0.5, engine: engine);
  return service;
}

const _serbian = TutorialLanguage.serbianLatin;
const _cyrillic = TutorialLanguage.serbianCyrillic;

void main() {
  group('the voice is the language\'s', () {
    test('a Serbian sentence on a phone is read by the Serbian voice',
        () async {
      final engine = _Engine(['en-US', 'hr-HR', 'sr-RS']);
      final speech = await _ready(engine);

      await speech.speak('Odigraj Bc4.', language: _serbian);

      expect(engine.spoken.single.voice, 'sr-RS');
      // And in Serbian words: the moves are said by the language's own
      // vocabulary, not by the English one the Settings voice would use.
      expect(engine.spoken.single.text, 'Odigraj lovac ce četiri.');
    });

    test('on Windows it is Croatian, which reads Serbian in Latin script',
        () async {
      final engine = _Engine(['en-US', 'de-DE', 'hr-HR']);
      final speech = await _ready(engine);

      await speech.speak('Odigraj Bc4.', language: _serbian);

      expect(engine.spoken.single.voice, 'hr-HR');
    });

    test('a sentence with no language is exactly what it always was', () async {
      // Every tutorial saved before this, and all of the app's own text.
      final engine = _Engine(['en-US', 'hr-HR', 'sr-RS']);
      final speech = await _ready(engine);

      await speech.speak('Play Bc4.');

      expect(engine.spoken.single.voice, 'en-US');
      expect(engine.spoken.single.text, 'Play bishop c four.');
    });

    test('the engine goes back to the Settings voice for the app\'s own text',
        () async {
      final engine = _Engine(['en-US', 'sr-RS']);
      final speech = await _ready(engine);

      await speech.speak('Odigraj Bc4.', language: _serbian);
      await speech.speak('Correct.');

      expect(engine.spoken.map((s) => s.voice).toList(), ['sr-RS', 'en-US']);
    });

    test('and is not switched again for a sentence in the voice it is on',
        () async {
      // Switching costs a round trip to the platform before every sentence;
      // a walk through a Serbian tutorial must not pay it on each move.
      final engine = _Engine(['en-US', 'sr-RS']);
      final speech = await _ready(engine);
      final before = engine.voices.length;

      await speech.speak('Prva rečenica.', language: _serbian);
      await speech.speak('Druga rečenica.', language: _serbian);

      expect(engine.voices.length - before, 1);
    });
  });

  group('no voice for the language means no reading', () {
    test('Serbian on an English machine is not read at all', () async {
      final engine = _Engine(['en-US', 'de-DE']);
      final speech = await _ready(engine);

      expect(speech.canRead(_serbian), isFalse);
      await speech.speak('Odigraj Bc4.', language: _serbian);
      expect(engine.spoken, isEmpty,
          reason: 'an English voice reading Serbian sounds as if it worked');
    });

    test('Cyrillic is not read by Croatian', () async {
      final engine = _Engine(['en-US', 'hr-HR']);
      final speech = await _ready(engine);

      expect(speech.canRead(_cyrillic), isFalse);
      await speech.speak('Одиграј Bc4.', language: _cyrillic);
      expect(engine.spoken, isEmpty);
    });

    test('a machine with no English voice can still read a Serbian tutorial',
        () async {
      // The app's own text has nothing to read it, and that is not the
      // tutorial's problem: its language is the only question it asks.
      final engine = _Engine(['hr-HR']);
      final speech = await _ready(engine);

      expect(speech.state, SpeechState.noVoice);
      expect(speech.canRead(null), isFalse);
      expect(speech.canRead(_serbian), isTrue);
      await speech.speak('Odigraj Bc4.', language: _serbian);
      expect(engine.spoken.single.voice, 'hr-HR');
    });
  });

  group('a voice that is listed and cannot be used', () {
    test('is set aside, and the sentence is not handed to another language',
        () async {
      final engine = _Engine(['en-US', 'hr-HR'], refuses: {'hr-HR'});
      final speech = await _ready(engine);
      var told = 0;
      speech.addListener(() => told += 1);

      expect(speech.canRead(_serbian), isTrue,
          reason: 'listed, so it is offered — Windows cannot be asked sooner');
      await speech.speak('Odigraj Bc4.', language: _serbian);
      await Future<void>.delayed(Duration.zero);

      expect(engine.spoken, isEmpty,
          reason:
              'not in the voice the engine was on before, which is English');
      expect(speech.canRead(_serbian), isFalse);
      expect(told, greaterThan(0), reason: 'the screen has to hear about it');
      expect(speech.isSpeaking, isFalse, reason: 'nothing is left hanging');
    });

    test('and the next voice in the language\'s order is used instead',
        () async {
      final engine = _Engine(['en-US', 'sr-RS', 'hr-HR'], refuses: {'sr-RS'});
      final speech = await _ready(engine);

      await speech.speak('Prva.', language: _serbian);
      await speech.speak('Druga rečenica, duža od prve.', language: _serbian);

      expect(engine.spoken.single.voice, 'hr-HR');
    });

    test('is tried again when the reader asks the machine again', () async {
      // Installing the voice is how a reader answers the message, and the
      // app must not keep claiming it is missing afterwards.
      final engine = _Engine(['en-US', 'hr-HR'], refuses: {'hr-HR'});
      final speech = await _ready(engine);
      await speech.speak('Odigraj Bc4.', language: _serbian);
      expect(speech.canRead(_serbian), isFalse);

      engine.refuses.clear();
      await speech.refresh();
      expect(speech.canRead(_serbian), isTrue);
    });
  });

  group('reading speed', () {
    test('is kept per voice', () async {
      // A sentence that takes three seconds to read, measured by moving the
      // test's clock inside the engine — the Serbian voice reads it at about
      // nineteen characters a second, nowhere near the fourteen a voice starts
      // from before it has said anything.
      var now = DateTime(2026, 9, 11, 12);
      final engine = _Slow(
          ['en-US', 'sr-RS'], () => now = now.add(const Duration(seconds: 3)));
      final speech = await _ready(engine);
      speech.debugClock = () => now;

      const sentence =
          'Beli kralj ide napred i zauzima opoziciju na šestom redu.';
      await speech.speak(sentence, language: _serbian);

      expect(speech.charsPerSecondFor(_serbian),
          closeTo(sentence.length / 3, 0.01));
      expect(speech.charsPerSecond, SpeechService.seedCharsPerSecond,
          reason: 'the English voice has read nothing, and must not inherit '
              'the Serbian one\'s speed');
      expect(speech.charsPerSecondFor(null), speech.charsPerSecond,
          reason: 'a tutorial with no language asks the Settings voice');
    });
  });
}

/// An engine whose sentences take time, by moving the test's clock.
class _Slow extends _Engine {
  _Slow(super.installed, this.tick);

  final void Function() tick;

  @override
  Future<void> speak(String text) async {
    tick();
    await super.speak(text);
  }
}
