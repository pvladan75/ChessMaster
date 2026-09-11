/// Writing imported tutorials to the library, one request each.
///
/// The single-file import does not come through here: it opens the studio, and
/// the studio's own „Save tutorial" writes it, with every refusal that screen
/// makes. This is the other door — a trainer who picked twelve files and wants
/// twelve tutorials — and it exists because opening twelve files one at a time
/// in an authoring screen is not a review, it is a chore that gets skipped.
///
/// **A file the pre-flight refused is never sent.** Not as politeness: the
/// server answers 422 for an unloadable FEN and for a solution that cannot be
/// played, and a batch that sends them anyway spends twelve requests to learn
/// what `readTutorialJson` already knew, with the failures arriving in an order
/// nobody can map back to a file.
library;

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

/// What became of one file.
class ImportOutcome {
  const ImportOutcome({
    required this.tutorial,
    this.lessonId,
    this.error,
  });

  final ImportedTutorial tutorial;

  /// The row the server wrote, when it wrote one.
  final int? lessonId;

  /// Why it was not written: the server's own sentence, or the pre-flight's.
  final String? error;

  bool get saved => error == null;

  /// What the file is called, or what the tutorial is called when it came from
  /// no file at all.
  String get name =>
      tutorial.fileName?.split(RegExp('[/\\\\]')).last ?? tutorial.title;
}

/// Saves every tutorial that can be saved, in the order they were picked.
///
/// One request at a time rather than a `Future.wait`: these go to the same
/// small server, twelve at once is twelve connections racing for one pool, and
/// the ordering is what lets the report say „the first three worked and the
/// fourth did not" instead of listing twelve results in whatever order they
/// happened to land.
Future<List<ImportOutcome>> saveImportedTutorials(
  List<ImportedTutorial> tutorials,
  LessonApiService api,
) async {
  final outcomes = <ImportOutcome>[];
  for (final tutorial in tutorials) {
    if (!tutorial.storable) {
      outcomes.add(ImportOutcome(
        tutorial: tutorial,
        error: tutorial.problems
            .where((p) => p.fault == ImportFault.refused)
            .map((p) => p.sentence)
            .join(' '),
      ));
      continue;
    }

    final result = await api.saveTutorial(
      title: tutorial.title,
      description: tutorial.description,
      tags: tutorial.tags,
      positionList: tutorial.positionList,
      // Stated either way: a new tutorial knows its answer, „not said"
      // included. A code the file got wrong was already dropped by the reader.
      language: LanguageWrite.of(tutorial.language),
    );

    outcomes.add(ImportOutcome(
      tutorial: tutorial,
      lessonId: result.id,
      error: result.error,
    ));
  }
  return outcomes;
}
