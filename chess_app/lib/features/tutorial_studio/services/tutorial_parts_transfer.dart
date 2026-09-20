/// Parts moving between tutorials: read some out of one, write some into a new
/// one.
///
/// Two operations, and between them they are the whole of „spoji tutorijale /
/// izdvoji delove": merging A and B into a third tutorial is a new tutorial
/// with [loadPartsOf] run twice, not a feature of its own.
///
/// **Nothing here is a copy of anything.** A saved tutorial becomes parts
/// through `TutorialDraft.fromLesson`, the same reader the studio opens one
/// with, and a new tutorial is written by `commitDraft`, the one place a draft
/// reaches the server. This file owns only the two questions those two do not
/// answer: *which* parts, and *what the new tutorial inherits*.
///
/// **Copies, never the parts themselves.** `TutorialSection.copy()` mints a
/// part with no `stepId` — two parts sharing one step id is a child's progress
/// showing up in the wrong half of a tutorial, which is why the model refuses
/// to carry the id and why `POST /lessons/:id/clone` mints fresh ones
/// server-side. Taking parts out therefore leaves the source untouched and
/// needs no second write: a trainer who wants them gone deletes them with the
/// button that is already on the row. The owner chose this over moving them on
/// 20.9.2026, and the reason is the one that keeps coming back here — a move is
/// two writes, and the second one can fail after the first has happened.
library;

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_save.dart';

/// A saved tutorial, opened only far enough to take parts out of it.
typedef PartsSource = ({
  int lessonId,
  String title,
  List<TutorialSection> parts,
  String? language,
  bool languageKnown,
  List<String> tags,
});

/// Reads the tutorial [lessonId] and hands back its parts.
///
/// Null when the server would not answer, or answered with a row that is not
/// that tutorial or carries no step list — `fetchTutorial` already refuses
/// those, and a tutorial read as „no parts" is worse than one that failed to
/// load: the trainer would be shown an empty picker and conclude the tutorial
/// is empty.
Future<PartsSource?> loadPartsOf(LessonApiService api, int lessonId) async {
  final lesson = await api.fetchTutorial(lessonId);
  if (lesson == null) return null;

  final draft = TutorialDraft.fromLesson(lesson);
  if (draft.sections.isEmpty) return null;

  return (
    lessonId: lessonId,
    title: draft.title,
    parts: draft.sections,
    language: draft.language,
    languageKnown: draft.languageKnown,
    tags: draft.tags,
  );
}

/// What came of writing a new tutorial.
///
/// [error] is the server's own sentence when there is one, for the reason
/// `commitDraft` gives: „the solution cannot be played in this position" is
/// something a trainer can act on and „saving failed" is not.
typedef ExtractOutcome = ({int? lessonId, String? error});

/// Writes [parts] as a tutorial of its own and answers what it became.
///
/// [from] is the tutorial the parts came out of, and it decides what the new
/// one inherits: the **language**, because the parts are written in it and a
/// tutorial that does not say its language is read by whatever voice Settings
/// has; and the **labels**, because they are a tutorial's only sorting handle
/// and a trainer with forty of them has a list nobody scrolls to the end of.
/// The description is deliberately not carried — it describes the tutorial
/// these parts left, not the one they are becoming.
///
/// The parts are copied here rather than by the caller, so that no route into
/// this function can write a part that still carries its old `stepId`.
Future<ExtractOutcome> extractToNewTutorial({
  required LessonApiService api,
  required String title,
  required List<TutorialSection> parts,
  PartsSource? from,
}) async {
  final named = title.trim();
  if (named.isEmpty) {
    return (lessonId: null, error: 'The new tutorial needs a name.');
  }
  if (parts.isEmpty) {
    return (lessonId: null, error: 'No parts were chosen.');
  }

  final draft = TutorialDraft(
    title: named,
    language: from?.language,
    languageKnown: from?.languageKnown ?? true,
    tags: from == null ? null : [...from.tags],
    sections: [for (final part in parts) part.copy()],
  );

  final failed = await commitDraft(draft, api);
  if (failed != null) return (lessonId: null, error: failed);

  // A create that the server accepted always names the tutorial it made. If it
  // somehow did not, the caller must not be told a saved tutorial is waiting
  // at an id nobody has.
  if (draft.lessonId == null) {
    return (lessonId: null, error: 'The tutorial was not saved.');
  }
  return (lessonId: draft.lessonId, error: null);
}
