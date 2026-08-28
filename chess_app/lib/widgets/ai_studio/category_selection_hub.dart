import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class CategorySelectionHubWidget extends StatelessWidget {
  final Function(String depth) onSelectMatePuzzle;
  final Function(String presetDifficulty) onSelectBasicMate;
  final VoidCallback onSelectWinningPosition;
  final VoidCallback onSelectTactics;
  final VoidCallback onSelectEndgameWin;
  final VoidCallback onSelectEndgameDraw;
  final VoidCallback onSelectBlunderGames;
  final VoidCallback onSelectRepertoire;

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          primary: false,
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero header card
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

              // SECTION: Otvaranje.
              //
              // The repertoire used to be a fourth button on the endgame card,
              // where it was the one thing in the hub that is neither an
              // endgame nor a set of exercises: it is a thing the student
              // builds and comes back to. It stands alone, and it stands first,
              // because it is the phase a game starts in.
              _section(context, 'Otvaranje'),
              _CategoryCard(
                accentColor: colors.brand,
                icon: Icons.menu_book_outlined,
                title: 'Repertoar otvaranja',
                description:
                    'Nije skup zadataka nego nešto što gradite: birate šta biste '
                    'odigrali, poziciju po poziciju, i odmah dobijate procenu '
                    'izbora. Repertoar ostaje sačuvan i dopunjuje se vremenom.',
                action: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Otvori repertoar'),
                  onPressed: onSelectRepertoire,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // SECTION: Taktika.
              //
              // Both cards below ask the same thing of the solver - one
              // position, find the move - and differ only in where the position
              // comes from and whether the answer ends in mate.
              _section(context, 'Taktika'),

              // Adaptive tactics first: it is the mode that adjusts to the
              // solver, while the one under it is a fixed set.
              _CategoryCard(
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
              ),

              const SizedBox(height: AppSpacing.lg),

              // Zagonetke: Mat u 1, 2 ili 3 poteza.
              _CategoryCard(
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
              ),

              const SizedBox(height: AppSpacing.xxl),

              // SECTION: Završnica i tehnika.
              //
              // Everything here is a position played out to the end rather than
              // a single move found: master endings, the classical mates, and a
              // won game that still has to be converted.
              _section(context, 'Završnica i tehnika'),

              // Two buttons for the master endings, not one: converting a won
              // position and holding a drawn one are different skills, and a
              // child asked to "find the move" without being told which of the
              // two it is has been asked the wrong question.
              _CategoryCard(
                accentColor: colors.warning,
                icon: Icons.flag_outlined,
                title: 'Završnice iz majstorskih partija',
                description:
                    'Pozicije izdvojene iz partija velemajstora. Za završnice '
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
              ),

              const SizedBox(height: AppSpacing.lg),

              // Vežbajte osnovno matiranje.
              _CategoryCard(
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
              ),

              const SizedBox(height: AppSpacing.lg),

              // Pronađite dobitni put.
              _CategoryCard(
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
              ),
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
