// keep_puzzles_panel.dart — the puzzles „Review entire game" found, kept as
// exercises (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.3).
//
// Since 1.3 a puzzle is the position *before* the game's move: the instruction
// of §4 does not name it, and the solution accepts every right answer (a mate
// may have more than one forcing first move). Mistakes are listed first and
// ticked; the only moves a player found sit apart, under their own heading,
// not ticked by default — a review of one's own game is first about what
// went wrong. A row keeps the index it was handed in [KeepPuzzlesPanel.puzzles]
// as its key, whatever order the panel draws the rows in.
library;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

/// „3. Bc4" or „3...Nf6" — the move the puzzle came from, numbered as the
/// game numbers it, read off the position before it ([LocalPuzzle.fen]).
String puzzleMoveLabel(LocalPuzzle p) {
  final fields = p.fen.trim().split(RegExp(r'\s+'));
  final number = fields.length > 5 ? fields[5] : '?';
  final black = fields.length > 1 && fields[1] == 'b';
  return black ? '$number...${p.playedSan}' : '$number. ${p.playedSan}';
}

/// Whether [sans] plays, move by move, from [fen].
bool _plays(String fen, List<String> sans) {
  try {
    final board = chess.Chess.fromFEN(fen);
    for (final san in sans) {
      if (!board.move(san)) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// The exercise [p] becomes, or null when an answer or a line does not play.
///
/// **The writer reads its own work back**: every answer is replayed on the
/// position, and so is every line of the review — the best and the second
/// from the position, the refutation from the position after the game's move
/// — before a request is made. The server replays them again
/// (`readReview`, `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md` phases 2 and 4); a line
/// it would refuse is one this should never have sent.
ExerciseDraft? puzzleExerciseDraft(LocalPuzzle p, {required String name}) {
  for (final answer in p.answers) {
    if (!_plays(p.fen, [answer])) return null;
  }
  if (p.bestLine.isEmpty || !_plays(p.fen, p.bestLine)) return null;
  if (!_plays(p.fen, p.secondLine)) return null;
  if (!_plays(p.fen, [p.playedSan, ...p.refutationLine])) return null;
  final label = puzzleMoveLabel(p);
  final number = label.split('.').first;
  return ExerciseDraft(
    name: '$name, move $number',
    fen: p.fen,
    instruction: p.instruction,
    task: const {'type': 'find'},
    solution: [ExerciseStep(accept: p.answers)],
    origin: 'mistakes',
    sourceTitle: name,
    sourceLabel: label.replaceAll(' ', ''),
    // No words until the language model writes them (phase 3): absent, not an
    // empty string that would read as an explanation with nothing in it.
    review: {
      'played': p.playedSan,
      'bestLine': p.bestLine,
      'refutationLine': p.refutationLine,
      'secondLine': p.secondLine,
      'chances': {
        'best': p.bestChances,
        'played': p.playedChances,
        if (p.secondChances != null) 'second': p.secondChances,
      },
    },
  );
}

/// The found puzzles — mistakes first, ticked; the only moves under their own
/// heading, not ticked — a name, and „Keep N as exercises".
class KeepPuzzlesPanel extends StatefulWidget {
  const KeepPuzzlesPanel({
    super.key,
    required this.puzzles,
    required this.defaultName,
    required this.api,
    required this.onDone,
  });

  final List<LocalPuzzle> puzzles;

  /// The game's name when it has one, else „Game of dd.mm.yyyy".
  final String defaultName;
  final ExerciseApiService api;

  /// Called when the panel is finished with — after keeping, or on „Close"
  /// without keeping. [kept] is how many exercises were written.
  final void Function(int kept) onDone;

  @override
  State<KeepPuzzlesPanel> createState() => _KeepPuzzlesPanelState();
}

class _KeepPuzzlesPanelState extends State<KeepPuzzlesPanel> {
  late final TextEditingController _name = TextEditingController(
    text: widget.defaultName,
  );

  /// The puzzles that can be kept: those whose answers and lines all play
  /// ([puzzleExerciseDraft]). Any other cannot be ticked, and says so.
  late final Set<int> _keepable = {
    for (var i = 0; i < widget.puzzles.length; i++)
      if (puzzleExerciseDraft(widget.puzzles[i], name: 'check') != null) i,
  };

  /// Ticked by index into [KeepPuzzlesPanel.puzzles] — every mistake that can
  /// be kept, by default; no only move.
  late final Set<int> _ticked = {
    for (final i in _keepable)
      if (widget.puzzles[i].kind == PuzzleKind.mistake) i,
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _keep() async {
    final name = _name.text.trim();
    if (name.isEmpty || _ticked.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    var kept = 0;
    String? firstError;
    for (final i in _ticked.toList()..sort()) {
      final draft = puzzleExerciseDraft(widget.puzzles[i], name: name);
      if (draft == null) {
        firstError ??= 'The answer to ${puzzleMoveLabel(widget.puzzles[i])} '
            'does not play there, so it was not kept.';
        continue;
      }
      final result = await widget.api.create(draft);
      if (!mounted) return;
      if (result.exercise != null) {
        kept++;
      } else {
        firstError ??= result.error;
      }
    }
    if (!mounted) return;
    if (firstError != null) {
      setState(() {
        _saving = false;
        _error = kept == 0 ? firstError : 'Kept $kept. $firstError';
      });
      return;
    }
    widget.onDone(kept);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = _ticked.length;
    final mistakes = <int>[];
    final onlyMoves = <int>[];
    for (var i = 0; i < widget.puzzles.length; i++) {
      (widget.puzzles[i].kind == PuzzleKind.mistake ? mistakes : onlyMoves).add(
        i,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Found ${widget.puzzles.length} '
          '${widget.puzzles.length == 1 ? 'puzzle' : 'puzzles'} in this game',
          style: AppText.bodyBold.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final i in mistakes) _row(context, i, widget.puzzles[i]),
        if (onlyMoves.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Only moves the player found',
            key: const Key('keep-only-moves'),
            style: AppText.bodyBold.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (final i in onlyMoves) _row(context, i, widget.puzzles[i]),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('keep-puzzles-name'),
          controller: _name,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_error!, style: AppText.body.copyWith(color: colors.danger)),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            TextButton(
              onPressed: _saving ? null : () => widget.onDone(0),
              child: const Text('Close'),
            ),
            FilledButton(
              key: const Key('keep-puzzles-save'),
              onPressed: _saving || count == 0 || _name.text.trim().isEmpty
                  ? null
                  : _keep,
              child: Text(
                'Keep $count as ${count == 1 ? 'an exercise' : 'exercises'}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, int i, LocalPuzzle p) {
    final colors = context.colors;
    final label = puzzleMoveLabel(p);
    final headline = p.kind == PuzzleKind.mistake
        ? '$label · lost ${p.lostChances.round()}'
            '${p.missedTimes > 1 ? ', missed ${p.missedTimes} times' : ''}'
        : '$label · the only good move';
    return Padding(
      key: ValueKey('keep-puzzle-$i'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('keep-puzzle-tick-$i'),
            value: _ticked.contains(i),
            onChanged: _saving || !_keepable.contains(i)
                ? null
                : (on) => setState(() {
                      if (on == true) {
                        _ticked.add(i);
                      } else {
                        _ticked.remove(i);
                      }
                    }),
          ),
          BoardThumbnail(fen: p.fen, size: 48),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppText.body.copyWith(color: colors.textPrimary),
                ),
                Text(
                  _keepable.contains(i)
                      ? 'Answer: ${p.answers.join(' or ')}'
                      : 'Its line does not play here — cannot be kept',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                      color: _keepable.contains(i)
                          ? colors.textSecondary
                          : colors.danger),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
