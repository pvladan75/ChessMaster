import 'package:flutter/material.dart';

import 'package:chess_app/services/puzzle_api_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Asking the model about the position on the board.
///
/// The endpoint and its quota have existed since the AI coach was built
/// (`POST /api/ai/explain-position`, metered against `ai_comments`), and
/// `PuzzleApiService.explainPosition` has been written all along — with no
/// caller anywhere in the app. This is the caller.
///
/// It is deliberately **not** a judge. The build screen already has one: the
/// opening judge, which answers "is this move sound, judged by the games real
/// people played", and that is the better question for a repertoire. What comes
/// back here is prose about a position, offered as something to read and — if
/// it is worth keeping — to put into your own comment after you have edited it.
/// Nothing it says is stored anywhere on its own.
class PositionAdvice {
  const PositionAdvice({
    required this.summary,
    required this.keyMotif,
    required this.plan,
    this.recommendedMoves = const [],
  });

  final String summary;
  final String keyMotif;
  final String plan;
  final List<String> recommendedMoves;

  /// The whole answer as one block of text, which is the shape a comment box
  /// takes. The reader edits it there; nothing is saved until they say so.
  String get asComment {
    final parts = <String>[
      if (summary.trim().isNotEmpty) summary.trim(),
      if (keyMotif.trim().isNotEmpty) 'Motiv: ${keyMotif.trim()}',
      if (plan.trim().isNotEmpty) plan.trim(),
    ];
    return parts.join('\n');
  }

  static PositionAdvice? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final summary = json['summary'] as String? ?? '';
    final plan = json['plan'] as String? ?? '';
    if (summary.trim().isEmpty && plan.trim().isEmpty) return null;
    return PositionAdvice(
      summary: summary,
      keyMotif: json['keyMotif'] as String? ?? '',
      plan: plan,
      recommendedMoves: ((json['recommendedMoves'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// Asks about one position. Null when nothing usable came back — the caller
/// says so rather than drawing an empty card.
///
/// [evals] carries whatever the screen already knows: the stored evaluation and
/// the engine's line. The keys are the ones the server's fallback reads
/// (`cp`, `bestMove`, `continuation`), so the answer stays sensible even when
/// the model itself is unreachable.
Future<PositionAdvice?> askAboutPosition({
  required String fen,
  Map<String, dynamic> evals = const {},
}) async {
  final answer = await PuzzleApiService.instance.explainPosition(
    fen: fen,
    evals: evals,
    userToken: SessionService.instance.current.token,
  );
  return PositionAdvice.fromJson(answer);
}

/// Shows the answer, and offers to carry it into the student's own comment.
///
/// Returns the text to hand to the comment editor, or null when the reader just
/// closed it. Deliberately two steps: what a model wrote is not a comment until
/// a person has read it and decided it is.
Future<String?> showPositionAdviceDialog(
  BuildContext context,
  PositionAdvice advice,
) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final colors = context.colors;
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: colors.accent),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('AI o poziciji')),
          ],
        ),
        content: SizedBox(
          // Taken from MediaQuery: a fixed 360 on a 360 dp phone is a dialog
          // with no margins, which this app has shipped once already.
          width: MediaQuery.of(context).size.width * 0.85,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (advice.summary.trim().isNotEmpty)
                  Text(advice.summary.trim(),
                      style: AppText.body.copyWith(color: colors.textPrimary)),
                if (advice.keyMotif.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Motiv: ${advice.keyMotif.trim()}',
                      style: AppText.captionBold.copyWith(color: colors.info)),
                ],
                if (advice.plan.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(advice.plan.trim(),
                      style:
                          AppText.body.copyWith(color: colors.textSecondary)),
                ],
                if (advice.recommendedMoves.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  // A Wrap, not a Row: four moves at a phone's width is where a
                  // row runs off the edge with no warning in a release build.
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final move in advice.recommendedMoves)
                        Chip(
                          label: Text(move, style: AppText.caption),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Ovo je mišljenje modela, ne ocena vašeg poteza. Sud o '
                  'potezu i dalje daje otvaranjska baza.',
                  style: AppText.micro.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zatvori'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(advice.asComment),
            child: const Text('U moj komentar'),
          ),
        ],
      );
    },
  );
}
