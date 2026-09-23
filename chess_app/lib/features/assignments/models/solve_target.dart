// solve_target.dart — what a set of find exercises is being solved *for*
// (`docs/PLAN-MATERIJAL.md`, phase 1).
//
// `CustomPuzzleSolverScreen` was written for homework and read four things
// from the assignment: its title, its note, where an answer is sent, and the
// door to its review. Those four are this class. Homework builds one over the
// assignment; solving one's own exercises builds one over
// `ExerciseApiService.attempt`, so the board, the verdict and the lock after
// one move are the same screen either way.
library;

import 'package:flutter/widgets.dart';

import 'assignment.dart';

class SolveTarget {
  const SolveTarget({
    required this.title,
    required this.submit,
    this.note,
    this.onReview,
    this.onOpen,
  });

  /// The app bar's title.
  final String title;

  /// A line under the task, for the whole set — a homework's instructions.
  final String? note;

  /// Sends one move and answers the server's verdict, or null when none came
  /// back.
  final Future<CustomAttemptResult?> Function(
      String puzzleId, String moveSan, int msTaken) submit;

  /// „Solution and comments" on a position answered in an earlier sitting —
  /// homework only, whose answers are kept.
  final void Function(BuildContext context)? onReview;

  /// „Open" under a verdict: the exercise's own screen. Only for exercises the
  /// account owns; homework has no such door.
  final void Function(BuildContext context, CustomPosition position)? onOpen;
}
