import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

String _motifLabel(TacticalMotif motif) {
  switch (motif) {
    case TacticalMotif.pin:
      return 'Vez';
    case TacticalMotif.fork:
      return 'Viljuška';
    case TacticalMotif.discoveredAttack:
      return 'Otkriveni napad';
    case TacticalMotif.skewer:
      return 'Ražanj';
    case TacticalMotif.deflection:
      return 'Skretanje';
    case TacticalMotif.overloading:
      return 'Preopterećenje';
    case TacticalMotif.hangingPiece:
      return 'Visi figura';
    case TacticalMotif.mateThreat:
      return 'Pretnja matom';
    case TacticalMotif.doubleAttack:
      return 'Dvostruki napad';
    case TacticalMotif.mateThreatAndPieceAttack:
      return 'Dvojni udar';
  }
}

/// Shows the tactical findings for the current position from
/// [TacticalMotifDetector.detect]: green chips are threats/advantages for
/// whoever just moved, red chips are what that move left exposed instead.
class TacticalFindingsPanelWidget extends StatelessWidget {
  final MotifResult result;

  const TacticalFindingsPanelWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!result.hasMotif) return const SizedBox.shrink();

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
              Icon(Icons.bolt, color: colors.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                'Taktički motivi',
                style: AppText.bodyBold.copyWith(color: colors.accent),
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

  Widget _buildChip(BuildContext context, MotifFinding finding) {
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
          _motifLabel(finding.motifs.first),
          style: AppText.caption
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
