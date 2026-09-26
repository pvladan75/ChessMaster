/// A tutorial's family of parts as one move tree, **for display only** — D6
/// of `docs/PLAN-REDOSLED-GRANA.md`.
///
/// The Tree tab showed the open part alone, and since a part is one line that
/// was a chain with nothing to reorder: the variations of a tutorial are its
/// other parts. So the tab draws the open part's **family** — every part joined
/// to it by hanging — as one tree: the first part as it is, and each part that
/// hangs from a move attached under that move, after the line that was already
/// going on there. Its variations at a move are therefore the parts that leave
/// that move, in film order.
///
/// **Nothing is merged into the draft**, and that is the point: two parts often
/// say two things about one position, and a stored tree has room for one
/// comment per node — which is why editing the tutorial as one PGN is not in
/// that plan. These nodes are copies. Each keeps its original's **id**, so the
/// tree widget's „this is the move you are on" works unchanged, and
/// [originOf] leads back to the part and the node the copy was made from.
library;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_part_map.dart';

/// Where a node of the family tree came from.
typedef TreeOrigin = ({int part, AnalysisNode node});

class TutorialTree {
  TutorialTree._(this.root, this._origin, this._shownAt, this.map);

  /// The family's first part, with every hanging part attached.
  final AnalysisNode root;

  /// The map the family was read from.
  final PartMap map;

  final Map<String, TreeOrigin> _origin;
  final Map<String, AnalysisNode> _shownAt;

  /// The part and the original node a node of this tree was copied from.
  TreeOrigin? originOf(AnalysisNode node) => _origin[node.id];

  /// Where [original], a node of some part, is drawn — for a part's own
  /// starting position that is the move it hangs from.
  AnalysisNode? shownAt(AnalysisNode original) => _shownAt[original.id];

  /// The part whose branch [node] starts, when it is the first move of a part
  /// that hangs from a move; null for a move inside a part.
  ///
  /// A part that only adds a sentence where another ended has no move of its
  /// own, so the first move of the part after it stands for both: the branch
  /// is the first part up that chain that hangs from the move itself.
  int? branchAt(AnalysisNode node, TutorialDraft draft) {
    final origin = _origin[node.id];
    if (origin == null) return null;
    final part = draft.sections[origin.part];
    if (!identical(origin.node.parent, part.root)) return null;
    var branch = origin.part;
    if (map.entries[branch].from == null) return null;
    while (true) {
      final from = map.entries[branch].from!;
      final above = draft.sections[from.part];
      final climbs = from.beat == 0 &&
          above.root.children.isEmpty &&
          map.entries[from.part].from != null;
      if (!climbs) return branch;
      branch = from.part;
    }
  }
}

/// The open part's family of [draft] as one tree.
TutorialTree tutorialTreeOf(TutorialDraft draft) {
  final map = partMapOf(draft);
  final family = _familyOf(map, draft.selected);
  final origin = <String, TreeOrigin>{};
  final shownAt = <String, AnalysisNode>{};

  AnalysisNode copy(AnalysisNode o, AnalysisNode? parent, int part) {
    final n = AnalysisNode(
      id: o.id,
      fen: o.fen,
      moveSan: o.moveSan,
      moveUci: o.moveUci,
      comment: o.comment,
      nag: o.nag,
      arrows: [...o.arrows],
      squares: [...o.squares],
      parent: parent,
    );
    origin[n.id] = (part: part, node: o);
    shownAt[o.id] = n;
    n.children = [for (final c in o.children) copy(c, n, part)];
    return n;
  }

  AnalysisNode? root;
  for (final part in family) {
    final section = draft.sections[part];
    final from = map.entries[part].from;
    if (from == null) {
      root = copy(section.root, null, part);
      continue;
    }
    final target = shownAt[_beat(draft.sections[from.part], from.beat).id]!;
    shownAt[section.root.id] = target;
    for (final child in section.root.children) {
      target.children.add(copy(child, target, part));
    }
  }
  return TutorialTree._(root!, origin, shownAt, map);
}

/// The node of [part]'s line at [beat] — its first children, [beat] deep.
AnalysisNode _beat(TutorialSection part, int beat) {
  var node = part.root;
  for (var i = 0; i < beat && node.children.isNotEmpty; i++) {
    node = node.children.first;
  }
  return node;
}

/// Every part joined to [part] by hanging, either way, in film order.
List<int> _familyOf(PartMap map, int part) {
  // Union by the one link each part has, to the part it hangs from.
  final parent = List<int>.generate(map.entries.length, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  for (final e in map.entries) {
    final from = e.from;
    if (from != null) parent[find(e.part)] = find(from.part);
  }
  final mine = find(part);
  return [
    for (var i = 0; i < map.entries.length; i++)
      if (find(i) == mine) i,
  ];
}
