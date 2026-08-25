import 'package:flutter/material.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/theme/app_typography.dart';

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
    if (!result.hasMotif) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.tealAccent, size: 16),
              const SizedBox(width: 6),
              Text('Taktički motivi',
                  style: AppText.bodyBold.copyWith(color: Colors.tealAccent)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: result.findings.map(_buildChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(MotifFinding finding) {
    final color = finding.favorsMover ? Colors.greenAccent : Colors.redAccent;
    return Tooltip(
      message: finding.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.6)),
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
