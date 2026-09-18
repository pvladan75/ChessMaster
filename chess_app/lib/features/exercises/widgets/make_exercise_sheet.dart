// make_exercise_sheet.dart — Preparation's „Make exercise" door
// (`docs/PLAN-EXERCISE.md`, phase 2b).
//
// A trainer does not send a position, they send an exercise: a position plus
// a task. This is the only task built in this phase — *find the move(s)* —
// read straight off the room's own move tree, never from wherever the
// trainer's cursor happens to be (`ExerciseLine.fromTree`, and the 6.9.2026
// bug it exists to not repeat).
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
import '../services/exercise_api_service.dart';

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
  List<String> _labels = const [];
  String? _serverError;
  bool _saving = false;

  late final ExerciseLineReading _reading =
      ExerciseLine.fromTree(widget.moveTree);

  @override
  void dispose() {
    _nameController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _reading.ok && _nameController.text.trim().isNotEmpty;

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
    final draft = ExerciseDraft(
      name: _nameController.text.trim(),
      fen: widget.moveTree.root.fen,
      instruction: _instructionController.text.trim().isEmpty
          ? null
          : _instructionController.text.trim(),
      themes: _labels,
      task: const {'type': 'find'},
      solution: _reading.steps,
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
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'E.g. Queen out early',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
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
