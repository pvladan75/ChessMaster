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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/position_scanner/screens/scan_review_screen.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  group('scanFailureMessage', () {
    test('an image scan is called a scan, and never a font problem', () {
      final message = scanFailureMessage(
        const ScanOutcome(error: 'server message', code: 'no_text'),
      );

      expect(message, contains('image'));
      expect(message, isNot(contains('font we cannot')));
    });

    // Reworded on 22.9.2026: this is now shown only when no picture diagram
    // was found either, so it names both kinds and the drawings it cannot read,
    // where it used to say "text" and "images".
    test('a text book with no readable diagram names pictures and drawings',
        () {
      final message = scanFailureMessage(
        const ScanOutcome(error: 'server message', code: 'no_diagram_text'),
      );

      expect(message, contains('picture'));
      expect(message, contains('drawn'));
      expect(message, isNot(contains('font we cannot')));
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

    // Since 22.9.2026 the scanner reads picture diagrams too, so a sentence
    // that says it reads only a chess font is untrue — and these messages are
    // shown only when no picture diagram was found either, which is what they
    // must say instead.
    test('no refusal says the scanner reads only a chess font', () {
      for (final code in ['no_text', 'no_diagram_text']) {
        final message = scanFailureMessage(ScanOutcome(code: code));
        expect(message, isNot(contains('only reads')), reason: code);
        expect(message, contains('picture'), reason: code);
      }
    });
  });

  testWidgets('the empty scanner names both kinds of diagram it reads',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: ScanReviewScreen(
          session:
              UserSession(id: 1, token: 't', email: 'e', name: 'N', role: 'x')),
    ));
    await tester.pump();
    expect(find.textContaining('not images'), findsNothing,
        reason: 'the old sentence, untrue since picture diagrams are read');
    expect(find.textContaining('chess font'), findsOneWidget);
    expect(find.textContaining('pictures'), findsOneWidget);
  });
}
