import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:chess_app/core/services/speech_text.dart';
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
      AppLogger.log('[Govor] Čekanje na kraj izgovora nije podržano: $e');
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
  static SpeechService forTesting(TtsEngine engine) {
    final service = SpeechService._internal();
    service._engine = engine;
    return service;
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

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Whether a sentence is being read right now.
  ///
  /// Asked by anything that moves the board on a timer: a move played under a
  /// sentence that is still being spoken means the listener hears about a
  /// position that is no longer there.
  bool _speaking = false;
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

  /// What was said last, so the same sentence twice in a row is said once.
  ///
  /// The panel rebuilds for reasons that have nothing to do with its text - a
  /// resize, a chip changing - and every one of those would otherwise start the
  /// sentence again over itself.
  String _lastSpoken = '';

  /// Serbian first, then the languages a Serbian speaker can be read to in.
  ///
  /// This is not a courtesy: Windows ships no Serbian voice at all (Microsoft's
  /// own list has Croatian and not Serbian), and Croatian reads Latin-script
  /// Serbian correctly - same alphabet, same sounds. Without this the desktop
  /// half of the app would be silent for everyone who has not gone hunting for
  /// a voice.
  static const preferredLanguages = ['sr', 'hr', 'bs', 'sh', 'me'];

  /// Whether a voice reads Serbian text as Serbian.
  ///
  /// Used to mark the list in settings rather than to censor it. Any voice can
  /// be chosen - an English one reading Serbian is a perfectly reasonable thing
  /// to want to hear once - but which ones are meant for it should not have to
  /// be guessed from a tag.
  static bool fitsSerbian(String language) {
    final tag = language.toLowerCase().replaceAll('_', '-');
    return preferredLanguages
        .any((wanted) => tag == wanted || tag.startsWith('$wanted-'));
  }

  /// Picks the voice to read Serbian with, out of what is installed.
  ///
  /// Never falls back to an unrelated language. An English voice handed Serbian
  /// text does not fail - it reads it with English phonetics, which is worse
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

    try {
      // Built inside the guard, not before it. Creating the plugin object is
      // itself a call into the platform, and a machine without speech at all
      // is a machine where that is where it fails.
      _engine = engine ?? _engine ?? FlutterTtsEngine();
      _available = await _engine!.languages();
    } catch (e) {
      // A missing engine is a fact about the machine, not a crash: Android
      // without Google's speech services, or Windows with the feature stripped.
      AppLogger.log('[Govor] Sinteza nije dostupna: $e');
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
          '[Govor] Nema srpskog glasa. Instalirano: ${_available.join(', ')}');
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
      return true;
    } catch (e) {
      AppLogger.log('[Govor] Glas "$language" nije upotrebljiv: $e');
      _state = SpeechState.noVoice;
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
    await _apply();
    notifyListeners();
  }

  /// Says a sentence the screen is showing.
  ///
  /// [force] is for the settings screen's test button, which has to speak even
  /// though it is saying the same thing every time.
  Future<void> speak(String? text, {bool force = false}) async {
    if (!_enabled || _state != SpeechState.ready) return;
    final spoken = speakable(text);
    if (spoken.isEmpty) return;
    if (!force && spoken == _lastSpoken) return;
    _lastSpoken = spoken;

    try {
      // Barge-in rather than queue. Verdicts replace each other - the one from
      // two moves ago is not worth hearing out, and a queue turns a fast
      // sequence into a monologue that ends long after the position changed.
      // Marked as speaking before anything is awaited, not after. Between the
      // stop and the speak there is a gap the event loop can run in, and a
      // board timer that ticks inside it would see silence and move on.
      _startSpeaking(spoken);
      await _engine?.stop();
      await _engine?.speak(spoken);
    } catch (e) {
      AppLogger.log('[Govor] Neuspelo izgovaranje: $e');
    } finally {
      _finishSpeaking();
    }
  }

  void _startSpeaking(String text) {
    _speaking = true;
    _watchdog?.cancel();
    _watchdog = Timer(_budget(text), () {
      if (!_speaking) return;
      AppLogger.log('[Govor] Kraj izgovora nije javljen, nastavljam dalje.');
      _finishSpeaking();
    });
    notifyListeners();
  }

  void _finishSpeaking() {
    _watchdog?.cancel();
    _watchdog = null;
    if (!_speaking) return;
    _speaking = false;
    notifyListeners();
  }

  /// Clears what was last said, so the same sentence is spoken again when it
  /// comes back. Called when a screen closes or a new exercise starts.
  void forget() => _lastSpoken = '';

  Future<void> stop() async {
    _lastSpoken = '';
    _finishSpeaking();
    try {
      await _engine?.stop();
    } catch (_) {
      // Stopping a synthesiser that never started is not worth reporting.
    }
  }
}
