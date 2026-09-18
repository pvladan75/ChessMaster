// exercise_filter.dart — where an exercise came from, and the two filters the
// Library's Exercises chip draws (`docs/PLAN-EXERCISE.md`, phase 4).
//
// What is asked (`ExerciseAsk`) already has its one home in
// `exercise_task_words.dart`; this file is the other half, where it came
// from, plus the function that applies both at once.

import 'package:chess_app/features/exercises/models/exercise_task_words.dart';

import 'library_entry.dart';

/// Where a trainer's exercise came from. A closed set, the same reason
/// [ExerciseAsk] is one: a filter the reader cannot name is a filter they
/// cannot use.
enum ExerciseOrigin {
  book('From a book'),
  manual('Made by me'),
  mistakes('From mistakes');

  const ExerciseOrigin(this.label);

  final String label;
}

/// [entry]'s origin, or [ExerciseOrigin.book] for one this app does not
/// recognise — the same rule `LibraryEntry.origin` already reads the wire
/// with: an unknown value is never guessed into a made-up fourth kind.
ExerciseOrigin exerciseOriginOf(LibraryEntry entry) => switch (entry.origin) {
      'manual' => ExerciseOrigin.manual,
      'mistakes' => ExerciseOrigin.mistakes,
      _ => ExerciseOrigin.book,
    };

/// Narrows [entries] by what is asked and where it came from. Both are
/// single-choice and either may be left unset — null lets everything
/// through. An entry that is not an exercise (a tutorial, an analysis…) is
/// never removed by these filters: they are not what is being filtered, so
/// a bare position or another kind rides along untouched.
List<LibraryEntry> filterExercises(
  List<LibraryEntry> entries, {
  ExerciseAsk? ask,
  ExerciseOrigin? origin,
}) =>
    entries.where((entry) {
      if (!entry.isExercise) return true;
      if (ask != null && exerciseAskOf(entry.task) != ask) return false;
      if (origin != null && exerciseOriginOf(entry) != origin) return false;
      return true;
    }).toList();
