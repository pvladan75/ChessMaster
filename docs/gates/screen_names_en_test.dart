// Each board screen is named for what it is for, in English.
//
// The successor to `test/screen_names_test.dart`, which pins the same four
// names in Serbian. When the sweep is done this file moves into `test/` and
// that one is deleted.
//
//   „Soba"                 -> Room             the live session, with a student
//   „Priprema"             -> Preparation      the same room alone, your library
//   „Analiza"              -> Analysis         the engine, the database, the tree
//   „Studio za tutorijal"  -> Tutorial Studio  and the only „studio" there is
//
// **It lives in `docs/gates/` until it is green.** A red suite hides the next
// real failure, and this one is red from the moment it is written until the
// last batch lands.
//
// The contract is `docs/GLOSSARY-EN.md`. If the two disagree, the glossary wins.
//
//   cd chess_app && flutter test ../docs/gates/screen_names_en_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Retired with the language. The Serbian names went first (8.9.2026, phase
/// 1b); these are the same four screens after the sweep.
const _retired = <String>[
  'Šahovski studio',
  'Šahovski Studio',
  'Tabla za Analizu',
  'Tablu za Analizu',
  'Studio Kontrole',
  'Studio Režim',
  'Video Studio',
  // And the Serbian names phase 1b introduced, which are now themselves the
  // old ones. Listed so a half-finished sweep cannot leave the app speaking
  // two languages on the same shelf.
  "'Priprema'",
  "'Analiza'",
  "'Soba: ",
  "'Studio za tutorijal'",
];

/// Where „Studio" may still be written, and why none of them is a screen name a
/// reader meets.
const _allowedStudio = <String>[
  "'Tutorial Studio'",
  '[AnalysisStudio',
  '[TutorialStudio',
  // A PGN header, written into files other programs read.
  "'Analysis Studio Session'",
];

Iterable<File> _dartFiles(String root) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

void main() {
  test('the Serbian screen names are gone', () {
    final offences = <String>[];
    for (final file in _dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        for (final name in _retired) {
          if (lines[i].contains(name)) {
            offences.add('${file.path}:${i + 1}  $name');
          }
        }
      }
    }
    expect(offences, isEmpty,
        reason: 'a screen still names itself in Serbian:\n'
            '${offences.take(30).join('\n')}');
  });

  test('the four English names are on the screens', () {
    final text = [
      for (final file in _dartFiles('lib')) file.readAsStringSync(),
    ].join('\n');

    for (final name in const [
      "'Preparation'",
      "'Analysis'",
      "'Tutorial Studio'",
    ]) {
      expect(text, contains(name),
          reason: '$name is not written anywhere — the sweep renamed the '
              'screen to something the glossary does not know');
    }
    expect(text, contains('Room: '),
        reason: 'the live room is titled by its code, as „Room: 589388"');
  });

  test('„studio" names one screen', () {
    final offences = <String>[];
    for (final file in _dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (!RegExp(r"'[^']*\b[Ss]tudio\b[^']*'").hasMatch(line)) continue;
        if (_allowedStudio.any(line.contains)) continue;
        offences.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }
    expect(offences, isEmpty,
        reason: 'the word „studio" is a screen name again, and it is supposed '
            'to name exactly one:\n${offences.join('\n')}');
  });

  test('and the two screens that read alike still say what is different', () {
    final dashboard =
        File('lib/widgets/home/dashboard_tab.dart').readAsStringSync();
    final library =
        File('lib/widgets/home/biblioteka_tab.dart').readAsStringSync();

    expect(dashboard, contains("Text('Preparation'"));
    expect(dashboard.toLowerCase(), contains('without a student'),
        reason: 'the card for Preparation has to say what is different about '
            'it — before 8.9.2026 both cards described the same thing');
    expect(library, contains('Analysis'));
    expect(library.toLowerCase(), contains('engine'),
        reason: 'the card for Analysis described a free board for working '
            'with PGN and FEN, which is what the other one said too');
  });
}
