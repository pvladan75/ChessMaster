import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The one menu a move in a tree opens — phase 1 of
/// `docs/PLAN-REDOSLED-GRANA.md`.
///
/// It existed twice, once in the graph and once in the notation, and the two
/// had drifted: the notation drew an item only when its callback was given
/// (the 7.9.2026 finding of a „Delete" that did nothing), the graph drew
/// „Promote" and „Delete" always. One list now, and two ways to show it: a
/// menu at the pointer for a right click, a sheet from the bottom for a long
/// press — which is how a desktop and a phone each open a menu.
class MoveTreeMenuItem {
  const MoveTreeMenuItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.tone,
  });

  final Key key;
  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// The icon's colour, from the theme; the text colour is always the same.
  final Color Function(BuildContext context)? tone;
}

/// Labels of the two new commands — D2 of the plan: not „up/down", because the
/// graph's default layout puts variations side by side.
const String moveVariationEarlierLabel = 'Move variation earlier';
const String moveVariationLaterLabel = 'Move variation later';

/// What [node]'s menu offers, each item only where it does something (rule
/// 15): a callback that was not given draws nothing, and a variation that is
/// already first or last is not offered the move it cannot make.
List<MoveTreeMenuItem> moveTreeMenuItems(
  AnalysisNode node, {
  void Function(AnalysisNode node)? onPromoteNode,
  void Function(AnalysisNode node)? onDeleteNode,
  String Function(AnalysisNode node)? deleteLabel,
  String? Function(AnalysisNode node)? extraLabel,
  void Function(AnalysisNode node)? onExtra,
  void Function(AnalysisNode node, {required bool earlier})? onMoveVariation,
}) {
  final parent = node.parent;
  final extra = extraLabel?.call(node);
  bool can(bool earlier) =>
      onMoveVariation != null &&
      parent != null &&
      parent.canMoveVariation(node, earlier: earlier);
  return [
    if (onPromoteNode != null)
      MoveTreeMenuItem(
        key: const Key('move-menu-promote'),
        label: 'Promote to Main Line',
        icon: Icons.star,
        tone: (c) => c.colors.warning,
        onSelected: () {
          if (parent != null) onPromoteNode(node);
        },
      ),
    if (can(true))
      MoveTreeMenuItem(
        key: const Key('move-menu-earlier'),
        label: moveVariationEarlierLabel,
        icon: Icons.move_up,
        tone: (c) => c.colors.accent,
        onSelected: () => onMoveVariation!(node, earlier: true),
      ),
    if (can(false))
      MoveTreeMenuItem(
        key: const Key('move-menu-later'),
        label: moveVariationLaterLabel,
        icon: Icons.move_down,
        tone: (c) => c.colors.accent,
        onSelected: () => onMoveVariation!(node, earlier: false),
      ),
    if (onDeleteNode != null)
      MoveTreeMenuItem(
        key: const Key('move-menu-delete'),
        label: deleteLabel?.call(node) ?? 'Delete this variation',
        icon: Icons.delete,
        tone: (c) => c.colors.danger,
        onSelected: () => onDeleteNode(node),
      ),
    if (extra != null)
      MoveTreeMenuItem(
        key: const Key('move-menu-extra'),
        label: extra,
        icon: Icons.call_split,
        tone: (c) => c.colors.accent,
        onSelected: () => onExtra?.call(node),
      ),
  ];
}

/// Opens [items] — at [at], a pointer's position, as a menu (a right click on
/// the desktop), or without it as a sheet from the bottom (a long press).
///
/// [moreTitle] and [more] are a second section under a divider: the graph's
/// „Same position reached via:". Nothing at all opens nothing — an empty menu
/// is the same lie as a dead item, one step further on.
Future<void> showMoveTreeMenu(
  BuildContext context, {
  required List<MoveTreeMenuItem> items,
  Offset? at,
  String? moreTitle,
  List<MoveTreeMenuItem> more = const [],
}) async {
  if (items.isEmpty && more.isEmpty) return;

  if (at != null) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final chosen = await showMenu<MoveTreeMenuItem>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(at, at),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final item in items) _popupItem(context, item),
        if (more.isNotEmpty) ...[
          const PopupMenuDivider(),
          if (moreTitle != null)
            PopupMenuItem<MoveTreeMenuItem>(
              enabled: false,
              height: 32,
              child: Text(moreTitle,
                  style: AppText.captionBold
                      .copyWith(color: context.colors.textMuted)),
            ),
          for (final item in more) _popupItem(context, item),
        ],
      ],
    );
    chosen?.onSelected();
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items) _sheetTile(ctx, item),
          if (more.isNotEmpty) ...[
            Divider(color: ctx.colors.border, height: 1),
            if (moreTitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 10, AppSpacing.lg, AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(moreTitle,
                      style: AppText.captionBold
                          .copyWith(color: ctx.colors.textMuted)),
                ),
              ),
            for (final item in more) _sheetTile(ctx, item),
          ],
        ],
      ),
    ),
  );
}

PopupMenuItem<MoveTreeMenuItem> _popupItem(
        BuildContext context, MoveTreeMenuItem item) =>
    PopupMenuItem<MoveTreeMenuItem>(
      key: item.key,
      value: item,
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: item.tone?.call(context)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(item.label,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
          ),
        ],
      ),
    );

Widget _sheetTile(BuildContext ctx, MoveTreeMenuItem item) => ListTile(
      key: item.key,
      leading: Icon(item.icon, color: item.tone?.call(ctx)),
      title: Text(item.label,
          style: AppText.bodyLarge.copyWith(color: ctx.colors.textPrimary)),
      onTap: () {
        // Closed first, then done: the action may push or rebuild the screen
        // the sheet belongs to.
        Navigator.pop(ctx);
        item.onSelected();
      },
    );
