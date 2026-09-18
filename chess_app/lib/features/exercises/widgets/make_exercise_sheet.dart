// make_exercise_sheet.dart — Preparation's „Make exercise" door
// (`docs/PLAN-EXERCISE.md`, phases 2b and 3b).
//
// A trainer does not send a position, they send an exercise: a position plus
// a task. The sheet asks **what** before anything else, in `ExerciseAsk`'s own
// words. *Find the move(s)* is read straight off the room's own move tree,
// never from wherever the trainer's cursor happens to be (`ExerciseLine.
// fromTree`, and the 6.9.2026 bug it exists to not repeat). *Win* and *Draw or
// better* (phase 3b) need no line — only the position, the root's FEN, as
// everywhere in this feature — and two more questions:
// `lib/features/exercises/models/exercise_task_words.dart` is the one home
// for the words a game task is asked and judged in; this sheet reads it
// rather than wording a task a second time.
//
// The sheet never calls `AppFeedback` on success: it pops with the saved
// [Exercise], and the caller — which still has a live context — says so. A
// refusal is different: it is shown *in* the sheet, in the server's own
// words, and the sheet stays open so the trainer can fix it.
import 'package:flutter/material.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/save_position_dialog.dart'
    show LabelChipInput;

import '../models/exercise.dart';
import '../models/exercise_line.dart';
import '../models/exercise_task_words.dart';
import '../services/exercise_api_service.dart';

const Map<String, String> _kEngineLevelLabels = {
  'lako': 'Easy',
  'srednje': 'Medium',
  'tesko': 'Hard',
};

/// Beside „Save position" in the studio room: opens [MakeExerciseSheet] on
/// the tree in front of the trainer.
///
/// Its own widget, rather than an inline `onPressed` in the screen that hosts
/// it, so the door can be pumped and tapped on its own — the full studio room
/// needs a live Socket.IO connection a widget test cannot give it (CLAUDE.md
/// rule 10: every layer can be right and a feature still unreachable).
class MakeExerciseButton extends StatelessWidget {
  const MakeExerciseButton({
    super.key,
    required this.api,
    required this.moveTree,
    required this.availableUserLabels,
    this.onSaved,
  });

  final ExerciseApiService api;
  final MoveTree moveTree;
  final List<String> availableUserLabels;

  /// Told the saved exercise once the sheet has popped — the caller says so
  /// through `AppFeedback`, which needs a context the sheet no longer has.
  final ValueChanged<Exercise>? onSaved;

  Future<void> _open(BuildContext context) async {
    final saved = await showDialog<Exercise>(
      context: context,
      builder: (_) => MakeExerciseSheet(
        api: api,
        moveTree: moveTree,
        availableUserLabels: availableUserLabels,
      ),
    );
    if (saved != null) onSaved?.call(saved);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.task_alt, size: 16),
        label: const Text('Make exercise'),
      ),
    );
  }
}

class MakeExerciseSheet extends StatefulWidget {
  const MakeExerciseSheet({
    super.key,
    required this.api,
    required this.moveTree,
    required this.availableUserLabels,
  });

  final ExerciseApiService api;
  final MoveTree moveTree;
  final List<String> availableUserLabels;

  @override
  State<MakeExerciseSheet> createState() => _MakeExerciseSheetState();
}

class _MakeExerciseSheetState extends State<MakeExerciseSheet> {
  final _nameController = TextEditingController();
  final _instructionController = TextEditingController();
  final _forMovesController = TextEditingController(text: '5');
  List<String> _labels = const [];
  String? _serverError;
  bool _saving = false;

  /// What the sheet asks — the first question, before anything else. „Find
  /// the move" is what this sheet has always built; „Win" and „Draw or
  /// better" are the game exercise (phase 3b).
  ExerciseAsk _ask = ExerciseAsk.find;

  /// „To the end of the game" versus „For N moves".
  bool _toEnd = true;

  /// The side the **student** plays. Nothing pre-selected: the position never
  /// decides this (unlike a homework's own board, whose FEN sometimes speaks
  /// for itself, this is always the trainer's own choice — an answer offered
  /// in advance is an answer half-given, learned 18.9.2026 on the homework
  /// dialog), so Save stays off until it is chosen.
  String? _gameSide;

  /// Medium is the app's own default strength, selected from the start.
  String _level = 'srednje';

  late final ExerciseLineReading _reading =
      ExerciseLine.fromTree(widget.moveTree);

  @override
  void dispose() {
    _nameController.dispose();
    _instructionController.dispose();
    _forMovesController.dispose();
    super.dispose();
  }

  /// „For N moves", within 1..50, or null when the field cannot be read as
  /// one — which, while [_toEnd] is false, is also not yet a task to save.
  int? get _forMoves {
    if (_toEnd) return null;
    final n = int.tryParse(_forMovesController.text.trim());
    return (n != null && n >= 1 && n <= 50) ? n : null;
  }

  bool get _forMovesUnreadable => !_toEnd && _forMoves == null;

  ExerciseJudge get _judge => exerciseJudgeFor(
        fen: widget.moveTree.root.fen,
        ask: _ask,
        forMoves: _forMoves,
      );

  bool get _canSave {
    if (_saving || _nameController.text.trim().isEmpty) return false;
    if (_ask == ExerciseAsk.find) return _reading.ok;
    if (_gameSide == null || _forMovesUnreadable) return false;
    return _judge != ExerciseJudge.refused;
  }

