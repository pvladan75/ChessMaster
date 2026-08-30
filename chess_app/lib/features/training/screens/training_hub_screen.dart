import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';

import '../widgets/resume_strip.dart';

/// What there is to practise, as a list of cards and nothing else.
///
/// Its own screen because choosing and doing were one widget of 2662 lines, and
/// that is why three cards on this list used to navigate by route and three by
/// setting a field: nobody could see the difference from inside. Here every
/// card does the same thing - it names a path.
///
/// It draws no board and holds no engine, so it costs nothing to keep mounted
/// behind whatever it opened, and coming back to it is a pop rather than a
/// rebuild.
class TrainingHubScreen extends StatelessWidget {
  const TrainingHubScreen({
    super.key,
    required this.session,
    this.embedded = false,
  });

  final UserSession session;

  /// True when this sits inside the home screen's tab stack, which now draws
  /// the tab's name itself for all four tabs. Its own AppBar would then be a
  /// second title saying the same thing. Pushed as a route it is the only one,
  /// and it carries the way back.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: embedded
          ? null
          : AppBar(
              // The title the reader sees, which is not the name the code uses.
              // The screen behind this used to be called a studio for reasons
              // that stopped being true a long time ago.
              title: const Text('Trening'),
              elevation: 0,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // What was left open, above what there is to start. Shows nothing
              // when nothing was left, which is most visits.
              const ResumeStrip(),
              CategorySelectionHubWidget(
                onSelectTactics: () => context.push(AppRoutes.tactics),
                onSelectEndgameWin: () =>
                    context.push('${AppRoutes.endgamePicker}?mode=win'),
                onSelectEndgameDraw: () =>
                    context.push('${AppRoutes.endgamePicker}?mode=draw'),
                onSelectBlunderGames: () =>
                    context.push(AppRoutes.blunderGames),
                onSelectRepertoire: () => context.push(AppRoutes.repertoire),
                onSelectMyGames: () => context.push(AppRoutes.archiveImport),
                onSelectMistakesDrill: () => context.push(AppRoutes.archiveMistakes),
                // These three used to be a value on the working screen's state.
                // They are places, so they have paths.
                onSelectMatePuzzle: (depth) => context
                    .push(AppRoutes.drillPath('mate_puzzle', depth: depth)),
                onSelectBasicMate: (level) => context
                    .push(AppRoutes.drillPath('basic_mate', level: level)),
                onSelectWinningPosition: () =>
                    context.push(AppRoutes.drillPath('winning_position')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
