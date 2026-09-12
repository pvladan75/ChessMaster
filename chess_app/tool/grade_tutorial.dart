/// Grades a tutorial file with the app's own reader.
///
///     dart run tool/grade_tutorial.dart <file.json | run directory> ...
///
/// Written for the language-model experiment in `tools/game_annotate/`, where
/// three arms each produce a `tutorial.json` and the question is which of them
/// produced something a child could actually be given.
///
/// **It calls `readTutorialJson` and nothing else.** That is the same function
/// the „Import from a file" door calls, which reads every line through
/// `LessonStepLine` — the child's own parser. A grader with a parser of its own
/// would be a second reader disagreeing with the app's, which is a fault this
/// repository has already paid for; and a model's output judged by a lenient
/// reader is a model that looks better than it is.
///
/// Exit code: 0 clean, 1 storable but damaged, 2 refused or unreadable. So a
/// batch can be graded by a script and a regression cannot be read as a pass.
///
/// The counts under each verdict are the experiment's own measurements: how
/// many parts, how many of them ask something, how long the lines are and how
/// long the sentences are. The contract asks for 4 to 10 parts, 3 to 8 moves in
/// a demonstration and sentences of 40 to 140 characters, so what is printed is
/// what those rules are about.
library;

import 'dart:io';

import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/grade_tutorial.dart '
        '<file.json | run directory> ...');
    exit(64);
  }

  var worst = 0;
  for (final arg in args) {
    final file = _resolve(arg);
    if (file == null) {
      stdout.writeln('[missing] $arg — no tutorial.json there');
      worst = worst < 2 ? 2 : worst;
      continue;
    }
    final code = _grade(file);
    if (code > worst) worst = code;
  }
  exit(worst);
}

/// The JSON file [arg] names, directly or as the run directory holding it.
File? _resolve(String arg) {
  final asFile = File(arg);
  if (asFile.existsSync()) return asFile;
  final inDir = File('$arg${Platform.pathSeparator}tutorial.json');
  if (inDir.existsSync()) return inDir;
  return null;
}

int _grade(File file) {
  final result = readTutorialJson(
    file.readAsStringSync(),
    fileName: file.uri.pathSegments.last,
  );

  final verdict = !result.openable
      ? 'REFUSED  '
      : !result.storable
          ? 'REFUSED  '
          : result.clean
              ? 'CLEAN    '
              : 'DAMAGED  ';

  stdout.writeln('');
  stdout.writeln('$verdict ${file.path}');
  stdout.writeln('─' * 72);

  if (!result.openable) {
    for (final problem in result.problems) {
      stdout.writeln('  ✗ ${problem.sentence}');
    }
    return 2;
  }

  stdout.writeln('  title      ${result.title}');
  stdout.writeln('  language   ${result.language ?? '(not said)'}');
  if (result.tags.isNotEmpty) {
    stdout.writeln('  labels     ${result.tags.join(', ')}');
  }

  _measure(result);

  if (result.problems.isEmpty) {
    stdout.writeln('  problems   none');
    return 0;
  }

  stdout.writeln('  problems   ${result.problems.length}');
  for (final problem in result.problems) {
    final mark = problem.fault == ImportFault.refused ? '✗' : '!';
    stdout.writeln('    $mark ${problem.sentence}');
  }
  return result.storable ? 1 : 2;
}

/// The numbers the format contract's own limits are about.
void _measure(ImportedTutorial result) {
  final kinds = <String, int>{};
  final moveCounts = <int>[];
  final sentences = <String>[];

  for (final step in result.positionList) {
    final kind = (step['kind'] ?? 'show').toString();
    kinds[kind] = (kinds[kind] ?? 0) + 1;

    final pgn = (step['pgn'] ?? '').toString();
    if (pgn.trim().isNotEmpty) moveCounts.add(_moveTokens(pgn));
    sentences.addAll(_comments(pgn));

    final instruction = (step['instruction'] ?? '').toString().trim();
    if (instruction.isNotEmpty) sentences.add(instruction);
  }

  final kindText = kinds.entries.map((e) => '${e.value} ${e.key}').join(', ');
  stdout.writeln('  parts      ${result.partCount}  ($kindText)'
      '${_outside(result.partCount, 4, 10) ? '   ← the contract asks for 4 to 10' : ''}');

  if (moveCounts.isNotEmpty) {
    final long = moveCounts.where((n) => n > 8).length;
    stdout.writeln('  moves      ${moveCounts.join(', ')}'
        '${long > 0 ? '   ← $long line(s) over the 8 the contract asks for' : ''}');
  }

  if (sentences.isEmpty) {
    stdout.writeln('  sentences  none   ← nothing is read aloud to the child');
    return;
  }
  final lengths = sentences.map((s) => s.length).toList()..sort();
  final short = sentences.where((s) => s.length < 40).length;
  final long = sentences.where((s) => s.length > 140).length;
  stdout.writeln('  sentences  ${sentences.length}, '
      '${lengths.first}–${lengths.last} characters'
      '${short + long > 0 ? '   ← $short under 40, $long over 140' : ''}');
}

bool _outside(int value, int low, int high) => value < low || value > high;

/// The words inside `{ }`, with the arrow and square commands taken out.
///
/// Braces and nothing else, the way `tools/tutorial_translate/translate.py`
/// finds the same strings: a PGN comment cannot contain one, so this needs no
/// parser and cannot disagree with the app about where a move is.
List<String> _comments(String pgn) {
  final out = <String>[];
  for (final match in RegExp(r'\{([^}]*)\}').allMatches(pgn)) {
    final words = match
        .group(1)!
        .replaceAll(RegExp(r'\[%(cal|csl)\s+[^\]]*\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (words.isNotEmpty) out.add(words);
  }
  return out;
}

/// How many moves the text holds, comments removed first.
int _moveTokens(String pgn) {
  final bare = pgn
      .replaceAll(RegExp(r'\{[^}]*\}'), ' ')
      .replaceAll(RegExp(r'\d+\.(\.\.)?'), ' ')
      .replaceAll('*', ' ');
  return bare.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty).length;
}
