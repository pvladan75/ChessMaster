import 'package:flutter/material.dart';
import 'package:chess_app/core/models/positional_factor.dart';
import 'package:chess_app/theme/app_typography.dart';

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
    if (!result.hasFinding) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view, color: Colors.amberAccent, size: 16),
              const SizedBox(width: 6),
              Text('Pozicioni faktori', style: AppText.bodyBold.copyWith(color: Colors.amberAccent)),
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

  Widget _buildChip(PositionalFinding finding) {
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
          _factorLabel(finding.factors.first),
          style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
