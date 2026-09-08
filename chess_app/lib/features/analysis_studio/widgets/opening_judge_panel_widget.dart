import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// "1 game", "2 games" — English singular and plural.
String gamesLabel(int count) => count == 1 ? '1 game' : '$count games';

/// Centipawns as a reader sees them: 0.35 rather than 35.
String pawns(int centipawns) => (centipawns.abs() / 100).toStringAsFixed(2);

/// The three verdicts and the one non-verdict, each with its own colour, icon
/// and heading.
///
/// `unknown` looks unlike the other three on purpose. It is not a milder
/// mistake — it is the judge saying it could not judge, and a child must be
/// able to tell those apart at a glance.
({IconData icon, String title}) _face(OpeningVerdict verdict) {
  switch (verdict) {
    case OpeningVerdict.theory:
      return (icon: Icons.menu_book, title: 'Mainline theory');
    case OpeningVerdict.playable:
      return (
        icon: Icons.thumb_up_alt_outlined,
        title: 'Practical alternative'
      );
    case OpeningVerdict.mistake:
      return (icon: Icons.warning_amber_rounded, title: 'Dubious move');
    case OpeningVerdict.unknown:
      return (icon: Icons.help_outline, title: 'No verdict');
  }
}

Color _colorOf(BuildContext context, OpeningVerdict verdict) {
  switch (verdict) {
    case OpeningVerdict.theory:
      return context.colors.success;
    case OpeningVerdict.playable:
      return context.colors.info;
    case OpeningVerdict.mistake:
      return context.colors.danger;
    case OpeningVerdict.unknown:
      return context.colors.textMuted;
  }
}

/// One move, judged: theory, playable, or a mistake — and, when it is a
/// mistake, what to play instead and how the move gets punished.
///
/// Asked for by hand rather than on every click, the same way the endgame
/// trainer asks the tables. Two reasons, and the second is the one that
/// decides: it spends the reader's own Lichess allowance, and a panel that
/// spends it silently while somebody clicks through a game is a panel that
/// empties an allowance nobody agreed to give.
class OpeningJudgePanelWidget extends StatelessWidget {
  const OpeningJudgePanelWidget({
    super.key,
    required this.hasToken,
    required this.moveSan,
    required this.isLoading,
    required this.judgement,
    this.reason,
    this.onJudge,
    this.onOpenSettings,
  });

  /// Whether the reader has a Lichess token of their own. Without it the panel
  /// offers nothing to press: judging is not on the shared allowance.
  final bool hasToken;

  /// The move that led to the position on the board, or null at the start of
  /// the game, where there is nothing to judge.
  final String? moveSan;

  final bool isLoading;

  /// Null until the reader asks. Belongs to [moveSan]; the screen keeps the two
  /// together rather than letting a verdict outlive the move it is about.
  final OpeningJudgement? judgement;

  /// Why there is no verdict, when there is none.
  final String? reason;

  final VoidCallback? onJudge;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.55),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Move Verdict',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.colors.accent),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ..._body(context),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (!hasToken) return _noToken(context);
    if (moveSan == null) {
      return [
        Text(
          'Play a move on the board to judge it.',
          style: AppText.caption.copyWith(color: context.colors.textMuted),
        ),
      ];
    }
    final verdict = judgement;
    if (verdict == null) {
      return [
        if (reason != null) ...[
          _reasonLine(context, reason!),
          const SizedBox(height: 6),
        ],
        // Wrap and not Row: the label carries the move, and a 360 dp phone runs
        // out of width before a long one does — an overflow a release build
        // clips without a word.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: isLoading ? null : onJudge,
              icon: const Icon(Icons.gavel, size: 16),
              label: Text('Judge $moveSan'),
            ),
            Text(
              'Uses your Lichess token.',
              style: AppText.micro.copyWith(color: context.colors.textMuted),
            ),
          ],
        ),
      ];
    }
    return _verdict(context, verdict);
  }

  List<Widget> _noToken(BuildContext context) {
    return [
      Text(
        'Move judging requires your own Lichess token — it queries Lichess up to four times '
        'per move, so it does not use the shared server token.',
        style: AppText.caption.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onOpenSettings != null)
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Settings'),
            ),
          Text(
            'The opening database works without it.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    ];
  }

  Widget _reasonLine(BuildContext context, String reason) {
    // Each one says what actually happened. "We could not ask" and "the move is
    // fine" must never read the same.
    const messages = {
      'unauthorized': 'Lichess rejected your token. Check it in Settings.',
      'rate-limited': 'Lichess request quota exceeded. '
          'Try again in a few minutes.',
      'network': 'Server unavailable, move was not judged.',
      'no-token': 'No Lichess token found.',
      'guest': 'Sign in required to judge moves.',
      'bad-request': 'Cannot judge this move in this position.',
    };
    return Text(
      messages[reason] ?? 'Move not judged ($reason).',
      style: AppText.caption.copyWith(color: context.colors.warning),
    );
  }

  List<Widget> _verdict(BuildContext context, OpeningJudgement j) {
    final face = _face(j.verdict);
    final color = _colorOf(context, j.verdict);

    return [
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(face.icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text('${j.san} · ${face.title}',
                    style: AppText.bodyBold.copyWith(color: color)),
              ],
            ),
          ),
          if (onJudge != null)
            TextButton.icon(
              onPressed: isLoading ? null : onJudge,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry'),
            ),
        ],
      ),
      const SizedBox(height: 6),
      for (final line in _sentences(j)) ...[
        Text(line,
            style: AppText.caption.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.xxs),
      ],
    ];
  }

  /// What the verdict is based on, said plainly and in this order: the books
  /// first, then what it cost, then — only where it teaches something — what to
  /// play instead and how the move is punished.
  List<String> _sentences(OpeningJudgement j) {
    final lines = <String>[];

    switch (j.verdict) {
      case OpeningVerdict.theory:
        lines.add('Played by masters: ${gamesLabel(j.mastersGames)}.');
        break;
      case OpeningVerdict.unknown:
        lines.add(
            'Lichess has no evaluation for this position, so the move is not judged — '
            'this is not the same as a bad move.');
        break;
      case OpeningVerdict.playable:
      case OpeningVerdict.mistake:
        final loss = j.lossCp;
        final mate = j.mateAfter;
        if (mate != null && mate < 0) {
          lines.add('Mate in ${mate.abs()} against you after this.');
        } else if (loss != null && loss > 0) {
          lines.add('Costs ${pawns(loss)} pawns.');
        } else {
          lines.add('Loses nothing compared to the best move.');
        }
        if (j.verdict == OpeningVerdict.mistake &&
            (j.afterCp ?? 0) < 0 &&
            (loss ?? 0) <= 0) {
          // The other way a move fails the test: it gives nothing away because
          // there is nothing left to give.
          lines.add('The position was already worse before it.');
        }
        if (j.bandGames > 0) {
          final band = j.minRating == null
              ? 'in practice'
              : 'by ${j.minRating}+ players';
          lines.add('Played $band: ${gamesLabel(j.bandGames)}.');
        }
        break;
    }

    if (j.better != null) lines.add('Better was ${j.better}.');
    if (j.punishment.isNotEmpty) {
      lines.add('Punished with ${j.punishment.join(' ')}.');
    }
    return lines;
  }
}
