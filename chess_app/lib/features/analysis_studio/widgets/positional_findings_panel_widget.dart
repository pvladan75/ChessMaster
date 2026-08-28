import 'package:chess_app/core/models/positional_factor.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

String _factorLabel(PositionalFactor factor) {
  switch (factor) {
    case PositionalFactor.doubledPawn:
      return 'Udvojeni pešaci';
    case PositionalFactor.isolatedPawn:
      return 'Izolovani pešak';
    case PositionalFactor.backwardPawn:
      return 'Zaostali pešak';
    case PositionalFactor.passedPawn:
      return 'Prolazni pešak';
    case PositionalFactor.pawnIslands:
      return 'Pešačka ostrva';
    case PositionalFactor.openFile:
      return 'Otvorena linija';
    case PositionalFactor.semiOpenFile:
      return 'Poluotvorena linija';
    case PositionalFactor.centerControl:
      return 'Kontrola centra';
    case PositionalFactor.knightOutpost:
      return 'Uporište';
    case PositionalFactor.bishopPair:
      return 'Lovački par';
    case PositionalFactor.colorComplexWeakness:
      return 'Slab kompleks polja';
    case PositionalFactor.kingShield:
      return 'Sigurnost kralja';
  }
}

/// Shows the positional/strategic findings for the current position from
/// [PositionalEvaluatorService.evaluate] — same green/red convention as
/// [TacticalFindingsPanelWidget]: green favors whoever just moved, red is
/// what that move left the position with instead.
class PositionalFindingsPanelWidget extends StatelessWidget {
  final PositionalResult result;

  const PositionalFindingsPanelWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!result.hasFinding) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view, color: colors.warning, size: 16),
              const SizedBox(width: 6),
              Text(
                'Pozicioni faktori',
                style: AppText.bodyBold.copyWith(color: colors.warning),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                result.findings.map((f) => _buildChip(context, f)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, PositionalFinding finding) {
    final colors = context.colors;
    final color = finding.favorsMover ? colors.success : colors.danger;
    return Tooltip(
      message: finding.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          _factorLabel(finding.factors.first),
          style: AppText.caption
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
