import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/services/billing_service.dart';

/// Dialogs used by [HomeScreen] that are pure UI: they read whatever they
/// need from their parameters and report the result back through a callback
/// rather than touching the screen's state directly.

void showInviteDialog(BuildContext context,
    {required String roomCode,
    required String trainerName,
    required VoidCallback onJoin}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Poziv na lekciju'),
        content: Text(
            'Trener $trainerName vas poziva na lekciju. Da li želite da se pridružite?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odbij'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onJoin();
            },
            child: const Text('Pridruži se'),
          ),
        ],
      );
    },
  );
}

/// The bell, and the only place a relationship request is answered.
///
/// The request used to live in two places: a card in the Prijatelji tab, where
/// it could be answered, and a notification here, which told you to go there.
/// Two owners of one thing, and it had already cost something — the
/// notification stayed unread for good, because nothing tied the answer back to
/// it. A child who is invited looks at the bell; they do not go hunting through
/// tabs. The bell is also the only thing on screen carrying a count, so it is
/// the only thing that says by itself that something is waiting.
///
/// [pendingRequests] is the authority for what is unanswered, not the
/// notification list: `/notifications` returns the last twenty, so a request
/// could scroll out of it and become unanswerable. Anything still pending is
/// shown here whether its notification survived or not.
void showNotificationsDialog(
  BuildContext context, {
  required List<dynamic> notifications,
  required List<dynamic> pendingRequests,
  required void Function(int notifId, String roomCode) onJoinFromNotification,
  required Future<bool> Function(int requestId, bool accept) onRespondToRequest,
}) {
  // Answered in this sitting: the row stays, saying what was decided, instead
  // of vanishing from under the finger that answered it.
  final Map<int, bool> answered = {};
  final Set<int> answering = {};

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        // A request still waiting is shown once, as the row with the buttons.
        // Its own notification would otherwise repeat it directly underneath.
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

        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.notifications_active, color: Colors.amberAccent),
              SizedBox(width: 8),
              // Expanded: the title is wider than the dialog on a narrow phone,
              // and a title that overflows takes the whole dialog down with it.
              Expanded(
                child: Text('Notifikacije i Pozivnice',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          // Narrower margins than the default, so a 360 dp phone keeps most of
          // its width for the content.
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          // A width, because AlertDialog wraps its content in an IntrinsicWidth
          // which cannot descend into a lazy list — but not a fixed one. It was
          // 360, and a phone *is* 360 dp: the dialog's own margins and padding
          // then put the content 79 px past the edge, where a release build
          // clips it without a word. That is what squeezed the request text
          // into one word per line, and why several tests in
          // notifications_dialog_test.dart had been widened to 800 to pass.
          content: SizedBox(
            width: math.min(
              360,
              MediaQuery.sizeOf(context).width - 32 - 48,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (messages.isEmpty && waiting.isEmpty && answered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Nemate novih notifikacija.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Requests first: an unanswered one is the only thing
                          // here that somebody else is waiting on.
                          for (final r in waiting)
                            _requestCard(
                              r,
                              busy: answering.contains(r['id'] as int),
                              onAnswer: (accept) =>
                                  answer(r['id'] as int, accept),
                            ),
                          for (final entry in answered.entries)
                            _answeredCard(entry.value),
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
              child: const Text('Zatvori'),
            ),
          ],
        );
      },
    ),
  );
}

/// One request, with the two answers to it.
Widget _requestCard(
  dynamic r, {
  required bool busy,
  required void Function(bool accept) onAnswer,
}) {
  final iAmStudent = r['i_am_student'] == true;
  final name = r['other_name'] ?? r['other_email'] ?? '';

  // The two buttons sit under the text rather than beside it. In a dialog this
  // narrow, a trailing pair of icon buttons leaves the text about a hundred
  // logical pixels, and "pavle želi da vas upiše kao učenika" came out one word
  // per line on a phone. Nothing overflowed; it was simply unreadable.
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iAmStudent ? Icons.school : Icons.person_add,
                  color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      iAmStudent
                          ? 'želi da vas upiše kao učenika'
                          : 'želi da mu budete trener',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            // Wrap, not Row: with a wide font or a small screen the two labels
            // stack instead of running off the edge.
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('Odbij',
                      style: TextStyle(color: Colors.redAccent)),
                  onPressed: () => onAnswer(false),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Prihvati',
                      style: TextStyle(color: Colors.green)),
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
Widget _answeredCard(bool accepted) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    child: ListTile(
      dense: true,
      leading: Icon(accepted ? Icons.check_circle : Icons.do_not_disturb_on,
          color: accepted ? Colors.green : Colors.grey),
      title: Text(accepted ? 'Zahtev je prihvaćen.' : 'Zahtev je odbijen.',
          style: const TextStyle(fontSize: 12)),
    ),
  );
}

