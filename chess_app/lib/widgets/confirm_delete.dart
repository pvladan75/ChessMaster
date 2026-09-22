import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';

/// Asks before a delete that cannot be taken back; true only on a clear yes,
/// and only while [context] is still mounted. One dialog for the Library's
/// cards and Home's recordings, so the two cannot drift apart.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  required String title,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $what?'),
      content: Text('"$title" will be permanently deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Delete', style: TextStyle(color: ctx.colors.danger)),
        ),
      ],
    ),
  );
  return confirmed == true && context.mounted;
}
