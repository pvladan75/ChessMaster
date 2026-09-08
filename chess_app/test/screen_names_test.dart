// Each board screen is named for what it is for, and „studio" names one thing.
//
// Phase 1b of `docs/PLAN-ZAVRSNICA.md`. Three screens carry a board and side
// panels, and two of them looked so alike that the owner asked why both exist —
// with reason: their own descriptions on the home screen described the same
// thing. „Samostalni rad, FEN postavljanje, PGN i Stockfish analiza" against
// „Slobodna šahovska tabla za duboku analizu … rad sa PGN/FEN pozicijama".
//
//   „Soba"                 the room with a student in it
//   „Priprema"             the same room alone, with your library — your material
//   „Analiza"              the engine, the opening database, the tree — a position
//   „Studio za tutorijal"  writing a tutorial, and the only „studio" left
//
// This is a vocabulary gate, kept for the reason `tutorial_vocabulary_test`
// is kept: a retired name comes back one careless string at a time, and the
// manual being written in Phase 4 is written against these words. If the plan
// and this file disagree, the plan wins and this file is wrong.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Names that were retired on 8.9.2026 and must not come back.
const _retired = <String>[
  'Šahovski studio',
  'Šahovski Studio',
  'Tabla za Analizu',
  'Tablu za Analizu',
  'Studio Kontrole',
  'Studio Režim',
  'Video Studio',
];

/// The places „Studio" may still be written, and why each one is not a screen
/// name a reader meets.
///
/// Deliberately short. A allowance list that grows is a rule nobody is
/// enforcing.
const _allowed = <String>[
  // The one screen the word names.
  "'Studio za tutorijal'",
  // Log lines, read by us and never by a trainer.
  '[AnalysisStudio',
  '[TutorialStudio',
  // A PGN header. It is written into files other programs read, and changing
  // it would change every exported game's `[Event]` for no reader's benefit.
  "'Analysis Studio Session'",
];

Iterable<File> _dartFiles(String root) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

void main() {
  test('the retired screen names are gone from the app', () {
    final offences = <String>[];

    for (final file in _dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final name in _retired) {
          if (!lines[i].contains(name)) continue;
          // A comment explaining what the name used to be is not the name
          // coming back. This file's own prose is the same case.
          final trimmed = lines[i].trimLeft();
          if (trimmed.startsWith('//')) continue;
          offences.add('${file.path}:${i + 1}  $name');
        }
      }
    }

    expect(offences, isEmpty,
        reason: 'a retired screen name is back:\n${offences.join('\n')}');
  });

  test('„studio" names one screen', () {
    final offences = <String>[];

    for (final file in _dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // The word inside a string a reader could see. Class names, file names
        // and identifiers are not what this is about — `AnalysisStudioScreen`
        // is a name for us.
        if (!RegExp(r"'[^']*\bStudio\b[^']*'").hasMatch(line) &&
            !RegExp(r"'[^']*\bstudio\b[^']*'").hasMatch(line)) {
          continue;
        }
        if (line.trimLeft().startsWith('//')) continue;
        if (_allowed.any(line.contains)) continue;
        offences.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }

    expect(offences, isEmpty,
        reason: 'the word „studio" is a screen name again, and it is supposed '
            'to name exactly one:\n${offences.join('\n')}');
  });

  test('and the two screens that read alike no longer describe the same thing',
      () {
    final dashboard =
        File('lib/widgets/home/dashboard_tab.dart').readAsStringSync();
    final library =
        File('lib/widgets/home/biblioteka_tab.dart').readAsStringSync();

    expect(dashboard, contains("Text('Preparation'"));
    expect(dashboard, contains('without a student'),
        reason: 'the card for „Priprema" has to say what is different about '
            'it, or the name is the only thing that changed');
    expect(library, contains('Analysis'));
    expect(library, contains('Engine, opening database, and variation tree'),
        reason: 'the card for „Analiza" described a free board for working '
            'with PGN and FEN, which is what the other one said too');
  });
}
