// The app says a move the way the film does, in every language a tutorial may
// be written in.
//
// The cases live in `chess_backend/test/fixtures/spoken_moves_cases.json`, and
// `chess_backend/test/spoken_moves.test.js` reads the same file for the
// server's `spokenMoves`. One file judging both ends is the whole point: until
// 11.9.2026 the server carried a hand-copied list of this app's English
// expectations, which held the two together only until somebody edited one
// copy. CI runs both suites in one checkout, so the path exists there too.
import 'dart:convert';
import 'dart:io';

import 'package:chess_app/core/services/speech_text.dart';
import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final shared = File('../chess_backend/test/fixtures/spoken_moves_cases.json');

  test('the shared cases are where both suites expect them', () {
    expect(shared.existsSync(), isTrue,
        reason:
            'a moved fixture must fail here, not pass with nothing to judge');
  });

  final cases = shared.existsSync()
      ? ((jsonDecode(shared.readAsStringSync())
              as Map<String, dynamic>)['cases'] as List)
          .cast<Map<String, dynamic>>()
      : const <Map<String, dynamic>>[];

  test('every case is said exactly as the film says it', () {
    expect(cases, isNotEmpty);
    final wrong = <String>[];
    for (final c in cases) {
      final language = TutorialLanguage.of(c['language'] as String);
      if (language == null) {
        wrong.add('${c['language']}: not a tutorial language');
        continue;
      }
      final said =
          speakable(c['written'] as String, vocabulary: language.vocabulary);
      if (said != c['spoken']) {
        wrong.add('${c['language']} ${jsonEncode(c['written'])}: '
            'said ${jsonEncode(said)}, expected ${jsonEncode(c['spoken'])}');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('every tutorial language is judged by the file, and nothing else is',
      () {
    // A language with no case is a vocabulary nobody checks; a case in a
    // language this build does not offer is a vocabulary nobody can reach.
    expect(
      cases.map((c) => c['language']).toSet(),
      TutorialLanguage.all.map((l) => l.code).toSet(),
    );
  });
}
