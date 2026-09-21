import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The room's voice, all of it, in the panel the bar's voice chip opens —
/// phase 6 of docs/PLAN-SESIJA.md.
///
/// It used to be the „Audio Classroom" card at the bottom of the right column,
/// under the moves, where a phone reached it only by scrolling past everything
/// else. Pure on purpose: the states arrive from Agora and over Socket.IO,
/// which a widget test has none of, so everything is handed in and every
/// action is handed back.
class RoomVoicePanel extends StatelessWidget {
  const RoomVoicePanel({
    super.key,
    required this.isVoiceOn,
    required this.isConnecting,
    required this.error,
    required this.micProblem,
    required this.mayUseMic,
    required this.isMuted,
    required this.othersInCall,
    required this.users,
    required this.activeSpeakers,
    required this.myId,
    required this.isLeader,
    required this.isStudentSeat,
    required this.isHandRaised,
    required this.onJoin,
    required this.onLeave,
    required this.onToggleMute,
    required this.onSetHand,
    required this.onSetStudentVoice,
    required this.onMuteUser,
  });

  final bool isVoiceOn;
  final bool isConnecting;

  /// Why the voice did not start, kept whether it is on or off: a refused join
  /// turns the panel back off, and the reason has to survive that.
  final String? error;

  /// A microphone the call cannot hear, read from Agora's local-audio state.
  final String? micProblem;

  /// What the server says this person may do: talk, or only listen.
  final bool mayUseMic;
  final bool isMuted;

  /// Names of whoever else is in the call.
  final List<String> othersInCall;

  /// `audio_users_list` as the server sent it.
  final List<dynamic> users;
  final Set<int> activeSpeakers;
  final Object? myId;
  final bool isLeader;
  final bool isStudentSeat;
  final bool isHandRaised;

  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onToggleMute;

  /// Up or down.
  final ValueChanged<bool> onSetHand;

  /// A student's microphone for good — the row the voice token is minted from.
  final void Function(int userId, bool mayTalk) onSetStudentVoice;

