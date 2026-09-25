/// The languages a tutorial may say it is written in — the language its film is
/// narrated in, by the server's voice for it.
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
    this.vocabulary,
  );

  /// What is stored and sent: `sr-Latn`, `de`.
  final String code;

  /// What a trainer picks from: „Serbian (Latin)".
  final String label;

  /// The words a move in this language is said with.
  final SpeechVocabulary vocabulary;

  static const english = TutorialLanguage._('en', 'English', englishSpeech);
  static const serbianLatin =
      TutorialLanguage._('sr-Latn', 'Serbian (Latin)', serbianLatinSpeech);
  static const serbianCyrillic = TutorialLanguage._(
      'sr-Cyrl', 'Serbian (Cyrillic)', serbianCyrillicSpeech);
  static const german = TutorialLanguage._('de', 'German', germanSpeech);
  static const spanish = TutorialLanguage._('es', 'Spanish', spanishSpeech);
  static const italian = TutorialLanguage._('it', 'Italian', italianSpeech);
  static const french = TutorialLanguage._('fr', 'French', frenchSpeech);

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
