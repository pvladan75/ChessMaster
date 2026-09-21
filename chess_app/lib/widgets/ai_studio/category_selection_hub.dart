import 'package:flutter/material.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

class CategorySelectionHubWidget extends StatelessWidget {
  /// The one stated limit on this tab — `docs/PLAN-POCETNI-TABOVI.md`,
  /// decision 2. The hub has three phases and eight cards; in three columns
  /// all of them are on one screen, so more width could show nothing more.
  static const int maxColumns = 3;

  /// The widest the cards may spread: [maxColumns] cards at
  /// [AdaptiveCardGrid.maxTileWidth] and the gaps between them. Derived, not
  /// written down, so the cap and the column count cannot disagree.
  static const double maxCardsWidth =
      maxColumns * AdaptiveCardGrid.maxTileWidth +
          (maxColumns - 1) * AdaptiveCardGrid.spacing;

  final Function(String depth) onSelectMatePuzzle;
  final Function(String presetDifficulty) onSelectBasicMate;
  final VoidCallback onSelectWinningPosition;
  final VoidCallback onSelectTactics;
  final VoidCallback onSelectEndgameWin;
  final VoidCallback onSelectEndgameDraw;
  final VoidCallback onSelectBlunderGames;
  final VoidCallback onSelectRepertoire;
  final VoidCallback onSelectMyGames;
  final VoidCallback onSelectMistakesDrill;

  /// What the player has done with each source's puzzles, by source name
  /// (`PuzzleSource.*`), as `PuzzleAttemptApi.progress()` answers it. Null
  /// when nothing was read; a card whose source is absent draws no line —
  /// a card with nothing seen says nothing (docs/PLAN-NAPREDAK-VEZBI.md §4).
  final Map<String, SourceProgress>? progress;

  /// „Retry failed" on a card, with that card's source. Drawn only for a
  /// retryable source with something to retry.
  final void Function(String source)? onRetry;

  const CategorySelectionHubWidget({
    super.key,
    required this.onSelectMatePuzzle,
    required this.onSelectBasicMate,
    required this.onSelectWinningPosition,
    required this.onSelectTactics,
    required this.onSelectEndgameWin,
    required this.onSelectEndgameDraw,
    required this.onSelectBlunderGames,
    required this.onSelectRepertoire,
    required this.onSelectMyGames,
    required this.onSelectMistakesDrill,
    this.progress,
    this.onRetry,
  });

  /// „Solved N" or „Solved N · M to retry", drawn only when the source was
  /// seen at all — a card with nothing seen says nothing
  /// (docs/PLAN-NAPREDAK-VEZBI.md §4).
  ///
  /// [label] names the source in front of the number, and is passed only by
  /// the one card that carries two of these lines. Reported live on 18.9.2026
  /// (TODO-provera 176.4): the endgames card read „Solved 0 · 2 to retry" over
  /// „Solved 1" with nothing to say that the first line was the endgames and
  /// the second the blunders from the reader's own games — two true numbers
  /// under no labels, which reads as one number contradicting itself. A card
  /// with a single line needs no label: its title is the label.
  String? _progressLine(String source, {String? label}) {
    final p = progress?[source];
    if (p == null || p.seen == 0) return null;
    final line = p.toRetry > 0
        ? 'Solved ${p.solved} · ${p.toRetry} to retry'
        : 'Solved ${p.solved}';
    return label == null ? line : '$label: $line';
  }

  /// „Retry failed (M)", only for a retryable source with something to
  /// retry.
  Widget? _retryButton(String source) {
    final p = progress?[source];
    if (p == null || p.toRetry <= 0) return null;
    if (!PuzzleSource.retryable.contains(source)) return null;
    return OutlinedButton.icon(
      icon: const Icon(Icons.replay),
      label: Text('Retry failed (${p.toRetry})'),
      onPressed: () => onRetry?.call(source),
    );
  }

