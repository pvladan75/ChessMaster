import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
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
class TrainingHubScreen extends StatefulWidget {
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
  State<TrainingHubScreen> createState() => _TrainingHubScreenState();
}

class _TrainingHubScreenState extends State<TrainingHubScreen> {
  Map<String, SourceProgress>? _progress;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  /// A guest has no attempt log to read. Null draws no line on any card,
  /// which is also what a failed read draws — the two look the same to the
  /// player, and both are correct here (docs/PLAN-NAPREDAK-VEZBI.md §4).
  Future<void> _loadProgress() async {
    if (widget.session.isGuest) return;
    final progress =
        await PuzzleAttemptApi(authToken: widget.session.token).progress();
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  /// Pushes a drill and refreshes the cards when the reader comes back —
  /// `context.push` already resolves on the pop, which is the cheapest way
  /// to notice a drill just wrote to the log this screen stays mounted
  /// through.
  Future<void> _pushAndRefresh(String path) async {
    await context.push(path);
    _loadProgress();
  }

  void _onRetry(String source) {
    switch (source) {
      case PuzzleSource.lichess:
        _pushAndRefresh('${AppRoutes.tactics}?retry=1');
      case PuzzleSource.matePuzzle:
        _pushAndRefresh(AppRoutes.drillPath('mate_puzzle', retry: true));
      case PuzzleSource.winningPosition:
        _pushAndRefresh(AppRoutes.drillPath('winning_position', retry: true));
      case PuzzleSource.endgame:
        _pushAndRefresh('${AppRoutes.endgames}?retry=1');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: widget.embedded
          ? null
          : AppBar(
              // The title the reader sees, which is not the name the code uses.
              // The screen behind this used to be called a studio for reasons
              // that stopped being true a long time ago. The tab's own name,
              // `kTabNames[0]` — it said „Trening" until 11.9.2026, three days
              // after the English pivot, because a Serbian word with no
              // Serbian letter in it is invisible to the language gate.
              title: const Text('Training'),
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
                onSelectTactics: () => _pushAndRefresh(AppRoutes.tactics),
                onSelectEndgameWin: () =>
                    _pushAndRefresh('${AppRoutes.endgamePicker}?mode=win'),
                onSelectEndgameDraw: () =>
                    _pushAndRefresh('${AppRoutes.endgamePicker}?mode=draw'),
                onSelectBlunderGames: () =>
                    _pushAndRefresh(AppRoutes.blunderGames),
                onSelectRepertoire: () => _pushAndRefresh(AppRoutes.repertoire),
                onSelectMyGames: () => _pushAndRefresh(AppRoutes.archiveHome),
                onSelectMistakesDrill: () =>
                    _pushAndRefresh(AppRoutes.archiveMistakes),
                // These three used to be a value on the working screen's state.
                // They are places, so they have paths.
                onSelectMatePuzzle: (depth) => _pushAndRefresh(
                    AppRoutes.drillPath('mate_puzzle', depth: depth)),
                onSelectBasicMate: (level) => _pushAndRefresh(
                    AppRoutes.drillPath('basic_mate', level: level)),
                onSelectWinningPosition: () =>
                    _pushAndRefresh(AppRoutes.drillPath('winning_position')),
                progress: _progress,
                onRetry: _onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
