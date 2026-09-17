import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_spacing.dart';

/// The Analyse tab — phase 5 of `docs/PLAN-REORGANIZACIJA.md`, §6.3: the
/// board *is* the tab.
///
/// The Analysis screen is mounted as the tab's body, with its own bar (the
/// tools, „Use in a tutorial", the board view) — the shell draws no second
/// header over it. Above the board, one row for what sits beside analysis
/// rather than inside it: the player's own games and the book scanner. Saved
/// analyses are already in the bar.
///
/// Built only once the tab is first selected: the screen starts an engine and
/// three services in `initState`, and a player who never opens Analyse must
/// not pay for them on every launch. The shell keeps the widget in its stack
/// afterwards, so the tree, the engine and the draft survive switching away.
class AnalyseTab extends StatelessWidget {
  const AnalyseTab({
    super.key,
    required this.session,
    required this.onOpenMyGames,
    required this.onOpenScanner,
  });

  final UserSession session;
  final VoidCallback onOpenMyGames;
  final VoidCallback onOpenScanner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: onOpenMyGames,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('My games'),
              ),
              TextButton.icon(
                onPressed: onOpenScanner,
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: const Text('Scan a book'),
              ),
            ],
          ),
        ),
        Expanded(child: AnalysisStudioScreen(userSession: session)),
      ],
    );
  }
}
