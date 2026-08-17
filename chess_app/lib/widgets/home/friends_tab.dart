import 'package:flutter/material.dart';

/// The "Prijatelji" tab: add-by-email form plus the current friends list.
class HomeFriendsTab extends StatelessWidget {
  final TextEditingController studentEmailController;
  final bool isLoadingStudents;

  /// People I teach. The tab used to draw only these, so someone who had a
  /// trainer but no students was told they had nobody at all.
  final List<dynamic> students;

  /// People who teach me — the same relationships read from the other end.
  final List<dynamic> trainers;

  /// Requests waiting for *this* user to answer, in either direction — a
  /// trainer who enrolled them, or a student asking them to coach.
  final List<dynamic> pendingRequests;
  final ValueChanged<int> onAcceptRequest;
  final ValueChanged<int> onDeclineRequest;

  final VoidCallback onAddStudent;
  final ValueChanged<int> onDeleteStudent;

  /// Which side the sender is claiming for the request they are about to send.
  /// Sending one is not "adding a student": it says who teaches whom, and the
  /// other person answers that exact claim.
  final bool iAmTrainerInRequest;
  final ValueChanged<bool> onRoleChanged;

  /// Pull to refresh. The other side answers on their own device, so this
  /// screen can be out of date without anything having gone wrong.
  final Future<void> Function() onRefresh;

  /// Opens the student's progress report. Receives the raw row so the caller
  /// keeps the id and the display name together.
  final void Function(Map<String, dynamic> student) onOpenProgress;

  const HomeFriendsTab({
    super.key,
    required this.studentEmailController,
    required this.isLoadingStudents,
    required this.students,
    required this.trainers,
    required this.pendingRequests,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onAddStudent,
    required this.onDeleteStudent,
    required this.iAmTrainerInRequest,
    required this.onRoleChanged,
    required this.onRefresh,
    required this.onOpenProgress,
  });

  /// Rows worth listing: everything settled, plus requests *I* sent and am
  /// waiting on. A request waiting on **me** belongs in "Čeka vaš odgovor"
  /// above — listing it here too would show the same person twice, once with
  /// buttons and once greyed out.
  List<dynamic> _awaitingOther(List<dynamic> rows) => rows
      .where((r) => r['status'] != 'pending' || r['i_asked'] == true)
      .toList();

  List<dynamic> get myStudents => _awaitingOther(students);
  List<dynamic> get myTrainers => _awaitingOther(trainers);

  /// One person, from whichever end. `iTeachThem` decides only what the row
  /// offers: homework and progress belong to the teaching side, and breaking
  /// the relationship belongs to both — consent that cannot be withdrawn from
  /// one side is not consent.
  List<Widget> _rows(List<dynamic> rows, {required bool iTeachThem}) {
    return rows.map((r) {
      final isPending = r['status'] == 'pending';
      return ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: !isPending,
        leading: CircleAvatar(
          backgroundColor: isPending ? Colors.grey.shade700 : null,
          child: Icon(isPending
              ? Icons.hourglass_empty
              : (iTeachThem ? Icons.person : Icons.school)),
        ),
        title: Text(r['name'] ?? 'Korisnik',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isPending ? '${r['email'] ?? ''} — čeka potvrdu' : (r['email'] ?? ''),
        ),
        onTap: (isPending || !iTeachThem)
            ? null
            : () => onOpenProgress(Map<String, dynamic>.from(r)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iTeachThem)
              IconButton(
                icon: const Icon(Icons.insights, size: 20),
                tooltip: isPending
                    ? 'Dostupno kad učenik prihvati'
                    : 'Napredak i zadaci',
                onPressed: isPending
                    ? null
                    : () => onOpenProgress(Map<String, dynamic>.from(r)),
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
              tooltip:
                  iTeachThem ? 'Raskini odnos' : 'Raskini odnos sa trenerom',
              onPressed: () => onDeleteStudent(r['id']),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return SingleChildScrollView(
      // Always scrollable so the pull gesture exists even when the list is
      // short enough to fit — which is exactly when there is nothing on screen
      // to explain why it looks stale.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.people,
                              color: Colors.purpleAccent, size: 28),
                          SizedBox(width: 12),
                          // Expanded, not a bare Text: at 360 px this title is
                          // wider than the card and overflowed off the right
                          // edge. Only the phone shows it, and the tab had
                          // never been rendered at that width.
                          Expanded(
                            child: Text('Moji Prijatelji & Kontakti',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // The direction is stated before the address, because it
                      // changes what the address means: the same email is a
                      // student in one reading and a trainer in the other.
                      // Chips rather than a segmented button so the pair wraps
                      // instead of overflowing on a ~360 px screen.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('Ja sam trener'),
                            selected: iAmTrainerInRequest,
                            onSelected: (_) => onRoleChanged(true),
                          ),
                          ChoiceChip(
                            label: const Text('Ja sam učenik'),
                            selected: !iAmTrainerInRequest,
                            onSelected: (_) => onRoleChanged(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        iAmTrainerInRequest
                            ? 'Vi predajete, druga strana je učenik.'
                            : 'Druga strana predaje, vi ste učenik.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: studentEmailController,
                              decoration: InputDecoration(
                                labelText: iAmTrainerInRequest
                                    ? 'Email učenika'
                                    : 'Email trenera',
                                hintText: 'osoba@example.com',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: onAddStudent,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            child: const Text('Pošalji zahtev'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Requests come first: an unanswered one is the only
                      // thing on this screen that someone else is waiting on.
                      if (pendingRequests.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Čeka vaš odgovor (${pendingRequests.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        ...pendingRequests.map((r) {
                          final iAmStudent = r['i_am_student'] == true;
                          final name =
                              r['other_name'] ?? r['other_email'] ?? '';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                iAmStudent ? Icons.school : Icons.person_add,
                                color: Colors.amber,
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                iAmStudent
                                    ? 'želi da vas upiše kao učenika'
                                    : 'želi da mu budete trener',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    tooltip: 'Prihvati',
                                    onPressed: () => onAcceptRequest(r['id']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.redAccent),
                                    tooltip: 'Odbij',
                                    onPressed: () => onDeclineRequest(r['id']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],

                      const Divider(),
                      const SizedBox(height: 8),
                      if (isLoadingStudents)
                        const Center(child: CircularProgressIndicator())
                      else if (myStudents.isEmpty && myTrainers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                              child: Text('Još nemate ni učenika ni trenera.',
                                  style: TextStyle(color: Colors.grey))),
                        )
                      else ...[
                        if (myStudents.isNotEmpty) ...[
                          const Text('Moji učenici',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ..._rows(myStudents, iTeachThem: true),
                        ],
                        if (myStudents.isNotEmpty && myTrainers.isNotEmpty)
                          const SizedBox(height: 16),
                        if (myTrainers.isNotEmpty) ...[
                          const Text('Moji treneri',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ..._rows(myTrainers, iTeachThem: false),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
