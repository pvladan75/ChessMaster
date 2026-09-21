import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Dialogs used by [HomeScreen] that are pure UI: they read whatever they
/// need from their parameters and report the result back through a callback
/// rather than touching the screen's state directly.

void showInviteDialog(
  BuildContext context, {
  required String roomCode,
  required String trainerName,
  required VoidCallback onJoin,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Session Invitation'),
        content: Text(
          'Trainer $trainerName invites you to a session. Would you like to join?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onJoin();
            },
            child: const Text('Join'),
          ),
        ],
      );
    },
  );
}

/// The bell, and the only place a relationship request is answered.
void showNotificationsDialog(
  BuildContext context, {
  required List<dynamic> notifications,
  required List<dynamic> pendingRequests,
  required void Function(int notifId, String roomCode) onJoinFromNotification,
  required Future<bool> Function(int requestId, bool accept) onRespondToRequest,
}) {
  final colors = context.colors;
  final Map<int, bool> answered = {};
  final Set<int> answering = {};

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        final waiting = pendingRequests
            .where((r) => !answered.containsKey(r['id'] as int))
            .toList();
        final pendingIds = pendingRequests.map((r) => r['id'] as int).toSet();
        final messages = notifications.where((n) {
          if ((n['kind'] ?? 'room').toString() != 'student_request') {
            return true;
          }
          final ref = n['ref_id'];
          return !(ref is int && pendingIds.contains(ref));
        }).toList();

        Future<void> answer(int requestId, bool accept) async {
          setModalState(() => answering.add(requestId));
          final ok = await onRespondToRequest(requestId, accept);
          setModalState(() {
            answering.remove(requestId);
            if (ok) answered[requestId] = accept;
          });
        }

        final unreadCount = messages.where((n) => n['is_read'] != true).length;

        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active, color: colors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Notifications and Invitations',
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              if (waiting.isNotEmpty || unreadCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  badgeExplanation(
                    waiting: waiting.length,
                    unread: unreadCount,
                  ),
                  style: AppText.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ],
          ),
          insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
          content: SizedBox(
            width: math.min(
              360,
              MediaQuery.sizeOf(context).width - 32 - 48,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (messages.isEmpty && waiting.isEmpty && answered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'You have no new notifications.',
                      style: AppText.body.copyWith(color: colors.textMuted),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final r in waiting)
                            _requestCard(
                              context,
                              r,
                              busy: answering.contains(r['id'] as int),
                              onAnswer: (accept) =>
                                  answer(r['id'] as int, accept),
                            ),
                          for (final entry in answered.entries)
                            _answeredCard(context, entry.value),
                          for (final n in messages)
                            _messageCard(ctx, n, onJoinFromNotification),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

/// One request, with the two answers to it.
Widget _requestCard(
  BuildContext context,
  dynamic r, {
  required bool busy,
  required void Function(bool accept) onAnswer,
}) {
  final colors = context.colors;
  final iAmStudent = r['i_am_student'] == true;
  final name = r['other_name'] ?? r['other_email'] ?? '';

  return Card(
    margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 10, AppSpacing.sm, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iAmStudent ? Icons.school : Icons.person_add,
                  color: colors.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.bodyLargeBold
                          .copyWith(color: colors.textPrimary),
                    ),
                    Text(
                      iAmStudent
                          ? 'wants to add you as a student'
                          : 'wants you to be their trainer',
                      style:
                          AppText.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.close, color: colors.danger),
                  label: Text(
                    'Decline',
                    style: TextStyle(color: colors.danger),
                  ),
                  onPressed: () => onAnswer(false),
                ),
                TextButton.icon(
                  icon: Icon(Icons.check, color: colors.success),
                  label: Text(
                    'Accept',
                    style: TextStyle(color: colors.success),
                  ),
                  onPressed: () => onAnswer(true),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

/// What was just decided, in place of the row that was answered.
Widget _answeredCard(BuildContext context, bool accepted) {
  final colors = context.colors;

  return Card(
    margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: ListTile(
      dense: true,
      leading: Icon(
        accepted ? Icons.check_circle : Icons.do_not_disturb_on,
        color: accepted ? colors.success : colors.textMuted,
      ),
      title: Text(
        accepted ? 'Request accepted.' : 'Request declined.',
        style: AppText.body.copyWith(color: colors.textPrimary),
      ),
    ),
  );
}

/// A notification that is only a message: a room invitation, or a refusal.
Widget _messageCard(
  BuildContext ctx,
  dynamic n,
  void Function(int notifId, String roomCode) onJoinFromNotification,
) {
  final colors = ctx.colors;
  final notifId = n['id'] as int;

  final roomCode = n['room_code'] as String?;
  final kind = (n['kind'] ?? 'room').toString();
  final isRead = n['is_read'] == true;
  final isInvitation = kind == 'room' && roomCode != null;
  // `room_live` is the server's word that the room is still a session. An
  // invitation used to keep a working „Join" for ever, and an old one is how
  // two people ended up in two rooms on 21.9.2026. **Only `true` is a door**:
  // a server that does not say reads as „not now", never as „yes".
  final canJoin = isInvitation && n['room_live'] == true;

  return Card(
    margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: ListTile(
      dense: true,
      leading: Icon(
        switch (kind) {
          'student_request' => Icons.school,
          'request_accepted' => Icons.handshake,
          'request_declined' => Icons.do_not_disturb_on,
          'assignment_new' => Icons.assignment,
          'assignment_done' => Icons.assignment_turned_in,
          'assignment_note' => Icons.chat_bubble_outline,
          'awaiting_parent' => Icons.family_restroom,
          'student_stated_minor_age' => Icons.family_restroom,
          // A film rendered after its export was answered — item 5 of part two
          // of docs/PLAN-SNIMANJE.md. Both icons are already drawn elsewhere
          // in the app, so a stale Windows icon font cannot leave these blank.
          'video_ready' => Icons.movie,
          'video_failed' => Icons.error_outline,
          // A trainer shared a lesson recorded in Preparation (phase 5b); it is
          // under Recordings on Home.
          'recording_shared' => Icons.movie,
          _ => Icons.star,
        },
        color: isRead ? colors.textMuted : colors.warning,
      ),
      title: Text(
        n['message'] ?? '',
        style: (isRead ? AppText.body : AppText.bodyBold)
            .copyWith(color: isRead ? colors.textMuted : colors.textPrimary),
      ),
      subtitle: Text(
        canJoin
            ? 'Room: $roomCode'
            : isInvitation
                ? 'This session has ended.'
                : (kind == 'student_request' ? 'Answered.' : ''),
        style: AppText.micro.copyWith(color: colors.textSecondary),
      ),
      trailing: canJoin
          ? ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onJoinFromNotification(notifId, roomCode);
              },
              child: Text('Join', style: AppText.caption),
            )
          : null,
    ),
  );
}

/// Asks before a remembered session is dropped for another one.
///
/// Reached only for a room the server still calls live — one that has ended is
/// forgotten without asking (`GameSessionService.reconcile`). It replaced a
/// dialog that refused outright and offered only the way back into the old
/// room, which on 21.9.2026 kept two people in two different rooms.
Future<bool?> showLeaveOtherSessionDialog(
  BuildContext context, {
  required String roomCode,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Leave the other session?'),
      content: Text(
        'You are still in session $roomCode. Leave it and continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('leave-other-session'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Leave and continue'),
        ),
      ],
    ),
  );
}

String badgeExplanation({required int waiting, required int unread}) {
  final parts = <String>[
    if (waiting > 0)
      waiting == 1
          ? '1 request awaiting your response'
          : '$waiting requests awaiting your response',
    if (unread > 0)
      unread == 1 ? '1 new notification' : '$unread new notifications',
  ];
  return parts.join(' · ');
}
