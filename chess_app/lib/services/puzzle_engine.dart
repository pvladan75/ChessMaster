enum MoveValidationResult {
  correct,
  incorrect,
  checkmate,
}

class BranchPoint {
  final String moveUci;
  final List<String> remainingOpponentMoves;

  BranchPoint({
    required this.moveUci,
    required this.remainingOpponentMoves,
  });
}

class PuzzleEngine {
  final Map<String, dynamic> rootSolutions;
  Map<String, dynamic>? _currentNode;
  final List<String> _visitedMovePath = [];
  final List<BranchPoint> _branchPoints = [];
  int _completedVariations = 0;
  int _totalVariations = 0;

  PuzzleEngine(this.rootSolutions) {
    _currentNode = Map<String, dynamic>.from(rootSolutions);
    _calculateTotalVariations(rootSolutions);
    if (_totalVariations == 0) _totalVariations = 1;
  }

  Map<String, dynamic>? get currentNode => _currentNode;
  List<String> get visitedMovePath => List.unmodifiable(_visitedMovePath);
  int get completedVariations => _completedVariations;
  int get totalVariations => _totalVariations;
  bool get isFullySolved => _completedVariations > 0 && _completedVariations >= _totalVariations;
  List<BranchPoint> get branchPoints => List.unmodifiable(_branchPoints);

  void _calculateTotalVariations(dynamic node) {
    if (node == 'CHECKMATE' || node == null) {
      _totalVariations++;
      return;
    }
    if (node is Map) {
      if (node.isEmpty) {
        _totalVariations++;
        return;
      }
      for (var value in node.values) {
        _calculateTotalVariations(value);
      }
    }
  }

  MoveValidationResult playUserMove(String moveUci) {
    if (_currentNode == null) return MoveValidationResult.incorrect;

    final String normalizedMove = moveUci.toLowerCase();
    String? matchedKey;

    for (var key in _currentNode!.keys) {
      if (key.toLowerCase() == normalizedMove) {
        matchedKey = key;
        break;
      }
    }

    if (matchedKey == null) {
      return MoveValidationResult.incorrect;
    }

    _visitedMovePath.add(matchedKey);
    final dynamic nextBranch = _currentNode![matchedKey];

    if (nextBranch == 'CHECKMATE') {
      _completedVariations++;
      return MoveValidationResult.checkmate;
    }

    if (nextBranch is Map<String, dynamic>) {
      _currentNode = nextBranch;
      if (_currentNode!.isEmpty) {
        _completedVariations++;
        return MoveValidationResult.checkmate;
      }
      return MoveValidationResult.correct;
    }

    return MoveValidationResult.incorrect;
  }

  String? playOpponentResponse() {
    if (_currentNode == null || _currentNode!.isEmpty) return null;

    final opponentMoves = _currentNode!.keys.toList();
    if (opponentMoves.isEmpty) return null;

    final String chosenOpponentMove = opponentMoves.first;
    if (opponentMoves.length > 1) {
      _branchPoints.add(
        BranchPoint(
          moveUci: chosenOpponentMove,
          remainingOpponentMoves: opponentMoves.sublist(1),
        ),
      );
    }

    _visitedMovePath.add(chosenOpponentMove);
    final dynamic nextBranch = _currentNode![chosenOpponentMove];

    if (nextBranch is Map<String, dynamic>) {
      _currentNode = nextBranch;
    }

    return chosenOpponentMove;
  }

  bool rewindToNextVariation() {
    if (_branchPoints.isEmpty) {
      _currentNode = Map<String, dynamic>.from(rootSolutions);
      _visitedMovePath.clear();
      return false;
    }

    final lastBranch = _branchPoints.last;
    if (lastBranch.remainingOpponentMoves.isEmpty) {
      _branchPoints.removeLast();
      return rewindToNextVariation();
    }

    final nextOpponentMove = lastBranch.remainingOpponentMoves.removeAt(0);
    final sub = _findSubtree(rootSolutions, nextOpponentMove);

    if (sub != null) {
      _currentNode = {nextOpponentMove: sub};
      return true;
    }

    return false;
  }

  dynamic _findSubtree(dynamic tree, String targetKey) {
    if (tree is Map) {
      if (tree.containsKey(targetKey)) {
        return tree[targetKey];
      }
      for (var val in tree.values) {
        final res = _findSubtree(val, targetKey);
        if (res != null) return res;
      }
    }
    return null;
  }
}
