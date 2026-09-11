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
  group('Serbian in Latin script', () {
    const sr = TutorialLanguage.serbianLatin;

    test('a Serbian voice first, even when Croatian is listed before it', () {
      // The language's order, not the engine's: `hr-HR` comes first in the
      // phone's list, and Serbian must still win.
      expect(voiceFor(sr, phone), 'sr-RS');
    });

    test('Croatian where there is no Serbian, which is Windows', () {
      expect(voiceFor(sr, windowsWithCroatian), 'hr-HR');
    });

    test('nothing at all where there is neither, and never English', () {
      expect(voiceFor(sr, windowsWithout), isNull);
    });

    test('an engine that writes its tags with underscores is still read', () {
      expect(voiceFor(sr, const ['en_US', 'hr_HR']), 'hr_HR');
    });

    test('a tag that only starts with the same letters is not the language',
        () {
      // `hrx` is not Croatian; the hyphen is what makes `hr-HR` a variant of
      // `hr`, and matching without it would take any tag with those letters.
      expect(voiceFor(sr, const ['en-US', 'hrx-XX', 'srn-SR']), isNull);
    });
  });

  group('Serbian in Cyrillic script', () {
    const sr = TutorialLanguage.serbianCyrillic;

    test('a Serbian voice reads it', () {
      expect(voiceFor(sr, phone), 'sr-RS');
    });

    test('Croatian does not, because it cannot read Cyrillic', () {
      expect(voiceFor(sr, windowsWithCroatian), isNull);
    });
  });

  group('the other languages', () {
    test('find their own voice', () {
      expect(voiceFor(TutorialLanguage.german, phone), 'de-DE');
      expect(voiceFor(TutorialLanguage.english, windowsWithout), 'en-US');
    });

    test('and nothing else when they are missing', () {
      for (final language in [
        TutorialLanguage.spanish,
        TutorialLanguage.italian,
        TutorialLanguage.french,
      ]) {
        expect(voiceFor(language, phone), isNull, reason: language.code);
      }
    });

    test('no language but English ever asks for an English voice', () {
      // The rule the whole feature rests on, asked of the table itself rather
      // than of one list: a French tutorial on an English machine is silent.
      for (final language in TutorialLanguage.all) {
        if (language == TutorialLanguage.english) continue;
        expect(language.deviceVoices.any((v) => v.startsWith('en')), isFalse,
            reason: language.code);
      }
    });
  });

  group('the sentence in place of the play button', () {
    test('names the language, and the install that actually answers it', () {
      final latin = noVoiceSentence(TutorialLanguage.serbianLatin);
      expect(latin, contains('Serbian (Latin)'));
      expect(latin, contains('Croatian voice'),
          reason: 'Windows has no Serbian voice; Croatian reads Latin Serbian');

      // Recommending Croatian for Cyrillic would send a reader to install a
      // voice that still cannot read their tutorial.
      final cyrillic = noVoiceSentence(TutorialLanguage.serbianCyrillic);
      expect(cyrillic, contains('Serbian (Cyrillic)'));
      expect(cyrillic, isNot(contains('Croatian')));

      expect(
          noVoiceSentence(TutorialLanguage.german), contains('German voice'));
    });
  });

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
