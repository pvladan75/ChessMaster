import 'package:flutter/material.dart';

/// The "Prijatelji" tab: add-by-email form plus the current friends list.
class HomeFriendsTab extends StatelessWidget {
  final TextEditingController studentEmailController;
  final bool isLoadingStudents;
  final List<dynamic> students;

  /// Requests waiting for *this* user to answer, in either direction — a
  /// trainer who enrolled them, or a student asking them to coach.
  final List<dynamic> pendingRequests;
  final ValueChanged<int> onAcceptRequest;
  final ValueChanged<int> onDeclineRequest;

  final VoidCallback onAddStudent;
  final ValueChanged<int> onDeleteStudent;

  /// Opens the student's progress report. Receives the raw row so the caller
  /// keeps the id and the display name together.
  final void Function(Map<String, dynamic> student) onOpenProgress;

  const HomeFriendsTab({
    super.key,
    required this.studentEmailController,
    required this.isLoadingStudents,
    required this.students,
    required this.pendingRequests,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onAddStudent,
    required this.onDeleteStudent,
    required this.onOpenProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                          Text('Moji Prijatelji & Kontakti',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: studentEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email prijatelja',
                                hintText: 'prijatelj@example.com',
                                border: OutlineInputBorder(),
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
                            child: const Text('Dodaj prijatelja'),
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
                      else if (students.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                              child: Text('Nemate još uvek dodatih prijatelja.',
                                  style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          separatorBuilder: (ctx, idx) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final s = students[idx];
                            // A pending row is shown rather than hidden, but it
                            // must not offer homework: the server would refuse
                            // it, and a button that fails is worse than one
                            // that explains itself.
                            final isPending = s['status'] == 'pending';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              enabled: !isPending,
                              leading: CircleAvatar(
                                backgroundColor:
                                    isPending ? Colors.grey.shade700 : null,
                                child: Icon(isPending
                                    ? Icons.hourglass_empty
                                    : Icons.person),
                              ),
                              title: Text(s['name'] ?? 'Prijatelj',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                isPending
                                    ? '${s['email'] ?? ''} — čeka potvrdu'
                                    : (s['email'] ?? ''),
                              ),
                              onTap: isPending
                                  ? null
                                  : () => onOpenProgress(
                                      Map<String, dynamic>.from(s)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.insights, size: 20),
                                    tooltip: isPending
                                        ? 'Dostupno kad učenik prihvati'
                                        : 'Napredak i zadaci',
                                    onPressed: isPending
                                        ? null
                                        : () => onOpenProgress(
                                            Map<String, dynamic>.from(s)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.redAccent, size: 20),
                                    onPressed: () => onDeleteStudent(s['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
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
