// The English vocabulary, kept frozen: **Tutorial** is the artefact a trainer
// writes and a child walks alone, **Session** is the live meeting in a room.
//
// The successor to `test/tutorial_vocabulary_test.dart`, which keeps the same
// pair apart in Serbian („Tutorijal" / „Čas"). When the sweep is done this file
// moves into `test/` and that one is deleted — one pair, one guard, one
// language.
//
// **It lives in `docs/gates/` until it is green**, which is the same place
// `tutorial_branching_test.dart` and the Serbian vocabulary test waited. A red
// suite hides the next real failure, and a translation sweep in three batches
// would leave it red for days.
//
// The contract it enforces is `docs/GLOSSARY-EN.md`. If the two disagree, the
// glossary wins and this file is wrong.
//
// To run it before it is moved:
//   cd chess_app && flutter test ../docs/gates/vocabulary_en_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// „Lesson" may still be written where it names the artefact in code — the
/// table is `saved_lessons`, the wire type is `LessonStep`, and none of that is
/// being renamed by a translation. What must not happen is the word reaching a
/// screen, where it would mean the opposite of what it means in the code.
///
/// Matched as substrings of the whole line, so they survive reformatting.
const _allowedLesson = <String>[
  'LessonStep',
  'LessonViewer',
  'LessonApiService',
  'LessonStepLine',
  'lessonApi',
  'lessonId',
  'saved_lessons',
  '/lessons',
  'lesson_',
  'assignments/lesson',
];

/// Serbian letters. Any of them inside a string literal means the sweep has not
/// reached that line.
final _serbian = RegExp(r'[čćžšđČĆŽŠĐ]');

/// A Dart string literal, single or double quoted, no escapes worth the
/// trouble — the point is to find copy, not to parse Dart.
final _literal = RegExp("'[^']*'" r'|"[^"]*"');

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

void main() {
  final sources = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[entity.path.replaceAll(r'\', '/')] = entity.readAsLinesSync();
  }

  test('the walk actually read the app, or the rest proves nothing', () {
    // The guard `app_feedback_guard_test.dart` carries too: a scanner that read
    // nothing passes every other test in this file.
    expect(sources.length, greaterThan(100),
        reason: 'run this from chess_app/, not from the repo root');
  });

  test('no string a reader sees is still in Serbian', () {
    final offenders = <String>[];
    for (final entry in sources.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final line = entry.value[i];
        if (_isComment(line)) continue;
        for (final match in _literal.allMatches(line)) {
          if (_serbian.hasMatch(match.group(0)!)) {
            offenders.add('${entry.key}:${i + 1}: ${line.trim()}');
            break;
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '${offenders.length} literals still carry Serbian letters:\n'
            '${offenders.take(40).join('\n')}');
  });

  test('the live thing is a Session and never a Lesson', () {
    // The whole point of the pair. „Lesson" on a screen would mean the live
    // meeting to a reader and the written artefact to the code.
    final offenders = <String>[];
    for (final entry in sources.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final line = entry.value[i];
        if (_isComment(line)) continue;
        if (_allowedLesson.any(line.contains)) continue;
        for (final match in _literal.allMatches(line)) {
          final text = match.group(0)!;
          if (RegExp(r'\b[Ll]esson\b').hasMatch(text)) {
            offenders.add('${entry.key}:${i + 1}: ${line.trim()}');
            break;
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'docs/GLOSSARY-EN.md: the live meeting is a Session. These '
            'say Lesson on screen:\n${offenders.join('\n')}');
  });

  test('and the written thing is a Tutorial, in those words', () {
    // The other half: a sweep that translated „Tutorijal" as anything else —
    // „course", „lesson plan", „material" — has broken the pair from the far
    // side, and the manual is written against the word that is here.
    final text = sources.values.map((l) => l.join('\n')).join('\n');

    expect(text, contains('Tutorial Studio'));
    expect(RegExp(r"'[^']*\bTutorial\b[^']*'").allMatches(text).length,
        greaterThan(20),
        reason: 'the word the whole feature is named for barely appears — a '
            'sweep that renamed it to something else passes every other test '
            'in this file');
  });

  test('the three kinds of part keep their wire names', () {
    // The interface is translated; the contract is not. `show`, `ask_move` and
    // `ask_choice` are what the server stores and what a saved tutorial on a
    // child's device already carries.
    final text = sources.values.map((l) => l.join('\n')).join('\n');
    for (final wire in ["'show'", "'ask_move'", "'ask_choice'"]) {
      expect(text, contains(wire),
          reason: 'a wire value was translated. Every tutorial already saved '
              'would stop being readable');
    }
  });
}
