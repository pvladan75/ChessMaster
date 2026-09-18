/// Sending a written homework to students — `docs/PLAN-DOMACI-ZADATAK.md`
/// §5, phase 4's app half.
///
/// Writing a homework and sending it are two acts (the owner's rule), and
/// this is the second one's only door. It is one request per student, which
/// is what makes the quota rule true: the server charges one unit per
/// request, so a five-item homework costs one unit per student and three
/// students cost three. Nothing here batches that into a single call — a
/// batch would have to answer „sent to two of three" with one status code,
/// and the trainer would not know which two.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

import '../services/homework_api_service.dart';

/// What one sending did, as one sentence and one flag.
class HomeworkSendResult {
  const HomeworkSendResult({
    required this.anySent,
    required this.anyRefused,
    required this.message,
  });

  /// At least one student has the homework now, so a list showing „sent to"
  /// is out of date.
  final bool anySent;

  /// At least one student did not get it. Its own flag rather than something
  /// read back out of [message]: a refusal must not be missed because a
  /// student's name happens to contain the punctuation the reader looked for.
  final bool anyRefused;

  /// What to tell the trainer: who got it, and the server's own sentence for
  /// every student it refused.
  final String message;
}

/// Opens the send dialog for [homeworkId], says what happened, and answers
/// whether at least one student got it.
///
/// The saying is done here, with the caller's context, rather than inside the
/// dialog: a dialog that pops itself and then speaks is speaking through a
/// context that is already gone, and `AppFeedback` would correctly say
/// nothing at all.
Future<bool> showHomeworkSendDialog(
  BuildContext context, {
  required HomeworkApiService api,
  required int homeworkId,
  required String title,
  GroupApiService? groupApi,
}) async {
  final result = await showDialog<HomeworkSendResult>(
    context: context,
    builder: (_) => HomeworkSendDialog(
      api: api,
      homeworkId: homeworkId,
      title: title,
      groupApi: groupApi,
    ),
  );
  if (result == null || !context.mounted) return false;
  if (result.anyRefused) {
    AppFeedback.error(context, result.message);
  } else {
    AppFeedback.success(context, result.message);
  }
  return result.anySent;
}

class HomeworkSendDialog extends StatefulWidget {
  const HomeworkSendDialog({
    super.key,
    required this.api,
    required this.homeworkId,
    required this.title,
    this.groupApi,
  });

  final HomeworkApiService api;
  final int homeworkId;
  final String title;

  /// For tests, which have no server to answer.
  final GroupApiService? groupApi;

  @override
  State<HomeworkSendDialog> createState() => _HomeworkSendDialogState();
}

/// What became of one student's copy.
class _Outcome {
  const _Outcome(this.name, this.error);
  final String name;
  final String? error;
}

class _HomeworkSendDialogState extends State<HomeworkSendDialog> {
  late final GroupApiService _groups = widget.groupApi ?? GroupApiService();
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _students = const [];
  final Set<int> _picked = {};
  DateTime? _dueAt;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final all = await _groups.myStudents();
    if (!mounted) return;
    setState(() {
      _loading = false;
      // Only students who have accepted: an invitation nobody has answered
      // grants nothing, the server refuses it, and offering the name here
      // would promise something this trainer cannot do yet.
      _students =
          all.where((student) => student['status'] == 'accepted').toList();
    });
  }

  int? _idOf(Map<String, dynamic> student) {
    final raw = student['id'];
    return raw is int ? raw : int.tryParse('$raw');
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _dueAt = picked);
  }

  /// One request per student, in the order they are listed, each answered
  /// before the next is asked. A student the server refuses is named with the
  /// server's own sentence, and the students it accepted are still reported
  /// as sent — half a send is a fact, not an error to swallow.
  Future<void> _send() async {
    setState(() => _sending = true);
    final results = <_Outcome>[];
    for (final student in _students) {
      final id = _idOf(student);
      if (id == null || !_picked.contains(id)) continue;
      final error = await widget.api.send(
        homeworkId: widget.homeworkId,
        studentId: id,
        dueAt: _dueAt,
        note: _noteController.text,
      );
      results.add(_Outcome(student['name']?.toString() ?? 'Student', error));
    }
    if (!mounted) return;
    setState(() => _sending = false);

    // Do the thing, then say it — and say it where there is still a screen
    // to say it on, which is the caller's, not this dialog's.
    Navigator.of(context).pop(HomeworkSendResult(
      anySent: results.any((r) => r.error == null),
      anyRefused: results.any((r) => r.error != null),
      message: _summary(results),
    ));
  }

  /// What to tell the trainer, naming every student the server refused and
  /// why. Never „sent" on its own when something did not go.
  String _summary(List<_Outcome> results) {
    final sent = results.where((r) => r.error == null).map((r) => r.name);
    final refused = results.where((r) => r.error != null);
    final parts = <String>[];
    if (sent.isNotEmpty) parts.add('Sent to ${sent.join(', ')}.');
    for (final one in refused) {
      parts.add('${one.name}: ${one.error}');
    }
    return parts.isEmpty ? 'Nothing was sent.' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = MediaQuery.of(context).size.width - 96;

    return AlertDialog(
      title: Text('Send "${widget.title}"'),
      content: SizedBox(
        width: width.clamp(180.0, 420.0),
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              )
            : _students.isEmpty
                ? Text(
                    'You have no students who have accepted the invitation.',
                    style: AppText.body.copyWith(color: colors.textSecondary),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final student in _students) _studentRow(student),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dueAt == null
                                    ? 'No due date'
                                    : 'Due ${_dueAt!.day}.${_dueAt!.month}.${_dueAt!.year}.',
                                style: AppText.body,
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('homework-send-due'),
                              onPressed: _pickDueDate,
                              icon: const Icon(Icons.event, size: 16),
                              label: const Text('Due date'),
                            ),
                          ],
                        ),
                        TextField(
                          key: const Key('homework-send-note'),
                          controller: _noteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'A note for this sending (optional)',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Each student counts as one homework against your '
                          'quota, whatever it holds.',
                          style:
                              AppText.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('homework-send-confirm'),
          // Nothing to send to is not a send: the button stays off rather
          // than answering „Nothing was sent" after a tap.
          onPressed: _picked.isEmpty || _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_picked.length > 1 ? 'Send to ${_picked.length}' : 'Send'),
        ),
      ],
    );
  }

  Widget _studentRow(Map<String, dynamic> student) {
    final id = _idOf(student);
    if (id == null) return const SizedBox.shrink();
    return CheckboxListTile(
      key: Key('homework-send-student-$id'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _picked.contains(id),
      title: Text(student['name']?.toString() ?? 'Student'),
      onChanged: _sending
          ? null
          : (on) => setState(() {
                if (on == true) {
                  _picked.add(id);
                } else {
                  _picked.remove(id);
                }
              }),
    );
  }
}
