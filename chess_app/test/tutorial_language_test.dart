// Which voice on this device may read a tutorial in a given language.
//
// Phase 2 of docs/PLAN-JEZIK-GLASA.md. The lists below are shaped like the
// machines this ships to: a phone whose Google engine has Serbian (verified
// live 23.8.2026), a Windows machine whose only voice for Serbian is the
// Croatian `Matej`, and a Windows machine without it. The answer that matters
// most is null — a device with no voice for the language says so, and never
// hands the sentence to English.
import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:flutter_test/flutter_test.dart';

const phone = ['en-US', 'hr-HR', 'de-DE', 'sr-RS'];
const windowsWithCroatian = ['en-US', 'de-DE', 'hr-HR'];
const windowsWithout = ['en-US', 'en-GB', 'de-DE'];

void main() {
  group('the seven codes', () {
    test('are the ones the server stores, one of each', () {
      // `services/tutorialLanguage.js` holds the same seven; the shared
      // spoken-moves fixture ties both lists to it from each side.
      expect(TutorialLanguage.all.map((l) => l.code).toList(),
          ['en', 'sr-Latn', 'sr-Cyrl', 'de', 'es', 'it', 'fr']);
      expect(TutorialLanguage.all.map((l) => l.label).toSet(),
          hasLength(TutorialLanguage.all.length));
    });

    test('a code is found, and anything else is „not said"', () {
      for (final language in TutorialLanguage.all) {
        expect(TutorialLanguage.of(language.code), same(language));
      }
      // Not said, and a code this build does not know, are both read the old
      // way. `sr` alone says no script, so it is not a code either.
      for (final code in [null, '', 'sr', 'EN', 'pt']) {
        expect(TutorialLanguage.of(code), isNull, reason: '$code');
      }
    });
  });
}
