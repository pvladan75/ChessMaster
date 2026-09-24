import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/services/opening_tree_judge.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/facts_store.dart'
    show engineIdentity;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart'
    show localEnginePath;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/uci_engine.dart'
    show UciEnginePool, defaultFactsWorkers;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

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
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: ElevatedButton.icon(
          onPressed: _startJudging,
          icon: const Icon(Icons.gavel, size: 16),
          label: const Text('Judge with the engine'),
        ),
      );
    }

    // Still checking whether there is an engine on disk.
    return const SizedBox.shrink();
  }

  Widget _buildLosingHabitsSection(BuildContext context, LeakReport report) {
    final flagged = report.nodes.map((n) => n.fenKey).toSet();
    final extra =
        report.losingHabits.where((h) => !flagged.contains(h.fenKey)).toList();
    if (report.losingHabits.isEmpty) return const SizedBox.shrink();
    final count = report.losingHabits.length;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (extra.isNotEmpty) ...[
            Text(
              "Losing habits your score doesn't show",
              style:
                  AppText.bodyBold.copyWith(color: context.colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final habit in extra) _buildLosingHabitRow(context, habit),
            const SizedBox(height: AppSpacing.sm),
          ],
          // Every losing habit, flagged or not — the drill asks „here you
          // play X; find the better move" (§9.4).
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
    return Container(
      key: ValueKey('losing-habit-${habit.fenKey}-${habit.uci}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoardThumbnail(
            fen: habit.fen,
            size: 56,
            isWhiteBottom: _color == 'w',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${habit.san} — ${habit.games} of ${habit.nodeGames} games',
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
                        'Loses $lost winning chances — $better was better',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption
                            .copyWith(color: context.colors.danger),
                      ),
                    ),
                  ],
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

    return Container(
      key: ValueKey(node.fenKey),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoardThumbnail(
            fen: node.fen,
            size: 80,
            isWhiteBottom: _color == 'w',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ply ${node.ply} · score ${(node.score * 100).toStringAsFixed(1)}%',
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${mainMove.san} — ${mainMove.games} of ${node.games} ${node.games == 1 ? 'game' : 'games'} · ${(mainMove.score * 100).toStringAsFixed(1)}%',
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
                    if (report.nodes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'No opening leaks found.',
                            style: AppText.body
                                .copyWith(color: context.colors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...report.nodes.map((node) => _buildNode(context, node)),
                    _buildLosingHabitsSection(context, report),
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
