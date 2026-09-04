import 'dart:math' as math;

class AnalysisNode {
  final String id;
  String fen;
  String? moveSan;
  String? moveUci;
  String comment;
  String? nag; // '!!', '!', '?', '??', '!?', '!□'

  // A node used to carry the engine's evaluation, and it no longer does.
  // Removed 4.9.2026 by the owner's decision: a number the engine wrote is not
  // a thing the reader chose to say, and the place for what the reader wants
  // remembered about a position is [comment], which they type. It also ended a
  // fault rather than tidying one — two writers of that field encoded a mate
  // differently (±(100 − distance) from the live engine, ±(1000 − distance)
  // from the generator), so a mate the engine found live was drawn on a card
  // as „+98.00". Deleting the field deletes both the encoder and the decoder.
  //
  // Reading an old saved tree still works: `eval` and `evalDepth` are simply
  // not read out of the JSON any more.

  List<AnalysisNode> children;
  AnalysisNode? parent;

  AnalysisNode({
    String? id,
    required this.fen,
    this.moveSan,
    this.moveUci,
    this.comment = '',
    this.nag,
    List<AnalysisNode>? children,
    this.parent,
  })  : id = id ?? _generateId(),
        children = children ?? [];

  static String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final rand = math.Random().nextInt(999999);
    return '${timestamp}_$rand';
  }

  /// Returns true if this is the root node (has no parent)
  bool get isRoot => parent == null;

  /// Returns true if this node is in the main line (0th index child of parent)
  bool get isMainLine {
    if (parent == null) return true;
    return parent!.children.isNotEmpty && parent!.children.first.id == id;
  }

  /// Adds a child move node. If a move with the same moveUci already exists, returns existing node.
  AnalysisNode addChild({
    required String childFen,
    required String san,
    required String uci,
  }) {
    for (var child in children) {
      if (child.moveUci == uci) {
        return child;
      }
    }
    final newNode = AnalysisNode(
      fen: childFen,
      moveSan: san,
      moveUci: uci,
      parent: this,
    );
    children.add(newNode);
    return newNode;
  }

  /// Promotes a child variation node to be the main line (0th index in children list).
  void promoteToMainLine(AnalysisNode child) {
    final index = children.indexWhere((c) => c.id == child.id);
    if (index > 0) {
      final promoted = children.removeAt(index);
      children.insert(0, promoted);
    }
  }

  /// Removes a child variation node.
  void removeChild(AnalysisNode child) {
    children.removeWhere((c) => c.id == child.id);
  }

  /// Serializes this node and its full subtree. [parent] is intentionally
  /// omitted — it's reconstructed by [fromJson] from tree structure alone.
  Map<String, dynamic> toJson() {
    return {
      'fen': fen,
      'moveSan': moveSan,
      'moveUci': moveUci,
      'comment': comment,
      'nag': nag,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  /// Rebuilds a node and its full subtree from [toJson] output, wiring each
  /// child's [parent] back-reference as it goes.
  factory AnalysisNode.fromJson(Map<String, dynamic> json,
      {AnalysisNode? parent}) {
    final node = AnalysisNode(
      fen: json['fen'] as String,
      moveSan: json['moveSan'] as String?,
      moveUci: json['moveUci'] as String?,
      comment: json['comment'] as String? ?? '',
      nag: json['nag'] as String?,
      parent: parent,
    );
    final childrenJson = (json['children'] as List?) ?? const [];
    node.children = childrenJson
        .whereType<Map>()
        .map((c) =>
            AnalysisNode.fromJson(Map<String, dynamic>.from(c), parent: node))
        .toList();
    return node;
  }
}
