import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// What the room's bar says about who is in it — phase 2 of
/// docs/PLAN-SESIJA.md.
///
/// The roster used to be a card far down the right column, below the move tree
/// and the trainer's switches. On 21.9.2026 two people sat alone in two
/// different rooms and nothing on either screen said so: a student alone in a
/// room saw a board. **A room says who is here, where it cannot be missed** —
/// and says it loudest when the answer is „nobody".
///
/// Pure on purpose: the roster arrives over Socket.IO, which a widget test has
/// none of, so everything worth testing is in [presenceLine].
class RoomPresenceTitle extends StatelessWidget {
  const RoomPresenceTitle({
    super.key,
    required this.status,
    required this.members,
    required this.myId,
    required this.compact,
  });

  /// „Room: 123456", „Connecting...", „Preparation".
  final String status;

  /// `room_members_list` as the server sent it: maps with `userId`, `name`,
  /// `role`. Empty until the first one arrives — and always, in Preparation.
  final List<dynamic> members;
  final Object? myId;

  /// The 44 px bar of a phone on its side: one line, not two.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final presence = presenceLine(members, myId);
    if (presence == null) {
      return Text(status, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final color =
        presence.alone ? context.colors.warning : context.colors.textSecondary;
    // A shape as well as a colour: the owner is colourblind, and „you are
    // alone here" is the one thing this line must not leave to a hue.
    final icon = presence.alone ? Icons.hourglass_empty : Icons.people;

    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            presence.text,
            key: const Key('room-presence-line'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: color),
          ),
        ),
      ],
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Flexible(child: line),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
        line,
      ],
    );
  }
}

/// What to say about [members] to the person with [myId]; null while there is
/// nothing to say (no roster yet, or Preparation).
///
/// `alone` is true whenever the person this session needs is missing: nobody
/// else at all, or — for somebody who is not leading — no trainer.
({String text, bool alone})? presenceLine(List<dynamic> members, Object? myId) {
  final people = [
    for (final m in members)
      if (m is Map) m,
  ];
  if (people.isEmpty) return null;

  bool isMe(Map m) => '${m['userId']}' == '$myId';
  final me = people.where(isMe).firstOrNull;
  final others = people.where((m) => !isMe(m)).toList();
  final iLead = me != null && me['role'] == 'trener';

  if (others.isEmpty) {
    return (
      text: iLead ? 'Nobody has joined yet' : 'Waiting for the trainer',
      alone: true,
    );
  }

  final names = others.map((m) => '${m['name'] ?? 'Guest'}').join(', ');
  final trainerHere = iLead || others.any((m) => m['role'] == 'trener');
  if (!trainerHere) {
    return (text: 'Waiting for the trainer · with $names', alone: true);
  }
  return (text: 'With $names', alone: false);
}
