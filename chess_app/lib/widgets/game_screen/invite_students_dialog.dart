import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Who to call into a running session — docs/PLAN-SESIJA.md, §5.6.
///
/// The list is the account's **accepted students** and nobody else: whoever
/// starts a session is teaching in it, and the server takes no other
/// invitation. It used to read `/friends`, which holds both directions of every
/// relationship, so a student was offered their trainer (reported 21.9.2026).
///
/// **A group is a way of ticking people, not a second kind of recipient** — the
/// rule the homework dialog already follows. A group's chip ticks its members
/// as they are today, the names stay visible and can be unticked one by one,
/// and what is sent is a list of people. So there is nothing for the server to
/// learn about groups here, and a student who left a group last week is not
/// invited through it.
///
/// Pops with the chosen ids, or null.
class InviteStudentsDialog extends StatefulWidget {
  const InviteStudentsDialog({
    super.key,
    required String this.roomCode,
    required this.groupApi,
  })  : title = 'Invite students to session',
        heading = null,
        prompt = 'Select the students you want to invite:',
        action = 'Send invitations',
        initial = const {},
        mayBeEmpty = false;

  /// The same list for sharing a recorded lesson (phase 5b.4 of
  /// docs/PLAN-SESIJA.md): those it is shared with are ticked, and an empty
  /// list is an answer — unticking everybody takes the share back.
  const InviteStudentsDialog.share({
    super.key,
    required String recordingTitle,
    required this.groupApi,
    required this.initial,
  })  : roomCode = null,
        title = 'Share with students',
        heading = recordingTitle,
        prompt = 'Who may watch this recording:',
        action = 'Share',
        mayBeEmpty = true;

  final String? roomCode;
  final GroupApiService groupApi;
  final String title;
  final String? heading;
  final String prompt;
  final String action;
  final Set<int> initial;
  final bool mayBeEmpty;

  @override
  State<InviteStudentsDialog> createState() => _InviteStudentsDialogState();
}

class _InviteStudentsDialogState extends State<InviteStudentsDialog> {
  /// Null while loading; [_loadFailed] says whether the null that follows is
  /// „could not ask", which must never be drawn as „you have nobody".
  List<Map<String, dynamic>>? _students;
  bool _loadFailed = false;
  List<StudentGroup> _groups = const [];
  final Map<int, List<int>> _membersOf = {};
  int? _loadingGroup;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initial);
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      widget.groupApi.acceptedStudents(),
      widget.groupApi.list(),
    ]);
    if (!mounted) return;
    final students = results[0] as List<Map<String, dynamic>>?;
    setState(() {
      _students = students ?? const [];
      _loadFailed = students == null;
      // A group with nobody in it has nothing to tick.
      _groups = [
        for (final g in results[1] as List<StudentGroup>)
          if (g.members > 0) g,
      ];
    });
  }

  Set<int> get _studentIds =>
      {for (final s in _students ?? const []) (s['id'] as num).toInt()};

  /// The members of [groupId] this account may invite. Membership rows can
  /// outlive a relationship; the student list is what decides.
  List<int> _eligibleIn(int groupId) => [
        for (final id in _membersOf[groupId] ?? const <int>[])
          if (_studentIds.contains(id)) id,
      ];

  bool _groupTicked(int groupId) {
    final eligible = _eligibleIn(groupId);
    return eligible.isNotEmpty && eligible.every(_selected.contains);
  }

  Future<void> _toggleGroup(StudentGroup group) async {
    if (!_membersOf.containsKey(group.id)) {
      setState(() => _loadingGroup = group.id);
      final members = await widget.groupApi.members(group.id);
      if (!mounted) return;
      _membersOf[group.id] = [for (final m in members) m.id];
      _loadingGroup = null;
    }
    final eligible = _eligibleIn(group.id);
    setState(() {
      if (_groupTicked(group.id)) {
        _selected.removeAll(eligible);
      } else {
        _selected.addAll(eligible);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final students = _students;

    return AlertDialog(
      // The default inset leaves about 280 px on a 360 dp phone.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          Icon(Icons.person_add, color: colors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(widget.title, style: AppText.title),
          ),
        ],
      ),
      // One scroll for the whole body, not a list with a fixed share of it: on
      // a phone held sideways the header and the chips took everything and the
      // list was measured 9 px tall. `AlertDialog` caps the content to the
      // height that exists, and this scrolls inside that.
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  widget.roomCode != null
                      ? 'Room: ${widget.roomCode}'
                      : widget.heading ?? '',
                  style: AppText.bodyBold.copyWith(color: colors.accent)),
              const SizedBox(height: AppSpacing.sm),
              if (students == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadFailed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Could not load list.',
                      style: AppText.caption.copyWith(color: colors.warning)),
                )
              else if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                      'You have no students yet. Students who accepted you '
                      'appear here.',
                      style: AppText.caption.copyWith(color: colors.textMuted)),
                )
              else ...[
                if (_groups.isNotEmpty) ...[
                  Text('A whole group:', style: AppText.caption),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final group in _groups)
                        FilterChip(
                          key: ValueKey('invite-group-${group.id}'),
                          avatar: _loadingGroup == group.id
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.groups, size: 16),
                          label: Text('${group.name} (${group.members})'),
                          selected: _groupTicked(group.id),
                          onSelected: _loadingGroup == null
                              ? (_) => _toggleGroup(group)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(widget.prompt, style: AppText.body),
                const SizedBox(height: AppSpacing.sm),
                for (final s in students)
                  CheckboxListTile(
                    key: ValueKey('invite-student-${s['id']}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['name'] ?? 'Student'}',
                        style: AppText.bodyBold),
                    value: _selected.contains((s['id'] as num).toInt()),
                    onChanged: (ticked) => setState(() {
                      final id = (s['id'] as num).toInt();
                      if (ticked == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    }),
                  ),
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
        ElevatedButton(
          key: const Key('invite-send'),
          onPressed: _selected.isEmpty && !widget.mayBeEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()..sort()),
          child: Text(_selected.isEmpty
              ? widget.action
              : '${widget.action} (${_selected.length})'),
        ),
      ],
    );
  }
}
