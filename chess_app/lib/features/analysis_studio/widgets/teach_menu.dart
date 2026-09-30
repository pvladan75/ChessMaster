import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// One row of the door into teaching material, by what it does.
enum TeachRow {
  newFromPosition,
  newFromLine,
  newFromGame,
  addPosition,
  addLine,
  edit,
}

/// The rows the door draws, in its three groups — new, add, edit — and the
/// one home of which of them a board can deliver: the sheet on a phone and
/// the „Tutorial" menu of a window's bar both read this, so neither can offer
/// a row the other hides.
List<List<(TeachRow, String, IconData)>> teachRowGroups({
  required bool hasLine,
  required bool hasGame,
}) =>
    [
      [
        (
          TeachRow.newFromPosition,
          TeachMenuSheet.newFromPosition,
          Icons.auto_stories_outlined
        ),
        if (hasLine)
          (TeachRow.newFromLine, TeachMenuSheet.newFromLine, Icons.timeline),
        if (hasGame)
          (
            TeachRow.newFromGame,
            TeachMenuSheet.newFromGame,
            Icons.school_outlined
          ),
      ],
      [
        (TeachRow.addPosition, TeachMenuSheet.addPosition, Icons.add_task),
        if (hasLine)
          (TeachRow.addLine, TeachMenuSheet.addLine, Icons.playlist_add),
      ],
      [
        (TeachRow.edit, TeachMenuSheet.edit, Icons.edit_note),
      ],
    ];

/// The same rows as the entries of a popup menu, a divider between groups —
/// what „Tutorial" opens in the bar of a desktop window
/// (`docs/PLAN-ANALIZA-TRAKA.md`, D4).
List<PopupMenuEntry<TeachRow>> teachMenuEntries({
  required bool hasLine,
  required bool hasGame,
}) {
  final entries = <PopupMenuEntry<TeachRow>>[];
  for (final group in teachRowGroups(hasLine: hasLine, hasGame: hasGame)) {
    if (entries.isNotEmpty) entries.add(const PopupMenuDivider());
    for (final (id, label, _) in group) {
      entries.add(PopupMenuItem<TeachRow>(value: id, child: Text(label)));
    }
  }
  return entries;
}

/// The one door from Analysis into teaching material.
///
/// Phase 1 of `docs/PLAN-REORGANIZACIJA.md` (S2). Four bar actions with four
/// names led to three places; now one action, „Use in a tutorial", opens this
/// sheet and the question is asked once, after the tap. The rows are frozen
/// here and in `docs/gates/`: a synonym that reads better in one place is how
/// a vocabulary comes apart.
///
/// The sheet draws only what it was given (rule 15): a row whose condition is
/// false is not drawn greyed out, it is absent. Since phase 6c of
/// `docs/PLAN-REORGANIZACIJA.md` every row is drawn on every platform; only
/// `hasLine` and `hasGame` still hide one.
///
/// Every callback runs **after** the sheet has closed, so a row that pushes a
/// screen pushes it over the Analysis board and not over the sheet.
class TeachMenuSheet extends StatelessWidget {
  const TeachMenuSheet({
    super.key,
    required this.hasLine,
    required this.hasGame,
    required this.onNewFromPosition,
    required this.onNewFromLine,
    required this.onNewFromGame,
    required this.onAddPosition,
    required this.onAddLine,
    required this.onEdit,
  });

  /// The cursor's node has moves after it.
  final bool hasLine;

  /// The tree has a main line at all — the game flow refuses an empty one.
  final bool hasGame;

  final VoidCallback onNewFromPosition;
  final VoidCallback onNewFromLine;
  final VoidCallback onNewFromGame;
  final VoidCallback onAddPosition;
  final VoidCallback onAddLine;
  final VoidCallback onEdit;

  static const String title = 'Use in a tutorial';

  static const String newFromPosition = 'New tutorial from this position';
  static const String newFromLine = 'New tutorial from this line';
  static const String newFromGame = 'New tutorial from this game';
  static const String addPosition = 'Add this position to a tutorial…';
  static const String addLine = 'Add this line to a tutorial…';
  static const String edit = 'Open a tutorial to edit…';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget row(String label, IconData icon, VoidCallback onTap) => ListTile(
          dense: true,
          leading: Icon(icon, size: 20, color: colors.accent),
          title: Text(label,
              style: AppText.bodyLarge.copyWith(color: colors.textPrimary)),
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
        );

    final callbacks = <TeachRow, VoidCallback>{
      TeachRow.newFromPosition: onNewFromPosition,
      TeachRow.newFromLine: onNewFromLine,
      TeachRow.newFromGame: onNewFromGame,
      TeachRow.addPosition: onAddPosition,
      TeachRow.addLine: onAddLine,
      TeachRow.edit: onEdit,
    };
    final groups = teachRowGroups(hasLine: hasLine, hasGame: hasGame);

    // Six rows and a title do not fit the 9/16 of a 360 × 640 phone a modal
    // sheet is allowed by default — the first run of the 360 dp test
    // overflowed by nine pixels — so the column scrolls inside the sheet.
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxs),
              child: Text(title,
                  style: AppText.bodyBold.copyWith(color: colors.textPrimary)),
            ),
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              for (final (id, label, icon) in groups[i])
                row(label, icon, callbacks[id]!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the sheet over [context]. Same parameters as [TeachMenuSheet].
Future<void> showTeachMenu(
  BuildContext context, {
  required bool hasLine,
  required bool hasGame,
  required VoidCallback onNewFromPosition,
  required VoidCallback onNewFromLine,
  required VoidCallback onNewFromGame,
  required VoidCallback onAddPosition,
  required VoidCallback onAddLine,
  required VoidCallback onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => TeachMenuSheet(
      hasLine: hasLine,
      hasGame: hasGame,
      onNewFromPosition: onNewFromPosition,
      onNewFromLine: onNewFromLine,
      onNewFromGame: onNewFromGame,
      onAddPosition: onAddPosition,
      onAddLine: onAddLine,
      onEdit: onEdit,
    ),
  );
}
