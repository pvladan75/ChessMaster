// keep_puzzles_panel.dart — the puzzles „Review entire game" found, kept as
// exercises (`docs/PLAN-MATERIJAL.md`, phase 4, decision 8).
//
// Until this phase they were a set of their own: saved at once under a
// timestamp, opened by the studio's puzzle mode, judged by nothing, sent to
// nobody. Now each is a Find exercise with origin „mistakes" — the shape
// `homeworkFromArchive.js` already writes: the position after the mistake,
// the engine's answer to it, a sentence naming the move just played. They are
// shown before anything is kept, as the scanner shows its positions, and only
// the ticked ones are sent.
library;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

/// „23. Qe7" or „23...Qe7" — the move the puzzle came from, numbered as the
/// game numbers it, read off the position before it.
String puzzleMoveLabel(LocalPuzzle p) {
  final fields = (p.fenBefore ?? p.fen).trim().split(RegExp(r'\s+'));
  final number = fields.length > 5 ? fields[5] : '?';
  final black = fields.length > 1 && fields[1] == 'b';
  return black ? '$number...${p.sourceMoveSan}' : '$number. ${p.sourceMoveSan}';
}

/// The side that played the mistake, in words.
String _blunderer(LocalPuzzle p) {
  final fields = (p.fenBefore ?? '').trim().split(RegExp(r'\s+'));
  if (fields.length > 1) return fields[1] == 'b' ? 'Black' : 'White';
  // No position before it: the side to move now is the one answering.
  final after = p.fen.trim().split(RegExp(r'\s+'));
  return after.length > 1 && after[1] == 'w' ? 'Black' : 'White';
}

/// The exercise [p] becomes, or null when it has no answer that plays.
///
/// **The writer reads its own work back**: the answer is replayed on the
/// position before a request is made, so a move the engine named for some
/// other position never reaches the server as an exercise's solution.
ExerciseDraft? puzzleExerciseDraft(LocalPuzzle p, {required String name}) {
  final answer = p.refutationSan;
  if (answer == null || answer.isEmpty) return null;
  try {
    final board = chess.Chess.fromFEN(p.fen);
    if (!board.move(answer)) return null;
  } catch (_) {
    return null;
  }
  final label = puzzleMoveLabel(p);
  final number = label.split('.').first;
  return ExerciseDraft(
    name: '$name, move $number',
    fen: p.fen,
    // A fact, not a task: what the student is asked is the answer to it.
    instruction: '${_blunderer(p)} just played ${p.sourceMoveSan}.',
    themes: [if (p.themeKey != null) p.themeKey!],
    task: const {'type': 'find'},
    solution: [
      ExerciseStep(accept: [answer]),
    ],
    origin: 'mistakes',
    sourceTitle: name,
    sourceLabel: label.replaceAll(' ', ''),
  );
}

/// The found puzzles, each ticked, a name, and „Keep N as exercises".
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
  late final TextEditingController _name =
      TextEditingController(text: widget.defaultName);

  /// Ticked by index; a puzzle with no answer cannot be ticked.
  late final Set<int> _ticked = {
    for (var i = 0; i < widget.puzzles.length; i++)
      if (widget.puzzles[i].refutationSan != null) i,
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
        for (var i = 0; i < widget.puzzles.length; i++)
          _row(context, i, widget.puzzles[i]),
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
                  'Keep $count as ${count == 1 ? 'an exercise' : 'exercises'}'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, int i, LocalPuzzle p) {
    final colors = context.colors;
    final answer = p.refutationSan;
    return Padding(
      key: ValueKey('keep-puzzle-$i'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('keep-puzzle-tick-$i'),
            value: _ticked.contains(i),
            onChanged: answer == null || _saving
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
                  'After ${puzzleMoveLabel(p)} · '
                  '${p.swing.toStringAsFixed(1)}',
                  style: AppText.body.copyWith(color: colors.textPrimary),
                ),
                Text(
                  answer == null
                      ? 'No answer found — cannot be kept'
                      : 'Answer: $answer · ${p.themeLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
