import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';

/// The Analyse tab — phase 5 of `docs/PLAN-REORGANIZACIJA.md`, §6.3: the
/// board *is* the tab.
///
/// The Analysis screen is mounted as the tab's body, with its own bar — the
/// shell draws no second header over it, and since 18.9.2026 nothing else
/// either.
///
/// **There was a row above the board** carrying „My games" and the book
/// scanner, and on a phone it was the third stacked header before any chess
/// appeared: the shell's title, that row, then the Analysis bar. Reported live
/// against TODO-provera 180.2 and 180.5 — „u landscape orjentaciji veliki deo
/// površine iznad table je pokriven nepotrebnim elementima", and in portrait
/// the panels under the board could not be reached at all. The row is gone.
/// „My games" kept its card on Practise. The scanner had no other door then,
/// so it moved into the Analysis bar; it has had a card on Teach since
/// 22.9.2026, and on 30.9.2026 it left this tab altogether
/// (`docs/PLAN-ANALIZA-TRAKA.md`).
///
/// Built only once the tab is first selected: the screen starts three services
/// in `initState`, and a player who never opens Analyse must not pay for them
/// on every launch. The shell keeps the widget in its stack afterwards, so the
/// tree and the draft survive switching away. (The engine no longer starts
/// itself here — see `_showEvaluation` on the screen.)
class AnalyseTab extends StatelessWidget {
  const AnalyseTab({super.key, required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    return AnalysisStudioScreen(userSession: session);
  }
}
