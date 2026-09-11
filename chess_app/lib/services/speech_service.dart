import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:chess_app/core/services/speech_text.dart';
import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/services/app_logger.dart';

/// Everything the app needs from a synthesiser, and nothing else.
///
/// An interface rather than the plugin itself, because the plugin talks to a
/// platform channel and a widget test has no platform on the other end. It also
/// keeps the one decision worth testing - which voice gets picked out of what
/// the machine happens to have - in Dart, where a test can hand it a list.
abstract class TtsEngine {
  Future<List<String>> languages();
  Future<void> setLanguage(String language);
  Future<void> setSpeechRate(double rate);
  Future<void> speak(String text);
  Future<void> stop();
}

class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine() : _tts = FlutterTts() {
    // Without this, speak() returns the moment the text is handed over, and
    // the app has no way to know when the sentence actually ended. With it,
    // the future completes when the voice stops - which is what lets the board
    // wait for it.
    //
    // Unawaited, so a platform that rejects it would throw where nothing is
    // listening and take the app down. Caught here instead: the wait then has
    // only its deadline to fall back on, which is what the deadline is for.
    _tts.awaitSpeakCompletion(true).catchError((Object e) {
      AppLogger.log('[Govor] Waiting for speech completion not supported: $e');
    });
  }

  final FlutterTts _tts;

  @override
  Future<List<String>> languages() async {
    final raw = await _tts.getLanguages;
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  @override
  Future<void> setLanguage(String language) => _tts.setLanguage(language);

  @override
  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}

/// Why the app is not speaking, when it is not.
///
/// Silence has three causes and they need different answers from the user, so
/// they are not collapsed into one "off". The one that would otherwise be
/// invisible is [noVoice]: everything is switched on, the engine answered, and
/// there is simply no voice on the machine for the language - which on Windows
/// is the ordinary case until someone installs one.
enum SpeechState { off, ready, noVoice, failed }

/// Speaks what the screen says, when asked to.
///
/// Deliberately not clever about *what* to say: the caller passes the sentence
/// it is already showing, and [speakable] turns notation into words. A second
/// source of truth for the wording would drift from the visible one, and the
/// point of reading it aloud is that the eyes can stay on the board.
class SpeechService extends ChangeNotifier {
  SpeechService._internal();

  static final SpeechService instance = SpeechService._internal();

  /// Replaces the engine and resets what was learned about it. Tests only.
  @visibleForTesting
  static SpeechService forTesting(TtsEngine engine) =>
      SpeechService.forSubclass(engine);

  /// The same thing, as a constructor, so a test can subclass this and watch
  /// one answer. The only other way in is a private constructor, and a service
  /// nothing can extend means a screen that reads one of its getters has no way
  /// of being asked whether it read it.
  @visibleForTesting
  SpeechService.forSubclass(TtsEngine engine) {
    _engine = engine;
  }

  TtsEngine? _engine;

  SpeechState _state = SpeechState.off;
  SpeechState get state => _state;

  List<String> _available = const [];

  /// Every language the machine offers, as the engine names them. Shown in
  /// settings so the choice is made from what exists rather than from a list
  /// the app invented.
  List<String> get availableLanguages => _available;

  String? _language;
  String? get language => _language;

  double _rate = 0.5;
  double get rate => _rate;

  /// How fast this voice actually reads, in characters a second.
  ///
  /// Measured, not assumed. A screen that writes a sentence out while it is
  /// being read has to move at the voice's speed, and no platform will say what
  /// that speed is: `flutter_tts` reports word ranges on Android and nothing at
  /// all on Windows, which is where a trainer checks their own material. What
  /// every platform does report is that a sentence has finished - and a
  /// sentence whose length and duration are both known is a rate.
  ///
  /// It describes **this voice at this rate setting**, so changing either
  /// forgets it. A slider moved from 0.5 to 0.9 leaves every sample describing
  /// a voice that no longer exists.
  ///
  /// This is the Settings voice's rate. A tutorial in its own language is read
  /// by another voice, which reads at its own speed - see [charsPerSecondFor].
  double get charsPerSecond => _rateOf(_language);

  /// How fast the voice that reads a tutorial in [language] actually reads.
  ///
  /// **Kept per voice** (`docs/PLAN-JEZIK-GLASA.md`). One number for two voices
  /// would apply the Serbian voice's measurement to the English one, and the
  /// writing that follows the voice would quietly stop following either. A
  /// tutorial that has not said its language asks [charsPerSecond] itself, so
  /// anything that watches that getter still sees the question.
  double charsPerSecondFor(TutorialLanguage? language) =>
      language == null ? charsPerSecond : _rateOf(_voiceFor(language));

