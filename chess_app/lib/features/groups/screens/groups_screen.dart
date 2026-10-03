import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

/// Groups of students: the list, and who is in each.
///
/// Asked for with a plain reason: with forty students, inviting the same eight
/// every Tuesday means going down a list and finding them each time. The group
/// is that list, named once — and this screen is where it gets named.
///
/// On a window (pattern B, `docs/PLAN-EKRANI.md` R7) the groups stand on the
/// left and the chosen group — the first one when the screen opens — on the
/// right, its members in columns. On a phone the list is alone and a tap opens
/// the group on a page of its own. „New group" is in the bar on both, because
/// a floating button lay over the last group's actions (R8).
///
/// Only names are shown. The address used to travel through every list of
/// people in this app and no longer does: most of the people here are children,
/// and a trainer who needs to write to one already knows how.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.students, this.api});

  /// The trainer's accepted students, as the rest of the app already has them:
  /// rows with `id`, `name` and `status`. Passed in rather than fetched again,
  /// so the two screens cannot disagree about who a student is.
  final List<dynamic> students;

  final GroupApiService? api;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupApiService _api = widget.api ?? GroupApiService();

  List<StudentGroup> _groups = const [];
  bool _loading = true;
  String? _error;

  /// The group shown in the pane. Null means the first one; a group that has
  /// gone from the list means the same.
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [quiet] reloads the list under the pane without the spinner, which would
  /// replace the pane and lose what it holds.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final groups = await _api.list();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  StudentGroup? get _selected {
    if (_groups.isEmpty) return null;
    for (final group in _groups) {
      if (group.id == _selectedId) return group;
    }
    return _groups.first;
  }

  Future<void> _create() async {
    final name = await _askForName(context, title: 'New group');
    if (name == null || !mounted) return;

    final made = await _api.create(name);
    if (!mounted) return;
    if (made.group == null) {
      setState(() => _error = made.error);
      return;
    }
    setState(() => _error = null);
    await _load();
  }

  Future<void> _afterDelete() async {
    setState(() => _selectedId = null);
    await _load(quiet: true);
  }

  Widget _detail(StudentGroup group, {required VoidCallback onDeleted}) {
    return _GroupDetail(
      key: ValueKey(group.id),
      api: _api,
      students: widget.students,
      group: group,
      onChanged: () => _load(quiet: true),
      onDeleted: onDeleted,
    );
  }

  void _open(StudentGroup group, {required bool wide}) {
    if (wide) {
      setState(() => _selectedId = group.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => Scaffold(
          backgroundColor: context.colors.canvas,
          appBar: AppBar(title: const Text('Student groups'), elevation: 0),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _detail(
                group,
                onDeleted: () {
                  Navigator.of(pageContext).pop();
                  _afterDelete();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Student groups'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New group'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              _error!,
              style: AppText.caption.copyWith(color: context.colors.danger),
            ),
          ),
        Expanded(
          child: _groups.isEmpty
              ? _buildEmpty(context)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= Breakpoints.wide;
                    final list = _buildList(context, wide: wide);
                    if (!wide) return list;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: _listWidth, child: list),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: _detail(_selected!, onDeleted: _afterDelete),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// About what the sketch gives the list: a name and a count, nothing wider.
  static const double _listWidth = 380;

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No groups yet.',
              style: AppText.bodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'A group is a list of students, named once. When inviting to a room, '
              'invite the group instead of searching for the same people on the '
              'list every time.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, {required bool wide}) {
    final selected = wide ? _selected?.id : null;
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final group = _groups[i];
        final chosen = group.id == selected;
        return Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.roundedMd,
            // The choice is an outline, as in the Library's list.
            side: chosen
                ? BorderSide(color: context.colors.accent, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: const Icon(Icons.groups),
            title: Text(group.name, style: AppText.bodyBold),
            subtitle: Text(
              _studentCount(group.members),
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(group, wide: wide),
          ),
        );
      },
    );
  }
}

String _studentCount(int n) => n == 1 ? '1 student' : '$n students';

Future<String?> _askForName(
  BuildContext context, {
  required String title,
  String? initial,
}) async {
  // The dialog owns its controller rather than this function: disposing one
  // the moment `showDialog` returns kills it while the dialog is still
  // animating out, and the field rebuilds one frame later against a
  // controller that no longer exists.
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
  return (name == null || name.isEmpty) ? null : name;
}

