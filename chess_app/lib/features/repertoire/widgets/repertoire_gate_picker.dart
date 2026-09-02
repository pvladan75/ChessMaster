import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// One move out of a position, as the gate picker offers it.
class GateOption {
  const GateOption({
    required this.uci,
    required this.san,
    this.kept = false,
  });

  final String uci;
  final String san;

  /// Already one of the student's own moves in this position. Shown first and
  /// marked, because when two repertoires share a root the gate is nearly
  /// always a move one of them has already kept.
  final bool kept;
}

/// Every legal move in [fen], the kept ones first.
///
/// SAN is read from the library rather than assembled by hand — the same reason
/// the rest of the app does: castling alone has three different spellings
/// between the board, Lichess and the store, and this is the one place a wrong
/// one would silently pick a different gate.
List<GateOption> gateOptionsFor(String fen, {List<String> kept = const []}) {
  final chess.Chess game;
  try {
    game = chess.Chess.fromFEN(fen);
  } catch (_) {
    return const [];
  }
  final out = <GateOption>[];
  for (final move in legalMoves(game)) {
    final from = move['from'] as String?;
    final to = move['to'] as String?;
    if (from == null || to == null) continue;
    final promotion = (move['promotion'] as String?) ?? '';
    if (!playMove(game, move)) continue;
    final made = game.history.last.move;
    game.undo_move();
    final san = game.move_to_san(made);
    final uci = '$from$to$promotion';
    out.add(GateOption(uci: uci, san: san, kept: kept.contains(uci)));
  }
  out.sort((a, b) {
    if (a.kept != b.kept) return a.kept ? -1 : 1;
    return a.san.compareTo(b.san);
  });
  return out;
}

/// Choosing the move a repertoire goes through at its root.
///
/// Returns the uci chosen, the empty string for "no gate — the whole graph", or
/// null when the sheet was closed without deciding. Three answers, because
/// clearing a gate and changing nothing are different things and the caller
/// must not have to guess which happened.
///
/// The moves already kept in this position are at the top and marked: when two
/// repertoires share a root, the gate is nearly always a first move one of them
/// has already decided. Everything else legal is below, because the repertoire
/// being created may go through a move that has not been played yet — which is
/// exactly the case that made this feature necessary.
Future<String?> showGatePicker(
  BuildContext context, {
  required String rootFen,
  List<String> kept = const [],
  String? current,
}) {
  final options = gateOptionsFor(rootFen, kept: kept);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Kroz koji potez ide ovaj repertoar?',
                style:
                    AppText.bodyBold.copyWith(color: sheet.colors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Potezi ostaju zajednički za celu boju — ovo bira samo šta se '
              'vidi: stablo, red za odlučivanje i vežbanje pokazuju jedno '
              'otvaranje.',
              style: AppText.caption.copyWith(color: sheet.colors.textMuted),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(Icons.all_inclusive,
                      size: 18, color: sheet.colors.textSecondary),
                  title: const Text('Bez ograničenja'),
                  subtitle: Text('Ceo graf iz ove pozicije, kao do sada.',
                      style: AppText.caption
                          .copyWith(color: sheet.colors.textMuted)),
                  trailing: current == null
                      ? Icon(Icons.check, size: 18, color: sheet.colors.success)
                      : null,
                  // The empty string, not null: null is "closed without
                  // deciding", and clearing a gate is a decision.
                  onTap: () => Navigator.pop(sheet, ''),
                ),
                const Divider(height: 1),
                for (final option in options)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      option.kept
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                      size: 18,
                      color: option.kept
                          ? sheet.colors.success
                          : sheet.colors.textMuted,
                    ),
                    title: Text(option.san, style: AppText.bodyLarge),
                    subtitle: option.kept
                        ? Text('Već igrate ovaj potez ovde',
                            style: AppText.caption
                                .copyWith(color: sheet.colors.textMuted))
                        : null,
                    trailing: option.uci == current
                        ? Icon(Icons.check,
                            size: 18, color: sheet.colors.success)
                        : null,
                    onTap: () => Navigator.pop(sheet, option.uci),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