  /// A courtesy for the next few minutes, which the client honours.
  final void Function(Object? userId, bool mute) onMuteUser;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: colors.info),
                const SizedBox(width: AppSpacing.sm),
                const Text('Voice', style: AppText.headline),
              ],
            ),
            if (!isVoiceOn)
              Icon(Icons.mic_off, color: colors.textMuted, size: 16)
            else if (isConnecting)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.info),
              )
            else if (error != null)
              Icon(Icons.warning, color: colors.danger, size: 16)
            else
              Icon(Icons.check_circle, color: colors.success, size: 16),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (error != null) ...[
          Text(error!, style: AppText.caption.copyWith(color: colors.danger)),
          const SizedBox(height: AppSpacing.sm),
        ],
        // The voice is off until somebody asks for it. What this offers depends
        // on whether a conversation is already going on, because those are two
        // different questions: "do I want to start talking" and "the lesson is
        // being spoken and I am not hearing it".
        if (!isVoiceOn) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: othersInCall.isEmpty
                  ? colors.textMuted.withValues(alpha: 0.15)
                  : colors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  othersInCall.isEmpty
                      ? Icons.mic_off
                      : Icons.record_voice_over,
                  size: 16,
                  color:
                      othersInCall.isEmpty ? colors.textMuted : colors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    othersInCall.isEmpty
                        ? 'Voice is off. The microphone will not '
                            'open until you turn it on yourself.'
                        : 'In call: ${othersInCall.join(', ')}.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.headset_mic, size: 16),
            label: Text(
                othersInCall.isEmpty ? 'Turn on voice' : 'Join conversation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.success.withValues(alpha: 0.2),
              foregroundColor: colors.success,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
        if (isVoiceOn && micProblem != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mic_off, size: 16, color: colors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  micProblem!,
                  key: const Key('voice-mic-problem'),
                  style: AppText.caption.copyWith(color: colors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (isVoiceOn && !isConnecting && error == null) ...[
          // A button that cannot work must not be drawn. While the server says
          // this person only listens, the app holds a subscriber token: a
          // microphone switch would light up, the roster would say they are
          // speaking, and nobody would hear them.
          if (!mayUseMic)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.headset, size: 16, color: colors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'You are listening to the session. Respond with the '
                      'answers under the board and with moves on it.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: onToggleMute,
              icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
              label: Text(isMuted ? 'Turn on microphone' : 'Mute me'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isMuted
                    ? colors.danger.withValues(alpha: 0.2)
                    : colors.success.withValues(alpha: 0.2),
                foregroundColor: isMuted ? colors.danger : colors.success,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Participants in audio call:',
            style: AppText.captionBold.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 6),
          for (final user in users) _userRow(context, user),
          if (users.isEmpty)
            Text(
              'No connected users.',
              style: AppText.caption.copyWith(color: colors.textMuted),
            ),
          // Up and down with one control. The hand used to stay up for good:
          // the line said so and nothing took it back (F12).
          if (isStudentSeat && isMuted && isHandRaised) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => onSetHand(false),
              icon: const Icon(Icons.front_hand, size: 14),
              label: const Text('Lower hand'),
              style: OutlinedButton.styleFrom(foregroundColor: colors.warning),
            ),
          ] else if (isStudentSeat && isMuted) ...[
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: () => onSetHand(true),
              icon: const Icon(Icons.pan_tool, size: 14),
              label: const Text('Raise hand to speak'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.warning.withValues(alpha: 0.2),
                foregroundColor: colors.textPrimary,
              ),
            ),
          ],
        ],
        // Outside the block above on purpose: a voice that came up with an
        // error is exactly the one somebody needs to be able to switch off.
        if (isVoiceOn) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onLeave,
            icon: const Icon(Icons.call_end, size: 16),
            label: const Text('Leave voice'),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
          ),
        ],
      ],
    );
  }

  Widget _userRow(BuildContext context, dynamic user) {
    final colors = context.colors;
    final isUserMuted = user['isMuted'] ?? false;
    // Told by the server, unlike the mute flag beside it, which is whatever the
    // client reported about itself.
    final userMaySpeak = user['maySpeak'] == true;
    final isUserTalking = activeSpeakers.contains(user['userId']);
    final isUserTrainer = user['role'] == 'trener';
    final isMe = user['userId'] == myId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            !userMaySpeak
                ? Icons.headset
                : (isUserMuted ? Icons.mic_off : Icons.mic),
            size: 16,
            color: isUserTalking
                ? colors.success
                : (userMaySpeak && isUserMuted
                    ? colors.danger
                    : colors.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${user['userName']} ${isMe ? "(Me)" : ""} '
              '${isUserTrainer ? "[Trainer]" : ""}',
              style: AppText.body.copyWith(
                  fontWeight:
                      isUserTalking ? FontWeight.bold : FontWeight.normal,
                  color: isUserTalking ? colors.success : colors.textPrimary),
            ),
          ),
          // Two different controls, deliberately kept apart: this one is the
          // right, read again every time a voice token is minted, and the one
          // beside it is a courtesy for the next few minutes.
          if (isLeader && !isMe && !isUserTrainer)
            IconButton(
              icon: Icon(userMaySpeak ? Icons.mic : Icons.mic_off,
                  size: 16,
                  color: userMaySpeak ? colors.success : colors.textMuted),
              onPressed: () =>
                  onSetStudentVoice(user['userId'] as int, !userMaySpeak),
              tooltip: userMaySpeak
                  ? 'Revoke microphone (remains listening)'
                  : 'Grant microphone',
            ),
          if (isLeader && !isMe && userMaySpeak)
            IconButton(
              icon: Icon(isUserMuted ? Icons.volume_off : Icons.volume_up,
                  size: 16),
              onPressed: () => onMuteUser(user['userId'], !isUserMuted),
              tooltip: isUserMuted ? 'Unmute' : 'Mute student',
            ),
        ],
      ),
    );
  }
}
