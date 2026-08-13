import 'package:flutter/material.dart';

/// The "Prijatelji" tab: add-by-email form plus the current friends list.
class HomeFriendsTab extends StatelessWidget {
  final TextEditingController studentEmailController;
  final bool isLoadingStudents;
  final List<dynamic> students;
  final VoidCallback onAddStudent;
  final ValueChanged<int> onDeleteStudent;

  const HomeFriendsTab({
    super.key,
    required this.studentEmailController,
    required this.isLoadingStudents,
    required this.students,
    required this.onAddStudent,
    required this.onDeleteStudent,
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
                          Icon(Icons.people, color: Colors.purpleAccent, size: 28),
                          SizedBox(width: 12),
                          Text('Moji Prijatelji & Kontakti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            child: const Text('Dodaj prijatelja'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      if (isLoadingStudents)
                        const Center(child: CircularProgressIndicator())
                      else if (students.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('Nemate još uvek dodatih prijatelja.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final s = students[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(s['name'] ?? 'Prijatelj', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(s['email'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () => onDeleteStudent(s['id']),
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
