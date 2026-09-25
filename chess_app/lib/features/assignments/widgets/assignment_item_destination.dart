/// The one place that decides which screen an assignment item opens, given
/// its own detail (docs/PLAN-DOMACI-ZADATAK.md §6, phase 5).
///
/// `appRouteTable`'s three assignment routes and the student's homework
/// screen (`HomeworkAssignmentScreen`) all go through [assignmentItemScreen]
/// rather than deciding again — a second copy of this decision is exactly
/// what this function exists to prevent, and a homework item is a fourth kind
/// (`engine_game`) that only this phase reaches.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/theme/app_colors.dart';

import '../models/assignment.dart';
import '../screens/custom_assignment_overview_screen.dart';
import '../screens/video_assignment_screen.dart';
import '../services/assignment_api_service.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';

/// Builds the screen for one assignment item, from its own [detail].
///
/// `lesson` opens the tutorial's film to download; `puzzles` opens the overview when the
/// positions are the trainer's own and the tactics screen otherwise;
/// `engine_game` opens the assigned game, with its task read through
/// `EngineGameTask.fromJson` — a task that reader refuses is not opened.
/// `homework` has no screen here: a parent is opened on its own screen and
/// never through an item's destination.
Widget assignmentItemScreen({
  required UserSession session,
  required AssignmentDetail detail,
  AssignmentApiService? api,
}) {
  final assignment = detail.assignment;

  switch (assignment.kind) {
    case AssignmentKind.lesson:
      // A tutorial is sent as its film (docs/PLAN-TUTORIJAL-VIDEO.md); the
      // screen says so itself when the film is gone.
      return VideoAssignmentScreen(session: session, detail: detail, api: api);

    case AssignmentKind.engineGame:
      final task = EngineGameTask.fromJson(assignment.task ?? const {});
      if (task == null) {
        return const AssignmentUnavailableScreen(
          message: 'This game is no longer available.',
        );
      }
      return AiStudioScreen(
        userSession: session,
        initialCategory: 'engine_game',
        engineGameTask: task,
        assignmentId: assignment.id,
      );

    case AssignmentKind.homework:
      // A parent has no positions and no steps of its own; it is opened on
      // its own screen (`HomeworkAssignmentScreen`), never through here.
      return const AssignmentUnavailableScreen(
        message: 'This homework cannot be opened here.',
      );

    case AssignmentKind.puzzles:
      // Homework built from the trainer's own positions is solved on its own
      // screen: those carry a written task and one move, while the Lichess
      // set is a forced line, and one screen serving both would branch at
      // every step.
      if (detail.isCustom) {
        return CustomAssignmentOverviewScreen(session: session, detail: detail);
      }
      final pending = detail.pending;
      if (pending.isEmpty) {
        return const AssignmentNothingLeftScreen();
      }
      return TacticsTrainerScreen(
        session: session,
        assignmentId: assignment.id,
        assignmentTitle: assignment.title,
        // Only what is left, so coming back to a half-done assignment picks
        // up where the student stopped instead of starting over.
        puzzleIds: pending.map((item) => item.puzzleId!).toList(),
      );
  }
}

/// An assignment item this app cannot open: a task its own reader refused, a
/// kind with no screen here, or something else that made [assignmentItemScreen]
/// refuse rather than guess.
class AssignmentUnavailableScreen extends StatelessWidget {
  const AssignmentUnavailableScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// An assignment opened when there is nothing left in it.
///
/// Reachable now that this is a path: the list checks before it navigates,
/// but a link or a restored session does not, and answering the last puzzle
/// on another device makes it true while the screen is being opened.
class AssignmentNothingLeftScreen extends StatelessWidget {
  const AssignmentNothingLeftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: context.colors.success),
            const SizedBox(height: AppSpacing.md),
            const Text('This assignment is already completed.'),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
