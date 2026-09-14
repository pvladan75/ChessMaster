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
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// The depths offered (D1): 18 is where the thresholds were validated, and
/// nothing lower is offered until it is measured the same way.
const List<int> kGameTutorialDepths = [18, 20, 22];

const String kGameTutorialDepthPreference = 'app_game_tutorial_depth';
const String kGameTutorialThresholdPreference = 'app_game_tutorial_threshold';

/// What a move has to cost, in pawns, before it is a moment worth teaching.
///
/// The range and the step are the Review dialog's, so the two controls speak
/// one language. The **default is not** the Review dialog's: 2.0 pawns there
/// tags a blunder and cuts a puzzle from it, and 1.0 here is where phase 0
/// validated „worth teaching from" — a move that costs a pawn and a half is a
/// poor puzzle and a good lesson.
const double kGameTutorialMinThreshold = 0.2;
const double kGameTutorialMaxThreshold = 5.0;
const double kGameTutorialDefaultThreshold = 1.0;

/// One decimal, the step the slider moves in.
double roundThreshold(double value) => (value * 10).roundToDouble() / 10;

/// What the trainer chose before the run: how deep, and how bad a move has to
/// be to be taught.
typedef GameTutorialSettings = ({int depth, double minCost});

/// How long a depth takes, as phase 0 measured it on Windows with eight
/// workers: 39–109 s a game at 18, 1.9–3.8 times that at 20, 3.6–7.1 at 22.
String gameTutorialDepthTime(int depth) => switch (depth) {
      18 => 'under 2 minutes',
      20 => '1 to 7 minutes',
      22 => '2 to 13 minutes',
      _ => '',
    };

