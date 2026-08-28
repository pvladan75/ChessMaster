import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

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
    final colors = context.colors;
    final trainers = roomMembers.where((m) => m['role'] == 'trener').toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.share, color: colors.warning),
          const SizedBox(width: 8),
          const Text('Prikaži poziciju treneru', style: AppText.title),
        ],
      ),
      content: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Izaberite predavača u učionici kome želite da pošaljete vašu poziciju sa table na uvid:',
                style: AppText.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 12),
              if (trainers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                      'Trenutno nema prijavljenih trenera u ovoj učionici.',
                      style: AppText.body.copyWith(color: colors.warning)),
                )
              else
                ...trainers.map((t) => ListTile(
                      dense: true,
                      leading: Icon(Icons.person, color: colors.warning),
                      title: Text(t['name'], style: AppText.bodyLargeBold),
                      subtitle: const Text('Trener / Predavač'),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onShareToMember(t);
                        },
                        icon: const Icon(Icons.send, size: 14),
                        label: const Text('Prikaži treneru'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.warning,
                          foregroundColor: colors.canvas,
                        ),
                      ),
                    )),
            ],
          ),
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
