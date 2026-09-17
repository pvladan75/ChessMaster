/// The trainer's homework editor — `docs/PLAN-DOMACI-ZADATAK.md` §5, phase 3b.
///
/// Its gate is `docs/gates/homework_editor_test.dart`, copied unchanged into
/// `test/`: the header there states the exact widget keys this screen must
/// carry. The one rule the server already keeps and this screen must not
/// break is that an item's key travels with it across a reorder — this class
/// never renumbers a saved item's identity, only the list order, and never
/// sends `position` at all (the server numbers the list it receives).
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/course_picker_dialog.dart';
import 'package:chess_app/features/library/widgets/position_picker_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

import '../models/homework.dart';
import '../services/homework_api_service.dart';
import '../widgets/homework_item_pickers.dart';

class HomeworkEditorScreen extends StatefulWidget {
  const HomeworkEditorScreen({
    super.key,
    this.homeworkId,
    required this.api,
  });

  /// Null for a homework never saved — the first save is a `POST`.
  final int? homeworkId;
  final HomeworkApiService api;

  @override
  State<HomeworkEditorScreen> createState() => _HomeworkEditorScreenState();
}

/// One row's identity in this sitting: the item's own key once it has one,
/// or `new-N` counting the items added here, in the order added — never the
/// row's position, which a reorder changes.
class _Row {
  _Row(this.localKey, this.item);
  final String localKey;
  HomeworkItem item;
}

class _HomeworkEditorScreenState extends State<HomeworkEditorScreen> {
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();

  /// Built against the same client [HomeworkApiService] reads and writes
  /// through, so a test that hands the editor a `MockClient` sees every
  /// request the "Add" pickers make as well as the save (rule 7: fake the
  /// client, not the method).
  late final PositionLibraryService _positionLibrary = PositionLibraryService(
    authToken: widget.api.authToken,
    client: widget.api.client,
  );