  double _rateOf(String? voice) =>
      (voice == null ? null : _rates[voice]) ?? seedCharsPerSecond;

  /// Measured reading speeds, by the voice that read.
  final Map<String, double> _rates = {};

  /// Where the estimate starts, before this voice has said anything.
  ///
  /// Only the first sentence of a session is written at this speed; from the
  /// second on, measurement has taken over. Deliberately **not** shared with
  /// the exported video's rate: that one writes captions into a film at a fixed
  /// frame rate and can measure nothing. A comment here used to claim the two
  /// were one number while they were 14 and 12.
  static const double seedCharsPerSecond = 14;

  /// Under this many characters a sample says more about the engine's start-up
  /// than about its reading speed: "Correct." is three words and half a second
  /// of latency.
  static const int _minSampleChars = 40;

  /// Outside this range it is not a reading speed, it is a measurement that
  /// went wrong - a clock that did not move, an engine that returned before it
  /// spoke, a machine that slept mid-sentence.
  static const double _slowestPlausible = 2;
  static const double _fastestPlausible = 40;

  /// The clock, so a test can state two instants instead of waiting for them.
  @visibleForTesting
  DateTime Function() debugClock = DateTime.now;

  /// Folds one finished sentence into [voice]'s estimate.
  void _learnRate(String text, Duration took, String voice) {
    if (text.length < _minSampleChars) return;
    final seconds = took.inMilliseconds / 1000;
    // No separate guard for a clock that did not move, or moved backwards:
    // dividing by zero gives infinity and by a negative gives a negative, and
    // the plausible range below refuses both. A second check that cannot be
    // made to fail on its own is not a second check.
    final sample = text.length / seconds;
    if (sample < _slowestPlausible || sample > _fastestPlausible) return;
    // Weighted towards what is already known, so one odd sentence - a word the
    // voice spells out, a notification taking the audio focus - moves the
    // estimate rather than replacing it.
    final known = _rates[voice];
    _rates[voice] = known == null ? sample : known * 0.6 + sample * 0.4;
    // No notifyListeners, for the reason given on _startSpeaking: this runs
    // inside an utterance, and a screen asks for the rate when it starts
    // writing rather than being told that it changed.
  }

  /// Every voice's, because it is the rate setting that changed - or the
  /// machine was asked again what it has.
  void _forgetRate() => _rates.clear();

  /// The voice the engine is set to now, so a sentence in another language
  /// switches it and the next one in the same language does not.
  String? _engineVoice;

  /// Voices this session found listed and could not use.
  ///
  /// Windows answers `getLanguages` from the languages the system knows about,
  /// not the voices installed (see [_apply]), so a Serbian tutorial can be
  /// offered a Croatian voice that throws on the first sentence. That voice is
  /// set aside for the session and the next in the language's order is tried -
  /// never the Settings voice, which is a different language. [refresh] forgets
  /// the list, because installing the voice is how a reader answers it.
  final Set<String> _unusable = {};

  /// The installed voice that should read [language], leaving out the ones
  /// that failed. Null when there is none - see [voiceFor].
  String? _voiceFor(TutorialLanguage language) => voiceFor(language, [
        for (final voice in _available)
          if (!_unusable.contains(voice)) voice,
      ]);

  /// Whether a tutorial in [language] can be read aloud on this machine at
  /// all, whether or not speech is switched on right now. Decides whether the
  /// play button is drawn.
  ///
  /// A tutorial that has not said its language asks the old question: is
  /// there a voice for the app's own text. One that has asks only about its
  /// own language - an English voice on the machine is no answer to a Serbian
  /// tutorial, and no English voice is no obstacle to one.
  bool canRead(TutorialLanguage? language) {
    if (_state == SpeechState.failed) return false;
    if (language == null) return _state != SpeechState.noVoice;
    return _voiceFor(language) != null;
  }

  /// Whether a sentence in [language] would be spoken if asked for now.
  bool canSpeakNow(TutorialLanguage? language) {
    if (!_enabled) return false;
    if (language == null) return _state == SpeechState.ready;
    return _state != SpeechState.failed && _voiceFor(language) != null;
  }

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Whether a sentence is being read right now.
  ///
  /// Asked by anything that moves the board on a timer: a move played under a
  /// sentence that is still being spoken means the listener hears about a
  /// position that is no longer there.
  bool _speaking = false;

  /// True while a sentence is being said.
  ///
  /// Read by `SpeakableInfo`, whose one control has to mean "stop" while the
  /// voice is running and "say it again" when it is not — a speaker button that
  /// could only start is a button the reader presses to shut it up and is
  /// answered with the sentence a second time.
  bool get speaking => _speaking;
  bool get isSpeaking => _speaking;

