// The frozen vocabulary, kept frozen: **Tutorijal** is the artefact a trainer
// writes and a child walks through alone, **Čas** is the live session in a room.
//
// One word meant both until 6.9.2026, so „Poziv na lekciju" — a room opening
// this minute — and „Zadaj lekciju" — homework for Thursday — read to a child
// as the same event. A third word, „kurs", named the artefact in nine more
// places.
//
// This file was written before the sweep that made it green (batch 51 of
// docs/PLAN-TUTORIJAL.md) and lived in docs/gates/ until then, because a suite
// that is red hides the next real failure. It stays now for the reason
// app_feedback_guard_test.dart stays: an answer nobody is obliged to use is not
// an answer, and the old word comes back one careless string at a time.
//
// The contract it enforces is docs/TABELA-TUTORIJAL.md. If the two disagree,
// the table wins and this file is wrong.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lines that may keep the old word, with the reason from Table C.
///
/// Matched as substrings of the whole line, so they survive reformatting.
/// Deliberately few: every entry here is a place a reader will never look.
const _allowed = <String>[
  // Stored data. Rows already in the database carry this tag; rewriting the
  // written value splits one label into two that never match.
  "tags: const ['lekcija_kurs']",
  // Log lines are read by us, not by a child.
  "AppLogger.log('[Assignments] Zadavanje lekcije nije uspelo",
  "AppLogger.log('[Assignments] Učitavanje lekcija nije uspelo",
];

/// One expected new string per file the table changes.
///
/// The point is not to re-list the table — it is that a worker who renamed
/// half a file, or who applied a find-and-replace and produced „Ova tutorijal",
/// fails here. The strings chosen are the ones where the gender agreement
/// changes, because that is what a mechanical sweep gets wrong.
const _expected = <String, List<String>>{
  'lib/features/analysis_studio/screens/analysis_studio_screen.dart': [
    'Uredi korake tutorijala',
    'Koji tutorijal uređuješ?',
    'Tutorijal nije pronađen.',
    'Korak uspešno dodat u tutorijal.',
  ],
  'lib/features/assignments/screens/lesson_viewer_screen.dart': [
    'This tutorial has no parts.',
  ],
  'lib/features/assignments/screens/my_assignments_screen.dart': [
    'This tutorial is no longer available.',
  ],
  'lib/features/assignments/screens/student_progress_screen.dart': [
    'Tutorial sent to student.',
    'Assign tutorial',
  ],
  'lib/features/assignments/services/assignment_api_service.dart': [
    'Tutorial not assigned.',
  ],
  'lib/features/assignments/widgets/assign_lesson_dialog.dart': [
    'Could not load tutorials.',
    'Select a tutorial.',
    'You have no saved tutorials.',
  ],
  'lib/features/library/widgets/course_picker_dialog.dart': [
    'U koji tutorijal?',
    'Nema nijednog tutorijala sa koracima.',
  ],
  'lib/features/position_scanner/screens/saved_positions_screen.dart': [
    'Dodaj u tutorijal',
  ],
  'lib/features/reviews/screens/review_session_screen.dart': [
    'zadati tutorijal',
  ],
  'lib/screens/chess_game_screen.dart': [
    'Delete tutorial?',
    'Tutorial deleted.',
    'Tutorial with variations saved successfully!',
    'Tutorial with variations loaded!',
    'Search tutorials',
    'Saved tutorial from trainer',
  ],
  'lib/screens/shortcuts_screen.dart': ['tutorial'],
  'lib/widgets/account_stats_card.dart': ['Sačuvani tutorijali / pozicije'],
  'lib/widgets/create_course_dialog.dart': [
    'Unesite naziv tutorijala.',
    'Kreiraj tutorijal',
    'Sačuvaj tutorijal',
    'Naziv tutorijala',
  ],
  'lib/widgets/game_screen/course_step_bar.dart': [
    'Zatvori tutorijal',
    "'Tutorijal'",
  ],
  'lib/widgets/home/biblioteka_tab.dart': [
    'Library of positions and tutorials',
    'tutorials.',
  ],
  'lib/widgets/home/dashboard_tab.dart': ['Positions from tutorials'],
  'lib/widgets/home/home_dialogs.dart': [
    // Table B: the live session, which does **not** become a tutorial.
    'Session Invitation',
    'invites you to a session',
    'Session title',
    // …and the one line in the same file that is the artefact.
    'saved positions and tutorials',
  ],
  'lib/widgets/save_position_dialog.dart': [
    'Sačuvaj trenutni tutorijal / poziciju',
    'Naziv tutorijala / pozicije',
    'Unesite naziv tutorijala.',
  ],
};

