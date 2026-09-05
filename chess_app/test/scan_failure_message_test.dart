// What a trainer reads when a scan refuses.
//
// Four books were tried on 5.9.2026 and every one of them failed for a
// different reason, while the app named the same reason for all four:
//
//   * two were image scans with no text on the page at all;
//   * one had an OCR text layer whose diagrams are pictures, and the server
//     reported the letters of English prose (`e` 26 times) as unknown chess
//     glyphs;
//   * one was 43 MB against a 25 MB ceiling and never reached the scanner.
//
// Naming the wrong cause is worse than naming none: "the diagrams use a font we
// cannot read yet" sends the reader off to derive a glyph map for a font that
// is not in the file. These tests hold each code to its own sentence.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';

void main() {
  group('scanFailureMessage', () {
    test('an image scan is called a scan, and never a font problem', () {
      final message = scanFailureMessage(
        const ScanOutcome(error: 'poruka sa servera', code: 'no_text'),
      );

      expect(message, contains('slika'));
      expect(message, isNot(contains('font koji')));
    });

    test('picture diagrams inside a text book are named as pictures', () {
      final message = scanFailureMessage(
        const ScanOutcome(error: 'poruka sa servera', code: 'no_diagram_text'),
      );

      expect(message, contains('ima teksta'));
      expect(message, contains('slike'));
      expect(message, isNot(contains('font koji')));
    });

    test('only a real unknown alphabet is blamed on the font', () {
      final message = scanFailureMessage(
        const ScanOutcome(error: 'poruka sa servera', code: 'unknown_font'),
      );

      expect(message, contains('font'));
    });

    test('every unreadable book gets its own sentence, not a shared one', () {
      final said = <String>{};
      for (final code in ['no_text', 'no_diagram_text', 'unknown_font']) {
        said.add(scanFailureMessage(ScanOutcome(code: code)));
      }

      expect(said.length, 3, reason: 'three different problems, three answers');
    });

    test('anything else keeps the words the server chose', () {
      // The size ceiling is the case that matters here: the server knows the
      // number of megabytes and this screen does not, so the message has to
      // travel rather than be rewritten.
      final message = scanFailureMessage(
        const ScanOutcome(
          error:
              'Knjiga je veća od 25 MB. Podeli PDF na manje delove pa skeniraj deo po deo.',
          code: 'file_too_large',
        ),
      );

      expect(message, contains('25 MB'));
    });

    test('a refusal with no words at all still says something', () {
      expect(scanFailureMessage(const ScanOutcome()), isNotEmpty);
    });
  });
}
