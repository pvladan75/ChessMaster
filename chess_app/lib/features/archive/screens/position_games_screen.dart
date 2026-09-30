// position_games_screen.dart — the games that reached one position of the
// opening report, each openable in Analysis standing on it.
//
// The owner, 30.9.2026: most positions of the report say „your move holds —
// the problem comes later", and later is a different moment in every game.
// So a position lists its games — newest first, how each ended, the move
// played there — and a game opens whole in Analysis on that position, through
// the one door a game from the archive opens by (`openGameInAnalysis`).
// Pushed over the report, like Analysis over it: Back returns to each screen
// as it was left.

import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/exercises/models/exercise_task_words.dart'
    show sideToMoveWords;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/board_zoom_dialog.dart';

class PositionGamesScreen extends StatefulWidget {
  const PositionGamesScreen({
    super.key,
    required this.subject,
    required this.color,
    required this.fenKey,
    required this.fen,
    this.move,
  });

  final String subject;

  /// 'w' or 'b' — the side the player had, which also turns the boards.
  final String color;
  final String fenKey;
  final String fen;

  /// The move the list opens filtered to — a losing habit's own — or null
  /// for every game of the position.
  final String? move;

  /// Room for three lines and the door, measured in Roboto at 360 dp.
  static const double tileHeight = 128;

  @override
  State<PositionGamesScreen> createState() => _PositionGamesScreenState();
}

class _PositionGamesScreenState extends State<PositionGamesScreen> {
  late final Future<PositionGames> _games = ArchiveApiService.instance
      .getPositionGames(
          subject: widget.subject, color: widget.color, fenKey: widget.fenKey);
  late String? _move = widget.move;
  String? _opening;

  bool get _whiteBottom => widget.color != 'b';

  /// The whole game in Analysis, standing on this position: [PositionGame.ply]
  /// is the move played here, so ply - 1 moves are behind the board.
  Future<void> _open(PositionGame game) async {
    setState(() => _opening = game.id);
    try {
      final moves = await ArchiveApiService.instance.fetchGameMoves(game.id);
      if (!mounted) return;
      await openGameInAnalysis(context, (
        startFen: moves.startFen,
        uciMoves: moves.uciMoves,
        cursorPly: game.ply - 1,
        blackOrientation: !_whiteBottom,
      ));
    } catch (e) {
      if (mounted) {
        AppFeedback.error(
            context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  void _zoom() {
    showDialog<void>(
      context: context,
      builder: (_) => BoardZoomDialog(
        fen: widget.fen,
        whiteBottom: _whiteBottom,
        title: 'Games through this position',
      ),
    );
  }

  static String _date(DateTime? at) {
    if (at == null) return 'no date';
    final d = at.toLocal();
    return '${d.day}.${d.month}.${d.year}';
  }

  /// The move as a reader writes it: `3. d4`, `3... d6`.
  static String _numbered(int ply, String san) =>
      ply.isOdd ? '${(ply + 1) ~/ 2}. $san' : '${ply ~/ 2}... $san';

  /// How the game ended for the player, in words and a shape of its own —
  /// never in colour alone (the owner is colour-blind).
  ({IconData icon, String words, Color color}) _outcome(
      BuildContext context, PositionGame game) {
    if (game.score >= 1) {
      return (
        icon: Icons.emoji_events_outlined,
        words: 'Won',
        color: context.colors.success
      );
    }
    if (game.score <= 0) {
      return (
        icon: Icons.flag_outlined,
        words: 'Lost',
        color: context.colors.danger
      );
    }
    return (
      icon: Icons.remove,
      words: 'Drew',
      color: context.colors.textSecondary
    );
  }

  Widget _header(BuildContext context, PositionGames answer) {
    final colors = context.colors;
    final shown = answer.games.length;
    final counts = <String, int>{};
    for (final g in answer.games) {
      counts[g.san] = (counts[g.san] ?? 0) + 1;
    }
    final moves = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Enlarge the board',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: const Key('position-games-board'),
                    onTap: _zoom,
                    child: BoardThumbnail(
                        fen: widget.fen, size: 88, isWhiteBottom: _whiteBottom),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      answer.total == 1
                          ? '1 game reached this position'
                          : '${answer.total} games reached this position',
                      key: const Key('position-games-total'),
                      style: AppText.bodyLargeBold
                          .copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(sideToMoveWords(widget.fen),
                        style:
                            AppText.body.copyWith(color: colors.textSecondary)),
                    if (shown < answer.total) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Showing the latest $shown of ${answer.total}.',
                        style: AppText.caption.copyWith(color: colors.warning),
                      ),
                    ],
                    if (answer.games.isNotEmpty &&
                        answer.games.every((g) => !g.own)) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Another player\'s games: they are listed here, and '
                        'only your own games open in Analysis.',
                        style:
                            AppText.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (moves.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  key: const Key('position-games-all'),
                  label: Text('All moves ($shown)'),
                  selected: _move == null,
                  onSelected: (_) => setState(() => _move = null),
                ),
                for (final san in moves)
                  ChoiceChip(
                    key: ValueKey('position-games-move-$san'),
                    label: Text('$san (${counts[san]})'),
                    selected: _move == san,
                    onSelected: (_) => setState(() => _move = san),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, PositionGame game) {
    final colors = context.colors;
    final outcome = _outcome(context, game);
    final opponent = [
      'vs ${game.opponent ?? 'unknown'}',
      if (game.opponentElo != null) '(${game.opponentElo})',
    ].join(' ');
    final kind = [
      if (game.speed != null) game.speed!,
      if (game.timeControl != null) game.timeControl!,
    ].join(' ');
    return Container(
      key: ValueKey('position-game-${game.id}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(outcome.icon, size: 16, color: outcome.color),
              const SizedBox(width: 6),
              Text(outcome.words,
                  style: AppText.bodyLargeBold.copyWith(color: outcome.color)),
              Expanded(
                child: Text(
                  ' · ${_date(game.playedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(opponent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 2),
          Text(
            [
              'Played ${_numbered(game.ply, game.san)}',
              if (kind.isNotEmpty) kind,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: colors.textMuted),
          ),
          const Spacer(),
          if (game.own)
            TextButton.icon(
              key: ValueKey('position-game-open-${game.id}'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              onPressed: _opening == null ? () => _open(game) : null,
              icon: const Icon(Icons.biotech_outlined, size: 16),
              label: const Text('Open in Analysis'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Games through this position'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
      ),
      body: FutureBuilder<PositionGames>(
        future: _games,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: context.colors.danger),
                ),
              ),
            );
          }
          final answer = snapshot.data!;
          // A move filter that names no loaded game shows everything rather
          // than nothing.
          final move = answer.games.any((g) => g.san == _move) ? _move : null;
          final shown = move == null
              ? answer.games
              : answer.games.where((g) => g.san == move).toList();
          return LayoutBuilder(builder: (context, constraints) {
            const pad = AppSpacing.md;
            final columns =
                AdaptiveCardGrid.columnsFor(constraints.maxWidth - 2 * pad);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(context, answer)),
                if (answer.games.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No game of yours reached this position.',
                        textAlign: TextAlign.center,
                        style: AppText.body
                            .copyWith(color: context.colors.textMuted),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(pad),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AdaptiveCardGrid.spacing,
                        mainAxisSpacing: AdaptiveCardGrid.spacing,
                        mainAxisExtent: PositionGamesScreen.tileHeight,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _card(context, shown[i]),
                        childCount: shown.length,
                      ),
                    ),
                  ),
              ],
            );
          });
        },
      ),
    );
  }
}