  /// The label above a group of cards.
  ///
  /// The hub is ordered by phase of the game rather than by where the material
  /// comes from, because that is the order a lesson is taught in and the only
  /// grouping a child already has a name for.
  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppText.captionBold.copyWith(
          color: context.colors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// The player's own archive, which is the only card here whose material the
  /// player brings. Everything else on this hub is a set somebody made for
  /// them; this one is four thousand of their own games and the positions they
  /// keep answering the same wrong way.
  Widget _buildMyGamesCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.info,
      icon: Icons.inventory_2_outlined,
      title: 'My games',
      description:
          'Import a PGN export of your games and the app shows where your '
          'opening leaks: positions you reach often, the move you play '
          'repeatedly, and how many points it scored.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.info.withValues(alpha: 0.08),
          foregroundColor: colors.info,
          side: BorderSide(
            color: colors.info.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.file_upload),
        label: const Text('Import games'),
        onPressed: onSelectMyGames,
      ),
    );
  }

  Widget _buildMistakesCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.danger,
      icon: Icons.history_edu_outlined,
      title: 'My mistakes',
      description:
          'Review and drill blunders and mistakes from your played games. '
          'Remembers when you made a mistake and returns the position for spaced repetition.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.danger.withValues(alpha: 0.22),
          foregroundColor: colors.danger,
          side: BorderSide(
            color: colors.danger.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Drill mistakes'),
        onPressed: onSelectMistakesDrill,
      ),
    );
  }

  Widget _buildRepertoireCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.brand,
      icon: Icons.menu_book_outlined,
      title: 'Opening repertoire',
      description:
          'Not a set of puzzles, but something you build: choose what you would '
          'play, position by position, and get an immediate evaluation of the '
          'choice. The repertoire stays saved and grows over time.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand.withValues(alpha: 0.08),
          foregroundColor: colors.brand,
          side: BorderSide(
            color: colors.brand.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Open repertoire'),
        onPressed: onSelectRepertoire,
      ),
    );
  }

  Widget _buildTacticsCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.info,
      icon: Icons.auto_graph,
      title: 'Tactics tailored to you',
      description:
          'Puzzles from the Lichess database, matched to your rating and the theme '
          'you struggle with most. Rating is tracked per motif separately.',
      progressLine: _progressLine(PuzzleSource.lichess),
      retryButton: _retryButton(PuzzleSource.lichess),
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.info.withValues(alpha: 0.08),
          foregroundColor: colors.info,
          side: BorderSide(
            color: colors.info.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start training'),
        onPressed: onSelectTactics,
      ),
    );
  }

  Widget _buildMatePuzzlesCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.accent,
      icon: Icons.sports_esports_outlined,
      title: 'Puzzles: Mate in 1, 2 or 3 moves',
      description:
          'Solve forced checkmate sequences in the requested number of moves.',
      progressLine: _progressLine(PuzzleSource.matePuzzle),
      retryButton: _retryButton(PuzzleSource.matePuzzle),
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.looks_one_outlined),
            label: const Text('Mate in 1'),
            onPressed: () => onSelectMatePuzzle('1'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.looks_two_outlined),
            label: const Text('Mate in 2'),
            onPressed: () => onSelectMatePuzzle('2'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.looks_3_outlined),
            label: const Text('Mate in 3'),
            onPressed: () => onSelectMatePuzzle('3'),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterEndgamesCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.warning,
      icon: Icons.flag_outlined,
      title: 'Endgames from master games',
      description: 'Positions taken from grandmaster games. For endgames '
          'with few pieces the outcome is exact, not evaluated — any '
          'move that preserves the result is accepted, not just one. Before '
          'starting, choose the endgame type and difficulty level.',
      progressLine: _progressLine(PuzzleSource.endgame, label: 'Endgames'),
      secondaryLine:
          _progressLine(PuzzleSource.blunderGame, label: 'Game blunders'),
      retryButton: _retryButton(PuzzleSource.endgame),
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Win'),
            onPressed: onSelectEndgameWin,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Hold a draw'),
            onPressed: onSelectEndgameDraw,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.history_edu_outlined),
            label: const Text('Game blunders'),
            onPressed: onSelectBlunderGames,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicMateCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.accentAlt,
      icon: Icons.workspace_premium_outlined,
      title: 'Practice basic checkmates',
      description:
          'Checkmate the opponent in classic mating positions against Stockfish.',
      progressLine: _progressLine(PuzzleSource.basicMate),
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ElevatedButton.icon(
            icon: const Icon(
              Icons.sentiment_satisfied_alt,
              size: 20,
            ),
            label: const Text('Easy'),
            onPressed: () => onSelectBasicMate('easy'),
          ),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.sentiment_neutral,
              size: 20,
            ),
            label: const Text('Medium'),
            onPressed: () => onSelectBasicMate('medium'),
          ),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.sentiment_very_dissatisfied,
              size: 20,
            ),
            label: const Text('Hard'),
            onPressed: () => onSelectBasicMate('hard'),
          ),
        ],
      ),
    );
  }

  Widget _buildWinningPositionsCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.success,
      icon: Icons.military_tech_outlined,
      title: 'Find the winning path',
      description:
          'Play winning positions out against Stockfish with optional Blunder Alert.',
      progressLine: _progressLine(PuzzleSource.winningPosition),
      retryButton: _retryButton(PuzzleSource.winningPosition),
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.success.withValues(alpha: 0.22),
          foregroundColor: colors.success,
          side: BorderSide(
            color: colors.success.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start practicing winning positions'),
        onPressed: onSelectWinningPosition,
      ),
    );
  }

  /// One phase: its label, then its cards one under another.
  Widget _phase(BuildContext context, String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, title),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          cards[i],
        ],
      ],
    );
  }

  /// Columns laid side by side, each as tall as its own cards.
  Widget _side(List<Widget> columns) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: AdaptiveCardGrid.spacing),
          Expanded(child: columns[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const phaseGap = SizedBox(height: AppSpacing.xxl);

    return Center(
      child: ConstrainedBox(
        // The cap is on the cards, so the tab's own padding is added to it.
        constraints: BoxConstraints(
          maxWidth: maxCardsWidth + AppSpacing.screenPadding.horizontal,
        ),
        child: SingleChildScrollView(
          primary: false,
          padding: AppSpacing.screenPadding,
          // No header card: the tab's name is already at the top, and the
          // card that said „Chess trainer and drills" took height and said
          // little — removed on the owner's word, 21.9.2026.
          //
          // One column per phase of the game where three fit, today's split
          // where two do, today's order on a phone. The count is taken from
          // the width these cards are handed, never from the window
          // (`docs/PLAN-POCETNI-TABOVI.md` §3), and can never pass
          // [maxColumns] because the box above stops at their width.
          child: LayoutBuilder(builder: (context, constraints) {
            final opening = _phase(context, 'Opening', [
              _buildRepertoireCard(colors),
              _buildMyGamesCard(colors),
              _buildMistakesCard(colors),
            ]);
            final tactics = _phase(context, 'Tactics', [
              _buildTacticsCard(colors),
              _buildMatePuzzlesCard(colors),
            ]);
            final endgame = _phase(context, 'Endgame and technique', [
              _buildMasterEndgamesCard(colors),
              _buildBasicMateCard(colors),
              _buildWinningPositionsCard(colors),
            ]);

            switch (AdaptiveCardGrid.columnsFor(constraints.maxWidth)) {
              case 1:
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [opening, phaseGap, tactics, phaseGap, endgame],
                );
              case 2:
                return _side([
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [opening, phaseGap, tactics],
                  ),
                  endgame,
                ]);
              default:
                return _side([opening, tactics, endgame]);
            }
          }),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String description;
  final Widget action;

  /// „Solved N" / „Solved N · M to retry" for the card's own source, or null
  /// when nothing was read or nothing was seen.
  final String? progressLine;

  /// A second progress line for a source folded into this card without its
  /// own card (blunder games, inside the endgames card).
  final String? secondaryLine;

  /// „Retry failed (M)", joined into a `Wrap` with [action] so the row still
  /// fits a 360 dp phone.
  final Widget? retryButton;

  const _CategoryCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    this.progressLine,
    this.secondaryLine,
    this.retryButton,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.roundedLg,
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: AppRadii.roundedSm,
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppText.title.copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            if (progressLine != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                progressLine!,
                style: AppText.bodyBold.copyWith(color: accentColor),
              ),
            ],
            if (secondaryLine != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                secondaryLine!,
                style: AppText.body.copyWith(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (retryButton != null)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [action, retryButton!],
              )
            else
              action,
          ],
        ),
      ),
    );
  }
}
