/// The one way a whole game is opened in Analysis from another screen: the
/// archive's mistake (D4 of `docs/PLAN-SKELET.md`), the trainer's review of a
/// homework game and the student's own finished game (`docs/PLAN-EXERCISE.md`,
/// phase 13) — and, beside it, a tree standing on one of its nodes: a position
/// of the opening report (30.9.2026).
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Null — the default — pushes the real screen; a test sets it, because
/// Analysis starts an engine the test has none of.
@visibleForTesting
Future<void> Function(BuildContext context, AnalysisGame game)?
    debugOpenGameInAnalysis;

Future<void> openGameInAnalysis(BuildContext context, AnalysisGame game) {
  final open = debugOpenGameInAnalysis ?? _pushAnalysis;
  return open(context, game);
}

/// A game kept as SAN, opened whole or not at all: a game that does not
/// replay from its position is refused in words, never opened shorter than it
/// was played.
Future<void> openSanGameInAnalysis(
  BuildContext context, {
  required String startFen,
  required List<String> sans,
  required bool blackOrientation,
}) async {
  final game = analysisGameFromSans(
    startFen: startFen,
    sans: sans,
    blackOrientation: blackOrientation,
  );
  if (game == null) {
    AppFeedback.show(
      context,
      () => const SnackBar(
        content: Text('This game cannot be replayed from its position, so it '
            'was not opened.'),
      ),
    );
    return;
  }
  await openGameInAnalysis(context, game);
}

Future<void> _pushAnalysis(BuildContext context, AnalysisGame game) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AnalysisStudioScreen(
        userSession: SessionService.instance.current,
        initialGame: game,
      ),
    ));

/// Null — the default — pushes the real screen; a test sets it, for the same
/// reason as [debugOpenGameInAnalysis].
@visibleForTesting
Future<void> Function(
        BuildContext context, AnalysisNode root, AnalysisNode standOn)?
    debugOpenTreeInAnalysis;

/// A tree opened standing on one of its nodes, with its branches — how a
/// position of the opening report opens with the moves that led to it
/// (30.9.2026). **Pushed, like a game**: the screen that opened it stays
/// underneath as it was left, so Back returns to the same place.
Future<void> openTreeInAnalysis(
  BuildContext context, {
  required AnalysisNode root,
  required AnalysisNode standOn,
}) {
  final open = debugOpenTreeInAnalysis ?? _pushTree;
  return open(context, root, standOn);
}

Future<void> _pushTree(
        BuildContext context, AnalysisNode root, AnalysisNode standOn) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AnalysisStudioScreen(
        userSession: SessionService.instance.current,
        initialTree: root,
        initialNodeId: standOn.id,
      ),
    ));
