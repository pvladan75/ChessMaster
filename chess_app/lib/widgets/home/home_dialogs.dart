import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/services/billing_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

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
  final canJoin = kind == 'room' && roomCode != null;

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

void showCreateRoomWithFriendsDialog(
  BuildContext context, {
  required List<dynamic> availableFriends,
  required void Function(List<int> friendIds) onCreate,
}) {
  final colors = context.colors;
  final List<int> selectedFriendIds = [];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: colors.accent),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Create Session and Invite',
              style: AppText.title.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select friends you want to invite to a new session:',
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (availableFriends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'You have no added friends. You can add them in the "People" tab.',
                  style: AppText.caption.copyWith(color: colors.textMuted),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    children: availableFriends.map((f) {
                      final fId = f['id'] as int;
                      final isSel = selectedFriendIds.contains(fId);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(
                          f['name'] ?? 'Friend',
                          style: AppText.bodyLargeBold
                              .copyWith(color: colors.textPrimary),
                        ),
                        value: isSel,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              selectedFriendIds.add(fId);
                            } else {
                              selectedFriendIds.remove(fId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: Text(
              selectedFriendIds.isNotEmpty
                  ? 'Create and Invite (${selectedFriendIds.length})'
                  : 'Create session',
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onCreate(selectedFriendIds);
            },
          ),
        ],
      ),
    ),
  );
}

void showScheduleSessionDialog(
  BuildContext context, {
  required List<dynamic> availableFriends,
  required void Function(
          String title, String desc, DateTime scheduledAt, List<int> friendIds)
      onSchedule,
}) {
  final colors = context.colors;
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  DateTime selectedDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);
  final List<int> selectedFriendIds = [];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_month, color: colors.warning),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Schedule a Session',
              style: AppText.title.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Session title',
                  hintText: 'e.g. Sicilian Defense - Lecture',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(
                        '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}.',
                        style: AppText.body,
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 14),
                      label: Text(
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        style: AppText.body,
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Invite friends to scheduled session:',
                style:
                    AppText.bodyLargeBold.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (availableFriends.isEmpty)
                Text(
                  'You have no added friends.',
                  style: AppText.caption.copyWith(color: colors.textMuted),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: Column(
                      children: availableFriends.map((f) {
                        final fId = f['id'] as int;
                        final isSel = selectedFriendIds.contains(fId);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            f['name'] ?? 'Friend',
                            style: AppText.body
                                .copyWith(color: colors.textPrimary),
                          ),
                          value: isSel,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedFriendIds.add(fId);
                              } else {
                                selectedFriendIds.remove(fId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.event_available),
            label: const Text('Schedule and Save'),
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;

              final scheduledDateTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );

              Navigator.pop(ctx);
              onSchedule(title, descCtrl.text.trim(), scheduledDateTime,
                  selectedFriendIds);
            },
          ),
        ],
      ),
    ),
  );
}

void showScheduledSuccessDialog(
  BuildContext context, {
  required String message,
  required String? calendarUrl,
  required String roomCode,
}) {
  final colors = context.colors;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: colors.success),
          const SizedBox(width: AppSpacing.sm),
          const Text('Scheduled Successfully!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppText.body),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Room code: $roomCode',
            style: AppText.bodyLargeBold.copyWith(color: colors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          if (calendarUrl != null) ...[
            Text(
              'Sync with calendar:',
              style: AppText.caption.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Add to Google Calendar'),
              onPressed: () {
                launchUrl(
                  Uri.parse(calendarUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showPremiumModal(
  BuildContext context, {
  required BillingService billing,
  VoidCallback? onPurchased,
}) {
  final colors = context.colors;
  const benefits = [
    'Unlimited saved positions and tutorials (free: up to 20)',
    'Unlimited live sessions per month (free: up to 5)',
    'Export recorded sessions to MP4 video format',
    'Higher monthly quota for AI feedback',
  ];

  showDialog(
    context: context,
    builder: (ctx) => ValueListenableBuilder<EntitlementState>(
      valueListenable: billing.entitlements,
      builder: (ctx, state, _) {
        final isPaid = state.isPaid;
        final aiQuota = state.quota(Entitlements.aiComments);

        return ValueListenableBuilder<bool>(
          valueListenable: billing.purchaseInProgress,
          builder: (ctx, busy, __) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.workspace_premium, color: colors.warning, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Chess Trainer Premium',
                    style: AppText.title.copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaid
                        ? 'Your account is active (${state.tier}). Included:'
                        : 'Premium account removes free tier limitations:',
                    style:
                        AppText.bodyLarge.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final benefit in benefits)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isPaid ? Icons.check_circle : Icons.lock_outline,
                        color: isPaid ? colors.success : colors.textMuted,
                      ),
                      title: Text(benefit),
                    ),
                  if (aiQuota != null && !aiQuota.isUnlimited) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'AI comments this month: ${aiQuota.used} / ${aiQuota.limit}',
                      style: AppText.body.copyWith(color: colors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (!isPaid && !billing.canPurchase)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.15),
                        borderRadius: AppRadii.roundedSm,
                      ),
                      child: Text(
                        BillingService.isSupportedPlatform
                            ? 'Purchases are currently unavailable. Please try again later '
                                'or contact support.'
                            : 'Purchases are available in the Android version of the app. '
                                'An account purchased there is valid here too.',
                        style: AppText.caption.copyWith(color: colors.warning),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              if (!isPaid && billing.canPurchase)
                for (final product in billing.products)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final outcome = await billing.buy(product);
                            if (outcome == PurchaseOutcome.unavailable ||
                                outcome == PurchaseOutcome.failed) {
                              if (!ctx.mounted) return;
                              AppFeedback.show(
                                ctx,
                                () => SnackBar(
                                  content:
                                      const Text('Unable to start purchase.'),
                                  backgroundColor: colors.danger,
                                ),
                              );
                            }
                          },
                    child: busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textPrimary,
                            ),
                          )
                        : Text(
                            '${BillingService.displayTitle(product.title)} · ${product.price}',
                          ),
                  ),
            ],
          ),
        );
      },
    ),
  ).then((_) {
    if (billing.entitlements.value.isPaid) onPurchased?.call();
  });
}

void showActiveSessionBlockedDialog(
  BuildContext context, {
  required String roomCode,
  required VoidCallback onGoToSession,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('You already have an active session'),
      content: Text(
        'You are already in a session (code: $roomCode). Leave it ("Leave session" button in the room) before creating or joining another.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            onGoToSession();
          },
          child: const Text('Go to session'),
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
