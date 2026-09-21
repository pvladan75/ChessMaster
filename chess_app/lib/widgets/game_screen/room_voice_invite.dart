import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Who is in the voice other than [myId], as the server's `audio_users_list`
/// has them. Ids are compared as text: a guest's is a socket id.
List<Map> voiceUsersOther(List<dynamic> audioUsers, Object? myId) => [
      for (final u in audioUsers)
        if (u is Map && '${u['userId']}' != '$myId') u,
    ];

/// What the room's bar says to somebody who is **not hearing** a session that
/// is being spoken — phase 4 of docs/PLAN-SESIJA.md. Null while there is
/// nothing to say: their own voice is on, or nobody else's is.
///
/// The trainer is the name said, because that is who a student came to hear;
/// the roster itself is in the order people pressed the button.
String? voiceInviteLine(List<dynamic> audioUsers,
    {required Object? myId, required bool voiceOn}) {
  if (voiceOn) return null;
  final others = voiceUsersOther(audioUsers, myId);
  if (others.isEmpty) return null;

  final named =
      others.where((u) => u['role'] == 'trener').firstOrNull ?? others.first;
  final name = '${named['userName'] ?? 'Participant'}';
  final rest = others.length - 1;
  if (rest == 0) return '$name is in voice';
  return '$name and $rest ${rest == 1 ? 'other' : 'others'} are in voice';
}

/// The strip under the room's bar that carries [voiceInviteLine] and the one
/// way to act on it. Drawn only while the line is not null — the caller passes
/// `null` to `AppBar.bottom` otherwise, so the board keeps its height.
///
/// The button calls the same `_joinVoice` the panel's button does: the
/// microphone still opens only by this person's own tap.
class RoomVoiceInvite extends StatelessWidget implements PreferredSizeWidget {
  const RoomVoiceInvite({super.key, required this.line, required this.onJoin});

  final String line;
  final VoidCallback onJoin;

  static const double height = 40;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final color = context.colors.success;
    return Container(
      height: height,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // A shape as well as a colour — see RoomPresenceTitle.
          Icon(Icons.record_voice_over, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                line,
                key: const Key('voice-invite-line'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppText.caption.copyWith(color: context.colors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonalIcon(
            key: const Key('voice-invite-join'),
            onPressed: onJoin,
            icon: const Icon(Icons.headset_mic, size: 16),
            label: const Text('Join voice'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              // Said outright: a desktop theme is compact by default, which
              // takes 8 px off the height asked for above.
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
