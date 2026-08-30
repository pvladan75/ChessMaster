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
      title: 'Moje partije',
      description:
          'Uvezite PGN izvoz svojih partija i aplikacija pokazuje gde vam '
          'otvaranje stalno curi: pozicije do kojih stižete često, potez koji '
          'u njima igrate iznova i koliko vam je bodova doneo.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.info.withValues(alpha: 0.22),
          foregroundColor: colors.info,
          side: BorderSide(
            color: colors.info.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.file_upload),
        label: const Text('Uvezi partije'),
        onPressed: onSelectMyGames,
      ),
    );
  }

  Widget _buildMistakesCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.danger,
      icon: Icons.history_edu_outlined,
      title: 'Moje greške',
      description:
          'Pregledajte i uvežbajte previde i greške iz svojih odigranih partija. '
          'Pamti kad ste pogrešili i vraća poziciju na ponavljanje.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.danger.withValues(alpha: 0.22),
          foregroundColor: colors.danger,
          side: BorderSide(
            color: colors.danger.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Vežbaj greške'),
        onPressed: onSelectMistakesDrill,
      ),
    );
  }

  Widget _buildRepertoireCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.brand,
      icon: Icons.menu_book_outlined,
      title: 'Repertoar otvaranja',
      description:
          'Nije skup zadataka nego nešto što gradite: birate šta biste '
          'odigrali, poziciju po poziciju, i odmah dobijate procenu '
          'izbora. Repertoar ostaje sačuvan i dopunjuje se vremenom.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand.withValues(alpha: 0.22),
          foregroundColor: colors.brand,
          side: BorderSide(
            color: colors.brand.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Otvori repertoar'),
        onPressed: onSelectRepertoire,
      ),
    );
  }

  Widget _buildTacticsCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.info,
      icon: Icons.auto_graph,
      title: 'Taktika po vašoj meri',
      description:
          'Zagonetke iz Lichess baze, birane prema vašem rejtingu i temi '
          'koju najslabije rešavate. Rejting se prati po svakom motivu posebno.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.info.withValues(alpha: 0.22),
          foregroundColor: colors.info,
          side: BorderSide(
            color: colors.info.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Započni trening'),
        onPressed: onSelectTactics,
      ),
    );
  }

  Widget _buildMatePuzzlesCard(AppColorTokens colors) {
    return _CategoryCard(
      accentColor: colors.accent,
      icon: Icons.sports_esports_outlined,
      title: 'Zagonetke: Mat u 1, 2 ili 3 poteza',
      description:
          'Rešavajte forsiranu matnu sekvencu u traženom broju poteza.',
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.looks_one_outlined),
            label: const Text('Mat u 1'),
            onPressed: () => onSelectMatePuzzle('1'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.looks_two_outlined),
            label: const Text('Mat u 2'),
            onPressed: () => onSelectMatePuzzle('2'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.looks_3_outlined),
            label: const Text('Mat u 3'),
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
      title: 'Završnice iz majstorskih partija',
      description: 'Pozicije izdvojene iz partija velemajstora. Za završnice '
          'sa malo figura ishod je tačan, ne procenjen — priznaje se '
          'svaki potez koji drži rezultat, a ne samo jedan. Pre '
          'početka birate koje završnice i koji nivo.',
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Dobij'),
            onPressed: onSelectEndgameWin,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Održi remi'),
            onPressed: onSelectEndgameDraw,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.history_edu_outlined),
            label: const Text('Greške iz partija'),
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
      title: 'Vežbajte osnovno matiranje',
      description:
          'Matirajte protivnika u klasičnim matnim pozicijama protiv Stockfish-a.',
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ElevatedButton.icon(
            icon: const Icon(
              Icons.sentiment_satisfied_alt,
              size: 20,
            ),
            label: const Text('Lako'),
            onPressed: () => onSelectBasicMate('easy'),
          ),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.sentiment_neutral,
              size: 20,
            ),
            label: const Text('Srednje'),
            onPressed: () => onSelectBasicMate('medium'),
          ),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.sentiment_very_dissatisfied,
              size: 20,
            ),
            label: const Text('Teško'),
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
      title: 'Pronađite dobitni put',
      description:
          'Igrajte dobitne pozicije do kraja protiv Stockfish-a uz opcioni Blunder Alert.',
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.success.withValues(alpha: 0.22),
          foregroundColor: colors.success,
          side: BorderSide(
            color: colors.success.withValues(alpha: 0.45),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Započni vežbanje dobitnih pozicija'),
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
                            'Šahovski trener i vežbe',
                            style: AppText.headline.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Vežbe su poređane po fazi partije: otvaranje, taktika, pa završnica i tehnika.',
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
                          _section(context, 'Otvaranje'),
                          _buildRepertoireCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMyGamesCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMistakesCard(colors),
                          const SizedBox(height: AppSpacing.xxl),
                          _section(context, 'Taktika'),
                          _buildTacticsCard(colors),
                          const SizedBox(height: AppSpacing.lg),
                          _buildMatePuzzlesCard(colors),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    // Column 2: Završnica i tehnika
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(context, 'Završnica i tehnika'),
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
                _section(context, 'Otvaranje'),
                _buildRepertoireCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildMyGamesCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildMistakesCard(colors),
                const SizedBox(height: AppSpacing.xxl),
                _section(context, 'Taktika'),
                _buildTacticsCard(colors),
                const SizedBox(height: AppSpacing.lg),
                _buildMatePuzzlesCard(colors),
                const SizedBox(height: AppSpacing.xxl),
                _section(context, 'Završnica i tehnika'),
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
