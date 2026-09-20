/// The trainer's homeworks — the door both the Teach card and the Library
/// chip open onto (`docs/PLAN-DOMACI-ZADATAK.md` §5, phase 3b). *New
/// homework* and a row per homework, opening [HomeworkEditorScreen].
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/app_feedback.dart';

import '../models/homework.dart';
import '../services/homework_api_service.dart';
import '../widgets/homework_send_dialog.dart';
import 'homework_editor_screen.dart';

class HomeworkListScreen extends StatefulWidget {
  const HomeworkListScreen({super.key, required this.api, this.groupApi});

  final HomeworkApiService api;

  /// The student list the send dialog offers. For tests, which have no
  /// server to answer.
  final GroupApiService? groupApi;

  @override
  State<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends State<HomeworkListScreen> {
  List<Homework>? _homeworks;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.api.list();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _homeworks = list;
    });
  }

  Future<void> _openEditor({int? homeworkId}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          HomeworkEditorScreen(homeworkId: homeworkId, api: widget.api),
    ));
    if (mounted) _load();
  }

  /// Sending is its own act, from the row: writing a homework and giving it
  /// to somebody are two things, and the list is where a trainer picks which
  /// homework to give.
  Future<void> _send(Homework homework) async {
    if (homework.id == null) return;
    final sent = await showHomeworkSendDialog(
      context,
      api: widget.api,
      homeworkId: homework.id!,
      title: homework.title,
      groupApi: widget.groupApi,
    );
    // „Sent to" on the row is now out of date.
    if (sent && mounted) _load();
  }

  /// Deleting a template is asked about first — it is one tap beside a row,
  /// there is no undo, and what it does needs saying: the homeworks already
  /// sent are untouched (`assignments.homework_id` is `ON DELETE SET NULL`,
  /// `chess_backend/db.js`), so a student in the middle of one keeps it.
  Future<void> _delete(Homework homework) async {
    if (homework.id == null) return;
    final sent = homework.sentCount ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${homework.title}"?'),
        content: Text(
          sent > 0
              ? 'The template goes; the $sent ${sent == 1 ? 'homework' : 'homeworks'} '
                  'already sent stay with the students who have them.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('homework-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await widget.api.remove(homework.id!);
    if (!mounted) return;
    if (!ok) {
      AppFeedback.error(context, widget.api.lastError ?? 'Could not delete.');
      return;
    }
    AppFeedback.success(context, 'Homework deleted.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Homework'),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('homework-list-new'),
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New homework'),
      ),
      body: _body(colors),
    );
  }

  Widget _body(AppColorTokens colors) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final homeworks = _homeworks ?? const <Homework>[];
    if (homeworks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Text(
            'No homework yet. "New homework" starts one.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    return AdaptiveCardGrid(
      itemCount: homeworks.length,
      itemBuilder: (context, index) {
        final homework = homeworks[index];
        final items = homework.itemCount ?? homework.items.length;
        final sent = homework.sentCount ?? 0;
        return Card(
          key: Key('homework-list-row-${homework.id}'),
          shape: AppRadii.cardShape,
          child: ListTile(
            title: Text(homework.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '$items ${items == 1 ? 'item' : 'items'}'
              '${sent > 0 ? ' · sent to $sent' : ''}',
            ),
            onTap: () => _openEditor(homeworkId: homework.id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('homework-list-send-${homework.id}'),
                  icon: Icon(Icons.send_outlined, color: colors.accent),
                  tooltip: 'Send to a student',
                  onPressed: () => _send(homework),
                ),
                IconButton(
                  key: Key('homework-list-delete-${homework.id}'),
                  icon: Icon(Icons.delete_outline, color: colors.danger),
                  tooltip: 'Delete',
                  onPressed: () => _delete(homework),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
