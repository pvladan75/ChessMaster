import 'package:flutter/material.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/analysis_studio/services/position_study/position_study.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Asking about the position on the board.
///
/// It is deliberately **not** a judge. The build screen already has one: the
/// opening judge, which answers "is this move sound, judged by the games real
/// people played", and that is the better question for a repertoire. What comes
/// back here is prose about a position, offered as something to read and — if
/// it is worth keeping — to put into your own comment after you have edited it.
/// Nothing it says is stored anywhere on its own.
///
/// **The position study's path with one item**
/// (`docs/PLAN-STUDIJA-POZICIJE.md`, D5): the engine reads the position and
/// looks for a threat, the model puts that into words, and the app checks the
/// words against the analysis before anything is shown. Gemini answered this
/// until 28.9.2026, from a FEN and nothing else.
class PositionAdvice {
  const PositionAdvice({
    required this.summary,
    this.recommendedMoves = const [],
    this.language,
  });

  /// What stands on the board and what is threatened, as written.
  final String summary;

  /// The engine's move.
  final List<String> recommendedMoves;

  /// The language the words were written in; null for English. The one
  /// chosen in „Study this position" (`docs/PLAN-JEZIK-STUDIJE.md`, L2).
  final String? language;

  /// The whole answer as one block of text, which is the shape a comment box
  /// takes. The reader edits it there; nothing is saved until they say so.
  String get asComment => summary.trim();
}

/// Asks about one position. A [WordsRefusal] says why nothing came back — the
/// caller says so rather than drawing an empty card.
Future<({PositionAdvice? advice, WordsRefusal? refusal})> askAboutPosition({
  required String fen,
  PositionAnalyzer? analyzer,
  StudyWordsAsker? ask,
}) async {
  final token = SessionService.instance.current.token;
  final language = chosenStudyLanguage();
  final engine = StockfishService();
  final holder = Object();
  engine.hold(holder);
  try {
    final answer = await commentOnPosition(
      fen: fen,
      analyzer: analyzer ??
          EvalCache.instance.wrap(
            engine.analyzePositionSync,
            engine: engine.answerStoreName,
          ),
      depth: AppSettingsService.instance.analysisDepth,
      tablebase: SyzygyTablebaseService.instance.lookup,
      ask: ask ??
          (request, {required comment}) =>
              requestStudyWords(request, token: token, comment: comment),
      language: language,
    );
    final text = answer.comment.text;
    if (text == null) return (advice: null, refusal: answer.comment.refusal);
    return (
      advice: PositionAdvice(
        summary: text,
        recommendedMoves: [if (answer.bestMove != null) answer.bestMove!],
        language: language,
      ),
      refusal: null,
    );
  } finally {
    engine.release(holder);
  }
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
            const Expanded(child: Text('AI on position')),
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
                  'The engine analysed the position and the model put it '
                  'into words. The opening database still judges your move.',
                  style: AppText.micro.copyWith(color: colors.textMuted),
                ),
                if (studyLanguageNote(advice.language) case final note?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(note,
                      style: AppText.micro.copyWith(color: colors.textMuted)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(advice.asComment),
            child: const Text('Add to my comment'),
          ),
        ],
      );
    },
  );
}
