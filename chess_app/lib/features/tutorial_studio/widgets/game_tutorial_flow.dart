/// „Make a tutorial from this game" — the door of phase 4 of
/// `docs/PLAN-SKELET.md`.
///
/// One press, one run: the depth, then the run with its progress and a cancel,
/// then the choice between the two tutorials the same words made — **Key
/// moments** and **Whole game** — and the chosen one opens in the studio,
/// unsaved, exactly as a file import does.
///
/// Every refusal is a sentence. The one that has somewhere to send the trainer
/// — no engine on this computer — has a button that goes there.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/app_slider.dart';

/// The shallowest depth offered (D1): 18 is where the thresholds were
/// validated, and nothing lower is offered until it is measured the same way.
const int kGameTutorialMinDepth = 18;

/// The depth a tutorial starts at: 20, the depth the mistake rule's floor
/// (`kMistakeLoss`) was measured at — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`,
/// phase 1b, the owner's choice of 25.9.2026. 18 until then.
const int kGameTutorialDefaultDepth = 20;

/// The deepest: the app's one ceiling. Until 17.9.2026 the trainer chose
/// between 18, 20 and 22 only — the three depths phase 0 had timed; the owner
/// asked for every depth up to 50 wherever a depth is chosen. Past 22 the time
/// is not measured, and the dialog says so rather than guessing.
const int kGameTutorialMaxDepth = AppSettingsService.kMaxEngineDepth;

/// A new key since phase 1b: the old one held the depth every earlier run had
/// saved, which was almost always the old default of 18, so the new default
/// would never have been seen. Everyone starts once at
/// [kGameTutorialDefaultDepth], and what a trainer then chooses is kept.
const String kGameTutorialDepthPreference = 'app_game_tutorial_depth_v2';

/// What the trainer chose before the run: how deep. The threshold that stood
/// beside it (`minCost`, pawns) is gone since phase 1b — the review's judge
/// decides what a mistake is.
typedef GameTutorialSettings = ({int depth});

/// How long a depth takes, as phase 0 measured it on Windows with eight
/// workers: 39–109 s a game at 18, 1.9–3.8 times that at 20, 3.6–7.1 at 22.
String gameTutorialDepthTime(int depth) => switch (depth) {
      18 => 'under 2 minutes',
      // Not timed; bounded by the next measured depth, which is never faster.
      19 => 'under 7 minutes',
      20 => '1 to 7 minutes',
      21 => 'under 13 minutes',
      22 => '2 to 13 minutes',
      _ => 'not measured — longer than depth 22, which takes 2 to 13 minutes',
    };

/// The depth, remembered from last time; null when the trainer cancels. It
/// buys engine time and cannot be taken back, so it is asked before the run.
Future<GameTutorialSettings?> chooseGameTutorialDepth(
    BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final remembered = prefs.getInt(kGameTutorialDepthPreference);
  var depth = remembered != null &&
          remembered >= kGameTutorialMinDepth &&
          remembered <= kGameTutorialMaxDepth
      ? remembered
      : kGameTutorialDefaultDepth;
  if (!context.mounted) return null;
  final chosen = await showDialog<GameTutorialSettings>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Make a tutorial from this game'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The engine searches every position of the game and finds its '
                'mistakes the way a game review does, and the moves where only '
                'one move held and the player found it. Those become the '
                'tutorial. How deep should it search?',
                style: AppText.body.copyWith(color: ctx.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Depth $depth', style: AppText.bodyBold),
              Text(
                key: const Key('game-tutorial-depth-time'),
                gameTutorialDepthTime(depth),
                style: AppText.body.copyWith(color: ctx.colors.textSecondary),
              ),
              AppSlider(
                key: const Key('game-tutorial-depth'),
                value: depth.toDouble(),
                min: kGameTutorialMinDepth.toDouble(),
                max: kGameTutorialMaxDepth.toDouble(),
                divisions: kGameTutorialMaxDepth - kGameTutorialMinDepth,
                label: '$depth',
                onChanged: (value) => setState(() => depth = value.round()),
              ),
              Text(
                'A game searched once is kept on this computer: making it again '
                'at the same depth takes almost no engine time.',
                style: AppText.caption.copyWith(color: ctx.colors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('game-tutorial-start'),
            onPressed: () => Navigator.of(ctx).pop((depth: depth)),
            child: const Text('Start'),
          ),
        ],
      ),
    ),
  );
  if (chosen != null) {
    await prefs.setInt(kGameTutorialDepthPreference, chosen.depth);
  }
  return chosen;
}

