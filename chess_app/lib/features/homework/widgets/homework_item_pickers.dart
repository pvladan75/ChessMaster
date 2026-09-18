/// The two "Add" pickers that have nothing in the Library to reuse — a
/// puzzle set's criteria (`CreateAssignmentDialog` is a full assignment
/// dialog with a student and a due date, awkward to fold a criteria-only
/// question into) and a "play it out" position (nothing already authors one).
/// The other two kinds — a tutorial, a set of positions — are picked through
/// `CoursePickerDialog` and `PositionPickerDialog`, already built for this.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/services/fen_legality.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show themeLabel, themeLabels;
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/position_picker_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Asks for a puzzle set's criteria and hands back the `puzzles` task —
/// `{themes, count, minRating, maxRating}` — or null on cancel. The same
/// theme catalogue `CreateAssignmentDialog` offers ([themeLabels]), read
/// rather than copied a second time.
Future<Map<String, dynamic>?> pickPuzzleCriteria(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _PuzzleCriteriaDialog(),
  );
}

class _PuzzleCriteriaDialog extends StatefulWidget {
  const _PuzzleCriteriaDialog();

  @override
  State<_PuzzleCriteriaDialog> createState() => _PuzzleCriteriaDialogState();
}

class _PuzzleCriteriaDialogState extends State<_PuzzleCriteriaDialog> {
  final Set<String> _themes = {};
  int _count = 10;
  RangeValues _ratingRange = const RangeValues(1000, 1800);

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.of(context).size.width - 128;
    return AlertDialog(
      title: const Text('Puzzle set'),
      content: SizedBox(
        width: available.clamp(180.0, 420.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Themes', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final theme in themeLabels.keys)
                    FilterChip(
                      label: Text(themeLabel(theme), style: AppText.body),
                      selected: _themes.contains(theme),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _themes.add(theme);
                        } else {
                          _themes.remove(theme);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Number of puzzles: $_count',
                  style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: _count.toDouble(),
                min: 5,
                max: 50,
                divisions: 9,
                label: '$_count',
                onChanged: (value) => setState(() => _count = value.round()),
              ),
              Text(
                'Difficulty: ${_ratingRange.start.round()}–${_ratingRange.end.round()}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              RangeSlider(
                values: _ratingRange,
                min: 400,
                max: 2800,
                divisions: 24,
                labels: RangeLabels(
                  '${_ratingRange.start.round()}',
                  '${_ratingRange.end.round()}',
                ),
                onChanged: (values) => setState(() => _ratingRange = values),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('homework-puzzle-submit'),
          onPressed: () => Navigator.pop(context, {
            'themes': _themes.toList(),
            'count': _count,
            'minRating': _ratingRange.start.round(),
            'maxRating': _ratingRange.end.round(),
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Asks for a "play it out" position and hands back the `engine_game` task,
/// or null on cancel.
///
/// **The trainer picks which colour the student plays** (the owner's answer to
/// `docs/PLAN-DOMACI-ZADATAK.md` §9, item 2), and the engine takes the other.
/// It starts on the position's own mover, because that is the ordinary case and
/// every fixture in `docs/gates/engine_game_cases.json` reads that way — but it
/// can be the other one, and then the engine opens: `ai_studio_screen.dart`
/// asks the engine to move when `turn != task.side`, and the server counts the
/// student's own moves by whose turn it was, so „hold this draw, engine to
/// move" is a task both ends already judge correctly.
///
/// The task is accepted only once it has round-tripped through
/// [EngineGameTask.fromJson], the one reader both ends trust (rule: the writer
/// reads its own work back through the reader before saving it).
Future<Map<String, dynamic>?> pickEngineGameTask(
  BuildContext context, {
  required PositionLibraryService positionLibrary,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _EngineGameItemDialog(positionLibrary: positionLibrary),
  );
}

class _EngineGameItemDialog extends StatefulWidget {
  const _EngineGameItemDialog({required this.positionLibrary});

  final PositionLibraryService positionLibrary;

  @override
  State<_EngineGameItemDialog> createState() => _EngineGameItemDialogState();
}

class _EngineGameItemDialogState extends State<_EngineGameItemDialog> {
  final _fenController = TextEditingController();
  String _goal = 'win';
  int _surviveMoves = 10;
  String? _level;
  String? _error;

  /// The colour the trainer chose, or null while it still follows the
  /// position's own turn.
  ///
  /// **The switch decides, and a pasted FEN sets the switch.** Asked for in
  /// those words on 18.9.2026: „odlučujuće treba da bude dugme koje odlučuje ko
  /// je na potezu, a dugme se pri pastovanju fen-a postavlja u položaj koji fen
  /// diktira". So a new FEN clears this and the switch reads the position
  /// again; moving the switch sets it and the FEN is rewritten to match on the
  /// way out. The old comment here said the opposite — that a pasted FEN must
  /// not overturn a deliberate choice — which left the switch showing White
  /// over a position the trainer had just pasted with Black to move.
  String? _side;

  @override
  void initState() {
    super.initState();
    // The side buttons and the line under them read the FEN, so they have to
    // be rebuilt as it is typed or pasted — without this the dialog would
    // show „White plays" over a position with Black to move.
    _fenController.addListener(_onFenChanged);
  }

  void _onFenChanged() {
    final side = _sideOfFen(_fenController.text);
    setState(() {
      // **A pasted position always takes the switch**, whatever was tapped
      // before it: „nema veze šta sam dirao pre pastovanja" (18.9.2026). An
      // earlier attempt kept the trainer's tap when the new FEN happened to
      // name the same side as the old one, which is a rule nobody can see from
      // the outside — the switch would sometimes follow a paste and sometimes
      // not, for a reason two positions ago.
      //
      // Writing the completed FEN back on „Add" runs through here too, and sets
      // the switch to the side it was just given: the same value it already
      // held, so nothing moves.
      if (side != null) _side = side;
    });
  }

  @override
  void dispose() {
    _fenController.removeListener(_onFenChanged);
    _fenController.dispose();
    super.dispose();
  }

  Future<void> _pickFromLibrary() async {
    final chosen = await showDialog<List<LibraryEntry>>(
      context: context,
      builder: (_) => PositionPickerDialog(
        service: widget.positionLibrary,
        purpose: PickerPurpose.homework,
        multiSelect: false,
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() {
      _fenController.text = chosen.first.fen;
      // A different position is a different default; the trainer can pick
      // again, but nothing they chose for the old one carries over.
      _side = null;
    });
  }

  /// `w`/`b` from the FEN's own turn field — which side the *position* hands
  /// the move to. The default for [_studentSide], not the answer.
  String? _sideOfFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return parts[1] == 'b' ? 'b' : (parts[1] == 'w' ? 'w' : null);
  }

  /// The side the student plays: what the trainer chose, or the position's own
  /// mover until they choose otherwise.
  String get _studentSide => _side ?? _sideOfFen(_fenController.text) ?? 'w';

  void _submit() {
    var fen = _fenController.text.trim();

    // **A board on its own is finished here, not refused.** What a diagram tool
    // hands you is the board and nothing else, and the trainer said so on
    // 18.9.2026: „ne moram, ionako obeležavam ko je na potezu" — the side is
    // already a switch on this dialog, so asking them to type it into the FEN
    // as well is asking twice.
    //
    // The completion is **written back into the field** rather than used out of
    // sight: castling is inferred from where the kings and rooks stand, which
    // is a guess a diagram cannot settle, and a guess about the rules of the
    // game being set for a student belongs where the trainer can see and
    // correct it.
    // A board on its own is finished; one that already carries a side has that
    // side set to whatever the switch says. Either way the switch is the one
    // that decides, and either way the result is written back into the field.
    final completed = completedFen(fen);
    fen = completed == null
        ? fenWithSideToMove(fen, _studentSide)
        : fenWithSideToMove(completed, _studentSide);
    if (fen != _fenController.text.trim()) _fenController.text = fen;

    // And what is still wrong is said in the validator's own words. It knows
    // whether a king is missing, a pawn stands on the first rank, or the side
    // not to move is already in check; the dialog used to answer all of them
    // with „Not a valid position".
    final reason = fenIllegalReason(fen);
    if (reason != null) {
      setState(() => _error = reason);
      return;
    }

    final task = <String, dynamic>{
      'fen': fen,
      'side': _studentSide,
      'goal': _goal,
      if (_goal == 'survive') 'surviveMoves': _surviveMoves,
      if (_level != null) 'level': _level,
    };
    // The writer reads its own work back through the reader before saving:
    // a task this app cannot itself play is refused here, not on the server.
    if (EngineGameTask.fromJson(task) == null) {
      setState(() => _error = 'Not a valid position for "play it out".');
      return;
    }
    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final available = MediaQuery.of(context).size.width - 128;
    return AlertDialog(
      title: const Text('Play it out'),
      content: SizedBox(
        width: available.clamp(180.0, 420.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('homework-engine-fen'),
                      controller: _fenController,
                      decoration: const InputDecoration(labelText: 'FEN'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    tooltip: 'Pick from library',
                    onPressed: _pickFromLibrary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('The student plays',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                key: const Key('homework-engine-side'),
                segments: const [
                  ButtonSegment(value: 'w', label: Text('White')),
                  ButtonSegment(value: 'b', label: Text('Black')),
                ],
                selected: {_studentSide},
                showSelectedIcon: false,
                onSelectionChanged: (picked) {
                  if (picked.isEmpty) return;
                  setState(() => _side = picked.first);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The student moves first; the engine takes the other side.',
                style: AppText.caption.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Goal', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                key: const Key('homework-engine-goal'),
                segments: const [
                  ButtonSegment(value: 'win', label: Text('Win')),
                  ButtonSegment(value: 'hold', label: Text('Hold')),
                  ButtonSegment(value: 'survive', label: Text('Survive')),
                ],
                selected: {_goal},
                showSelectedIcon: false,
                onSelectionChanged: (picked) {
                  if (picked.isEmpty) return;
                  setState(() => _goal = picked.first);
                },
              ),
              if (_goal == 'survive') ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Own moves to survive: $_surviveMoves',
                    style: Theme.of(context).textTheme.labelLarge),
                Slider(
                  value: _surviveMoves.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: '$_surviveMoves',
                  onChanged: (v) => setState(() => _surviveMoves = v.round()),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('Engine strength (optional)',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('App default'),
                    selected: _level == null,
                    onSelected: (_) => setState(() => _level = null),
                  ),
                  for (final entry in const {
                    'lako': 'Easy',
                    'srednje': 'Medium',
                    'tesko': 'Hard',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _level == entry.key,
                      onSelected: (_) => setState(() => _level = entry.key),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: TextStyle(color: colors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('homework-engine-submit'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