  /// Stops [isSpeaking] from sticking when a platform never reports that it
  /// finished.
  ///
  /// flutter_tts promises completion on Android; Windows is a different
  /// implementation and this app is not in a position to promise for it. A
  /// flag that never clears would freeze the walkthrough forever, which is a
  /// far worse bug than a sentence talked over - so the wait has an end even
  /// if the engine never says so.
  Timer? _watchdog;

  /// Roughly how long the sentence can take, generously.
  ///
  /// Measured from words rather than fixed, because "Tačno." and a full
  /// explanation with three moves in it are an order of magnitude apart.
  static Duration _budget(String text) {
    final words = text.split(RegExp(r'\s+')).length;
    final ms = 1500 + words * 600;
    return Duration(milliseconds: ms > 20000 ? 20000 : ms);
  }

  /// Whether anything has been spoken yet in this run of the app.
  ///
  /// Guards every stop, and the reason is a null pointer in the Windows half of
  /// flutter_tts. Its stop() does this:
  ///
  ///     if (awaitSpeakCompletion) { speakResult->Success(1); }
  ///
  /// and `speakResult` is only ever set inside speak(). Stopping before
  /// anything has been said dereferences a pointer that was never given a
  /// value, and the process is gone - no Dart exception, no stack, nothing a
  /// try/catch could hold. It was reproduced down to those two lines: a fresh
  /// synthesiser, awaitSpeakCompletion(true), one stop(), and the app dies.
  ///
  /// Which is exactly what switching speech off did, since nothing had been
  /// said yet, and what the first sentence of a session did too - the barge-in
  /// stop runs before the speak it is making room for.
  bool _spokeAtLeastOnce = false;

  /// What was said last, so the same sentence twice in a row is said once.
  ///
  /// The panel rebuilds for reasons that have nothing to do with its text - a
  /// resize, a chip changing - and every one of those would otherwise start the
  /// sentence again over itself.
  String _lastSpoken = '';

  /// The language the app's own text is written in.
  ///
  /// It was `['sr', 'hr', 'bs', 'sh', 'me']` until the English pivot, and the
  /// reason it was a *list* is worth keeping in mind rather than mourning:
  /// Windows ships no Serbian voice at all, so the desktop half of the app
  /// leaned on Croatian, which reads Latin-script Serbian correctly. English
  /// needs no such rescue - every desktop and phone this ships to has an
  /// English voice - so the list is one entry and any `en-*` matches it.
  ///
  /// **This is the app's language, not the user's material.** A trainer may
  /// write a tutorial, a repertoire comment or a task in any language they
  /// like, and text like that must not be read by an English voice. A
  /// tutorial says its language since 11.9.2026 and is read by a voice for it
  /// or not at all - `speak(language:)`, `canRead`, and
  /// `core/services/tutorial_language.dart`, per `docs/PLAN-JEZIK-GLASA.md`.
  /// Everything else a user writes, and a tutorial that has not said, is still
  /// read by the voice picked in Settings.
  static const preferredLanguages = ['en'];

  /// Whether a voice reads the app's own text as it is written.
  ///
  /// Used to mark the list in settings rather than to censor it. Any voice can
  /// be chosen - somebody whose repertoire comments are in Serbian wants a
  /// Serbian one and should have it - but which ones are meant for the
  /// interface should not have to be guessed from a tag.
  static bool fitsAppLanguage(String language) {
    final tag = language.toLowerCase().replaceAll('_', '-');
    return preferredLanguages
        .any((wanted) => tag == wanted || tag.startsWith('$wanted-'));
  }

  /// Picks the voice to read the app's own text with, out of what is installed.
  ///
  /// Never falls back to an unrelated language. A German voice handed English
  /// text does not fail - it reads it with German phonetics, which is worse
  /// than silence because it sounds like the feature works.
  static String? pickLanguage(List<String> installed) {
    for (final wanted in preferredLanguages) {
      for (final candidate in installed) {
        final tag = candidate.toLowerCase().replaceAll('_', '-');
        if (tag == wanted || tag.startsWith('$wanted-')) return candidate;
      }
    }
    return null;
  }