/// What the engine found, before the words are paid for — point 6 of the
/// owner's live pass, 14.9.2026. Since phase 1b there is nothing to slide: the
/// review's judge decided what a mistake is, so this says how many mistakes
/// and only moves were found, how many become parts, and — when there are too
/// few — that the game is clean at this depth. Nothing is spent until the
/// trainer presses the button.
///
/// Returns the parameters to write the tutorial with, or null to stop.
Future<SkeletonParameters?> chooseGameTutorialSlice(
  BuildContext context,
  GameTutorialSlice slice,
) {
  final counts = slice.counts;
  final found = slice.found;
  final parts = slice.parts;
  final enough = found >= 2;
  String many(int n, String one, String more) => n == 1 ? '1 $one' : '$n $more';
  return showDialog<SkeletonParameters>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('What the engine found'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key: const Key('game-tutorial-found'),
              '${many(counts.mistakes, 'mistake', 'mistakes')} and '
              '${many(counts.onlyMoves, 'move', 'moves')} where only one move '
              'held.',
              style: AppText.bodyBold,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              // The cap is said whenever it bites, because „14 found" over a
              // tutorial of eight parts reads as a fault in the tutorial.
              found > parts
                  ? 'The $parts that matter most become parts of the tutorial.'
                  : found == 0
                      ? 'Nothing to teach from at depth ${slice.depth ?? '?'}.'
                      : 'All of them become parts of the tutorial.',
              style: AppText.body.copyWith(color: ctx.colors.textSecondary),
            ),
            if (slice.unsettled > 0 || slice.unjudged > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                key: const Key('game-tutorial-unsure'),
                [
                  if (slice.unsettled > 0)
                    'The looks still disagreed on ${slice.unsettled} move(s).',
                  if (slice.unjudged > 0)
                    'The engine did not answer on ${slice.unjudged} move(s).',
                ].join(' '),
                style: AppText.caption.copyWith(color: ctx.colors.textMuted),
              ),
            ],
            if (!enough) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                key: const Key('game-tutorial-too-few'),
                'A tutorial needs at least two.',
                style: AppText.body.copyWith(color: ctx.colors.warning),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Only writing the words is paid for.',
              style: AppText.caption.copyWith(color: ctx.colors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('game-tutorial-slice-cancel'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('game-tutorial-slice-write'),
          onPressed:
              enough ? () => Navigator.of(ctx).pop(slice.parameters) : null,
          child: const Text('Write the tutorial'),
        ),
      ],
    ),
  );
}

/// The run, with its progress and a cancel. Pops a [GameTutorialResult] or a
/// [GameTutorialStopped].
class GameTutorialProgressDialog extends StatefulWidget {
  const GameTutorialProgressDialog({
    super.key,
    required this.runner,
    required this.gameName,
    required this.startFen,
    required this.uciMoves,
    required this.depth,
    this.chooseSlice,
  });

  final GameTutorialRunner runner;
  final String gameName;
  final String startFen;
  final List<String> uciMoves;
  final int depth;

  /// Asked once the engine is done and before the words are paid for.
  /// Injected so a test can answer it without a second dialog.
  final Future<SkeletonParameters?> Function(
      BuildContext context, GameTutorialSlice slice)? chooseSlice;

  @override
  State<GameTutorialProgressDialog> createState() =>
      _GameTutorialProgressDialogState();
}

