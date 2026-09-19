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
//
// Phase 5 (`docs/PLAN-EXERCISE.md`, decision 5, `docs/briefs/
// BRIEF-EXERCISE-FAZA5-APP.md`) asks the tablebase and the engine what they
// know of the exercise **as it is made**, through the injected [checker] —
// while the trainer fills in the name, never blocking Save. A finding is
// never applied by itself: only the trainer's own tap on *Accept* moves a
// finding's moves into the solution, through `acceptFinding`.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/save_position_dialog.dart'
    show LabelChipInput;

import '../models/exercise.dart';
import '../models/exercise_check.dart';
import '../models/exercise_line.dart';
import '../models/exercise_task_words.dart';
import '../services/exercise_api_service.dart';
import '../services/exercise_checker.dart';

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

/// Under a find line that reads, in the making mode: nothing tells the
/// trainer this works until they are told (owner, 185.1) — a variation played
/// on the student's own move has been an accepted alternative since phase 2b.
const String kVariationHint =
    "A variation played on the student's own move is accepted as an "
    'alternative.';

/// „1. Qh5 (or Qf3) g6  2. Qxe5+." — the solution as the trainer will
/// recognise it: the moves, alternatives in brackets after the one the line
/// goes on from. One function, so this sheet and `ExerciseEditorScreen` read
/// the same line the same way rather than wording it twice.
String exerciseSolutionText(List<ExerciseStep> steps) {
  final parts = <String>[];
  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    final alt =
        step.accept.length > 1 ? ' (or ${step.accept.skip(1).join(', ')})' : '';
    final reply = step.reply != null ? ' ${step.reply}' : '';
    parts.add('${i + 1}. ${step.accept.first}$alt$reply');
  }
  return parts.join('  ');
}

class MakeExerciseSheet extends StatefulWidget {
  /// Makes a new exercise from the room's own tree — never from wherever the
  /// trainer's cursor happens to be (`ExerciseLine.fromTree`).
  const MakeExerciseSheet({
    super.key,
    required this.api,
    required MoveTree this.moveTree,
    required this.availableUserLabels,
    this.checker = defaultExerciseChecker,
  })  : exercise = null,
        editSteps = null;

  /// Edits an exercise already saved (phase 11): prefilled from [exercise],
  /// or from [steps] when the caller has a line still in progress
  /// (`ExerciseLineEdit`); the kind does not change, and Save sends
  /// `PUT /exercises/:id` without a position.
  const MakeExerciseSheet.edit({
    super.key,
    required this.api,
    required Exercise this.exercise,
    List<ExerciseStep>? steps,
    required this.availableUserLabels,
    this.checker = defaultExerciseChecker,
  })  : moveTree = null,
        editSteps = steps;

  final ExerciseApiService api;
  final MoveTree? moveTree;
  final Exercise? exercise;
  final List<ExerciseStep>? editSteps;
  final List<String> availableUserLabels;

  /// What asks the tablebase and the engine — the real one by default, which
  /// costs nothing to hold until [ExerciseChecker.check] is actually called.
  final ExerciseChecker checker;

  bool get isEditing => exercise != null;

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

  /// The position everything else is asked about: the tree's root when
  /// making one, the exercise's own otherwise — an edit never moves it.
  String get _fen =>
      widget.isEditing ? widget.exercise!.fen : widget.moveTree!.root.fen;

  late final ExerciseLineReading _reading = widget.isEditing
      ? ExerciseLine.read(
          fen: widget.exercise!.fen,
          steps: widget.editSteps ?? widget.exercise!.solution ?? const [],
        )
      : ExerciseLine.fromTree(widget.moveTree!);

  /// The find exercise's solution as it will be saved: [_reading]'s own
  /// steps, plus whatever the trainer has accepted from a finding. Never
  /// touched by the check itself — only `acceptFinding`, from the trainer's
  /// own tap, changes it.
  List<ExerciseStep> _steps = const [];

  /// What the tablebase or the engine found of the *current* choice — a
  /// finding from one task must not still be showing under another, so every
  /// call to [_runCheck] replaces this outright.
  List<ExerciseFinding> _findings = const [];

  /// Whether a check is still in flight. The line saying so goes the moment
  /// [ExerciseChecker.check] answers — findings or none — so the sheet never
  /// shows a spinner that outlives the checker's own timeout.
  bool _checking = false;