/// The gendered mistake a find-and-replace makes. „Tutorijal" is masculine.
const _wrongGender = <String>[
  'Ova tutorijal',
  'ovu tutorijal',
  'jednu tutorijal',
  'sačuvana tutorijal',
  'zadata tutorijal',
  'tutorijal je poslata',
  'tutorijal nije pronađena',
  'tutorijal nema nijednu',
];

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('/*') || t.startsWith('*');
}

void main() {
  final sources = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[entity.path.replaceAll(r'\', '/')] = entity.readAsLinesSync();
  }

  test('the walk actually read the app, or the rest proves nothing', () {
    // The same guard app_feedback_guard_test.dart carries: a scanner that read
    // nothing passes every other test in this file.
    expect(sources.length, greaterThan(100),
        reason: 'run this from chess_app/, not from the repo root');
    expect(
        sources.containsKey('lib/widgets/create_course_dialog.dart'), isTrue);
  });

  test('no string a reader sees still says lekcija or kurs', () {
    final offenders = <String>[];
    for (final entry in sources.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final line = entry.value[i];
        if (_isComment(line)) continue;
        final lower = line.toLowerCase();
        if (!lower.contains('lekcij') && !lower.contains('kurs')) continue;
        if (_allowed.any(line.contains)) continue;
        offenders.add('${entry.key}:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'docs/TABELA-TUTORIJAL.md is the contract; these are left:\n'
            '${offenders.join('\n')}');
  });

  test('every file the table changes says the new word', () {
    final missing = <String>[];
    for (final entry in _expected.entries) {
      final lines = sources[entry.key];
      if (lines == null) {
        missing.add('${entry.key}: FILE MISSING — stop and report it');
        continue;
      }
      final text = lines.join('\n');
      for (final wanted in entry.value) {
        if (!text.contains(wanted)) missing.add('${entry.key}: "$wanted"');
      }
    }
    expect(missing, isEmpty,
        reason: 'the replacement from the table is not there:\n'
            '${missing.join('\n')}');
  });

  test('the new word is declined as a masculine noun', () {
    // „Lekcija" is feminine and „tutorijal" is masculine, so every agreeing
    // word around it changes too. This is the one thing a find-and-replace
    // cannot get right, and the one a reader notices immediately.
    final offenders = <String>[];
    for (final entry in sources.entries) {
      final text = entry.value.join('\n').toLowerCase();
      for (final wrong in _wrongGender) {
        if (text.contains(wrong.toLowerCase())) {
          offenders.add('${entry.key}: "$wrong"');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'wrong gender agreement:\n${offenders.join('\n')}');
  });

  test('nothing outside the table was renamed', () {
    // An identifier rename is not this batch. It is a diff nobody can review
    // beside a string change, and it breaks the API field names the backend
    // reads.
    final forbidden = <String>[
      'Tutorijal position_list',
      "'tutorijal_kurs'",
      'tutorialApiService',
      'TutorialViewerScreen',
      'tutorial_api_service.dart',
    ];
    final offenders = <String>[];
    for (final entry in sources.entries) {
      final text = entry.value.join('\n');
      for (final word in forbidden) {
        if (text.contains(word)) offenders.add('${entry.key}: "$word"');
      }
    }
    expect(offenders, isEmpty,
        reason: 'the word changes for the reader, not for the schema:\n'
            '${offenders.join('\n')}');
  });
}
