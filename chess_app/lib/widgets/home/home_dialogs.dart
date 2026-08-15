import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/services/billing_service.dart';

/// Dialogs used by [HomeScreen] that are pure UI: they read whatever they
/// need from their parameters and report the result back through a callback
/// rather than touching the screen's state directly.

void showInviteDialog(BuildContext context, {required String roomCode, required String trainerName, required VoidCallback onJoin}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Poziv na lekciju'),
        content: Text('Trener $trainerName vas poziva na lekciju. Da li želite da se pridružite?'),
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

void showNotificationsDialog(
  BuildContext context, {
  required List<dynamic> notifications,
  required void Function(int notifId, String roomCode) onJoinFromNotification,
}) {
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('Notifikacije i Pozivnice', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nemate novih notifikacija.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: Column(
                    children: notifications.map((n) {
                      final notifId = n['id'] as int;
                      final roomCode = n['room_code'] as String;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.star, color: Colors.amber),
                          title: Text(n['message'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text('Soba: $roomCode', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              onJoinFromNotification(notifId, roomCode);
                            },
                            child: const Text('Pridruži se', style: TextStyle(fontSize: 11)),
                          ),
                        ),
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
            child: const Text('Zatvori'),
          ),
        ],
      ),
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
            Text('Kreiranje sesije i Pozivanje', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Izaberite prijatelje koje želite da pozovete u novu sesiju:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            if (availableFriends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('Nemate dodatih prijatelja. Možete ih dodati u kartici "Lista prijatelja" ispod.', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                        title: Text(f['name'] ?? 'Prijatelj', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(f['email'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
            label: Text(selectedFriendIds.isNotEmpty ? 'Kreiraj i Pozovi (${selectedFriendIds.length})' : 'Kreiraj sesiju'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
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
  required void Function(String title, String desc, DateTime scheduledAt, List<int> friendIds) onSchedule,
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
                      label: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}.'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
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
                      label: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
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
              const Text('Pozovi prijatelje na zakazani čas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (availableFriends.isEmpty)
                const Text('Nemate dodatih prijatelja.', style: TextStyle(fontSize: 11, color: Colors.grey))
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
                          title: Text(f['name'] ?? 'Prijatelj', style: const TextStyle(fontSize: 12)),
                          subtitle: Text(f['email'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
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
              onSchedule(title, descCtrl.text.trim(), scheduledDateTime, selectedFriendIds);
            },
          ),
        ],
      ),
    ),
  );
}

void showScheduledSuccessDialog(BuildContext context, {required String message, required String? calendarUrl, required String roomCode}) {
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
          Text('Kod sobe: $roomCode', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
          const SizedBox(height: 12),
          if (calendarUrl != null) ...[
            const Text('Sinhronizujte sa kalendarom:', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Dodaj u Google Kalendar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              onPressed: () {
                launchUrl(Uri.parse(calendarUrl), mode: LaunchMode.externalApplication);
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
                  child: Text('Chess Master Premium', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        style: const TextStyle(fontSize: 11.5, color: Colors.amberAccent),
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
                                  content: Text('Kupovinu nije moguće pokrenuti.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text('${BillingService.displayTitle(product.title)} · ${product.price}'),
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
