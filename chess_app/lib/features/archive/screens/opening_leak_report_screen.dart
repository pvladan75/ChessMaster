import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart'
    show openTreeInAnalysis;
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/services/opening_position_tree.dart';
import 'package:chess_app/features/archive/screens/position_games_screen.dart';
import 'package:chess_app/features/archive/services/opening_tree_judge.dart';
import 'package:chess_app/core/services/engine_identity.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart'
    show localEnginePath;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/uci_engine.dart'
    show UciEnginePool, defaultFactsWorkers;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/board_zoom_dialog.dart';

/// Reused from the tutorial builder's own refusal
/// (`game_tutorial_run.dart`, `no-engine`) — one sentence for „there is no
/// engine on this device", not two.
const _noEngineReason =
    'Judging needs the chess engine on this computer. Download it in the '
    'engine settings, then try again.';

class OpeningLeakReportScreen extends StatefulWidget {
  const OpeningLeakReportScreen({
    super.key,
    required this.subject,
  });

  final String subject;

  @override
  State<OpeningLeakReportScreen> createState() =>
      _OpeningLeakReportScreenState();
}

class _OpeningLeakReportScreenState extends State<OpeningLeakReportScreen> {
  String _color = 'w'; // 'w' or 'b'

  /// Off until asked. Judging asks Lichess's cloud evaluation twice per
  /// position, and the counted half of this report — which positions, how
  /// often, how badly — is complete without it.
  bool _judge = false;
  Future<LeakReport>? _reportFuture;
  bool _isBackfilling = false;

  /// Null while `localEnginePath()` has not answered yet.
  bool? _engineAvailable;

  bool _judging = false;
  bool _drillingHabits = false;
  int _judgeDone = 0;
  int _judgeTotal = 0;
  OpeningTreeJudge? _activeJudge;
  UciEnginePool? _enginePool;

  @override
  void initState() {
    super.initState();
    _fetchReport();
    _checkEngine();
  }

  @override
  void dispose() {
    _activeJudge?.cancel();
    _enginePool?.close();
    super.dispose();
  }