class _GameTutorialProgressDialogState
    extends State<GameTutorialProgressDialog> {
  GameTutorialProgress _progress =
      const GameTutorialProgress(GameTutorialStage.engine);
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    Object outcome;
    try {
      outcome = await widget.runner.run(
        gameName: widget.gameName,
        startFen: widget.startFen,
        uciMoves: widget.uciMoves,
        depth: widget.depth,
        parameters: const SkeletonParameters(),
        chooseSlice: (slice) async {
          if (!mounted) return null;
          return (widget.chooseSlice ?? chooseGameTutorialSlice)(
              context, slice);
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } on GameTutorialStopped catch (stop) {
      outcome = stop;
    } catch (e) {
      outcome = GameTutorialStopped('failed', 'No tutorial was made ($e).');
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  String get _sentence => switch (_progress.stage) {
        GameTutorialStage.engine => 'Getting the engine ready…',
        GameTutorialStage.masters =>
          'Asking the masters database about the opening…',
        GameTutorialStage.analysis =>
          'The engine is searching every position of the game.',
        GameTutorialStage.review =>
          'Checking which moves are mistakes, the way a game review does.',
        GameTutorialStage.words =>
          'Writing the words for the moments worth teaching. This takes up to '
              'a minute and cannot be cancelled.',
        GameTutorialStage.assembly => 'Putting the tutorial together…',
      };

  static String _left(int seconds) {
    if (seconds < 60) return 'under a minute left';
    final minutes = (seconds / 60).ceil();
    return 'about $minutes ${minutes == 1 ? 'minute' : 'minutes'} left';
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final analysing = (p.stage == GameTutorialStage.analysis ||
            p.stage == GameTutorialStage.review) &&
        p.total > 0;
    final canCancel = p.stage != GameTutorialStage.words &&
        p.stage != GameTutorialStage.assembly &&
        !_cancelling;
    return PopScope(
      // A misplaced tap must not throw minutes of engine time away; the
      // Cancel button is the way out.
      canPop: false,
      child: AlertDialog(
        title: const Text('Making the tutorial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_sentence,
                key: const Key('game-tutorial-stage'),
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: analysing ? p.done / p.total : null,
              backgroundColor: context.colors.surfaceRaised,
              color: context.colors.accent,
            ),
            if (analysing && p.stage == GameTutorialStage.analysis) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${p.done} of ${p.total} positions'
                '${p.secondsLeft == null ? '' : ' · ${_left(p.secondsLeft!)}'}',
                key: const Key('game-tutorial-count'),
                style: AppText.caption
                    .copyWith(color: context.colors.textSecondary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('game-tutorial-cancel'),
            onPressed: canCancel
                ? () {
                    setState(() => _cancelling = true);
                    widget.runner.cancel();
                  }
                : null,
            child: Text(_cancelling ? 'Cancelling…' : 'Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Which of the two tutorials to open, or null.
Future<ImportedTutorial?> chooseGameTutorial(
    BuildContext context, GameTutorialResult result) {
  final toCheck = [...result.claims, ...result.missingSlots];
  // One version: a tutorial is made for its film, and asks nothing
  // (docs/PLAN-TUTORIJAL-VIDEO.md, D10). The choice between „For students"
  // and „For a video" went with the questions.
  return showDialog<ImportedTutorial>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      Widget option(
          String key, String title, String detail, ImportedTutorial tutorial) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: OutlinedButton(
            key: Key(key),
            onPressed: () => Navigator.of(ctx).pop(tutorial),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(AppSpacing.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyBold),
                Text(
                  '${tutorial.partCount} '
                  '${tutorial.partCount == 1 ? 'part' : 'parts'} — $detail',
                  style:
                      AppText.caption.copyWith(color: ctx.colors.textSecondary),
                ),
              ],
            ),
          ),
        );
      }

      return AlertDialog(
        title: Text(result.keyMoments.title.isEmpty
            ? 'The tutorial is ready'
            : result.keyMoments.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'The same words made two tutorials. Open one to edit it — '
                'nothing is saved until you save it.',
                style: AppText.body.copyWith(color: ctx.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              option('game-tutorial-key-moments', 'Key moments',
                  'only the moments worth teaching', result.keyMoments),
              option(
                  'game-tutorial-whole-game',
                  'Whole game',
                  'the whole game, with those moments in their places',
                  result.wholeGame),
              if (result.mastersNote != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(result.mastersNote!,
                    style:
                        AppText.caption.copyWith(color: ctx.colors.textMuted)),
              ],
              if (toCheck.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${toCheck.length} '
                  '${toCheck.length == 1 ? 'sentence' : 'sentences'} to check '
                  'before you save it:',
                  key: const Key('game-tutorial-to-check'),
                  style: AppText.caption.copyWith(color: ctx.colors.warning),
                ),
                for (final line in toCheck.take(5))
                  Text('• $line',
                      style: AppText.caption
                          .copyWith(color: ctx.colors.textSecondary)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }),
  );
}

/// What to tell the trainer when no tutorial was made.
Future<void> showGameTutorialStopped(
  BuildContext context,
  GameTutorialStopped stop, {
  VoidCallback? onOpenEngineSettings,
}) async {
  if (stop.kind == 'cancelled') {
    AppFeedback.info(context, stop.message);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
          stop.upgradeRequired ? 'A Premium feature' : 'No tutorial was made'),
      content: Text(stop.message, key: const Key('game-tutorial-stopped')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
        if (stop.offerEngineDownload && onOpenEngineSettings != null)
          FilledButton(
            key: const Key('game-tutorial-engine-settings'),
            onPressed: () {
              Navigator.of(ctx).pop();
              onOpenEngineSettings();
            },
            child: const Text('Engine settings'),
          ),
      ],
    ),
  );
}

Future<void> _openInStudio(
    BuildContext context, UserSession session, ImportedTutorial tutorial) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => TutorialStudioScreen(
      session: session,
      entry: TutorialEntry.imported(tutorial.asLesson,
          sourceName: tutorial.fileName),
    ),
  ));
}

/// The whole door: from a game's tree to a tutorial open in the studio.
///
/// [runnerFor] and [openInStudio] are seams for tests; a real build passes
/// neither.
Future<void> makeTutorialFromGame(
  BuildContext context, {
  required UserSession session,
  required AnalysisNode root,
  required String gameName,
  VoidCallback? onOpenEngineSettings,
  Future<SkeletonParameters?> Function(
          BuildContext context, GameTutorialSlice slice)?
      chooseSlice,
  GameTutorialRunner Function()? runnerFor,
  Future<void> Function(BuildContext context, ImportedTutorial tutorial)?
      openInStudio,
}) async {
  final uciMoves = <String>[];
  for (var node = root; node.children.isNotEmpty; node = node.children.first) {
    final uci = node.children.first.moveUci;
    if (uci == null || uci.isEmpty) break;
    uciMoves.add(uci);
  }
  if (uciMoves.isEmpty) {
    AppFeedback.error(context,
        'There are no moves to make a tutorial from. Load a game first.');
    return;
  }

  final settings = await chooseGameTutorialDepth(context);
  if (settings == null || !context.mounted) return;

  final runner = runnerFor?.call() ?? GameTutorialRunner(token: session.token);
  final outcome = await showDialog<Object>(
    context: context,
    barrierDismissible: false,
    builder: (_) => GameTutorialProgressDialog(
      runner: runner,
      gameName: gameName,
      startFen: root.fen,
      uciMoves: uciMoves,
      depth: settings.depth,
      chooseSlice: chooseSlice,
    ),
  );
  if (!context.mounted) return;
  if (outcome is GameTutorialStopped) {
    await showGameTutorialStopped(context, outcome,
        onOpenEngineSettings: onOpenEngineSettings);
    return;
  }
  if (outcome is! GameTutorialResult) return;

  final chosen = await chooseGameTutorial(context, outcome);
  if (chosen == null || !context.mounted) return;
  if (openInStudio != null) {
    await openInStudio(context, chosen);
  } else {
    await _openInStudio(context, session, chosen);
  }
}
