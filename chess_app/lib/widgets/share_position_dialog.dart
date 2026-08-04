import 'package:flutter/material.dart';

class ShareStudentPositionDialog extends StatelessWidget {
  final List<dynamic> roomMembers;
  final Function(dynamic member) onShareToMember;

  const ShareStudentPositionDialog({
    super.key,
    required this.roomMembers,
    required this.onShareToMember,
  });

  @override
  Widget build(BuildContext context) {
    final trainers = roomMembers.where((m) => m['role'] == 'trener').toList();

    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.share, color: Colors.amberAccent),
          SizedBox(width: 8),
          Text('Prikaži poziciju treneru', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Izaberite predavača u učionici kome želite da pošaljete vašu poziciju sa table na uvid:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (trainers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Trenutno nema prijavljenih trenera u ovoj učionici.', style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
              )
            else
              ...trainers.map((t) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person, color: Colors.amber),
                    title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Trener / Predavač'),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onShareToMember(t);
                      },
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Prikaži treneru'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zatvori'),
        ),
      ],
    );
  }
}
