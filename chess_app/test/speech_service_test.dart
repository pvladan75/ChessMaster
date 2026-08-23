import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/speech_service.dart';

/// A synthesiser that only remembers what it was told.
class FakeTts implements TtsEngine {
  FakeTts(this.installed);

  final List<String> installed;

  final spoken = <String>[];
  final stops = <int>[];
  String? language;
  double? rate;

  /// Machines without speech exist, and the app has to survive one.
  bool throwOnLanguages = false;

  @override
  Future<List<String>> languages() async {
    if (throwOnLanguages) throw StateError('no engine');
    return installed;
  }

  @override
  Future<void> setLanguage(String value) async => language = value;

  @override
  Future<void> setSpeechRate(double value) async => rate = value;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops.add(spoken.length);
}

/// A synthesiser that lists a language it cannot actually speak.
///
/// This is Windows, not a hypothetical: `getLanguages` there answers from the
/// languages the system knows about, so Croatian is offered on a machine with
/// no Croatian voice installed, and setting it throws.
class ListsMoreThanItHas extends FakeTts {
  ListsMoreThanItHas(super.installed);

  @override
  Future<void> setLanguage(String value) async {
    throw StateError('glas nije instaliran: $value');
  }
}

/// A synthesiser that holds on to the sentence until the test lets go.
///
/// The point of the wait is what happens *while* a sentence is being read, and
/// a fake that finishes instantly never enters that state.
class SlowTts extends FakeTts {
  SlowTts(super.installed);

  Completer<void>? _pending;

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    final completer = Completer<void>();
    _pending = completer;
    return completer.future;
  }

  void finish() {
    if (_pending?.isCompleted == false) _pending!.complete();
    _pending = null;
  }
}

Future<SpeechService> ready(FakeTts tts, {bool enabled = true}) async {
  final service = SpeechService.forTesting(tts);
  await service.init(enabled: enabled, rate: 0.5, engine: tts);
  return service;
}