  /// `localEnginePath()` itself, made safe for a caller that only wants to
  /// know whether an engine is there — a device that cannot even answer the
  /// question has no engine to run one on, so this reads the same as „no".
  Future<String?> _engineOnDisk() async {
    try {
      return await localEnginePath();
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkEngine() async {
    final path = await _engineOnDisk();
    if (!mounted) return;
    setState(() => _engineAvailable = path != null);
  }

  Future<void> _startJudging() async {
    final path = await _engineOnDisk();
    if (!mounted) return;
    if (path == null) {
      setState(() => _engineAvailable = false);
      return;
    }

    late final OpeningNodesReport nodesReport;
    try {
      nodesReport = await ArchiveApiService.instance
          .getOpeningNodes(subject: widget.subject, color: _color);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Positions could not be fetched: $e');
      return;
    }

    final UciEnginePool pool;
    final String engine;
    try {
      // The identity first: a pool started and then orphaned by a failing
      // stat would leave engine processes running with nobody to close them.
      engine = await engineIdentity(path);
      pool = await UciEnginePool.start(path, workers: defaultFactsWorkers());
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'The chess engine could not be started: $e');
      return;
    }

    final judge = OpeningTreeJudge(
      analyzers: [for (final e in pool.engines) e.analyze],
      engine: engine,
      send: ArchiveApiService.instance.sendJudgements,
    );
    setState(() {
      _judging = true;
      _judgeDone = 0;
      _judgeTotal = 0;
      _activeJudge = judge;
      _enginePool = pool;
    });

    try {
      final result = await judge.run(nodesReport.nodes, onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _judgeDone = progress.done;
          _judgeTotal = progress.total;
        });
      });
      // Done, then said — and what could not be judged is said with it.
      if (mounted) {
        if (result.unjudged.isEmpty && result.rejected == 0) {
          AppFeedback.success(context, result.summary);
        } else {
          AppFeedback.warning(context, result.summary);
        }
      }
    } catch (e) {
      // An engine that died or a server that would not take a batch stops
      // the run; what was sent before it stays, and the report shows it.
      if (mounted) AppFeedback.error(context, 'Judging stopped: $e');
    } finally {
      pool.close();
      if (mounted) {
        setState(() {
          _judging = false;
          _activeJudge = null;
          _enginePool = null;
        });
        _fetchReport();
      }
    }
  }

  void _cancelJudging() => _activeJudge?.cancel();

  void _fetchReport() {
    setState(() {
      _reportFuture = ArchiveApiService.instance.getLeaks(
        subject: widget.subject,
        color: _color,
        judge: _judge ? true : null,
      );
    });
  }

  Future<void> _backfill() async {
    setState(() => _isBackfilling = true);
    try {
      await ArchiveApiService.instance.backfill();
      if (!mounted) return;
      AppFeedback.success(context, 'Indexing started.');
      _fetchReport();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isBackfilling = false);
      }
    }
  }

  ({IconData icon, String title}) _face(OpeningVerdict verdict) {
    switch (verdict) {
      case OpeningVerdict.theory:
        return (icon: Icons.menu_book, title: 'Mainline theory');
      case OpeningVerdict.playable:
        return (
          icon: Icons.thumb_up_alt_outlined,
          title: 'Playable alternative'
        );
      case OpeningVerdict.mistake:
        return (icon: Icons.warning_amber_rounded, title: 'Dubious move');
      case OpeningVerdict.unknown:
        return (icon: Icons.help_outline, title: 'Not judged');
    }
  }

  Color _colorOf(BuildContext context, OpeningVerdict verdict) {
    switch (verdict) {
      case OpeningVerdict.theory:
        return context.colors.success;
      case OpeningVerdict.playable:
        return context.colors.info;
      case OpeningVerdict.mistake:
        return context.colors.danger;
      case OpeningVerdict.unknown:
        return context.colors.textMuted;
    }
  }

  /// What the device's engine says about one habit move: icon and text always
  /// paired (the owner is colourblind, so hue alone never carries this), and
  /// three different sentences — a move never judged is never shown as
  /// holding.
  ({IconData icon, Color color, String text}) _habitFace(
      BuildContext context, HabitJudgement? judgement) {
    if (judgement == null) {
      return (
        icon: Icons.help_outline,
        color: context.colors.textMuted,
        text: 'Not judged yet',
      );
    }
    if (judgement.isMistake) {
      final better = judgement.bestSan ?? judgement.bestUci;
      return (
        icon: Icons.trending_down,
        color: context.colors.danger,
        text: 'Your move loses: $better was better',
      );
    }
    return (
      icon: Icons.check_circle_outline,
      color: context.colors.success,
      text: 'Your move holds — the problem comes later',
    );
  }

  Widget _buildHabitJudgement(
      BuildContext context, LeakReportNode node, LeakReportMove move) {
    final face = _habitFace(context, move.judgement);
    // The move's own name on its own line — a 360 dp phone leaves this
    // column about 206 px wide beside the board thumbnail, and the verdict
    // sentence alone needs every one of them; concatenated with the move it
    // no longer fit in a readable number of lines.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${move.san}:',
              style: AppText.captionBold.copyWith(color: face.color)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(face.icon, size: 14, color: face.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  face.text,
                  key: ValueKey('habit-judgement-${node.fenKey}-${move.uci}'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: face.color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineJudgeBar(BuildContext context) {
    if (_judging) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Judging $_judgeDone of $_judgeTotal positions…',
                key: const Key('engine-judge-progress'),
                maxLines: 2,
                style: AppText.body.copyWith(color: context.colors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: _cancelJudging,
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    if (_engineAvailable == false) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.gavel, size: 16),
              label: const Text('Judge with the engine'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _noEngineReason,
              key: const Key('engine-judge-disabled-reason'),
              maxLines: 5,
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_engineAvailable == true) {
      // Its own width, not the window's: a list stretches its children, and
      // this button ran 1870 px across a desktop window.
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        alignment: Alignment.centerLeft,
        child: ElevatedButton.icon(
          key: const Key('engine-judge-start'),
          onPressed: _startJudging,
          icon: const Icon(Icons.gavel, size: 16),
          label: const Text('Judge with the engine'),
        ),
      );
    }

    // Still checking whether there is an engine on disk.
    return const SizedBox.shrink();
  }

  /// The position on a board as large as the window allows (the owner,
  /// 30.9.2026), with the door to Analysis in it where the position has one.
  void _zoom({
    required String fen,
    required String title,
    List<String> details = const [],
    VoidCallback? onOpenInAnalysis,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => BoardZoomDialog(
        fen: fen,
        whiteBottom: _color == 'w',
        title: title,
        details: details,
        onOpenInAnalysis: onOpenInAnalysis,
      ),
    );
  }

  /// Analysis over this screen, holding the moves that led to the position
  /// and the moves the report knows about there. **Pushed**, so this screen
  /// stays underneath as it was — the colour, the list and how far it was
  /// scrolled — and Back returns to the same place (the owner, 30.9.2026).
  Future<void> _openInAnalysis(
      OpeningLine line, String fenKey, List<List<String>> branches) async {
    final tree =
        openingPositionTree(line: line, fenKey: fenKey, branches: branches);
    if (tree == null) {
      AppFeedback.error(
          context,
          'The moves to this position could not be replayed, so Analysis '
          'was not opened.');
      return;
    }
    await openTreeInAnalysis(context, root: tree.root, standOn: tree.position);
  }

  /// A thumbnail that enlarges when clicked. The pointer says so on a
  /// desktop; the words say so to a screen reader.
  Widget _zoomableBoard({
    required Key key,
    required Widget board,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: 'Enlarge the board',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(key: key, onTap: onTap, child: board),
      ),
    );
  }

  /// The ways on from a position: Analysis with the moves that led to it,
  /// drawn only when the server sent them, and the games that reached it
  /// (the owner, 30.9.2026).
  Widget _doors({
    required String id,
    VoidCallback? open,
    required int games,
    required VoidCallback onGames,
  }) {
    final style = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        children: [
          if (open != null)
            TextButton.icon(
              key: ValueKey('open-in-analysis-$id'),
              style: style,
              onPressed: open,
              icon: const Icon(Icons.biotech_outlined, size: 16),
              label: const Text('Open in Analysis'),
            ),
          TextButton.icon(
            key: ValueKey('position-games-$id'),
            style: style,
            onPressed: onGames,
            icon: const Icon(Icons.format_list_bulleted, size: 16),
            label: Text('Games ($games)'),
          ),
        ],
      ),
    );
  }

  /// The games that reached a position, over this screen — Back returns here
  /// as it was left. [move] opens the list on the games that played it.
  void _openGames(String fenKey, String fen, {String? move}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PositionGamesScreen(
        subject: widget.subject,
        color: _color,
        fenKey: fenKey,
        fen: fen,
        move: move,
      ),
    ));
  }

  /// The move's own line of a card, one format for a flagged position's
  /// favourite and a losing habit alike.
  String _moveLine(String san, int games, int of, double score) =>
      '$san — $games of $of ${of == 1 ? 'game' : 'games'} · '
      '${(score * 100).toStringAsFixed(1)}%';

  Widget _buildLosingHabitsSection(BuildContext context, LeakReport report) {
    if (report.losingHabits.isEmpty) return const SizedBox.shrink();
    final count = report.losingHabits.length;

    // **Every losing habit is listed, the flagged ones too** — the owner,
    // 30.9.2026: the button said „Drill these 9" under a list of 8, and one
    // looked lost. It was on a card above, whose position the score already
    // flags, and this section used to leave those out as shown elsewhere.
    // The list is what the button drills, and each row carries its move's own
    // score, so a habit that scores well and still loses reads as one.
    return Container(
      key: const Key('losing-habits-section'),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Losing habits',
            style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Moves you keep playing that the engine says lose — whatever '
            'your score with them.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          AdaptiveCardRows(
            children: [
              for (final habit in report.losingHabits)
                _buildLosingHabitRow(context, habit),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // The drill asks „here you play X; find the better move" (§9.4).
          OutlinedButton.icon(
            key: const Key('drill-losing-habits'),
            onPressed: _drillingHabits ? null : _drillHabits,
            icon: const Icon(Icons.school_outlined),
            label: Text(count == 1
                ? 'Drill this losing habit'
                : 'Drill these $count losing habits'),
          ),
        ],
      ),
    );
  }

  /// The heading of the positions the score flags, now that they no longer
  /// open the screen: what they are, with the report's own thresholds when it
  /// sent them.
  Widget _buildPositionsHeading(BuildContext context, LeakReport report) {
    final min = report.minGames;
    final max = report.maxScore;
    return Padding(
      key: const Key('positions-heading'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Positions where you score low',
            style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
          ),
          if (min != null && max != null) ...[
            const SizedBox(height: 2),
            Text(
              'Reached at least $min times, scoring under '
              '${(max * 100).toStringAsFixed(0)}%.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _drillHabits() async {
    setState(() => _drillingHabits = true);
    try {
      final answer = await ArchiveApiService.instance
          .drillLosingHabits(subject: widget.subject, color: _color);
      if (!mounted) return;
      if (answer.complete) {
        AppFeedback.success(context, answer.summary);
      } else {
        AppFeedback.warning(context, answer.summary);
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Not added to the drill: $e');
    } finally {
      if (mounted) setState(() => _drillingHabits = false);
    }
  }

  Widget _buildLosingHabitRow(BuildContext context, LosingHabit habit) {
    final judgement = habit.judgement;
    final better = judgement?.bestSan ?? judgement?.bestUci ?? '?';
    final lost = judgement?.lostChances.toStringAsFixed(0) ?? '?';
    final title =
        _moveLine(habit.san, habit.games, habit.nodeGames, habit.score);
    final verdict = 'Loses $lost winning chances — $better was better';
    final id = '${habit.fenKey}-${habit.uci}';
    final line = habit.line;
    final open = line == null
        ? null
        : () => _openInAnalysis(line, habit.fenKey, branchesOfHabit(habit));
    return Container(
      key: ValueKey('losing-habit-$id'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _zoomableBoard(
            key: ValueKey('zoom-habit-$id'),
            onTap: () => _zoom(
              fen: habit.fen,
              title: title,
              details: [verdict],
              onOpenInAnalysis: open,
            ),
            board: BoardThumbnail(
              fen: habit.fen,
              size: 56,
              isWhiteBottom: _color == 'w',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.trending_down,
                        size: 14, color: context.colors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        verdict,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption
                            .copyWith(color: context.colors.danger),
                      ),
                    ),
                  ],
                ),
                _doors(
                  id: 'habit-$id',
                  open: open,
                  games: habit.games,
                  onGames: () =>
                      _openGames(habit.fenKey, habit.fen, move: habit.san),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(BuildContext context, LeakReportNode node) {
    final moves = node.moves;
    if (moves.isEmpty) return const SizedBox.shrink();

    final mainMove = moves.first;
    final otherMoves = moves.skip(1).toList();
    final where =
        'Ply ${node.ply} · score ${(node.score * 100).toStringAsFixed(1)}%';
    final title =
        _moveLine(mainMove.san, mainMove.games, node.games, mainMove.score);
    final line = node.line;
    final open = line == null
        ? null
        : () => _openInAnalysis(line, node.fenKey, branchesOfNode(node));

    return Container(
      key: ValueKey(node.fenKey),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _zoomableBoard(
            key: ValueKey('zoom-node-${node.fenKey}'),
            onTap: () => _zoom(
              fen: node.fen,
              title: title,
              details: [where],
              onOpenInAnalysis: open,
            ),
            board: BoardThumbnail(
              fen: node.fen,
              size: 80,
              isWhiteBottom: _color == 'w',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  where,
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary),
                ),
                if (otherMoves.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Other tries: ${otherMoves.map((m) => '${m.san} (${m.games})').join(', ')}',
                    style: AppText.caption
                        .copyWith(color: context.colors.textSecondary),
                  ),
                ],
                if (node.judgement != null &&
                    node.judgement!.verdict != OpeningVerdict.unknown) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildJudgement(context, node.judgement!),
                ],
                for (final move in moves)
                  if (move.habit) _buildHabitJudgement(context, node, move),
                _doors(
                  id: node.fenKey,
                  open: open,
                  games: node.games,
                  onGames: () => _openGames(node.fenKey, node.fen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgement(BuildContext context, LeakJudgement j) {
    final face = _face(j.verdict);
    final color = _colorOf(context, j.verdict);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(face.icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(face.title,
                  style: AppText.captionBold.copyWith(color: color)),
            ],
          ),
          if (j.better != null) ...[
            const SizedBox(height: 2),
            Text(
              'Better was ${j.better}.',
              style: AppText.micro.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Opening leaks'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<LeakReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: AppText.body.copyWith(color: context.colors.danger),
              ),
            );
          }

          final report = snapshot.data;
          if (report == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: context.colors.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Text('Color:',
                        style: AppText.bodyBold
                            .copyWith(color: context.colors.textPrimary)),
                    const SizedBox(width: AppSpacing.md),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'w', label: Text('White')),
                        ButtonSegment(value: 'b', label: Text('Black')),
                      ],
                      selected: {_color},
                      onSelectionChanged: (set) {
                        setState(() {
                          _color = set.first;
                          _fetchReport();
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _buildEngineJudgeBar(context),
                    if (!report.judge.requested) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: AppRadii.roundedSm,
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The numbers above are complete without judging. If '
                              'you also want an opinion on a move you play '
                              'repeatedly, ask for one.',
                              style: AppText.caption
                                  .copyWith(color: context.colors.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _judge = true);
                                _fetchReport();
                              },
                              icon: const Icon(Icons.gavel, size: 16),
                              label: const Text('Judge moves'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (report.gamesWithoutNodes > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: context.colors.info.withValues(alpha: 0.1),
                          borderRadius: AppRadii.roundedSm,
                          border: Border.all(
                              color:
                                  context.colors.info.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${report.gamesWithoutNodes} ${report.gamesWithoutNodes == 1 ? 'game is' : 'games are'} not indexed for openings.',
                              style: AppText.body
                                  .copyWith(color: context.colors.info),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ElevatedButton(
                              onPressed: _isBackfilling ? null : _backfill,
                              child: Text(_isBackfilling
                                  ? 'Starting...'
                                  : 'Index older games'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // The losing habits first (the owner, 30.9.2026): they are
                    // what the engine confirmed, and most positions below
                    // say „your move holds".
                    _buildLosingHabitsSection(context, report),
                    _buildPositionsHeading(context, report),
                    if (report.nodes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'No position you reach this often scores this low.',
                            style: AppText.body
                                .copyWith(color: context.colors.textMuted),
                          ),
                        ),
                      )
                    else
                      // The positions flow into rows of cards, as many across
                      // as the width holds and one on a phone, in the order
                      // the report ranks them (docs/PLAN-PRIJAVA-I-
                      // PODESAVANJA.md, §9). The rows keep the gap between
                      // cards, so the cards carry no margin of their own.
                      AdaptiveCardRows(
                        children: [
                          for (final node in report.nodes)
                            if (node.moves.isNotEmpty)
                              _buildNode(context, node),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
