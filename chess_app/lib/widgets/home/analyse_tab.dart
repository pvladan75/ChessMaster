import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';

/// The Analyse tab — phase 5 of `docs/PLAN-REORGANIZACIJA.md`, §6.3: the
/// board *is* the tab.
///
/// The Analysis screen is mounted as the tab's body, with its own bar (the
/// tools, „Use in a tutorial", the board view) — the shell draws no second
/// header over it, and since 18.9.2026 nothing else either.
///
/// **There was a row above the board** carrying „My games" and „Scan a book",
/// and on a phone it was the third stacked header before any chess appeared:
/// the shell's title, that row, then the Analysis bar. Reported live against
/// TODO-provera 180.2 and 180.5 — „u landscape orjentaciji veliki deo površine
/// iznad table je pokriven nepotrebnim elementima", and in portrait the panels
/// under the board could not be reached at all. The row is gone. „My games"
/// kept its card on Practise; „Scan a book" had no other door anywhere, so it
/// moved into the Analysis toolbar rather than out of the app.
///
/// Built only once the tab is first selected: the screen starts three services
/// in `initState`, and a player who never opens Analyse must not pay for them
/// on every launch. The shell keeps the widget in its stack afterwards, so the
/// tree and the draft survive switching away. (The engine no longer starts
/// itself here — see `_showEvaluation` on the screen.)
class AnalyseTab extends StatelessWidget {
  const AnalyseTab({
    super.key,
    required this.session,
    required this.onOpenScanner,
  });

  final UserSession session;
  final VoidCallback onOpenScanner;

  @override
  Widget build(BuildContext context) {
    return AnalysisStudioScreen(
      userSession: session,
      onOpenScanner: onOpenScanner,
    );
  }
}