/// One group: its name and count, its actions, and who is in it.
///
/// Drawn in the window's pane and on the phone's own page alike, so the two
/// cannot drift. It owns its members and the four flows that change them —
/// rename, delete, add, remove — and tells the screen through [onChanged]
/// and [onDeleted] only that the list under it is out of date.
class _GroupDetail extends StatefulWidget {
  const _GroupDetail({
    super.key,
    required this.api,
    required this.students,
    required this.group,
    required this.onChanged,
    required this.onDeleted,
  });

  final GroupApiService api;
  final List<dynamic> students;
  final StudentGroup group;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  State<_GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends State<_GroupDetail> {
  late String _name = widget.group.name;
  List<NamedPerson> _members = const [];
  bool _loading = true;
  String? _error;

  StudentGroup get _group => widget.group;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(_GroupDetail old) {
    super.didUpdateWidget(old);
    if (old.group.name != widget.group.name) _name = widget.group.name;
  }

  Future<void> _loadMembers() async {
    final members = await widget.api.members(_group.id);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final name = await _askForName(
      context,
      title: 'New group name',
      initial: _name,
    );
    if (name == null || !mounted) return;
    final error = await widget.api.rename(_group.id, name);
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _name = name;
    });
    if (error == null) widget.onChanged();
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$_name"?'),
        content: const Text(
          'The group is removed, your students remain. Rooms that had it on their '
          'invitee list lose this entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    final error = await widget.api.remove(_group.id);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) widget.onDeleted();
  }

  /// The trainer's accepted students who are not in this group yet.
  ///
  /// Pending ones are left out on purpose: a group must not become a second way
  /// to attach yourself to somebody who has not agreed to be taught by you. The
  /// server refuses them too — this only keeps the screen from offering what
  /// the server will turn down.
  List<Map<String, dynamic>> get _addable {
    final inGroup = {for (final member in _members) member.id};
    return widget.students
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['status'] == 'accepted')
        .where((row) => !inGroup.contains(row['id']))
        .toList();
  }

  Future<void> _addMembers() async {
    final chosen = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => _PickStudents(students: _addable),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;

    String? error;
    for (final studentId in chosen) {
      error = await widget.api.addMember(_group.id, studentId) ?? error;
    }
    if (!mounted) return;
    setState(() => _error = error);
    await _refresh();
  }

  Future<void> _removeMember(NamedPerson member) async {
    final error = await widget.api.removeMember(_group.id, member.id);
    if (!mounted) return;
    setState(() => _error = error);
    await _refresh();
  }

  Future<void> _refresh() async {
    final members = await widget.api.members(_group.id);
    if (!mounted) return;
    setState(() => _members = members);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = _loading ? _group.members : _members.length;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_name, style: AppText.title),
                Text(
                  _studentCount(count),
                  style: AppText.caption.copyWith(color: colors.textMuted),
                ),
                TextButton.icon(
                  onPressed: _rename,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Rename'),
                ),
                TextButton.icon(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete group'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  style: AppText.caption.copyWith(color: colors.danger),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            _buildMembers(context),
            TextButton.icon(
              onPressed: _addMembers,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Add students'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembers(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          'Group is empty.',
          style: AppText.caption.copyWith(color: context.colors.textMuted),
        ),
      );
    }
    // Columns from the width the pane has, never written down.
    return AdaptiveCardGrid(
      itemCount: _members.length,
      tileHeight: 44,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final member = _members[i];
        return Container(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.canvas,
            borderRadius: AppRadii.roundedMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  member.name,
                  style: AppText.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Remove from group',
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => _removeMember(member),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ticking off who joins the group.
///
/// Only accepted students are offered: a group is a convenience, never a way
/// around somebody agreeing to be taught by you.
class _PickStudents extends StatefulWidget {
  const _PickStudents({required this.students});

  final List<Map<String, dynamic>> students;

  @override
  State<_PickStudents> createState() => _PickStudentsState();
}

class _PickStudentsState extends State<_PickStudents> {
  final Set<int> _chosen = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to group'),
      content: SizedBox(
        width: 420,
        child: widget.students.isEmpty
            ? Text(
                'No students to add. Only students who have accepted your '
                'invite can be added to a group.',
                style: AppText.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final student in widget.students)
                      CheckboxListTile(
                        dense: true,
                        value: _chosen.contains(student['id']),
                        title: Text(student['name']?.toString() ?? 'Student'),
                        onChanged: (on) => setState(() {
                          final id = student['id'] as int;
                          if (on == true) {
                            _chosen.add(id);
                          } else {
                            _chosen.remove(id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(_chosen.toList()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Asking for a group's name.
///
/// Its own widget so the controller lives exactly as long as the dialog does —
/// see `_askForName`, where doing it by hand outlived the dialog by a frame and
/// threw on the way out.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Group name',
          hintText: 'e.g. Tuesday 6pm',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
