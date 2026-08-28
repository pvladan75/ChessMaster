import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class MoveHistoryView extends StatelessWidget {
  final MoveTree moveTree;
  final MoveNode currentNode;
  final Function(MoveNode node) onSelectNode;

  const MoveHistoryView({
    super.key,
    required this.moveTree,
    required this.currentNode,
    required this.onSelectNode,
  });

  List<InlineSpan> _buildSpans(MoveNode node, BuildContext context) {
    final List<InlineSpan> spans = [];
    _collectSpans(node, spans, context, true);
    return spans;
  }

  void _collectSpans(MoveNode node, List<InlineSpan> spans,
      BuildContext context, bool showMoveNumber) {
    if (node.children.isEmpty) return;
    final colors = context.colors;

    final mainChild = node.children[0];
    final parts = node.fen.split(' ');
    final isWhite = parts.length > 1 ? parts[1] == 'w' : true;
    final moveNum = parts.length > 5 ? (int.tryParse(parts[5]) ?? 1) : 1;

    if (isWhite) {
      spans.add(TextSpan(
        text: '$moveNum. ',
        style: AppText.bodyLargeBold.copyWith(color: colors.textMuted),
      ));
    } else if (showMoveNumber) {
      spans.add(TextSpan(
        text: '$moveNum... ',
        style: AppText.bodyLargeBold.copyWith(color: colors.textMuted),
      ));
    }

    final isMainActive = currentNode == mainChild;

    spans.add(TextSpan(
      text: '${mainChild.san} ',
      style: AppText.bodyLargeBold.copyWith(
        color: isMainActive ? colors.success : colors.textPrimary,
        backgroundColor: isMainActive
            ? colors.success.withValues(alpha: 0.15)
            : Colors.transparent,
      ),
      recognizer: TapGestureRecognizer()..onTap = () => onSelectNode(mainChild),
    ));

    if (mainChild.comment.isNotEmpty) {
      spans.add(TextSpan(
        text: '{${mainChild.comment}} ',
        style: AppText.body.copyWith(
          color: colors.warning,
          fontStyle: FontStyle.italic,
        ),
      ));
    }

    // Variations
    for (int i = 1; i < node.children.length; i++) {
      final varChild = node.children[i];
      spans.add(TextSpan(
        text: '( ',
        style: AppText.caption.copyWith(color: colors.textMuted),
      ));

      if (isWhite) {
        spans.add(TextSpan(
          text: '$moveNum. ',
          style: AppText.caption.copyWith(color: colors.textMuted),
        ));
      } else {
        spans.add(TextSpan(
          text: '$moveNum... ',
          style: AppText.caption.copyWith(color: colors.textMuted),
        ));
      }

      final isVarActive = currentNode == varChild;

      spans.add(TextSpan(
        text: '${varChild.san} ',
        style: AppText.caption.copyWith(
          fontWeight: FontWeight.normal,
          color: isVarActive ? colors.success : colors.textMuted,
          backgroundColor: isVarActive
              ? colors.success.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => onSelectNode(varChild),
      ));

      if (varChild.comment.isNotEmpty) {
        spans.add(TextSpan(
          text: '{${varChild.comment}} ',
          style: AppText.micro.copyWith(
            color: colors.warning,
            fontStyle: FontStyle.italic,
          ),
        ));
      }

      _collectSpans(varChild, spans, context, false);

      spans.add(TextSpan(
        text: ') ',
        style: AppText.caption.copyWith(color: colors.textMuted),
      ));
    }

    final nextShowMoveNumber = node.children.length > 1;
    _collectSpans(mainChild, spans, context, nextShowMoveNumber);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final List<InlineSpan> spans = _buildSpans(moveTree.root, context);

    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: colors.border),
      ),
      child: spans.isEmpty
          ? Center(
              child: Text(
                'Nema odigranih poteza.',
                style: AppText.bodyLarge.copyWith(color: colors.textMuted),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: RichText(
                text: TextSpan(
                  children: spans,
                ),
              ),
            ),
    );
  }
}
