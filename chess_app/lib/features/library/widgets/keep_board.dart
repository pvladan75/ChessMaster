import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/save_position_dialog.dart';

/// „Save as… → Position" and „Save as… → Exercise…", for every board that
/// has the menu — Preparation and, since `docs/PLAN-ANALIZA-TRAKA.md`,
/// Analysis. One home, so the same row on two screens keeps the same thing.

/// Keeps [fen] in the Library as a position: the board in front of the
/// reader and no line (D13 of `docs/PLAN-PRIPREMA.md`).
void keepBoardAsPosition(
  BuildContext context, {
  required LessonApiService api,
  required String fen,
  required List<String> labels,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => SavePositionDialog(
      availableUserLabels: labels,
      initialPersistedLabels: const [],
      initialShouldPersist: false,
      onSave: (title, description, tags, persist) async {
        final error = await api.save(
          title: title,
          description: description,
          tags: tags,
          fen: fen,
        );
        if (!context.mounted) return;
        if (error != null) {
          AppFeedback.error(context, error);
          return;
        }
        AppFeedback.success(context, 'Position saved.');
      },
    ),
  );
}

/// Opens the exercise sheet on [from] and the line under it. The line is
/// read back through the app's one reader first: an exercise whose answer is
/// not the line on the board is refused rather than made.
Future<void> keepBoardAsExercise(
  BuildContext context, {
  required ExerciseApiService api,
  required AnalysisNode from,
  required List<String> labels,
}) async {
  final pgn = PgnExporterService.exportToPgn(from);
  final parsed = MoveTree.parsePgn(pgn, startingFen: from.fen);
  if (parsed == null || parsed.rejectedMoves > 0) {
    final n = parsed?.rejectedMoves ?? 0;
    AppFeedback.error(context,
        '$n ${n == 1 ? 'move' : 'moves'} on this board could not be read back, so making an exercise of it would answer a different line than you built.');
    return;
  }
  final saved = await openMakeExerciseSheet(
    context,
    api: api,
    moveTree: parsed,
    availableUserLabels: labels,
  );
  if (saved != null && context.mounted) {
    AppFeedback.success(context, 'Exercise saved.');
  }
}