  /// „1. Qh5 (or Qf3) g6  2. Qxe5+." — the solution as the trainer will
  /// recognise it: the moves, alternatives in brackets after the one the line
  /// goes on from.
  String _solutionText(List<ExerciseStep> steps) {
    final parts = <String>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final alt = step.accept.length > 1
          ? ' (or ${step.accept.skip(1).join(', ')})'
          : '';
      final reply = step.reply != null ? ' ${step.reply}' : '';
      parts.add('${i + 1}. ${step.accept.first}$alt$reply');
    }
    return parts.join('  ');
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    // A game exercise needs no line on the board, only the position: „play
    // the solution first" is a refusal that applies to Find alone. The
    // position is the root's FEN, as everywhere in this feature.
    final draft = _ask == ExerciseAsk.find
        ? ExerciseDraft(
            name: _nameController.text.trim(),
            fen: widget.moveTree.root.fen,
            instruction: _instructionController.text.trim().isEmpty
                ? null
                : _instructionController.text.trim(),
            themes: _labels,
            task: const {'type': 'find'},
            solution: _reading.steps,
          )
        : ExerciseDraft(
            name: _nameController.text.trim(),
            fen: widget.moveTree.root.fen,
            instruction: _instructionController.text.trim().isEmpty
                ? null
                : _instructionController.text.trim(),
            themes: _labels,
            task: exerciseGameTask(
              side: _gameSide!,
              ask: _ask,
              forMoves: _forMoves,
              level: _level,
            ),
            solution: null,
          );
    final result = await widget.api.create(draft);
    if (!mounted) return;
    if (result.exercise != null) {
      Navigator.of(context).pop(result.exercise);
      return;
    }
    setState(() {
      _saving = false;
      _serverError = result.error ?? 'Could not save the exercise.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reading = _reading;

    return AlertDialog(
      title: const Text('Make exercise'),
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // What the sheet asks, before anything else.
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ask in ExerciseAsk.values)
                      ChoiceChip(
                        key: Key('exercise-ask-${ask.name}'),
                        label: Text(ask.label),
                        selected: _ask == ask,
                        onSelected: (_) => setState(() => _ask = ask),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_ask == ExerciseAsk.find) ...[
                  if (!reading.ok) ...[
                    Text(
                      reading.error ?? 'This line cannot be saved.',
                      style: AppText.body.copyWith(color: colors.danger),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Play the solution on the board first.',
                        style: AppText.body.copyWith(color: colors.textMuted)),
                  ] else ...[
                    Text(
                      reading.steps.length == 1
                          ? 'Find the move'
                          : 'Find the moves',
                      style: AppText.bodyLargeBold,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_solutionText(reading.steps),
                        style:
                            AppText.body.copyWith(color: colors.textSecondary)),
                    if (reading.droppedReply) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        "The last move is the opponent's and is not part of "
                        'the solution.',
                        style: AppText.body.copyWith(color: colors.textMuted),
                      ),
                    ],
                    if (reading.ignoredReplies > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        "Variations at the opponent's moves are not used.",
                        style: AppText.body.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ],
                ] else ...[
                  Text('How long?', style: AppText.bodyLargeBold),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        key: const Key('exercise-length-toEnd'),
                        label: const Text('To the end of the game'),
                        selected: _toEnd,
                        onSelected: (_) => setState(() => _toEnd = true),
                      ),
                      ChoiceChip(
                        key: const Key('exercise-length-forMoves'),
                        label: const Text('For N moves'),
                        selected: !_toEnd,
                        onSelected: (_) => setState(() => _toEnd = false),
                      ),
                    ],
                  ),
                  if (!_toEnd) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        key: const Key('exercise-for-moves-field'),
                        controller: _forMovesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Moves (1-50)',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text('The student plays', style: AppText.bodyLargeBold),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        key: const Key('exercise-side-w'),
                        label: const Text('White'),
                        selected: _gameSide == 'w',
                        onSelected: (_) => setState(() => _gameSide = 'w'),
                      ),
                      ChoiceChip(
                        key: const Key('exercise-side-b'),
                        label: const Text('Black'),
                        selected: _gameSide == 'b',
                        onSelected: (_) => setState(() => _gameSide = 'b'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Engine strength', style: AppText.bodyLargeBold),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in _kEngineLevelLabels.entries)
                        ChoiceChip(
                          key: Key('exercise-level-${entry.key}'),
                          label: Text(entry.value),
                          selected: _level == entry.key,
                          onSelected: (_) => setState(() => _level = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    exerciseJudgeWords(_judge),
                    key: const Key('exercise-judge-words'),
                    style: AppText.body.copyWith(color: colors.textSecondary),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const Key('exercise-name-field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'E.g. Queen out early',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('exercise-instruction-field'),
                  controller: _instructionController,
                  decoration: const InputDecoration(
                    labelText: 'Instruction (optional)',
                    hintText: 'What is the student asked to do?',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                LabelChipInput(
                  availableUserLabels: widget.availableUserLabels,
                  initialLabels: _labels,
                  onChanged: (tags) => _labels = tags,
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_serverError!,
                      style: AppText.body.copyWith(color: colors.danger)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
