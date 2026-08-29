import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// „5 partija", „2 partije", „1 partija" — Serbian counts three ways, and a
/// panel that says „2 partija" is a panel a child stops reading.
String gamesLabel(int count) {
  final lastTwo = count % 100;
  final last = count % 10;
  if (last == 1 && lastTwo != 11) return '$count partija';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$count partije';
  }
  return '$count partija';
}

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
      return (icon: Icons.menu_book, title: 'Glavna teorija');
    case OpeningVerdict.playable:
      return (
        icon: Icons.thumb_up_alt_outlined,
        title: 'Praktična alternativa'
      );
    case OpeningVerdict.mistake:
      return (icon: Icons.warning_amber_rounded, title: 'Sumnjiv potez');
    case OpeningVerdict.unknown:
      return (icon: Icons.help_outline, title: 'Nije presuđeno');
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
                child: Text('Sud o potezu',
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
          'Odigrajte potez na tabli pa ga presudite.',
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
              label: Text('Presudi $moveSan'),
            ),
            Text(
              'Troši vaš Lichess token.',
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
        'Suđenje poteza traži vaš Lichess token — pita Lichess do četiri puta '
        'po potezu, pa ne ide preko zajedničkog tokena servera.',
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
              label: const Text('Podešavanja'),
            ),
          Text(
            'Baza otvaranja radi i bez njega.',
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
      'unauthorized':
          'Lichess je odbio vaš token. Proverite ga u Podešavanjima.',
      'rate-limited': 'Potrošen je dozvoljeni broj upita ka Lichessu. '
          'Probajte za koji minut.',
      'network': 'Server nije dostupan, pa potez nije presuđen.',
      'no-token': 'Nema vašeg Lichess tokena.',
      'guest': 'Za suđenje poteza treba biti prijavljen.',
      'bad-request': 'Taj potez nije moguće presuditi u ovoj poziciji.',
    };
    return Text(
      messages[reason] ?? 'Potez nije presuđen ($reason).',
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
              label: const Text('Ponovo'),
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
        lines.add('Majstori ga igraju: ${gamesLabel(j.mastersGames)}.');
        break;
      case OpeningVerdict.unknown:
        lines.add('Lichess nema ocenu ove pozicije, pa potez nije presuđen — '
            'to nije isto što i loš potez.');
        break;
      case OpeningVerdict.playable:
      case OpeningVerdict.mistake:
        final loss = j.lossCp;
        final mate = j.mateAfter;
        if (mate != null && mate < 0) {
          lines.add('Posle njega je mat u ${mate.abs()} protiv vas.');
        } else if (loss != null && loss > 0) {
          lines.add('Košta ${pawns(loss)} pešaka.');
        } else {
          lines.add('Ne gubi ništa u odnosu na najbolji potez.');
        }
        if (j.verdict == OpeningVerdict.mistake &&
            (j.afterCp ?? 0) < 0 &&
            (loss ?? 0) <= 0) {
          // The other way a move fails the test: it gives nothing away because
          // there is nothing left to give.
          lines.add('Pozicija je i pre njega bila lošija.');
        }
        if (j.bandGames > 0) {
          final band =
              j.minRating == null ? 'u praksi' : 'kod ${j.minRating}+ igrača';
          lines.add('Odigran $band: ${gamesLabel(j.bandGames)}.');
        }
        break;
    }

    if (j.better != null) lines.add('Bolje je bilo ${j.better}.');
    if (j.punishment.isNotEmpty) {
      lines.add('Kažnjava se sa ${j.punishment.join(' ')}.');
    }
    return lines;
  }
}
