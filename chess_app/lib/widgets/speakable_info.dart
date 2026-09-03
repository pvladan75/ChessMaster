import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// A sentence the screen shows, and a way to hear it.
///
/// Phase 0 of `docs/PLAN-JEDNOSTAVNOST.md`, written before the batch that
/// spreads it, so the speaker control means the same thing everywhere it turns
/// up. The owner's reason: *„da korisnik čuje šta treba da uradi, da mu se
/// serviraju informacije, ne mora sve da čita sa ekrana"* — with the second
/// half of the ask, which is the part that makes speech bearable, being able to
/// **turn it off where it happens**.
///
/// Three rules it keeps, each of them paid for elsewhere in this codebase:
///
/// * **It never composes the sentence.** The screen passes what it already
///   shows. A second source for the wording drifts from the visible one, and
///   the point of reading it aloud is that the eyes can stay on the board.
/// * **It cannot take down what it describes.** Every call into the engine is
///   guarded: a machine with no voice, or a plugin that throws on `stop`, must
///   not be able to break the panel it was decorating. Same rule as
///   `AppFeedback`, for the same reason.
/// * **The button is never a no-op.** `SpeechService.speak` returns silently
///   when speech is off, so a speaker that only called it would do nothing at
///   all on the setting most readers start with. Pressing it with speech off
///   turns speech on and then speaks — which is also the in-screen switch the
///   owner asked for.
class SpeakableInfo extends StatefulWidget {
  const SpeakableInfo({
    super.key,
    required this.text,
    this.style,
    this.autoSpeak = false,
    this.child,
    this.settings,
    this.speech,
  });

  /// The sentence, both shown and spoken.
  final String text;

  final TextStyle? style;

  /// Speak it when it appears and whenever it changes, if speech is on.
  ///
  /// Off by default: a screen where every panel announces itself is the noise
  /// this feature is trying not to be. The panels that ask something of the
  /// reader turn it on; the ones that are merely true do not.
  final bool autoSpeak;

  /// Shown instead of the plain text, when the screen draws the sentence
  /// itself. [text] is still what gets spoken.
  final Widget? child;

  /// Injectable for tests. `compute`-free and side-effect-free by design — the
  /// real ones are singletons, and a widget test that reached them would be
  /// talking to the machine running the suite.
  final AppSettingsService? settings;
  final SpeechService? speech;

  @override
  State<SpeakableInfo> createState() => _SpeakableInfoState();
}

class _SpeakableInfoState extends State<SpeakableInfo> {
  AppSettingsService get _settings =>
      widget.settings ?? AppSettingsService.instance;
  SpeechService get _speech => widget.speech ?? SpeechService.instance;

  /// Whether a sentence handed over right now would actually be heard.
  bool get _canSpeak =>
      _settings.speechEnabled && _speech.state == SpeechState.ready;

  bool _couldSpeak = false;
  bool _shownOn = false;

  @override
  void initState() {
    super.initState();
    _couldSpeak = _canSpeak;
    _shownOn = _settings.speechEnabled;
    _settings.addListener(_availabilityChanged);
    _speech.addListener(_availabilityChanged);
    if (widget.autoSpeak) _say();
  }

  @override
  void dispose() {
    _settings.removeListener(_availabilityChanged);
    _speech.removeListener(_availabilityChanged);
    super.dispose();
  }

