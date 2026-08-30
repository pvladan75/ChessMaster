import 'package:flutter/material.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The four counters an import run reports, and the reasons behind the fourth.
///
/// Its own widget so a test can draw it. Reached through the screen it lives
/// on, it only appears after a file picker and a poll, which is to say never in
/// a widget test — and this is the one row in the feature that is four items
/// wide on a 360 dp phone, where a release build clips silently instead of
/// painting the stripes.
class ImportCounters extends StatelessWidget {
  const ImportCounters({super.key, required this.run});

  final ArchiveRun run;

  /// "300 preskočeno" is a number; "300 preskočeno: 297 nije standardni šah"
  /// is an answer. The reasons are the whole reason the run counts four things
  /// instead of one.
  static String describeSkipped(int count, Map<String, int> reasons) {
    if (count == 0 || reasons.isEmpty) return 'preskočeno $count';

    final translated = reasons.entries.map((e) {
      final reason = switch (e.key) {
        'unparsable-pgn' => 'neispravan pgn',
        'not-standard-variant' => 'nije standardni šah',
        'unfinished-game' => 'nezavršena partija',
        'subject-not-in-game' => 'igrač nije u partiji',
        'no-moves' => 'bez poteza',
        _ => e.key,
      };
      return '${e.value} $reason';
    }).join(', ');
    return 'preskočeno $count: $translated';
  }

  @override
  Widget build(BuildContext context) {
    final style = AppText.body.copyWith(color: context.colors.textSecondary);
    final parts = [
      'pročitano ${run.gamesRead}',
      'upisano ${run.gamesStored}',
      'već postojalo ${run.gamesDuplicate}',
      describeSkipped(run.gamesSkipped, run.skippedByReason),
    ];

    // Wrap, not Row: four counters and a list of skip reasons do not fit on a
    // 360 dp phone, and a Row would simply lose the last one off the edge.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) Text('·', style: style),
          Text(parts[i], style: style),
        ],
      ],
    );
  }
}
