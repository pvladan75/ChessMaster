import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Who may come into this room.
///
/// This is what groups are for. Empty, the room means what it always meant —
/// every student who has accepted this trainer may join. The moment one group
/// or one name is on the list, the room is those people and nobody else, which
/// is the only honest reading of "invite this group".
///
/// The dialog says that out loud rather than leaving it to be discovered: a
/// screen that quietly changes who can get in is the same class of surprise as
/// a control that works while its button is hidden.
class RoomGuestsDialog extends StatefulWidget {
  const RoomGuestsDialog({
    super.key,
    required this.roomCode,
    this.students,
    this.api,
  });

  final String roomCode;

  /// The trainer's students, as the rest of the app has them: rows with `id`,
  /// `name` and `status`. Fetched here when nobody hands them over, so opening
  /// this dialog does not depend on which screen it was opened from. Only
  /// accepted students can be invited, and the server checks that again.
  final List<dynamic>? students;

  final GroupApiService? api;

  @override
  State<RoomGuestsDialog> createState() => _RoomGuestsDialogState();
}

class _RoomGuestsDialogState extends State<RoomGuestsDialog> {
  late final GroupApiService _api = widget.api ?? GroupApiService();

  List<RoomGuest> _guests = const [];
  List<StudentGroup> _groups = const [];
  List<dynamic> _students = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final guests = await _api.roomGuests(widget.roomCode);
    final groups = await _api.list();
    final students = widget.students ?? await _api.myStudents();
    if (!mounted) return;
    setState(() {
      _guests = guests;
      _groups = groups;
      _students = students;
      _loading = false;
    });
  }

  List<StudentGroup> get _addableGroups {
    final already = {
      for (final guest in _guests)
        if (guest.isGroup) guest.id
    };
    return _groups.where((group) => !already.contains(group.id)).toList();
  }

  List<Map<String, dynamic>> get _addableStudents {
    final already = {
      for (final guest in _guests)
        if (!guest.isGroup) guest.id
    };
    return _students
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['status'] == 'accepted')
        .where((row) => !already.contains(row['id']))
        .toList();
  }

  Future<void> _inviteGroup(StudentGroup group) async {
    final error = await _api.invite(widget.roomCode, groupIds: [group.id]);
    if (!mounted) return;
    setState(() => _error = error);
    await _load();
  }

  Future<void> _inviteStudent(Map<String, dynamic> student) async {
    final error =
        await _api.invite(widget.roomCode, userIds: [student['id'] as int]);
    if (!mounted) return;
    setState(() => _error = error);
    await _load();
  }

  Future<void> _remove(RoomGuest guest) async {
    final error = await _api.uninvite(
      widget.roomCode,
      groupId: guest.isGroup ? guest.id : null,
      userId: guest.isGroup ? null : guest.id,
    );
    if (!mounted) return;
    setState(() => _error = error);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ko sme u sobu'),
      content: SizedBox(
        width: 460,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _guests.isEmpty
                          ? 'Spisak je prazan: soba je otvorena za sve vaše '
                              'učenike. Čim dodate grupu ili nekoga poimence, '
                              'ulaze samo oni.'
                          : 'Ulaze samo oni sa ovog spiska.',
                      style: AppText.caption.copyWith(
                        color: _guests.isEmpty
                            ? context.colors.textMuted
                            : context.colors.accent,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: AppText.caption
                              .copyWith(color: context.colors.danger)),
                    ],
                    const SizedBox(height: 12),
                    for (final guest in _guests)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            guest.isGroup ? Icons.groups : Icons.person_outline,
                            size: 18),
                        title: Text(guest.name, style: AppText.body),
                        subtitle: guest.isGroup
                            ? Text('cela grupa',
                                style: AppText.micro
                                    .copyWith(color: context.colors.textMuted))
                            : null,
                        trailing: IconButton(
                          tooltip: 'Skini sa spiska',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _remove(guest),
                        ),
                      ),
                    const Divider(height: 20),
                    _buildAdders(context),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Gotovo'),
        ),
      ],
    );
  }

  Widget _buildAdders(BuildContext context) {
    final groups = _addableGroups;
    final students = _addableStudents;

    if (groups.isEmpty && students.isEmpty) {
      return Text(
        'Nema više koga da se doda. Grupe se prave u „Ljudi → Grupe učenika".',
        style: AppText.caption.copyWith(color: context.colors.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groups.isNotEmpty) ...[
          Text('Pozovi grupu',
              style: AppText.bodyBold.copyWith(color: context.colors.accent)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final group in groups)
                ActionChip(
                  avatar: const Icon(Icons.groups, size: 16),
                  label: Text('${group.name} (${group.members})'),
                  onPressed: () => _inviteGroup(group),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (students.isNotEmpty) ...[
          Text('Pozovi pojedinačno',
              style: AppText.bodyBold.copyWith(color: context.colors.accent)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final student in students)
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt, size: 16),
                  label: Text(student['name']?.toString() ?? 'Učenik'),
                  onPressed: () => _inviteStudent(student),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