  List<_Row> _rows = [];
  int _newCounter = 0;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.homeworkId != null) _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final homework = await widget.api.load(widget.homeworkId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (homework != null) {
        _titleController.text = homework.title;
        _instructionsController.text = homework.instructions ?? '';
        _rows = [
          for (final item in homework.items) _Row(item.itemKey!, item),
        ];
      }
    });
    if (homework == null) {
      AppFeedback.error(
        context,
        widget.api.lastError ?? 'Could not load that homework.',
      );
    }
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(index);
      _rows.insert(target, row);
    });
  }

  void _remove(int index) {
    setState(() => _rows.removeAt(index));
  }

  void _setGate(int index, bool value) {
    setState(() => _rows[index].item = _rows[index].item.copyWith(gate: value));
  }

  void _setRequireSolved(int index, bool value) {
    setState(() =>
        _rows[index].item = _rows[index].item.copyWith(requireSolved: value));
  }

  void _addRow(HomeworkItemKind kind, Map<String, dynamic> task) {
    setState(() {
      _newCounter++;
      _rows.add(_Row(
        'new-$_newCounter',
        HomeworkItem(
          itemKey: null,
          kind: kind,
          task: task,
          gate: false,
          requireSolved: false,
        ),
      ));
    });
  }

  Future<void> _onAdd() async {
    final kind = await showModalBottomSheet<HomeworkItemKind>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('A tutorial'),
              onTap: () => Navigator.pop(sheetContext, HomeworkItemKind.lesson),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Positions'),
              onTap: () =>
                  Navigator.pop(sheetContext, HomeworkItemKind.positions),
            ),
            ListTile(
              leading: const Icon(Icons.extension_outlined),
              title: const Text('A puzzle set'),
              onTap: () =>
                  Navigator.pop(sheetContext, HomeworkItemKind.puzzles),
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Play it out'),
              onTap: () =>
                  Navigator.pop(sheetContext, HomeworkItemKind.engineGame),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;

    switch (kind) {
      case HomeworkItemKind.lesson:
        final course = await showDialog<CourseSummary>(
          context: context,
          builder: (_) => CoursePickerDialog(
            service: _positionLibrary,
            title: 'Which tutorial for this item?',
          ),
        );
        if (course == null || !mounted) return;
        _addRow(HomeworkItemKind.lesson, {'lessonId': course.id});

      case HomeworkItemKind.positions:
        final chosen = await showDialog<List<LibraryEntry>>(
          context: context,
          builder: (_) => PositionPickerDialog(
            service: _positionLibrary,
            purpose: PickerPurpose.homework,
          ),
        );
        if (chosen == null || chosen.isEmpty || !mounted) return;
        _addRow(HomeworkItemKind.positions, {
          'puzzleIds': [for (final entry in chosen) entry.id],
        });

      case HomeworkItemKind.puzzles:
        final task = await pickPuzzleCriteria(context);
        if (task == null || !mounted) return;
        _addRow(HomeworkItemKind.puzzles, task);

      case HomeworkItemKind.engineGame:
        final task = await pickEngineGameTask(context,
            positionLibrary: _positionLibrary);
        if (task == null || !mounted) return;
        _addRow(HomeworkItemKind.engineGame, task);
    }
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);
    final instructions = _instructionsController.text.trim();
    final homework = Homework(
      id: widget.homeworkId,
      title: _titleController.text.trim(),
      instructions: instructions.isEmpty ? null : instructions,
      items: [for (final row in _rows) row.item],
    );

    final saved = await widget.api.save(homework);
    if (!mounted) return;
    setState(() => _saving = false);

    // Do the thing, then say it: the save already happened above; nothing
    // past this point can take it back or make it look like it did not.
    if (saved == null) {
      AppFeedback.error(context, widget.api.lastError ?? 'Could not save.');
      return;
    }
    AppFeedback.success(context, 'Homework saved.');
  }

  String _kindLabel(HomeworkItem item) {
    switch (item.kind) {
      case HomeworkItemKind.lesson:
        return 'Tutorial';
      case HomeworkItemKind.positions:
        final ids = item.task['puzzleIds'];
        final count = ids is List ? ids.length : 0;
        return 'Positions ($count)';
      case HomeworkItemKind.puzzles:
        final count = item.task['count'];
        return 'Puzzle set${count == null ? '' : ' ($count)'}';
      case HomeworkItemKind.engineGame:
        return 'Play it out';
    }
  }

  IconData _kindIcon(HomeworkItemKind kind) => switch (kind) {
        HomeworkItemKind.lesson => Icons.auto_stories_outlined,
        HomeworkItemKind.positions => Icons.push_pin_outlined,
        HomeworkItemKind.puzzles => Icons.extension_outlined,
        HomeworkItemKind.engineGame => Icons.smart_toy_outlined,
      };

  Widget _buildRow(BuildContext context, int index) {
    final colors = context.colors;
    final row = _rows[index];
    final item = row.item;
    final key = row.localKey;

    final iconButtonStyle = IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );

    return Container(
      key: Key('homework-item-$key'),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: AppRadii.roundedMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_kindIcon(item.kind), color: colors.accent, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(_kindLabel(item),
                    overflow: TextOverflow.ellipsis, style: AppText.body),
              ),
              IconButton(
                key: Key('homework-up-$key'),
                icon: const Icon(Icons.arrow_upward, size: 16),
                style: iconButtonStyle,
                tooltip: 'Move up',
                onPressed: index > 0 ? () => _move(index, -1) : null,
              ),
              IconButton(
                key: Key('homework-down-$key'),
                icon: const Icon(Icons.arrow_downward, size: 16),
                style: iconButtonStyle,
                tooltip: 'Move down',
                onPressed:
                    index < _rows.length - 1 ? () => _move(index, 1) : null,
              ),
              IconButton(
                key: Key('homework-remove-$key'),
                icon:
                    Icon(Icons.delete_outline, size: 16, color: colors.danger),
                style: iconButtonStyle,
                tooltip: 'Remove',
                onPressed: () => _remove(index),
              ),
            ],
          ),
          Row(
            children: [
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  key: Key('homework-gate-$key'),
                  value: item.gate,
                  onChanged: (v) => _setGate(index, v),
                ),
              ),
              Expanded(
                child: Text(
                  // The server ignores a gate on the first item — there is
                  // nothing before it to wait for — so the first row says so
                  // rather than pretending the switch does something here.
                  // One line: a longer sentence is cut rather than wrapped,
                  // so a screen full of items never grows past what a phone
                  // screen holds without scrolling to the „Save" button.
                  index == 0
                      ? 'Gate (no effect on the first item)'
                      : 'Gate: not before the previous item is done',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  key: Key('homework-solved-$key'),
                  value: item.requireSolved,
                  onChanged: (v) => _setRequireSolved(index, v),
                ),
              ),
              Expanded(
                child: Text(
                  'Solved: a student who cannot solve this cannot go on',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(widget.homeworkId == null ? 'New homework' : 'Homework'),
        backgroundColor: colors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('homework-title'),
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      key: const Key('homework-instructions'),
                      controller: _instructionsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Instructions (optional)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < _rows.length; i++)
                      _buildRow(context, i),
                    OutlinedButton.icon(
                      key: const Key('homework-add'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      onPressed: _onAdd,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ElevatedButton(
                      key: const Key('homework-save'),
                      onPressed: _saving ? null : _onSave,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