/// The depth and the threshold, remembered from last time; null when the
/// trainer cancels.
///
/// Both are asked here, but they are not the same kind of question. The depth
/// buys engine time and cannot be taken back; the threshold costs nothing and
/// is asked again, with the count beside it, once the engine has finished
/// (`chooseGameTutorialSlice`). This is where a trainer who already knows what
/// they want says so.
Future<GameTutorialSettings?> chooseGameTutorialDepth(
    BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final remembered = prefs.getInt(kGameTutorialDepthPreference);
  var depth = kGameTutorialDepths.contains(remembered) ? remembered! : 18;
  var minCost = roundThreshold(
      prefs.getDouble(kGameTutorialThresholdPreference) ??
          kGameTutorialDefaultThreshold);
  if (minCost < kGameTutorialMinThreshold ||
      minCost > kGameTutorialMaxThreshold) {
    minCost = kGameTutorialDefaultThreshold;
  }
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
                'The engine searches every position of the game, then the '
                'words are written for the moments worth teaching. How deep '
                'should it search?',
                style: AppText.body.copyWith(color: ctx.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<int>(
                groupValue: depth,
                onChanged: (value) => setState(() => depth = value ?? depth),
                child: Column(
                  children: [
                    for (final d in kGameTutorialDepths)
                      RadioListTile<int>(
                        key: Key('game-tutorial-depth-$d'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: d,
                        title: Text('Depth $d'),
                        subtitle: Text(gameTutorialDepthTime(d)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  'Teach a move that cost ${minCost.toStringAsFixed(1)} pawns '
                  'or more',
                  style: AppText.body),
              Slider(
                key: const Key('game-tutorial-threshold'),
                value: minCost,
                min: kGameTutorialMinThreshold,
                max: kGameTutorialMaxThreshold,
                divisions: 48,
                label: minCost.toStringAsFixed(1),
                onChanged: (value) =>
                    setState(() => minCost = roundThreshold(value)),
              ),
              Text(
                'A game searched once is kept on this computer: making it again '
                'at the same depth takes no engine time. You can change the '
                'threshold again when the search is done, and see how many '
                'mistakes it finds.',
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
            onPressed: () =>
                Navigator.of(ctx).pop((depth: depth, minCost: minCost)),
            child: const Text('Start'),
          ),
        ],
      ),
    ),
  );
  if (chosen != null) {
    await prefs.setInt(kGameTutorialDepthPreference, chosen.depth);
    await prefs.setDouble(kGameTutorialThresholdPreference, chosen.minCost);
  }
  return chosen;
}

/// What the engine found, before the words are paid for — point 6 of the
/// owner's live pass, 14.9.2026: „koliko ima otkrivenih grešaka sa ovim
/// postavkama, pa može da ponovo izvrši analizu, ako mu je to malo ili mnogo".
///
/// It turned out to be better than „run it again": the facts are cached by
/// game, depth and engine and **the threshold is no part of that key**, so
/// another slice of the same game costs no engine time whatever. The trainer
/// moves the slider and the count answers at once; nothing is spent until they
/// press the button.
///
/// Returns the parameters to write the tutorial with, or null to stop.
Future<SkeletonParameters?> chooseGameTutorialSlice(
  BuildContext context,
  GameTutorialSlice slice,
) {
  var minCost = roundThreshold(slice.parameters.minCost);
  return showDialog<SkeletonParameters>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final found = slice.countAt(minCost);
        final parts = slice.partsAt(minCost);
        final enough = found >= 2;
        return AlertDialog(
          title: const Text('What the engine found'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('game-tutorial-found'),
                  found == 1
                      ? '1 move cost ${minCost.toStringAsFixed(1)} pawns or more.'
                      : '$found moves cost ${minCost.toStringAsFixed(1)} pawns '
                          'or more.',
                  style: AppText.bodyBold,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // The cap is said whenever it bites, because „14 found" over
                  // a tutorial of eight parts reads as a fault in the tutorial.
                  found > parts
                      ? 'The $parts worst become parts of the tutorial.'
                      : found == 0
                          ? 'Lower the threshold to find some.'
                          : 'All of them become parts of the tutorial.',
                  style: AppText.body.copyWith(color: ctx.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Teach a move that cost ${minCost.toStringAsFixed(1)} '
                    'pawns or more'),
                Slider(
                  key: const Key('game-tutorial-slice-threshold'),
                  value: minCost,
                  min: kGameTutorialMinThreshold,
                  max: kGameTutorialMaxThreshold,
                  divisions: 48,
                  label: minCost.toStringAsFixed(1),
                  onChanged: (value) =>
                      setState(() => minCost = roundThreshold(value)),
                ),
                if (!enough)
                  Text(
                    key: const Key('game-tutorial-too-few'),
                    'A tutorial needs at least two. Lower the threshold.',
                    style: AppText.body.copyWith(color: ctx.colors.warning),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Moving this costs no engine time — the search is done and '
                  'its answers are kept. Only writing the words is paid for.',
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
              onPressed: enough
                  ? () => Navigator.of(ctx)
                      .pop(slice.parameters.withMinCost(minCost))
                  : null,
              child: const Text('Write the tutorial'),
            ),
          ],
        );
      },
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
    required this.blackOrientation,
    this.minCost = kGameTutorialDefaultThreshold,
    this.chooseSlice,
  });

  final GameTutorialRunner runner;
  final String gameName;
  final String startFen;
  final List<String> uciMoves;
  final int depth;

  /// Which way round every part of the tutorial stands — the orientation the
  /// trainer has in Analysis, not the side to move.
  final bool blackOrientation;

  /// What a move must cost to be taught, as the first dialog left it.
  final double minCost;

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
        blackOrientation: widget.blackOrientation,
        parameters: const SkeletonParameters().withMinCost(widget.minCost),
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
    final analysing = p.stage == GameTutorialStage.analysis && p.total > 0;
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
            if (analysing) ...[
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
  return showDialog<ImportedTutorial>(
    context: context,
    builder: (ctx) {
      Widget option(String key, String title, String detail,
              ImportedTutorial tutorial) =>
          Padding(
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
                    style: AppText.caption
                        .copyWith(color: ctx.colors.textSecondary),
                  ),
                ],
              ),
            ),
          );
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
              const SizedBox(height: AppSpacing.md),
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
    },
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
  required bool blackOrientation,
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
      minCost: settings.minCost,
      blackOrientation: blackOrientation,
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
