import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';

class CategorySelectionHubWidget extends StatelessWidget {
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
  });

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isWide = Breakpoints.isWide(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 1080 : 640),
        child: SingleChildScrollView(
          primary: false,
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero header card (spans full width above columns)
              Container(
                padding: AppSpacing.cardPaddingComfortable,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.brand.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.psychology_outlined,
                        color: colors.brand,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chess trainer and drills',
                            style: AppText.headline.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Drills are arranged by game phase: opening, tactics, then endgame and technique.',
                            style: AppText.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              if (isWide) ...[
                // Two-column layout above Breakpoints.wide (840px)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Otvaranje & Taktika
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(context, 'Opening'),
                          _buildRepertoireCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMyGamesCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMistakesCard(colors),
                          const SizedBox(height: AppSpacing.xxl),
                          _section(context, 'Tactics'),
                          _buildTacticsCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMatePuzzlesCard(colors),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    // Column 2: Endgame and technique
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(context, 'Endgame and technique'),
                          _buildMasterEndgamesCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildBasicMateCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildWinningPositionsCard(colors),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Single-column layout on mobile / narrow screens (< 840px)
                _section(context, 'Opening'),
                _buildRepertoireCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildMyGamesCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildMistakesCard(colors),
                const SizedBox(height: AppSpacing.xxl),
                _section(context, 'Tactics'),
                _buildTacticsCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildMatePuzzlesCard(colors),
                const SizedBox(height: AppSpacing.xxl),
                _section(context, 'Endgame and technique'),
                _buildMasterEndgamesCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildBasicMateCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildWinningPositionsCard(colors),
              ],
            ],
          ),
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

  const _CategoryCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
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
            const SizedBox(height: AppSpacing.lg),
            action,
          ],
        ),
      ),
    );
  }
}
