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
          const SizedBox(width: AppSpacing.sm),
          const Text('Show position to trainer', style: AppText.title),
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
                'Choose a trainer in the room to show your position to:',
                style: AppText.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              if (trainers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text('No trainers currently in this room.',
                      style: AppText.body.copyWith(color: colors.warning)),
                )
              else
                ...trainers.map((t) => ListTile(
                      dense: true,
                      leading: Icon(Icons.person, color: colors.warning),
                      title: Text(t['name'], style: AppText.bodyLargeBold),
                      subtitle: const Text('Trainer'),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onShareToMember(t);
                        },
                        icon: const Icon(Icons.send, size: 14),
                        label: const Text('Show to trainer'),
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
          child: const Text('Close'),
        ),
      ],
    );
  }
}
