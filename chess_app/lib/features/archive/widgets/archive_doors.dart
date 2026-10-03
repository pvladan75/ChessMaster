import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';

/// The three places a player's imported games lead to, as quiet text buttons
/// of one kind (rule R4 of `docs/PLAN-EKRANI.md`).
///
/// One home for them: „My games" draws them on every player's card and
/// „Import games" draws them in its result card, and until phase 9 each held
/// its own copy, two filled and one tinted.
class ArchiveDoors extends StatelessWidget {
  const ArchiveDoors({super.key, required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Wrap(
      spacing: 4,
      children: [
        TextButton(
          style: style,
          onPressed: () => context.push(AppRoutes.archiveLeaksPath(subject)),
          child: const Text('View opening leaks'),
        ),
        TextButton(
          style: style,
          onPressed: () => context.push(
              '${AppRoutes.archiveRepertoire}?subject=${Uri.encodeQueryComponent(subject)}'),
          child: const Text('Repertoire from games'),
        ),
        TextButton(
          style: style,
          onPressed: () => context.push(AppRoutes.archiveProfilePath(subject)),
          child: const Text('Profile and habits'),
        ),
      ],
    );
  }
}
