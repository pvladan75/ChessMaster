/// The one place a tutorial draft is written to the server.
///
/// P3a of `docs/PLAN-STUDIO-REDIZAJN.md`, §6. There is one save button and it
/// has to work twice: the first press creates the tutorial, every press after
/// it edits the same one. That is only possible if the draft learns what the
/// server called it — the lesson's id, and the id of every step — which is what
/// [LessonWriteResult] now carries back and what this function writes down.
///
/// It is a function rather than a method on the screen so that the whole of it
/// can be tested without building a widget, and so that P5's controller has
/// something to call rather than something to reimplement.
library;

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';

/// Writes [draft] and teaches it what it now is.
///
/// Returns null on success, or the server's own sentence — never a sentence of
/// this app's invention, because „Rešenje ne može da se odigra u ovoj poziciji"
/// is something a trainer can act on and „Čuvanje nije uspelo" is not.
///
/// **Nothing is written into the draft unless the server accepted the write.**
/// A failed create that set `lessonId` would make the next attempt a `PUT` to a
/// tutorial that does not exist, and the trainer would be told their work is
/// gone rather than that it was never written.
Future<String?> commitDraft(TutorialDraft draft, LessonApiService api) async {
  final positionList = draft.positionList;

  // The description and the labels travel on every save, not only on the
  // create. The server leaves a column alone when the request says nothing
  // about it — but that rule is one release old (11.9.2026), and before it a
  // save that omitted them cleared them. Sending what the draft holds is the
  // half of that fix which lives here: it is also what makes editing a label
  // in the studio reach the database at all.
  final tags = draft.tags;
  final description = draft.description;

  final result = draft.lessonId == null
      ? await api.saveTutorial(
          title: draft.title.trim(),
          description: description,
          tags: tags,
          positionList: positionList,
        )
      : await api.updateTutorial(
          id: draft.lessonId!,
          title: draft.title.trim(),
          description: description,
          tags: tags,
          positionList: positionList,
        );

  if (!result.ok) return result.error;

  if (result.id != null) draft.lessonId = result.id;
  _learnStepIds(draft, result.steps, sent: positionList);
  return null;
}

/// Takes the ids the server minted, in the order the parts were sent.
///
/// **A list of a different length is not matched up.** The steps come back in
/// the order they went out, so position is the only thing that pairs them —
/// and pairing a list that does not line up would attach one part's id to
/// another part, which is a child's schedule and their recorded answers
/// silently moved to the wrong half of the tutorial. Nothing joins on a step
/// id, so nothing would ever complain.
///
/// A server that answers without a step list is a save that still happened.
/// Nothing is learned from it, and the next save meets the backend's own 409 —
/// „Koraci su stigli bez svojih oznaka. Osvežite tutorijal pa ga sačuvajte
/// ponovo." — which is loud, arrives at the right moment and is already worded
/// for a trainer. A second refusal invented here would only be an earlier one
/// that knows less.
void _learnStepIds(
  TutorialDraft draft,
  List<Map<String, dynamic>> stored, {
  required List<Map<String, dynamic>> sent,
}) {
  if (stored.length != draft.sections.length) return;

  for (var i = 0; i < draft.sections.length; i++) {
    final id = stored[i]['id'];
    // The stored text is authoritative: it is what a later read will hand back,
    // so recording it here is what keeps an untouched part byte-identical on
    // the next save instead of going through a fresh export with a new `[Date]`
    // header on it.
    draft.sections[i].markSaved(
      id: id is String && id.isNotEmpty ? id : null,
      pgn: stored[i]['pgn']?.toString() ?? sent[i]['pgn']?.toString(),
    );
  }
}