  /// Speech became possible while this sentence was already on screen.
  ///
  /// Without this a panel speaks only when it is built or when its words
  /// change. Turning speech on from the app bar is neither, so the drill sat
  /// silent on the question the reader was looking at and the first thing they
  /// heard was the verdict at the end of the line — the sentence they had
  /// asked to hear was the one sentence that never came. Reported live by the
  /// owner, 3.9.2026.
  ///
  /// It also covers a cold start: `SpeechService.init` is deliberately not
  /// awaited in `main`, so a screen reached quickly enough mounts before the
  /// machine has answered about its voices.
  void _availabilityChanged() {
    final now = _canSpeak;
    final became = now && !_couldSpeak;
    _couldSpeak = now;
    if (!mounted) return;
    // Only when the icon must actually change. `SpeechService` also notifies
    // on every utterance starting and stopping, and rebuilding this row on
    // each of those would be churn — and a `setState` that can land inside a
    // build, since the first notification arrives while `_say` above is still
    // running.
    final on = _settings.speechEnabled;
    if (on != _shownOn) {
      _shownOn = on;
      setState(() {});
    }
    // `force`, because the sentence may be the one this service last spoke and
    // the dedup would otherwise swallow exactly the case this exists for.
    if (became && widget.autoSpeak) _say(force: true);
  }

  @override
  void didUpdateWidget(SpeakableInfo old) {
    super.didUpdateWidget(old);
    if (widget.autoSpeak && widget.text != old.text) _say();
  }

  /// Says it, if speech is on. Never turns it on by itself — that is the
  /// reader's decision and it is made by pressing the speaker.
  Future<void> _say({bool force = false}) async {
    try {
      await _speech.speak(widget.text, force: force);
    } catch (_) {
      // A machine without a voice is a fact about the machine. The sentence is
      // on screen either way, which is the whole reason this is decoration.
    }
  }

  Future<void> _pressed() async {
    try {
      if (!_settings.speechEnabled) {
        await _settings.setSpeechEnabled(true);
        await _speech.setEnabled(true);
        if (!mounted) return;
        setState(() {});
        await _say(force: true);
        return;
      }
      // On, and already talking: the press means stop. On and quiet: say it
      // again. One control, and it is never dead.
      if (_speech.speaking) {
        await _speech.stop();
      } else {
        await _say(force: true);
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Same as above: this control decorates a sentence and must not be able
      // to take the screen down with it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = _settings.speechEnabled;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: widget.child ??
              Text(
                widget.text,
                style: widget.style ??
                    AppText.body.copyWith(color: context.colors.textPrimary),
              ),
        ),
        IconButton(
          // Said in the tooltip rather than only in the icon, because the two
          // states of a speaker glyph are exactly the pair somebody misses.
          tooltip: on ? 'Pročitaj naglas' : 'Uključi čitanje naglas',
          icon: Icon(
            on ? Icons.volume_up_outlined : Icons.volume_off_outlined,
            size: 20,
            color: on ? context.colors.accent : context.colors.textMuted,
          ),
          onPressed: _pressed,
        ),
      ],
    );
  }
}

/// The screen's own switch for speech, for an app bar.
///
/// „u ekranu može da isključi/uključi TTS bez izlaska iz ekrana" — the same
/// setting the settings screen writes, reachable where the talking happens.
class SpeechToggleButton extends StatefulWidget {
  const SpeechToggleButton({super.key, this.settings, this.speech});

  final AppSettingsService? settings;
  final SpeechService? speech;

  @override
  State<SpeechToggleButton> createState() => _SpeechToggleButtonState();
}

class _SpeechToggleButtonState extends State<SpeechToggleButton> {
  AppSettingsService get _settings =>
      widget.settings ?? AppSettingsService.instance;
  SpeechService get _speech => widget.speech ?? SpeechService.instance;

  Future<void> _toggle() async {
    final next = !_settings.speechEnabled;
    try {
      await _settings.setSpeechEnabled(next);
      await _speech.setEnabled(next);
      // Silence is immediate when it is switched off. A sentence that goes on
      // to the end after the reader has just said "stop talking" is the thing
      // that makes people turn a feature off for good.
      if (!next) await _speech.stop();
    } catch (_) {
      // The setting is written even when the engine refuses; the next screen
      // that asks will read it.
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final on = _settings.speechEnabled;
    return IconButton(
      tooltip: on ? 'Isključi čitanje naglas' : 'Uključi čitanje naglas',
      icon: Icon(on ? Icons.volume_up : Icons.volume_off_outlined),
      onPressed: _toggle,
    );
  }
}