/// A notification that is only a message: a room invitation, or a refusal.
Widget _messageCard(
  BuildContext ctx,
  dynamic n,
  void Function(int notifId, String roomCode) onJoinFromNotification,
) {
  final notifId = n['id'] as int;

  // Nullable since 16.8: a notification carrying a request to teach or be
  // taught has no room. This used to read `as String`, which threw during build
  // over a null and showed the user a blank screen instead of the list.
  final roomCode = n['room_code'] as String?;
  final kind = (n['kind'] ?? 'room').toString();
  final isRead = n['is_read'] == true;

  // Only a room invitation has somewhere to go.
  final canJoin = kind == 'room' && roomCode != null;

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
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
          _ => Icons.star,
        },
        color: isRead ? Colors.grey : Colors.amber,
      ),
      title: Text(n['message'] ?? '',
          style: TextStyle(
              fontSize: 12,
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              color: isRead ? Colors.grey : null)),
      subtitle: Text(
        canJoin
            ? 'Soba: $roomCode'
            // A request that reaches this list has already been answered — it
            // is history now, and offering the buttons again would be a lie.
            : (kind == 'student_request' ? 'Odgovoreno.' : ''),
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      trailing: canJoin
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                onJoinFromNotification(notifId, roomCode);
              },
              child: const Text('Pridruži se', style: TextStyle(fontSize: 11)),
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
  final List<int> selectedFriendIds = [];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.add_circle_outline, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('Kreiranje sesije i Pozivanje',
                style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Izaberite prijatelje koje želite da pozovete u novu sesiju:',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            if (availableFriends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                    'Nemate dodatih prijatelja. Možete ih dodati u kartici "Lista prijatelja" ispod.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                        title: Text(f['name'] ?? 'Prijatelj',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(f['email'] ?? '',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
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
            child: const Text('Otkaži'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: Text(selectedFriendIds.isNotEmpty
                ? 'Kreiraj i Pozovi (${selectedFriendIds.length})'
                : 'Kreiraj sesiju'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
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
          children: const [
            Icon(Icons.calendar_month, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('Zakazivanje sesije unapred', style: TextStyle(fontSize: 16)),
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
                  labelText: 'Naslov sesije / lekcije',
                  hintText: 'npr. Sicilijanska odbrana - Predavanje',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Opis (opciono)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(
                          '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}.'),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 14),
                      label: Text(
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
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
              const SizedBox(height: 16),
              const Text('Pozovi prijatelje na zakazani čas:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (availableFriends.isEmpty)
                const Text('Nemate dodatih prijatelja.',
                    style: TextStyle(fontSize: 11, color: Colors.grey))
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
                          title: Text(f['name'] ?? 'Prijatelj',
                              style: const TextStyle(fontSize: 12)),
                          subtitle: Text(f['email'] ?? '',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
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
            child: const Text('Otkaži'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.event_available),
            label: const Text('Zakaži i Sačuvaj'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber, foregroundColor: Colors.black),
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

void showScheduledSuccessDialog(BuildContext context,
    {required String message,
    required String? calendarUrl,
    required String roomCode}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.tealAccent),
          SizedBox(width: 8),
          Text('Zakazivanje Uspešno!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Text('Kod sobe: $roomCode',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent)),
          const SizedBox(height: 12),
          if (calendarUrl != null) ...[
            const Text('Sinhronizujte sa kalendarom:',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Dodaj u Google Kalendar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white),
              onPressed: () {
                launchUrl(Uri.parse(calendarUrl),
                    mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('U redu'),
        ),
      ],
    ),
  );
}

/// Shows what Premium includes, where the account stands, and — on Android —
/// lets the user actually buy it through Google Play.
///
/// Play prices are read from the store rather than hardcoded, so they are always
/// in the buyer's own currency and match what Play will charge. The purchase is
/// only ever confirmed by the server, which verifies the token with Google; a
/// successful `buy()` here means "Play accepted the request", not "paid".
void showPremiumModal(
  BuildContext context, {
  required BillingService billing,
  VoidCallback? onPurchased,
}) {
  const benefits = [
    'Neograničeno sačuvanih pozicija i lekcija (besplatno: do 20)',
    'Neograničeno živih sesija mesečno (besplatno: do 5)',
    'Izvoz snimljenih časova u MP4 video format',
    'Veća mesečna kvota za AI komentare',
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
              children: const [
                Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Šahovski trener Premium',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                        ? 'Vaš nalog je aktivan (${state.tier}). Uključeno je:'
                        : 'Premium nalog uklanja ograničenja besplatnog naloga:',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  for (final benefit in benefits)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isPaid ? Icons.check_circle : Icons.lock_outline,
                        color: isPaid ? Colors.tealAccent : Colors.grey,
                      ),
                      title: Text(benefit),
                    ),
                  if (aiQuota != null && !aiQuota.isUnlimited) ...[
                    const SizedBox(height: 8),
                    Text(
                      'AI komentari ovog meseca: ${aiQuota.used} / ${aiQuota.limit}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (!isPaid && !billing.canPurchase)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        BillingService.isSupportedPlatform
                            ? 'Kupovina trenutno nije dostupna. Pokušajte kasnije '
                                'ili nas kontaktirajte.'
                            : 'Kupovina je dostupna u Android verziji aplikacije. '
                                'Nalog kupljen tamo važi i ovde.',
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.amberAccent),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Zatvori'),
              ),
              if (!isPaid && billing.canPurchase)
                for (final product in billing.products)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: busy
                        ? null
                        : () async {
                            final outcome = await billing.buy(product);
                            if (outcome == PurchaseOutcome.unavailable ||
                                outcome == PurchaseOutcome.failed) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Kupovinu nije moguće pokrenuti.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            '${BillingService.displayTitle(product.title)} · ${product.price}'),
                  ),
            ],
          ),
        );
      },
    ),
  ).then((_) {
    // The purchase stream keeps running after the dialog closes, so the tier may
    // have changed by now.
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
      title: const Text('Već imate aktivnu sesiju'),
      content: Text(
        'Već ste u sesiji (kod: $roomCode). Napustite je (dugme "Napusti sesiju" u sobi) pre nego što napravite ili se priključite drugoj.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            onGoToSession();
          },
          child: const Text('Idi na sesiju'),
        ),
      ],
    ),
  );
}
