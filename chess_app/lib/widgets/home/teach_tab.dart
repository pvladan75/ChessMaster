import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';

/// The Teach tab — phase 5 of `docs/PLAN-REORGANIZACIJA.md`, §6.2.
///
/// Everything a trainer works with, in the order they reach for it: writing
/// (the tutorial card), preparing (the board alone), running (a session),
/// the students, and the library of everything kept. The pieces are handed
/// in as widgets and callbacks; this tab arranges them and owns none of the
/// state, so the shell keeps its one set of lists and controllers.
class TeachTab extends StatelessWidget {
  const TeachTab({
    super.key,
    this.tutorialCard,
    required this.onOpenPreparation,
    required this.onStartSession,
    required this.onOpenLibrary,
    required this.studentsSection,
  });

  /// The tutorial card, where the studio exists; null draws nothing (the card
  /// decides for itself and draws nothing off Windows until phase 6c).
  final Widget? tutorialCard;

  final VoidCallback onOpenPreparation;
  final VoidCallback onStartSession;
  final VoidCallback onOpenLibrary;

  /// Requests, the student and trainer lists, groups — the people card.
  final Widget studentsSection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final wide = Breakpoints.isWide(context);

    final preparation = _ActionCard(
      icon: Icons.dashboard,
      color: colors.brand,
      title: 'Preparation',
      line: 'Your board, your library, no student.',
      button: 'Open',
      onPressed: onOpenPreparation,
    );
    final session = _ActionCard(
      icon: Icons.video_call,
      color: colors.accent,
      title: 'New session',
      line: 'Open a room and invite your student.',
      button: 'Start',
      onPressed: onStartSession,
    );

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tutorialCard != null) tutorialCard!,
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: preparation),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: session),
                  ],
                )
              else ...[
                preparation,
                const SizedBox(height: AppSpacing.md),
                session,
              ],
              const SizedBox(height: AppSpacing.md),
              Card(
                shape: AppRadii.cardShape,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.collections_bookmark_outlined,
                              color: colors.accent, size: 28),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Library',
                            style: AppText.headline
                                .copyWith(color: colors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Everything you keep — tutorials, positions, analyses, recordings.',
                        style:
                            AppText.body.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onOpenLibrary,
                          icon: const Icon(Icons.collections_bookmark_outlined,
                              size: 18),
                          label: const Text('Open library'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(
                    left: AppSpacing.xs, bottom: AppSpacing.sm),
                child: Text(
                  'Students',
                  style: AppText.headline.copyWith(color: colors.textPrimary),
                ),
              ),
              studentsSection,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.line,
    required this.button,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String line;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.roundedLg,
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child:
                      Text(title, style: AppText.title.copyWith(color: color)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(line,
                style: AppText.caption.copyWith(color: colors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