void main() {
  group('choosing a voice', () {
    test('Serbian wins when the machine has it', () {
      expect(
        SpeechService.pickLanguage(['en-US', 'hr-HR', 'sr-RS']),
        'sr-RS',
      );
    });

    test('Croatian stands in for Serbian, because Windows ships no Serbian',
        () {
      // Not a courtesy. Microsoft's voice list has Croatian and no Serbian at
      // all, and Croatian reads Latin-script Serbian with the right sounds.
      // Without this the desktop half of the app is mute.
      expect(SpeechService.pickLanguage(['de-DE', 'en-US', 'hr-HR']), 'hr-HR');
    });

    test('an unrelated voice is never used', () async {
      // The failure that matters: an English voice handed Serbian does not
      // fail, it reads it with English phonetics. That sounds like the feature
      // works, which is worse than silence.
      expect(SpeechService.pickLanguage(['en-US', 'de-DE', 'fr-FR']), isNull);

      final tts = FakeTts(['en-US', 'de-DE']);
      final service = await ready(tts);
      expect(service.state, SpeechState.noVoice);
      await service.speak('Rd3 ispušta dobitak.');
      expect(tts.spoken, isEmpty);
      expect(tts.language, isNull);
    });

    test('the list is marked, not filtered', () async {
      // Any voice may be chosen - hearing an English one read Serbian is a
      // reasonable thing to want once. What settings owes the reader is which
      // ones are meant for it, so the tag does not have to be decoded.
      expect(SpeechService.fitsSerbian('sr-RS'), isTrue);
      expect(SpeechService.fitsSerbian('hr_HR'), isTrue);
      expect(SpeechService.fitsSerbian('en-US'), isFalse);
      expect(SpeechService.fitsSerbian('de-DE'), isFalse);

      final tts = FakeTts(['en-US', 'de-DE', 'hr-HR']);
      final service = await ready(tts);
      await service.setLanguage('de-DE');
      expect(service.language, 'de-DE');
      expect(service.state, SpeechState.ready);
      await service.speak('Tačno.');
      expect(tts.spoken, ['Tačno.']);
    });

    test('underscores and case do not hide a match', () {
      expect(SpeechService.pickLanguage(['sr_RS']), 'sr_RS');
      expect(SpeechService.pickLanguage(['HR-hr']), 'HR-hr');
    });

    test('a chosen language survives, and a removed one does not', () async {
      final tts = FakeTts(['sr-RS', 'hr-HR']);
      final kept = SpeechService.forTesting(tts);
      await kept.init(
          enabled: true, rate: 0.5, preferred: 'hr-HR', engine: tts);
      expect(kept.language, 'hr-HR');

      // The voice was uninstalled between runs: fall back to the best of what
      // is left rather than setting a language the engine does not have.
      final gone = FakeTts(['sr-RS']);
      final service = SpeechService.forTesting(gone);
      await service.init(
          enabled: true, rate: 0.5, preferred: 'hr-HR', engine: gone);
      expect(service.language, 'sr-RS');
    });
  });

  test('a voice installed while the app runs is found without a restart',
      () async {
    // The install happens in the operating system's own settings, with the app
    // already open. Answering from the startup scan would tell someone who has
    // just installed a voice that there is none.
    final installed = <String>['en-US'];
    final tts = FakeTts(installed);
    final service = await ready(tts);
    expect(service.state, SpeechState.noVoice);

    installed.add('hr-HR');
    await service.refresh();

    expect(service.state, SpeechState.ready);
    expect(service.language, 'hr-HR');
    await service.speak('Kf2 drži remi.');
    expect(tts.spoken.single, 'kralj ef dva drži remi.');
  });

  group('speaking', () {
    test('notation is turned into words before it reaches the engine',
        () async {
      final tts = FakeTts(['sr-RS']);
      final service = await ready(tts);
      await service.speak('Rd3 ispušta dobitak.');
      expect(tts.spoken.single, 'top de tri ispušta dobitak.');
    });

    test('the same sentence twice is said once', () async {
      // The panel rebuilds on a resize and on a chip changing, and every one
      // of those would otherwise restart the sentence over itself.
      final tts = FakeTts(['sr-RS']);
      final service = await ready(tts);
      await service.speak('Tačno.');
      await service.speak('Tačno.');
      expect(tts.spoken, ['Tačno.']);

      await service.speak('Tačno.', force: true);
      expect(tts.spoken.length, 2);
    });

    test('a sentence already started is heard out', () async {
      // What the app does on its own never cuts a sentence off. Being
      // interrupted mid-thought is how a spoken interface turns into noise, and
      // the board waits for the voice anyway.
      final tts = SlowTts(['sr-RS']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);

      unawaited(service.speak('Prva.'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      unawaited(service.speak('Druga.'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(tts.spoken, ['Prva.'], reason: 'druga ceka svoj red');
      expect(tts.stops, isEmpty, reason: 'aplikacija ne prekida sama sebe');

      tts.finish();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(tts.spoken, ['Prva.', 'Druga.']);
    });

    test('only the newest of the ones waiting is said', () async {
      // One slot, not a queue. Two verdicts arriving behind a third means the
      // older of them already describes a board that has moved on.
      final tts = SlowTts(['sr-RS']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);

      unawaited(service.speak('Prva.'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      unawaited(service.speak('Druga.'));
      unawaited(service.speak('Treća.'));

      tts.finish();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(tts.spoken, ['Prva.', 'Treća.']);
    });

    test('what the reader does cuts it off, and drops what was waiting',
        () async {
      // Moving through the game, answering, leaving - each says the sentence is
      // no longer wanted, and so is anything queued behind it.
      final tts = SlowTts(['sr-RS']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);

      unawaited(service.speak('Prva.'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      unawaited(service.speak('Druga.'));
      await service.stop();
      tts.finish();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(tts.spoken, ['Prva.']);
      expect(tts.stops.length, 1);
    });

    test('nothing is stopped before anything has been said', () async {
      // On Windows this is not a nicety. The plugin's stop() answers the
      // pending speak result, and there is no result until something has been
      // spoken - so the call dereferences a pointer that was never set and the
      // process dies where no try/catch can reach it.
      final tts = FakeTts(['sr-RS']);
      final service = await ready(tts);

      await service.stop();
      await service.setEnabled(false);
      expect(tts.stops, isEmpty);

      await service.setEnabled(true);
      await service.speak('Tačno.');
      await service.stop();
      expect(tts.stops.length, 1);
    });

    test('switched off, it says nothing at all', () async {
      final tts = FakeTts(['sr-RS']);
      final service = await ready(tts, enabled: false);
      expect(service.state, SpeechState.off);
      await service.speak('Tačno.');
      expect(tts.spoken, isEmpty);

      await service.setEnabled(true);
      await service.speak('Tačno.');
      expect(tts.spoken, ['Tačno.']);
    });

    test('an empty sentence is not an utterance', () async {
      final tts = FakeTts(['sr-RS']);
      final service = await ready(tts);
      await service.speak(null);
      await service.speak('   ');
      expect(tts.spoken, isEmpty);
    });

    test('turning it off stops what is being said', () async {
      final tts = FakeTts(['sr-RS']);
      final service = await ready(tts);
      await service.speak('Duga rečenica.');
      await service.setEnabled(false);
      expect(tts.stops.length, 1);
      expect(service.state, SpeechState.off);
      // Switching it off is a reader action, so it does cut the voice off.
    });
  });

  test('speaking never marks a widget dirty', () async {
    // The panel asks for a sentence from initState and didUpdateWidget, which
    // run inside a build. A notification there is "setState() called during
    // build": the frame fails in layout, and what reaches the screen is a board
    // with no squares and the pieces floating over the background.
    final tts = FakeTts(['sr-RS']);
    final service = await ready(tts);
    var notifications = 0;
    service.addListener(() => notifications++);

    await service.speak('Tačno — remi je održan.');
    expect(tts.spoken, isNotEmpty);
    expect(notifications, 0);
  });

  group('waiting for the voice', () {
    test('it is speaking while the engine has the sentence', () async {
      // What the walkthrough asks before it plays the next move. Without it the
      // board moves on under a sentence still being read, and the listener is
      // told about a position that is no longer there.
      final tts = SlowTts(['sr-RS']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);

      final speaking = service.speak('Tačno, remi je održan.');
      expect(service.isSpeaking, isTrue);
      // The sentence only reaches the engine after the barge-in stop, one turn
      // of the event loop later, so there is nothing to finish before then.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      tts.finish();
      await speaking;
      expect(service.isSpeaking, isFalse);
    });

    test('a voice that never reports the end does not freeze the board',
        () async {
      // The failure this guards: flutter_tts promises completion on Android,
      // and Windows is a different implementation. A flag that never clears
      // would stop the walkthrough forever, which is far worse than a sentence
      // being talked over.
      final tts = SlowTts(['sr-RS']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);

      unawaited(service.speak('Kratko.'));
      expect(service.isSpeaking, isTrue);

      // The watchdog is measured from the sentence, so a one-word verdict
      // clears in a couple of seconds rather than waiting out the cap.
      await Future<void>.delayed(const Duration(milliseconds: 2400));
      expect(service.isSpeaking, isFalse);
    });

    test('stopping clears it at once', () async {
      final tts = SlowTts(['sr-RS']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);
      unawaited(service.speak('Tačno.'));
      expect(service.isSpeaking, isTrue);
      await service.stop();
      expect(service.isSpeaking, isFalse);
      tts.finish();
    });
  });

  group('a voice that is listed but not installed', () {
    test('does not throw out of startup', () async {
      // The crash: choosing Croatian on a Windows machine that has no Croatian
      // voice took the whole app down on the way into settings, because the
      // engine threw out of an async call nobody was awaiting.
      final tts = ListsMoreThanItHas(['hr-HR', 'en-US']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);
      expect(service.state, SpeechState.noVoice);
    });

    test('does not throw when it is chosen by hand', () async {
      final tts = ListsMoreThanItHas(['hr-HR', 'en-US']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);
      await service.setLanguage('hr-HR');
      expect(service.state, SpeechState.noVoice);
    });

    test('stays silent rather than half working', () async {
      final tts = ListsMoreThanItHas(['hr-HR']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);
      await service.speak('Tačno.');
      expect(tts.spoken, isEmpty);
    });

    test('the rate is set through the same guard', () async {
      final tts = ListsMoreThanItHas(['hr-HR']);
      final service = SpeechService.forTesting(tts);
      await service.init(enabled: true, rate: 0.5, engine: tts);
      await service.setRate(0.9);
      expect(service.state, SpeechState.noVoice);
    });
  });

  test('a machine with no synthesiser is a state, not a crash', () async {
    final tts = FakeTts([])..throwOnLanguages = true;
    final service = await ready(tts);
    expect(service.state, SpeechState.failed);
    await service.speak('Tačno.');
    expect(tts.spoken, isEmpty);
  });

  test('the rate reaches the engine, at startup and when changed', () async {
    final tts = FakeTts(['sr-RS']);
    final service = await ready(tts);
    expect(tts.rate, 0.5);
    await service.setRate(0.8);
    expect(tts.rate, 0.8);
  });
}
