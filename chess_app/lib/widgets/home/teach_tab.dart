import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

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
    this.homeworkCard,
    required this.onOpenPreparation,
    required this.onStartSession,
    required this.onOpenLibrary,
    required this.onOpenScanner,
    required this.studentsSection,
  });

  /// The tutorial card, where the studio exists; null draws nothing (the card
  /// decides for itself and draws nothing off Windows until phase 6c).
  final Widget? tutorialCard;

  /// The homework card, beside the tutorial one — phase 3b of
  /// `docs/PLAN-DOMACI-ZADATAK.md`. Null draws nothing, the same rule as
  /// [tutorialCard].
  final Widget? homeworkCard;

  final VoidCallback onOpenPreparation;

  /// Starts a session. While the future it returns is pending the button is
  /// disabled and a second tap does nothing — two taps a few milliseconds
  /// apart made two sessions (reported live on 22.9.2026). The server makes
  /// that impossible too (`roomLifecycle.startSession`); this keeps the second
  /// room screen from being pushed over the first.
  final Future<void> Function() onStartSession;
  final VoidCallback onOpenLibrary;

  /// Opens the book scanner. Required, not optional: until 22.9.2026 its only
  /// door was the Analysis bar, behind ⋮ on a phone, and an optional door is
  /// the one that gets left out.
  final VoidCallback onOpenScanner;

  /// Requests, the student and trainer lists, groups — the people card.
  final Widget studentsSection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
    final scanner = _ActionCard(
      key: const Key('teach-scan-card'),
      icon: Icons.document_scanner_outlined,
      color: colors.brand,
      title: 'Scan a book',
      line: 'Diagrams from a PDF become positions and exercises.',
      button: 'Scan',
      onPressed: onOpenScanner,
    );
    final library = Card(
      key: const Key('teach-library-card'),
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
                Expanded(
                  child: Text(
                    'Library',
                    style: AppText.headline.copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Everything you keep — tutorials, positions, analyses, recordings.',
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenLibrary,
                icon: const Icon(Icons.collections_bookmark_outlined, size: 18),
                label: const Text('Open library'),
              ),
            ),
          ],
        ),
      ),
    );

    // Sections stack, their contents flow — `docs/PLAN-POCETNI-TABOVI.md`
    // §3. No cap and no reading of the window: each flow takes its column
    // count from the width it is handed, so a phone gets one card per line
    // and a wide window puts peers side by side. The first flow is what a
    // trainer makes and keeps, the second is live work; the Library sits
    // with the things it keeps rather than after the live cards, which is
    // the one change of order on a phone.
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveCardRows(
            key: const Key('teach-make-flow'),
            children: [
              if (tutorialCard != null) tutorialCard!,
              if (homeworkCard != null) homeworkCard!,
              library,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AdaptiveCardRows(
            key: const Key('teach-live-flow'),
            children: [preparation, session, scanner],
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
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    super.key,
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

  /// When it returns a future, the button stays disabled until it completes.
  final FutureOr<void> Function() onPressed;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  /// Set in the tap itself, not by a rebuild: two taps inside one frame both
  /// reach the handler before the disabled button is drawn.
  bool _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    final result = widget.onPressed();
    if (result is! Future) return;
    setState(() => _busy = true);
    try {
      await result;
    } catch (error, stack) {
      // Reported, not swallowed; and the button comes back either way, or one
      // failure would leave it disabled for good.
      FlutterError.reportError(FlutterErrorDetails(
          exception: error, stack: stack, library: 'teach tab'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = widget.color;
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
                Icon(widget.icon, color: color, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(widget.title,
                      style: AppText.title.copyWith(color: color)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.line,
                style: AppText.caption.copyWith(color: colors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _busy ? null : _press,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
