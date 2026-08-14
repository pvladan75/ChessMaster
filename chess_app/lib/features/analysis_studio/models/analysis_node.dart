import 'dart:math' as math;

class AnalysisNode {
  final String id;
  String fen;
  String? moveSan;
  String? moveUci;
  String comment;
  String? nag; // '!!', '!', '?', '??', '!?', '!□'
  double? eval;

  /// Engine depth [eval] was computed at. Lets a shallower, later analysis
  /// (e.g. the live eval bar re-triggering for whatever node is on screen)
  /// avoid silently overwriting a deeper, more authoritative eval that a
  /// prior whole-game review already wrote — see the live-analysis callback
  /// in AnalysisStudioScreen.
  int? evalDepth;

  List<AnalysisNode> children;
  AnalysisNode? parent;

  AnalysisNode({
    String? id,
    required this.fen,
    this.moveSan,
    this.moveUci,
    this.comment = '',
    this.nag,
    this.eval,
    this.evalDepth,
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
      'eval': eval,
      'evalDepth': evalDepth,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  /// Rebuilds a node and its full subtree from [toJson] output, wiring each
  /// child's [parent] back-reference as it goes.
  factory AnalysisNode.fromJson(Map<String, dynamic> json, {AnalysisNode? parent}) {
    final node = AnalysisNode(
      fen: json['fen'] as String,
      moveSan: json['moveSan'] as String?,
      moveUci: json['moveUci'] as String?,
      comment: json['comment'] as String? ?? '',
      nag: json['nag'] as String?,
      eval: (json['eval'] as num?)?.toDouble(),
      evalDepth: (json['evalDepth'] as num?)?.toInt(),
      parent: parent,
    );
    final childrenJson = (json['children'] as List?) ?? const [];
    node.children = childrenJson
        .whereType<Map>()
        .map((c) => AnalysisNode.fromJson(Map<String, dynamic>.from(c), parent: node))
        .toList();
    return node;
  }
}