  /// Asks the machine what it has and settles on a voice.
  ///
  /// [preferred] is the language the user chose in settings, if any; it wins
  /// over the automatic pick as long as the machine still has it, which it may
  /// not after a voice is uninstalled.
  Future<void> init({
    required bool enabled,
    required double rate,
    String? preferred,
    TtsEngine? engine,
  }) async {
    _enabled = enabled;
    _rate = rate;
    _forgetRate();
    _unusable.clear();
    _engineVoice = null;

    try {
      // Built inside the guard, not before it. Creating the plugin object is
      // itself a call into the platform, and a machine without speech at all
      // is a machine where that is where it fails.
      _engine = engine ?? _engine ?? FlutterTtsEngine();
      _available = await _engine!.languages();
    } catch (e) {
      // A missing engine is a fact about the machine, not a crash: Android
      // without Google's speech services, or Windows with the feature stripped.
      AppLogger.log('[Speech] Synthesis is not available: $e');
      _available = const [];
      _state = SpeechState.failed;
      notifyListeners();
      return;
    }

    final chosen = (preferred != null && _available.contains(preferred))
        ? preferred
        : pickLanguage(_available);
    _language = chosen;

    if (chosen == null) {
      _state = SpeechState.noVoice;
      AppLogger.log(
          '[Speech] No voice for the app language. Installed: ${_available.join(', ')}');
      notifyListeners();
      return;
    }

    if (await _apply()) {
      _state = _enabled ? SpeechState.ready : SpeechState.off;
    }
    notifyListeners();
  }

  /// Asks the machine again what it has.
  ///
  /// A voice is installed from the operating system's own settings, with the
  /// app already running, and the answer from startup is stale the moment that
  /// happens. Without this the app keeps telling somebody who has just
  /// installed a voice that there is none, which reads as the install having
  /// failed.
  Future<void> refresh() => init(
        enabled: _enabled,
        rate: _rate,
        preferred: _language,
      );

  /// Hands the choice to the engine, and survives the engine refusing it.
  ///
  /// A listed language is not an installed voice. Windows answers `getLanguages`
  /// from the languages the system knows about, so Croatian is offered on a
  /// machine that has no Croatian voice at all - and setting it there throws,
  /// out of an async call nobody was awaiting, which took the whole app down on
  /// the way into settings.
  ///
  /// So the failure is caught and turned into the state that already exists for
  /// it: listed but unusable is the same thing to the reader as not there, and
  /// the panel already knows how to say "install a voice".
  Future<bool> _apply() async {
    final engine = _engine;
    final language = _language;
    if (engine == null || language == null) return false;
    try {
      await engine.setLanguage(language);
      await engine.setSpeechRate(_rate);
      _engineVoice = language;
      return true;
    } catch (e) {
      AppLogger.log('[Speech] Voice "$language" is not usable: $e');
      _state = SpeechState.noVoice;
      _engineVoice = null;
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) await stop();
    if (_state != SpeechState.noVoice && _state != SpeechState.failed) {
      _state = value ? SpeechState.ready : SpeechState.off;
    }
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    _lastSpoken = '';
    _forgetRate();
    // Hopeful, then corrected: a voice that turns out not to be installed puts
    // the state back to noVoice from inside _apply.
    if (_state == SpeechState.noVoice) {
      _state = _enabled ? SpeechState.ready : SpeechState.off;
    }
    await _apply();
    notifyListeners();
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    _forgetRate();
    await _apply();
    notifyListeners();
  }

  /// A sentence waiting for the current one to finish.
  ///
  /// One slot, not a queue: if two verdicts arrive while a third is being read,
  /// the older of the two is already out of date and nobody wants to hear a
  /// backlog. What must not happen is losing the newest, which is the one that
  /// describes the board as it now stands.
  ({String text, String voice})? _queued;

  /// Says a sentence the screen is showing.
  ///
  /// A sentence that has started is heard out. Nothing the app does on its own
  /// cuts it off - not the next verdict, not the board playing a move - because
  /// being interrupted mid-thought is how a spoken interface becomes noise.
  /// Only the reader stops it: by moving through the game, by answering, or by
  /// leaving. Those call [stop].
  ///
  /// [force] is for the settings screen's test button, which has to speak even
  /// though it is saying the same thing every time.
  ///
  /// [language] is a tutorial's own (`docs/PLAN-JEZIK-GLASA.md`): the sentence
  /// is read by a voice for that language, with its moves said in that
  /// language's words, or **not at all** - never by the Settings voice, which
  /// would read it in the wrong phonetics and sound as if it worked. Without
  /// one, this is exactly what it always was.
  Future<void> speak(
    String? text, {
    bool force = false,
    TutorialLanguage? language,
  }) async {
    if (!canSpeakNow(language)) return;
    final voice = language == null ? _language : _voiceFor(language);
    if (voice == null) return;
    final spoken = language == null
        ? speakable(text)
        : speakable(text, vocabulary: language.vocabulary);
    if (spoken.isEmpty) return;
    if (!force && spoken == _lastSpoken) return;

    if (_speaking) {
      _queued = (text: spoken, voice: voice);
      return;
    }
    _lastSpoken = spoken;
    await _utter(spoken, voice);
  }

