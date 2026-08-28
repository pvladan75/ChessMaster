import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The "Biblioteka" tab: shortcuts into the Studio (empty board), the Analysis
/// board, and reading positions out of the trainer's own book. Stateless — all
/// three actions just navigate.
class HomeBibliotekaTab extends StatelessWidget {
  final VoidCallback onOpenStudio;
  final VoidCallback onOpenAnalysis;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenSavedPositions;

  const HomeBibliotekaTab({
    super.key,
    required this.onOpenStudio,
    required this.onOpenAnalysis,
    required this.onOpenScanner,
    required this.onOpenSavedPositions,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: AppRadii.cardShape,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.library_books,
                              color: context.colors.accent, size: 28),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Biblioteka Pozicija i Lekcija',
                            style: AppText.headline
                                .copyWith(color: context.colors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Upravljajte vašim sačuvanim pozicijama, PGN fajlovima i kursevima.',
                        style: AppText.body
                            .copyWith(color: context.colors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.dashboard_customize),
                        label: const Text(
                            'Otvori Šahovski Studio sa praznom tablom'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          padding: AppSpacing.buttonPadding,
                        ),
                        onPressed: onOpenStudio,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                shape: AppRadii.cardShape,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.biotech,
                              color: context.colors.accent, size: 28),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Tabla za Analizu 🔬',
                            style: AppText.headline
                                .copyWith(color: context.colors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Slobodna šahovska tabla za duboku analizu, unos varijacija za obe strane, rad sa PGN/FEN pozicijama i beleženje komentara i NAG simbola.',
                        style: AppText.body
                            .copyWith(color: context.colors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.biotech),
                          label: const Text('Otvori Tablu za Analizu'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            padding: AppSpacing.buttonPadding,
                          ),
                          onPressed: onOpenAnalysis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                shape: AppRadii.cardShape,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.document_scanner_outlined,
                              color: context.colors.accent, size: 28),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Pozicije iz vaše knjige',
                            style: AppText.headline
                                .copyWith(color: context.colors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Učitajte PDF knjige i izvucite dijagrame kao pozicije za zadatke. '
                        'Svaku poziciju potvrđujete sami, a dokument se ne čuva na serveru.',
                        style: AppText.body
                            .copyWith(color: context.colors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Skeniraj pozicije'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            padding: AppSpacing.buttonPadding,
                          ),
                          onPressed: onOpenScanner,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.grid_view_outlined),
                          label: const Text('Moje sačuvane pozicije'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            padding: AppSpacing.buttonPadding,
                          ),
                          onPressed: onOpenSavedPositions,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
