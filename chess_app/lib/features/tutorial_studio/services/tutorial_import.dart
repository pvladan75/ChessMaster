/// Reading a tutorial written outside the app — one JSON file, one tutorial.
///
/// The file is the body of `POST /lessons/save`, which is what
/// `PGN-TUTORIAL-FORMAT.md` has told generators to produce since 9.9.2026: a
/// `title`, an optional `description`, optional `tags`, and a `positionList` of
/// steps. Until now the only way to get one into the app was to POST it with
/// curl — which means a trainer could not do it at all, and nobody saw the
/// tutorial before it was in the database.
///
/// **Nothing here parses a line.** `TutorialSection.fromStep` already reads a
/// step into a tree through `readStepTree` → `LessonStepLine`, which is the
/// child's own parser, so an imported file goes through exactly the reader a
/// saved tutorial goes through. What this file adds is the question that reader
/// cannot ask on its own: *is this file worth opening at all*, and if not, in
/// which part and why.
///
/// **The report is a pre-flight, not an authority.** The server judges a step —
/// it refuses an unloadable FEN and an unplayable solution, and those rules
/// live there. The point of asking here is that a trainer who picked twelve
/// files should learn which three are broken *before* twelve requests, rather
/// than from a 422 naming a step number they cannot see.
library;

import 'dart:convert';

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/features/lessons/models/lesson_labels.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/services/fen_legality.dart';

/// How bad one finding is.
enum ImportFault {
  /// The server will refuse the whole tutorial: an unreadable FEN, a solution
  /// that cannot be played. Nothing is saved until it is fixed.
  refused,

  /// It would be stored, and it would be wrong — a line that does not replay
  /// from its own position, a question carrying the answer. The studio has a
  /// banner and a refusal for the second; the first is the silent version,
  /// where a child simply gets a shorter lesson than the file holds.
  damaged,
}

/// One thing wrong with one part of an imported file.
class ImportProblem {
  const ImportProblem({
    required this.fault,
    required this.message,
    this.partNumber,
  });

  final ImportFault fault;

  /// 1-based, the way the parts are numbered on the screen. Null for a fault
  /// about the file as a whole.
  final int? partNumber;

  final String message;

  /// "Part 3: the line has 2 moves that cannot be played…"
  String get sentence =>
      partNumber == null ? message : 'Part $partNumber: $message';
}

/// What one file came to.
class ImportedTutorial {
  const ImportedTutorial({
    required this.title,
    required this.description,
    required this.tags,
    required this.positionList,
    required this.problems,
    this.language,
    this.fileName,
  });

  /// A file that could not be read at all: not JSON, or JSON that is not a
  /// tutorial. It carries the reason and nothing else.
  factory ImportedTutorial.unreadable(String reason, {String? fileName}) =>
      ImportedTutorial(
        title: '',
        description: null,
        tags: const [],
        positionList: const [],
        problems: [ImportProblem(fault: ImportFault.refused, message: reason)],
        fileName: fileName,
      );

  final String title;
  final String? description;
  final List<String> tags;

  /// One of the seven codes of [TutorialLanguage], or null for **not said** —
  /// a file without the field, and a file whose code this app cannot read
  /// aloud, which is reported and dropped rather than sent: the server would
  /// refuse the whole tutorial over it. `docs/PLAN-JEZIK-GLASA.md`.
  final String? language;

  /// The steps, in the shape `TutorialDraft.fromLesson` reads and the shape
  /// `POST /lessons/save` takes.
  final List<Map<String, dynamic>> positionList;

  final List<ImportProblem> problems;

  /// Where it came from, for a report that lists several files.
  final String? fileName;

  int get partCount => positionList.length;

  /// Nothing wrong with it: every part replays, every question is answerable,
  /// and no question shows its own answer.
  bool get clean => problems.isEmpty;

  /// Whether there is a tutorial here at all. A file that is not JSON has no
  /// parts and cannot be opened; a file with a damaged part can be, and being
  /// able to open it is the point.
  bool get openable => positionList.isNotEmpty;

