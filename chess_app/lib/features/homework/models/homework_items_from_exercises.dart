// homework_items_from_exercises.dart — what picking exercises in the Library
// adds to a homework (`docs/PLAN-EXERCISE.md`, phase 4, decision 1: only an
// exercise can be set as homework, never a bare position).
//
// One door for exercises replaces the editor's old two ("Positions" and
// "Play it out"): every find-the-move exercise chosen travels together as one
// `positions` item, the way the old door already sent them, and every game
// exercise becomes its own `engine_game` item — its task copied whole from
// the exercise, which is where the engine and tablebase check ran when the
// exercise was made (decision 5).
library;

import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/features/library/models/library_entry.dart';

import 'homework.dart';

/// What picking [chosen] in the Library adds to a homework.
///
/// A row that is not an exercise (a bare position, an analysis…) or an
/// exercise the server will not let be set (`!assignable`) adds nothing — the
/// same rule the old „Positions" picker read off [LibraryEntry.assignable].
List<HomeworkItem> homeworkItemsFromExercises(List<LibraryEntry> chosen) {
  final findIds = <String>[];
  final gameItems = <HomeworkItem>[];

  for (final entry in chosen) {
    if (!entry.isExercise || !entry.assignable) continue;
    if (exerciseAskOf(entry.task) == ExerciseAsk.find) {
      findIds.add(entry.id);
      continue;
    }
    // Copied, not carried by reference: this item is edited independently of
    // the exercise it came from (reordering, a later „Play it out" tweak),
    // and `type` is the exercise's own word for its task kind, not part of
    // the engine-game task the server reads (`EngineGameTask.fromJson`).
    final task = Map<String, dynamic>.from(entry.task!)..remove('type');
    gameItems.add(HomeworkItem(
      itemKey: null,
      kind: HomeworkItemKind.engineGame,
      task: task,
      gate: false,
    ));
  }

  return [
    if (findIds.isNotEmpty)
      HomeworkItem(
        itemKey: null,
        kind: HomeworkItemKind.positions,
        task: {'puzzleIds': findIds},
        gate: false,
      ),
    ...gameItems,
  ];
}
