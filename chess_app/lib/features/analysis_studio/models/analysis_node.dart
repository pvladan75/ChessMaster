import 'dart:math' as math;

import 'package:chess_app/move_tree.dart';

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

  /// What the author drew on the board at this move.
  ///
  /// The studio could not hold these at all until phase 2 of
  /// `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`, while [MoveTree] — the room's model
  /// of the same thing — has held arrows and written `[%cal]` for a long time.
  /// Two models of one tree that disagreed about what a node may carry meant a
  /// trainer's arrow survived in one screen and vanished in the other, which is
  /// the sort of loss nobody reports as a bug because it looks like they forgot
  /// to draw it.
  ///
  /// Nothing in the studio writes these yet; the editor that does is phase 7.
  /// The format carries them from here so that when it arrives there is no
  /// second migration of everything already saved.
  List<ChessArrow> arrows;
  List<SquareMark> squares;

  List<AnalysisNode> children;
  AnalysisNode? parent;

  AnalysisNode({
    String? id,
    required this.fen,
    this.moveSan,
    this.moveUci,
    this.comment = '',
    this.nag,
    List<ChessArrow>? arrows,
    List<SquareMark>? squares,
    List<AnalysisNode>? children,
    this.parent,
  })  : id = id ?? _generateId(),
        arrows = arrows ?? [],
        squares = squares ?? [],
        children = children ?? [];

  /// The stored list as the dialect writes it: `Gd1h5,Rf1c4`.
  ///
  /// Empty when there is nothing stored, which the tag readers answer with an
  /// empty list — so a node saved before this field existed comes back with no
  /// arrows rather than with a broken one.
  static String _asCsv(dynamic value) {
    if (value is! List) return '';
    return value.whereType<String>().join(',');
  }

  static String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final rand = math.Random().nextInt(999999);
    return '${timestamp}_$rand';
  }

  /// Returns true if this is the root node (has no parent)
  bool get isRoot => parent == null;

  /// The move number this node carries, in the form a book writes it: `4. `
  /// for White's move and `4... ` for Black's, with the trailing space.
  ///
  /// Read from the FEN of the position the move led to, which is the only
  /// place that knows where the counting started — a tutorial part may open on
  /// any position, so the ply from the root is not the move number. Empty for
  /// the root, which is a position rather than a move.
  ///
  /// It lived as `_moveNumberOf` inside `VisualMoveTreeWidget` until the „Tok"
  /// timeline needed the same sentence. One rule, one home: three hand-written
  /// copies of one condition is how the `status = 'accepted'` bug got in.
  String get moveNumberLabel {
    if (isRoot) return '';
    final parts = fen.split(' ');
    if (parts.length < 6) return '';
    final fullmove = int.tryParse(parts[5]);
    if (fullmove == null) return '';
    // Black's move increments the counter, so the number belonging to it is
    // the one before.
    return fen.contains(' b ') ? '$fullmove. ' : '${fullmove - 1}... ';
  }

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
      if (arrows.isNotEmpty) 'arrows': arrows.map((a) => a.toString()).toList(),
      if (squares.isNotEmpty)
        'squares': squares.map((s) => s.toString()).toList(),
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
      // Read through the one dialect reader rather than a second decoder here:
      // `Gd1h5` and `Rd5` mean what `[%cal]` and `[%csl]` say they mean, and a
      // saved tree must not develop its own idea of that.
      arrows: MoveTree.parsePgnArrows('[%cal ${_asCsv(json['arrows'])}]'),
      squares: MoveTree.parsePgnSquares('[%csl ${_asCsv(json['squares'])}]'),
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
