/// The languages a tutorial may say it is written in, and which voice on this
/// device may read one.
///
/// Phase 2 of `docs/PLAN-JEZIK-GLASA.md`. **Seven, and only seven** — the ones
/// whose moves can be said properly, which is the owner's rule of 11.9.2026: a
/// language whose moves would be read out in English words is not offered. The
/// server holds the same seven in `services/tutorialLanguage.js`, and
/// `chess_backend/test/fixtures/spoken_moves_cases.json` ties both lists to the
/// vocabularies from each side.
///
/// A tutorial that has not said is **not English**. It carries no
/// [TutorialLanguage] at all, and is read exactly as every tutorial was before
/// this existed: by the voice the reader chose in Settings.
library;

import 'package:chess_app/core/services/speech_text.dart';

class TutorialLanguage {
  const TutorialLanguage._(
    this.code,
    this.label,
    this.deviceVoices,
    this.vocabulary,
  );

  /// What is stored and sent: `sr-Latn`, `de`.
  final String code;

  /// What a trainer picks from: „Serbian (Latin)".
  final String label;

  /// The device languages that may read this one, best first.
  ///
  /// Serbian in Latin script is the old `SpeechService.preferredLanguages`
  /// verbatim, and the reason it is a list still holds: Windows ships no
  /// Serbian voice, and Croatian reads the same alphabet with the same sounds.
  /// Cyrillic gets Serbian alone, because a Croatian voice cannot read it.
  /// Nothing ever falls back to English — see [voiceFor].
  final List<String> deviceVoices;

  /// The words a move in this language is said with.
  final SpeechVocabulary vocabulary;

  static const english =
      TutorialLanguage._('en', 'English', ['en'], englishSpeech);
  static const serbianLatin = TutorialLanguage._('sr-Latn', 'Serbian (Latin)',
      ['sr', 'hr', 'bs', 'sh', 'me'], serbianLatinSpeech);
  static const serbianCyrillic = TutorialLanguage._(
      'sr-Cyrl', 'Serbian (Cyrillic)', ['sr'], serbianCyrillicSpeech);
  static const german =
      TutorialLanguage._('de', 'German', ['de'], germanSpeech);
  static const spanish =
      TutorialLanguage._('es', 'Spanish', ['es'], spanishSpeech);
  static const italian =
      TutorialLanguage._('it', 'Italian', ['it'], italianSpeech);
  static const french =
      TutorialLanguage._('fr', 'French', ['fr'], frenchSpeech);

  /// In the order a trainer is offered them.
  static const all = [
    english,
    serbianLatin,
    serbianCyrillic,
    german,
    spanish,
    italian,
    french,
  ];

  /// The language [code] names, or null — for a tutorial that has not said,
  /// and for a code this build does not know. Both are read the old way; a
  /// code from a newer server is not a reason to guess.
  static TutorialLanguage? of(String? code) {
    for (final language in all) {
      if (language.code == code) return language;
    }
    return null;
  }

  @override
  String toString() => code;
}

/// The installed device language that should read [language], or null when
/// this device has none.
///
/// **Never an unrelated language.** A voice handed text in a language it does
/// not speak does not fail — it reads it in its own phonetics, which is worse
/// than silence because it sounds like the feature works. So a null here is the
/// answer the screen must show („this device has no voice for it"), not a cue
/// to try the Settings voice. The owner's decision of 11.9.2026.
///
/// [installed] is what the engine lists (`sr-RS`, `hr_HR`, `en-US`); matched
/// the way `SpeechService.pickLanguage` matches, in the language's own order of
/// preference rather than the list's.
String? voiceFor(TutorialLanguage language, List<String> installed) {
  for (final wanted in language.deviceVoices) {
    for (final candidate in installed) {
      final tag = candidate.toLowerCase().replaceAll('_', '-');
      if (tag == wanted || tag.startsWith('$wanted-')) return candidate;
    }
  }
  return null;
}