  /// Whether the server would take it. A damaged part is stored happily — the
  /// server has no PGN reader — so this is not the same question as [clean].
  bool get storable =>
      openable && !problems.any((p) => p.fault == ImportFault.refused);

  /// The row `TutorialDraft.fromLesson` reads — **with no `id`**, which is what
  /// makes the first press of "Save tutorial" create a tutorial rather than
  /// edit one.
  Map<String, dynamic> get asLesson => {
        'title': title,
        if (description != null) 'description': description,
        'tags': tags,
        // Always present, null included: an imported tutorial is new, so it
        // knows its answer even when the answer is „not said".
        'language': language,
        'position_list': positionList,
      };

  /// The same tutorial under different labels, for the import that labels a
  /// whole batch at once.
  ImportedTutorial withLabels(List<String> labels) => ImportedTutorial(
        title: title,
        description: description,
        tags: normaliseLabels([...tags, ...labels]),
        positionList: positionList,
        problems: problems,
        language: language,
        fileName: fileName,
      );
}

/// The longest a title may be. The column is `VARCHAR(255)`; the server's own
/// limit for a step title is 200 and this matches it rather than inventing a
/// third number.
const int maxImportedTitle = 200;

/// Reads one file's text.
///
/// Never throws: a file a trainer picked can be anything at all, and the answer
/// to "this is a photograph" is a sentence on the screen.
ImportedTutorial readTutorialJson(String text, {String? fileName}) {
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return ImportedTutorial.unreadable(
      'The file is not valid JSON.',
      fileName: fileName,
    );
  }

  if (decoded is! Map) {
    return ImportedTutorial.unreadable(
      'The file does not hold a tutorial object.',
      fileName: fileName,
    );
  }

  final json = Map<String, dynamic>.from(decoded);
  final rawList = json['positionList'] ?? json['position_list'];
  if (rawList is! List || rawList.isEmpty) {
    return ImportedTutorial.unreadable(
      'The file has no "positionList", so there is nothing to open.',
      fileName: fileName,
    );
  }

  final problems = <ImportProblem>[];

  // A title is required by the server and by the studio, and a file without one
  // is not worth refusing over: the name of the file it came from is a better
  // guess than an empty box, and the trainer can see it in the title field.
  var title = json['title']?.toString().trim() ?? '';
  if (title.isEmpty) title = titleFromFileName(fileName);
  if (title.length > maxImportedTitle) {
    title = title.substring(0, maxImportedTitle);
  }

  // `tags` is the column. `label` and `labels` are accepted because one label
  // is the common case, and a generator told to write a single word should not
  // have to know that the column holds a list.
  final rawTags = json['tags'] ?? json['labels'] ?? json['label'];
  final tags = normaliseLabels(switch (rawTags) {
    final List list => [for (final t in list) t.toString()],
    final String one => [one],
    _ => const <String>[],
  });

  // The language the file says it is in. A code this app cannot read aloud is
  // not a reason to refuse the tutorial, and not a thing to send either — the
  // server refuses a code outside the seven with the whole save — so it is
  // dropped, and said.
  final rawLanguage = json['language'];
  String? language;
  final said = rawLanguage is String ? rawLanguage.trim() : rawLanguage;
  if (said != null && said != '') {
    language = said is String ? TutorialLanguage.of(said)?.code : null;
    if (language == null) {
      problems.add(ImportProblem(
        fault: ImportFault.damaged,
        message: 'The file says it is in "$said", which this app cannot read '
            'aloud. It is imported without a language; the languages are '
            '${TutorialLanguage.all.map((l) => l.code).join(', ')}.',
      ));
    }
  }

  final positionList = <Map<String, dynamic>>[];
  for (var i = 0; i < rawList.length; i++) {
    final raw = rawList[i];
    if (raw is! Map) {
      problems.add(ImportProblem(
        fault: ImportFault.refused,
        partNumber: i + 1,
        message: 'this part is not an object.',
      ));
      continue;
    }
    final step = Map<String, dynamic>.from(raw);

    // **The id is dropped, always.** A step id resolves a schedule row and a
    // recorded answer, so two tutorials carrying one is a child's progress
    // appearing in the wrong copy. The server mints one per step on the first
    // save; a file has no business naming them, and the same file imported
    // twice would name them the same.
    step.remove('id');

    positionList.add(step);
    problems.addAll(problemsWithStep(step, partNumber: i + 1));
  }

  return ImportedTutorial(
    title: title,
    description: json['description']?.toString(),
    tags: tags,
    positionList: positionList,
    problems: problems,
    language: language,
    fileName: fileName,
  );
}

