/// The "Homework" door on the Teach tab, beside the Tutorials card —
/// `docs/PLAN-DOMACI-ZADATAK.md` §5, phase 3b, §9 item 5 ("a card on the
/// Teach tab and a filter chip in the Library"). Both doors open the same
/// list, [HomeworkListScreen]; only how each is reached differs.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

import '../screens/homework_list_screen.dart';
import '../services/homework_api_service.dart';

class HomeworkLibraryCard extends StatelessWidget {
  const HomeworkLibraryCard({super.key, required this.session, this.api});

  final UserSession session;

  /// The seam a test reaches this card's list through. Defaulted to a real
  /// service against this session's token, so nothing but a test passes it.
  final HomeworkApiService? api;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // No gap of its own: the Teach tab's flow spaces its cards, and a gap
    // inside one card of a row would end it short of its neighbours.
    return Card(
      key: const Key('homework-teach-card'),
      shape: AppRadii.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: colors.accent, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Homework',
                    style: AppText.headline.copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Write a homework once — a tutorial, positions, a puzzle set, '
              'a position to play out — and send it to a student.',
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              key: const Key('homework-teach-open'),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('My homeworks'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                padding: AppSpacing.buttonPadding,
              ),
              onPressed: () => _open(context),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HomeworkListScreen(
        api: api ?? HomeworkApiService(authToken: session.token),
      ),
    ));
  }
}
