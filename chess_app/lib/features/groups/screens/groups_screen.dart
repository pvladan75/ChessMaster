import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Groups of students: the list, and who is in each.
///
/// Asked for with a plain reason: with forty students, inviting the same eight
/// every Tuesday means going down a list and finding them each time. The group
/// is that list, named once — and this screen is where it gets named.
///
/// Only names are shown. The address used to travel through every list of
/// people in this app and no longer does: most of the people here are children,
/// and a trainer who needs to write to one already knows how.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({
    super.key,
    required this.students,
    this.api,
  });

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

  /// The group whose members are open, and who they are. One at a time: the
  /// list is short and a screen of nested lists is a screen nobody reads.
  int? _openGroupId;
  List<NamedPerson> _members = const [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final groups = await _api.list();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _openMembers(StudentGroup group) async {
    if (_openGroupId == group.id) {
      setState(() {
        _openGroupId = null;
        _members = const [];
      });
      return;
    }
    setState(() {
      _openGroupId = group.id;
      _loadingMembers = true;
      _members = const [];
    });
    final members = await _api.members(group.id);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loadingMembers = false;
    });
  }

  Future<void> _create() async {
    final name = await _askForName(title: 'Nova grupa');
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

  Future<void> _rename(StudentGroup group) async {
    final name =
        await _askForName(title: 'Novo ime grupe', initial: group.name);
    if (name == null || !mounted) return;
    final error = await _api.rename(group.id, name);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) await _load();
  }

  Future<void> _delete(StudentGroup group) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Obrisati „${group.name}"?'),
        content: const Text(
          'Grupa nestaje, učenici ostaju vaši. Sobe koje su je imale na spisku '
          'zvanica gube taj red.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    final error = await _api.remove(group.id);
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null && _openGroupId == group.id) _openGroupId = null;
    });
    if (error == null) await _load();
  }

  Future<String?> _askForName({required String title, String? initial}) async {
    // The dialog owns its controller rather than this method: disposing one
    // the moment `showDialog` returns kills it while the dialog is still
    // animating out, and the field rebuilds one frame later against a
    // controller that no longer exists.
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );
    return (name == null || name.isEmpty) ? null : name;
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

  Future<void> _addMembers(StudentGroup group) async {
    final chosen = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => _PickStudents(students: _addable),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;

    String? error;
    for (final studentId in chosen) {
      error = await _api.addMember(group.id, studentId) ?? error;
    }
    if (!mounted) return;
    setState(() => _error = error);
    await _refreshOpen(group);
  }

  Future<void> _removeMember(StudentGroup group, NamedPerson member) async {
    final error = await _api.removeMember(group.id, member.id);
    if (!mounted) return;
    setState(() => _error = error);
    await _refreshOpen(group);
  }

  Future<void> _refreshOpen(StudentGroup group) async {
    final members = await _api.members(group.id);
    final groups = await _api.list();
    if (!mounted) return;
    setState(() {
      _members = members;
      _groups = groups;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('Grupe učenika'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nova grupa'),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_error!,
                style: AppText.caption.copyWith(color: context.colors.danger)),
          ),
        Expanded(
          child: _groups.isEmpty ? _buildEmpty(context) : _buildList(context),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 40),
            const SizedBox(height: 12),
            Text('Još nema grupa.',
                style: AppText.bodyBold, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Grupa je spisak učenika, imenovan jednom. Kad pozivate u sobu, '
              'pozovete grupu umesto da svaki put tražite iste ljude po '
              'spisku.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final group = _groups[i];
        final open = _openGroupId == group.id;
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.groups),
                title: Text(group.name, style: AppText.bodyBold),
                subtitle: Text(
                  group.members == 1 ? '1 učenik' : '${group.members} učenika',
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Preimenuj',
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _rename(group),
                    ),
                    IconButton(
                      tooltip: 'Obriši',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _delete(group),
                    ),
                    Icon(open ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
                onTap: () => _openMembers(group),
              ),
              if (open) _buildMembers(context, group),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMembers(BuildContext context, StudentGroup group) {
    if (_loadingMembers) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_members.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Grupa je prazna.',
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted)),
            )
          else
            for (final member in _members)
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(member.name, style: AppText.body)),
                  IconButton(
                    tooltip: 'Ukloni iz grupe',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _removeMember(group, member),
                  ),
                ],
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addMembers(group),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Dodaj učenike'),
            ),
          ),
        ],
      ),
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
      title: const Text('Dodaj u grupu'),
      content: SizedBox(
        width: 420,
        child: widget.students.isEmpty
            ? Text(
                'Nema učenika koje biste dodali. U grupu ulaze samo oni koji su '
                'prihvatili vezu sa vama.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final student in widget.students)
                      CheckboxListTile(
                        dense: true,
                        value: _chosen.contains(student['id']),
                        title: Text(student['name']?.toString() ?? 'Učenik'),
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
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(_chosen.toList()),
          child: const Text('Dodaj'),
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
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

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
          labelText: 'Ime grupe',
          hintText: 'npr. Utorak 18h',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}
