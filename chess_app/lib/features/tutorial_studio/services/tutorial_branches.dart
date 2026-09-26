/// The branches of a tutorial, and their order — phase 2 of
/// `docs/PLAN-REDOSLED-GRANA.md`.
///
/// Since the owner's word of 26.9.2026 a part that goes back hangs from **the
/// move its row names**, so the parts that leave one move are exactly the
/// variations at that move, and their order is the film's. A **branch** is such
/// a part together with every part that hangs from it, directly or through
/// others. „Move variation earlier / later" swaps a branch with its neighbour
/// among the siblings: both are re-sequenced into the places they held, each
/// keeping its own order, and every other part stays where it was — the
/// owner's „da se prebace i svi nastavci".
///
/// Nothing can move before the part the move belongs to: siblings hang from
/// it, so they already come after it, and a swap only uses the places the two
/// branches held (D4).
library;

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_part_map.dart';

/// The parts that hang from the same move as part [part], in film order,
/// itself included; empty for a part that hangs from nothing (a new board).
List<int> siblingsOf(PartMap map, int part) {
  final from = map.entries[part].from;
  if (from == null) return const [];
  return [
    for (final e in map.entries)
      if (e.from == from) e.part,
  ];
}

/// Part [part] and every part that hangs from it, directly or through others,
/// in film order.
List<int> branchOf(PartMap map, int part) {
  final inBranch = <int>{part};
  for (final e in map.entries) {
    if (e.part <= part) continue;
    final from = e.from;
    if (from != null && inBranch.contains(from.part)) inBranch.add(e.part);
  }
  return inBranch.toList()..sort();
}

/// Whether part [part]'s branch can move one place [earlier] or later among
/// the branches that leave the same move.
bool canMoveBranch(TutorialDraft draft, int part, {required bool earlier}) {
  if (part < 0 || part >= draft.sections.length) return false;
  final siblings = siblingsOf(partMapOf(draft), part);
  final at = siblings.indexOf(part);
  if (at < 0) return false;
  return earlier ? at > 0 : at < siblings.length - 1;
}

/// Moves part [part]'s branch one place [earlier] or later among its siblings,
/// keeping the open part open. Answers whether anything moved.
bool moveBranch(TutorialDraft draft, int part, {required bool earlier}) {
  if (!canMoveBranch(draft, part, earlier: earlier)) return false;
  final map = partMapOf(draft);
  final siblings = siblingsOf(map, part);
  final at = siblings.indexOf(part);
  final first = branchOf(map, siblings[earlier ? at - 1 : at]);
  final second = branchOf(map, siblings[earlier ? at : at + 1]);

  final open = draft.section;
  final slots = [...first, ...second]..sort();
  final sequence = [
    for (final i in second) draft.sections[i],
    for (final i in first) draft.sections[i],
  ];
  for (var k = 0; k < slots.length; k++) {
    draft.sections[slots[k]] = sequence[k];
  }
  draft.selected = draft.sections.indexOf(open);
  return true;
}