/// "01_direktna_opozicija.json" → "01 direktna opozicija".
String titleFromFileName(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) return 'Imported tutorial';
  final base = fileName.split(RegExp('[/\\\\]')).last;
  final withoutExtension = base.toLowerCase().endsWith('.json')
      ? base.substring(0, base.length - 5)
      : base;
  final words = withoutExtension.replaceAll(RegExp('[_-]+'), ' ').trim();
  return words.isEmpty ? 'Imported tutorial' : words;
}

/// Everything wrong with one step.
List<ImportProblem> problemsWithStep(
  Map<String, dynamic> step, {
  required int partNumber,
}) {
  final problems = <ImportProblem>[];
  void refuse(String message) => problems.add(ImportProblem(
        fault: ImportFault.refused,
        partNumber: partNumber,
        message: message,
      ));
  void damaged(String message) => problems.add(ImportProblem(
        fault: ImportFault.damaged,
        partNumber: partNumber,
        message: message,
      ));

  final fen = step['fen']?.toString() ?? '';
  final fenReason = fenIllegalReason(fen);
  if (fenReason != null) {
    // Nothing below can be asked without a position to ask it in.
    refuse('the starting position cannot be read — $fenReason');
    return problems;
  }

  final kindName = step['kind']?.toString() ?? 'show';
  const known = {'show', 'ask_move', 'ask_choice'};
  if (!known.contains(kindName)) {
    refuse('"$kindName" is not a kind of step.');
    return problems;
  }

  final read = readStepTree(fen: fen, pgn: step['pgn']?.toString());
  if (read.rejectedMoves > 0) {
    damaged(
      'the line has ${read.rejectedMoves} '
      '${read.rejectedMoves == 1 ? 'move' : 'moves'} that cannot be played '
      'from this position, and they would be missing from the tutorial.',
    );
  }

  final hasLine = read.root.children.isNotEmpty;

  if (kindName == 'ask_move') {
    final solution = step['solutionSan']?.toString().trim() ?? '';
    if (solution.isEmpty) {
      refuse('it asks for a move and gives no solution.');
    } else if (!playsIn(fen, solution)) {
      refuse('the solution "$solution" cannot be played in this position.');
    }
    if (hasLine) {
      // The studio refuses to save this, and it is right to: the viewer draws
      // the move strip for every kind, so a question carrying a line hands the
      // child the answer under a "Next move" button.
      damaged('it asks for a move and carries the line that answers it — '
          'the student would be shown the answer.');
    }
  }

  if (kindName == 'ask_choice') {
    final rawChoices = step['choices'];
    final choices = rawChoices is List ? rawChoices : const [];
    if (choices.length < 2 || choices.length > 4) {
      refuse('a multiple-choice question needs between two and four answers, '
          'and this one has ${choices.length}.');
    } else if (!choices.any((c) => c is Map && c['correct'] == true)) {
      refuse('none of the offered answers is marked as the correct one.');
    }
  }

  return problems;
}

/// Whether [san] is a legal move in [fen].
///
/// A pre-flight reading of the rule `services/lessonSteps.js` enforces, and
/// deliberately the same question rather than a second opinion: the server
/// still decides, so a disagreement shows up as a refusal at save rather than
/// as a step stored on a rule only the app knows.
bool playsIn(String fen, String san) {
  try {
    final game = chess.Chess.fromFEN(fen);
    return game.move(san) == true;
  } catch (_) {
    return false;
  }
}