  /// Guards a check's answer against a staler one still in flight: only the
  /// most recently started check may write to [_findings].
  int _checkToken = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final exercise = widget.exercise!;
      _nameController.text = exercise.name;
      _instructionController.text = exercise.instruction ?? '';
      _labels = exercise.themes;
      _ask = exerciseAskOf(exercise.task);
      if (_ask != ExerciseAsk.find) {
        _gameSide = exercise.task['side'] as String?;
        _level = exercise.task['level'] as String? ?? 'srednje';
        final forMoves = exerciseForMoves(exercise.task);
        _toEnd = forMoves == null;
        if (forMoves != null) _forMovesController.text = '$forMoves';
      }
    }
    if (_reading.ok) _steps = _reading.steps;
    unawaited(_runCheck());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionController.dispose();
    _forMovesController.dispose();
    super.dispose();
  }

  /// The task to check, in the checker's own shape — null when there is
  /// nothing yet worth asking about (no valid line; no side chosen).
  Map<String, dynamic>? get _taskForCheck {
    if (_ask == ExerciseAsk.find) {
      return _reading.ok ? const {'type': 'find'} : null;
    }
    if (_gameSide == null) return null;
    return {
      'type': 'game',
      'side': _gameSide,
      'goal': _ask == ExerciseAsk.win ? 'win' : 'hold',
    };
  }

  /// Starts a check of the *current* choice. The check advises; it never
  /// blocks Save, and its own timeout is where „Checking…" ends, whether or
  /// not anybody answered.
  Future<void> _runCheck() async {
    final token = ++_checkToken;
    final task = _taskForCheck;
    if (task == null) {
      setState(() {
        _checking = false;
        _findings = const [];
      });
      return;
    }
    setState(() {
      _checking = true;
      _findings = const [];
    });
    final findings = await widget.checker.check(
      fen: _fen,
      task: task,
      steps: _ask == ExerciseAsk.find ? _steps : null,
    );
    if (!mounted || token != _checkToken) return;
    setState(() {
      _checking = false;
      _findings = findings;
    });
  }

  void _acceptFinding(ExerciseFinding finding) {
    setState(() {
      _steps = acceptFinding(_steps, finding);
      _findings = _findings.where((f) => f != finding).toList();
    });
  }

  /// „For N moves", within 1..50, or null when the field cannot be read as
  /// one — which, while [_toEnd] is false, is also not yet a task to save.
  int? get _forMoves {
    if (_toEnd) return null;
    final n = int.tryParse(_forMovesController.text.trim());
    return (n != null && n >= 1 && n <= 50) ? n : null;
  }

  bool get _forMovesUnreadable => !_toEnd && _forMoves == null;

  ExerciseJudge get _judge =>
      exerciseJudgeFor(fen: _fen, ask: _ask, forMoves: _forMoves);

  bool get _canSave {
    if (_saving || _nameController.text.trim().isEmpty) return false;
    if (_ask == ExerciseAsk.find) return _reading.ok;
    return _gameSide != null && !_forMovesUnreadable;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    // An edit says nothing about the position — the server keeps the one it
    // already has, and refuses a request that disagrees with it (409). A new
    // exercise's position is the root's FEN, as everywhere in this feature. A
    // game exercise needs no line on the board, only the position: „play the
    // solution first" is a refusal that applies to Find alone.
    final fen = widget.isEditing ? null : widget.moveTree!.root.fen;
    final instruction = _instructionController.text.trim().isEmpty
        ? null
        : _instructionController.text.trim();
    // `thinkSeconds` is not a question this sheet asks — it must still travel
    // through an edit exactly as it stood, rather than be lost by one.
    final thinkSeconds = widget.isEditing
        ? (widget.exercise!.task['thinkSeconds'] as num?)?.toInt()
        : null;
    final draft = _ask == ExerciseAsk.find
        ? ExerciseDraft(
            name: _nameController.text.trim(),
            fen: fen,
            instruction: instruction,
            themes: _labels,
            task: const {'type': 'find'},
            solution: _steps,
          )
        : ExerciseDraft(
            name: _nameController.text.trim(),
            fen: fen,
            instruction: instruction,
            themes: _labels,
            task: exerciseGameTask(
              side: _gameSide!,
              ask: _ask,
              forMoves: _forMoves,
              level: _level,
              thinkSeconds: thinkSeconds,
            ),
            solution: null,
          );
    final result = widget.isEditing
        ? await widget.api.update(widget.exercise!.id, draft)
        : await widget.api.create(draft);
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

    // The kind does not change under a homework already sent — an edit shows
    // only the one chip it already is, and it is not tappable into another.
    final askChoices = widget.isEditing ? [_ask] : ExerciseAsk.values;

    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit exercise' : 'Make exercise'),
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
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
                    for (final ask in askChoices)
                      ChoiceChip(
                        key: Key('exercise-ask-${ask.name}'),
                        label: Text(ask.label),
                        selected: _ask == ask,
                        onSelected: widget.isEditing
                            ? null
                            : (_) {
                                setState(() => _ask = ask);
                                unawaited(_runCheck());
                              },
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
                    Text(
                      'Play the solution on the board first.',
                      style: AppText.body.copyWith(color: colors.textMuted),
                    ),
                  ] else ...[
                    Text(
                      _steps.length == 1 ? 'Find the move' : 'Find the moves',
                      style: AppText.bodyLargeBold,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      exerciseSolutionText(_steps),
                      style: AppText.body.copyWith(color: colors.textSecondary),
                    ),
                    if (!widget.isEditing) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        kVariationHint,
                        style: AppText.body.copyWith(color: colors.textMuted),
                      ),
                    ],
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
                        // The same number, two meanings: a win asks for
                        // mate by then, a draw asks to last that long.
                        label: Text(
                          _ask == ExerciseAsk.win
                              ? 'Checkmate in N moves'
                              : 'For N moves',
                        ),
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
                        onSelected: (_) {
                          setState(() => _gameSide = 'w');
                          unawaited(_runCheck());
                        },
                      ),
                      ChoiceChip(
                        key: const Key('exercise-side-b'),
                        label: const Text('Black'),
                        selected: _gameSide == 'b',
                        onSelected: (_) {
                          setState(() => _gameSide = 'b');
                          unawaited(_runCheck());
                        },
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
                if (_checking) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Checking…',
                    key: const Key('exercise-check-status'),
                    style: AppText.body.copyWith(color: colors.textMuted),
                  ),
                ],
                for (final finding in _findings) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          finding.words,
                          key: Key('exercise-finding-${finding.hashCode}'),
                          style: AppText.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      if (finding.sans.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.xs),
                        TextButton(
                          key: Key(
                            'exercise-finding-accept-${finding.hashCode}',
                          ),
                          onPressed: () => _acceptFinding(finding),
                          child: const Text('Accept'),
                        ),
                      ],
                    ],
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
                  Text(
                    _serverError!,
                    style: AppText.body.copyWith(color: colors.danger),
                  ),
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
