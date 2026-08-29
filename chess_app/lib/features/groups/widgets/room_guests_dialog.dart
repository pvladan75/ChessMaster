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
///
/// The guest switch is the second half of the same question, and it is here
/// rather than in Settings because it belongs beside the list it is so easily
/// confused with. They are independent on purpose: **the list decides who is a
/// student in this room, the switch decides whether anybody at all may watch.**
/// Turning it on lets in whoever knows the six digits — so the room says that
/// in those words, while the switch is being flipped rather than afterwards.
/// `rooms.allow_guests` had existed for a day with no way to see it: a rule
/// nobody can look at is a rule nobody can rely on.
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

  /// Null means "not known": the answer never came. Drawn as a question rather
  /// than as an "off" switch, because a room full of children is not a place to
  /// guess about who may come in.
  bool? _allowGuests;
  String? _guestError;
  bool _savingGuests = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final guests = await _api.roomGuests(widget.roomCode);
    final groups = await _api.list();
    final students = widget.students ?? await _api.myStudents();
    final access = await _api.guestAccess(widget.roomCode);
    if (!mounted) return;
    setState(() {
      _guests = guests;
      _groups = groups;
      _students = students;
      _allowGuests = access.allowGuests;
      _guestError = access.error;
      _loading = false;
    });
  }

  /// Flips the guest door, and keeps whatever the room says afterwards — not
  /// what was asked for. A switch that snaps into the requested position and
  /// leaves the server where it was is this project's recurring bug wearing a
  /// different hat.
  Future<void> _setGuests(bool wanted) async {
    setState(() => _savingGuests = true);
    final result = await _api.setGuestAccess(widget.roomCode, wanted);
    // A write that failed leaves the question open, so it is asked again rather
    // than assumed either way.
    final settled =
        result.error == null ? result : await _api.guestAccess(widget.roomCode);
    if (!mounted) return;
    setState(() {
      _savingGuests = false;
      _allowGuests = settled.allowGuests;
      _guestError = result.error;
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
                  padding: EdgeInsets.all(AppSpacing.xxl),
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
                    if (_allowGuests == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Uz to, soba prima goste: ulazi i svako ko zna kod, '
                        'kao posmatrač, bez obzira na spisak.',
                        style: AppText.caption
                            .copyWith(color: context.colors.warning),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(_error!,
                          style: AppText.caption
                              .copyWith(color: context.colors.danger)),
                    ],
                    const SizedBox(height: AppSpacing.md),
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
                    const Divider(height: 20),
                    _buildGuestSwitch(context),
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

  /// The widest door in the room, drawn so it reads as one.
  ///
  /// Three states, and the third is the point: on, off, and *not known*. An
  /// answer that never arrived must not be painted as "off" — that is the exact
  /// shape of failure this project keeps paying for, a step that skips silently
  /// and reports success one layer up.
  Widget _buildGuestSwitch(BuildContext context) {
    if (_allowGuests == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 18, color: context.colors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            // The sentence stands whatever the reason was, and the reason is
            // added rather than substituted: "what is true of the room" and
            // "why I could not find out" are two different things to know.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ne znam da li soba prima goste — podešavanje nije moglo '
                  'da se pročita.',
                  style: AppText.caption.copyWith(color: context.colors.danger),
                ),
                if (_guestError != null)
                  Text(_guestError!,
                      style: AppText.micro
                          .copyWith(color: context.colors.textMuted)),
              ],
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Pokušaj ponovo')),
        ],
      );
    }

    final open = _allowGuests == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: open,
          onChanged: _savingGuests ? null : _setGuests,
          title: Text('Soba prima goste', style: AppText.bodyBold),
          subtitle: Text(
            open
                ? 'Uključeno: ulazi svako ko zna kod sobe, i neprijavljen. Ako '
                    'snimate čas, i on je u snimku.'
                : 'Isključeno: ulaze samo prijavljeni koje ste pozvali.',
            style: AppText.micro.copyWith(
              color: open ? context.colors.warning : context.colors.textMuted,
            ),
          ),
        ),
        if (_guestError != null)
          Text(_guestError!,
              style: AppText.caption.copyWith(color: context.colors.danger)),
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
          const SizedBox(height: AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.md),
        ],
        if (students.isNotEmpty) ...[
          Text('Pozovi pojedinačno',
              style: AppText.bodyBold.copyWith(color: context.colors.accent)),
          const SizedBox(height: AppSpacing.xs),
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