  /// Puts the engine on [voice], unless it is there already.
  ///
  /// False when the engine refused it. A tutorial's voice is then set aside
  /// for the session and the screen asking is told it cannot read, rather than
  /// the sentence being handed to whatever the engine was set to before. The
  /// listeners hear about it a microtask later: this can run under a build, and
  /// a notifier that fires there is refused by Flutter.
  Future<bool> _useVoice(String voice) async {
    if (voice == _engineVoice) return true;
    final engine = _engine;
    if (engine == null) return false;
    try {
      await engine.setLanguage(voice);
      await engine.setSpeechRate(_rate);
      _engineVoice = voice;
      return true;
    } catch (e) {
      AppLogger.log('[Speech] Voice "$voice" is not usable: $e');
      _engineVoice = null;
      if (voice == _language) {
        _state = SpeechState.noVoice;
      } else {
        _unusable.add(voice);
      }
      scheduleMicrotask(notifyListeners);
      return false;
    }
  }

  /// One sentence, start to finish, and whatever was waiting behind it.
  Future<void> _utter(String spoken, String voice) async {
    try {
      // Marked as speaking before anything is awaited, not after: the board's
      // timers ask this between frames, and a gap where it reads false is a
      // move played under a sentence.
      _startSpeaking(spoken);
      if (!await _useVoice(voice)) return;
      // Timed from here rather than from the call: switching voices is not
      // reading, and a rate that counted it would describe neither.
      final startedAt = debugClock();
      _spokeAtLeastOnce = true;
      await _engine?.speak(spoken);
      // `_speaking` is the whole guard, and it answers two questions at once:
      // the watchdog clears it when a platform never reported the end, and
      // [stop] clears it when the reader cut the sentence off. Neither elapsed
      // time is this voice reading this sentence through, and a rate learned
      // from either is worse than having no rate at all.
      if (_speaking) {
        _learnRate(spoken, debugClock().difference(startedAt), voice);
      }
    } catch (e) {
      AppLogger.log('[Govor] Neuspelo izgovaranje: $e');
    } finally {
      _finishSpeaking();
    }

    final next = _queued;
    _queued = null;
    if (next == null) return;
    if (!_enabled || _state == SpeechState.failed) return;
    _lastSpoken = next.text;
    await _utter(next.text, next.voice);
  }

  // Neither of these notifies, on purpose, and it is not an oversight to be
  // tidied up later.
  //
  // The panel asks for a sentence from initState and didUpdateWidget - that is
  // to say, from inside a build - and a ChangeNotifier that fires there marks
  // its listeners dirty mid-build, which Flutter refuses:
  //
  //   setState() or markNeedsBuild() called during build.
  //
  // The frame then failed in layout, and what reached the screen was a board
  // with no squares and the pieces floating over the background. Nothing
  // watches [isSpeaking] anyway - the board's timers ask it, they are not told.
  void _startSpeaking(String text) {
    _speaking = true;
    _watchdog?.cancel();
    _watchdog = Timer(_budget(text), () {
      if (!_speaking) return;
      AppLogger.log(
          '[Speech] End of utterance was never reported, carrying on.');
      _finishSpeaking();
    });
  }

  void _finishSpeaking() {
    _watchdog?.cancel();
    _watchdog = null;
    _speaking = false;
  }

  /// Clears what was last said, so the same sentence is spoken again when it
  /// comes back. Called when a screen closes or a new exercise starts.
  void forget() => _lastSpoken = '';

  /// Cuts the voice off. For what the reader does, and nothing else.
  ///
  /// Moving to the next move, answering, leaving the screen - each of those
  /// says the sentence is no longer wanted, and each of them calls this. The
  /// app itself never does.
  Future<void> stop() async {
    _lastSpoken = '';
    _queued = null;
    _finishSpeaking();
    await _stopEngine();
  }

  /// Silences the voice, if there is anything to silence.
  ///
  /// Nothing to stop is not an edge case worth being clever about - it is the
  /// ordinary state of the app until the first sentence - and on Windows it is
  /// the one call that must not be made. See [_spokeAtLeastOnce].
  Future<void> _stopEngine() async {
    if (!_spokeAtLeastOnce) return;
    try {
      await _engine?.stop();
    } catch (e) {
      AppLogger.log('[Speech] Stopping failed: $e');
    }
  }
}
