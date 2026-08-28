import 'package:chess/chess.dart' as chess;

class ChessArrow {
  final String from;
  final String to;
  final String colorCode; // 'G' (Green), 'R' (Red), 'B' (Blue), 'O' (Orange)

  ChessArrow({required this.from, required this.to, required this.colorCode});

  @override
  String toString() => '$colorCode$from$to';
}

class MoveNode {
  final String san;
  final String fen;
  final String from;
  final String to;
  String comment;
  MoveNode? parent;
  final List<MoveNode> children = [];
  List<ChessArrow> arrows = [];

  MoveNode({
    required this.san,
    required this.fen,
    required this.from,
    required this.to,
    this.comment = '',
    this.parent,
    List<ChessArrow>? arrows,
  }) : arrows = arrows ?? [];

  @override
  String toString() {
    return 'MoveNode($san, comment: "$comment", arrowsCount: ${arrows.length}, childrenCount: ${children.length})';
  }
}

class PgnGameInfo {
  final Map<String, String> headers;
  final String pgnBody;

  PgnGameInfo({required this.headers, required this.pgnBody});

  String get displayName {
    final white = headers['White'] ?? 'Beli';
    final black = headers['Black'] ?? 'Crni';
    final date = headers['Date'] ?? 'Nepoznat datum';
    final result = headers['Result'] ?? '*';
    return '$white vs $black ($date) - [$result]';
  }
}

/// What [MoveTree.appendLine] did with the moves it was given.
class AppendedLine {
  /// The node the walk ended on. The node it started from when nothing at all
  /// could be played.
  final MoveNode end;

  /// The first move of the line, whether it was created here or was already in
  /// the tree. Null when not a single move was playable.
  final MoveNode? head;

  /// How many nodes this actually created. Zero means every move was already
  /// in the tree, or none of them was legal — [rejected] tells those apart.
  final int added;

  /// A move in the line was not legal from the position reached. The walk
  /// stops there and keeps what came before it.
  final bool rejected;

  const AppendedLine({
    required this.end,
    required this.head,
    required this.added,
    required this.rejected,
  });
}

class MoveTree {
  final MoveNode root;
  MoveNode current;

  MoveTree({required String startingFen})
      : root = MoveNode(san: 'Root', fen: startingFen, from: '', to: ''),
        current = MoveNode(san: 'Root', fen: startingFen, from: '', to: '') {
    current = root;
  }

  // Serialize the tree to standard PGN string
  String exportToPgn() {
    final sb = StringBuffer();
    if (root.fen !=
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1') {
      sb.writeln('[SetUp "1"]');
      sb.writeln('[FEN "${root.fen}"]');
      sb.writeln();
    }
    _writePgnNode(root, sb, true);
    return sb.toString().trim();
  }

  void _writePgnNode(MoveNode node, StringBuffer sb, bool showMoveNumber) {
    if (node.children.isEmpty) return;

    final mainChild = node.children[0];
    final parts = node.fen.split(' ');
    final isWhite = parts[1] == 'w';
    final moveNum = int.tryParse(parts[5]) ?? 1;

    if (isWhite) {
      sb.write('$moveNum. ');
    } else {
      if (showMoveNumber) {
        sb.write('$moveNum... ');
      }
    }

    sb.write('${mainChild.san} ');

    // Write comment and arrows if any
    final mainCommentBuffer = StringBuffer();
    if (mainChild.comment.isNotEmpty) {
      mainCommentBuffer.write(mainChild.comment);
    }
    if (mainChild.arrows.isNotEmpty) {
      if (mainCommentBuffer.isNotEmpty) {
        mainCommentBuffer.write(' ');
      }
      mainCommentBuffer.write(
          '[%cal ${mainChild.arrows.map((a) => a.toString()).join(',')}]');
    }
    if (mainCommentBuffer.isNotEmpty) {
      sb.write('{ ${mainCommentBuffer.toString()} } ');
    }

    // Variations
    for (int i = 1; i < node.children.length; i++) {
      final varChild = node.children[i];
      sb.write('( ');

      if (isWhite) {
        sb.write('$moveNum. ');
      } else {
        sb.write('$moveNum... ');
      }

      sb.write('${varChild.san} ');

      final varCommentBuffer = StringBuffer();
      if (varChild.comment.isNotEmpty) {
        varCommentBuffer.write(varChild.comment);
      }
      if (varChild.arrows.isNotEmpty) {
        if (varCommentBuffer.isNotEmpty) {
          varCommentBuffer.write(' ');
        }
        varCommentBuffer.write(
            '[%cal ${varChild.arrows.map((a) => a.toString()).join(',')}]');
      }
      if (varCommentBuffer.isNotEmpty) {
        sb.write('{ ${varCommentBuffer.toString()} } ');
      }

      _writePgnNode(varChild, sb, false);
      sb.write(') ');
    }

    final nextShowMoveNumber = node.children.length > 1;
    _writePgnNode(mainChild, sb, nextShowMoveNumber);
  }

  static List<ChessArrow> parsePgnArrows(String commentText) {
    final List<ChessArrow> result = [];
    final match = RegExp(r'\[%cal\s+([^\]]+)\]').firstMatch(commentText);
    if (match != null) {
      final listStr = match.group(1)!;
      final tokens = listStr.split(',');
      for (var token in tokens) {
        token = token.trim();
        if (token.length == 5) {
          final color = token.substring(0, 1);
          final from = token.substring(1, 3);
          final to = token.substring(3, 5);
          result.add(ChessArrow(from: from, to: to, colorCode: color));
        }
      }
    }
    return result;
  }

  static String cleanPgnComment(String commentText) {
    return commentText.replaceAll(RegExp(r'\[%cal\s+[^\]]+\]'), '').trim();
  }

  // Parse a cleaned single-game PGN string into this tree
  static MoveTree? parsePgn(String pgn, {String? startingFen}) {
    String? extractedFen = startingFen;
    if (extractedFen == null) {
      final fenMatch = RegExp(r'\[[Ff][Ee][Nn]\s+"([^"]+)"\]').firstMatch(pgn);
      if (fenMatch != null) {
        extractedFen = fenMatch.group(1);
      }
    }
    final actualStartingFen = extractedFen ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    // Clean headers but preserve annotations like [%cal ...]
    var cleaned =
        pgn.replaceAll(RegExp(r'^\s*\[[^%][^\]]*\]\s*$', multiLine: true), '');
    cleaned = cleaned.replaceAll('{', ' { ');
    cleaned = cleaned.replaceAll('}', ' } ');
    cleaned = cleaned.replaceAll('(', ' ( ');
    cleaned = cleaned.replaceAll(')', ' ) ');
    cleaned = cleaned.replaceAll(RegExp(r'\b(1-0|0-1|1/2-1/2|\*)\b'), '');

    final tokens = cleaned.split(RegExp(r'\s+'));
    final tree = MoveTree(startingFen: actualStartingFen);

    MoveNode currentNode = tree.root;
    final List<MoveNode> variationStack = [];

    bool collectingComment = false;
    final List<String> currentCommentTokens = [];

    for (var token in tokens) {
      token = token.trim();
      if (token.isEmpty) continue;

      if (token == '{') {
        collectingComment = true;
        currentCommentTokens.clear();
        continue;
      } else if (token == '}') {
        collectingComment = false;
        final commentStr = currentCommentTokens.join(' ').trim();
        currentNode.arrows = parsePgnArrows(commentStr);
        currentNode.comment = cleanPgnComment(commentStr);
        continue;
      }

      if (collectingComment) {
        currentCommentTokens.add(token);
        continue;
      }

      // Skip move numbering annotations
      if (RegExp(r'^\d+(\.+)?$').hasMatch(token)) {
        continue;
      }

      if (token == '(') {
        if (currentNode.parent != null) {
          variationStack.add(currentNode);
          currentNode = currentNode.parent!;
        }
      } else if (token == ')') {
        if (variationStack.isNotEmpty) {
          currentNode = variationStack.removeLast();
        }
      } else {
        // Clean move number prefixes (e.g. "1.e4" -> "e4", "1...e5" -> "e5") and evaluation annotations (e.g. "e5?!" -> "e5")
        var cleanedToken = token.replaceAll(RegExp(r'^\d+\.{1,3}'), '');
        cleanedToken = cleanedToken.replaceAll(RegExp(r'[!?]+$'), '');

        if (cleanedToken.isEmpty) continue;

        // Skip purely numeric/result tokens
        if (RegExp(r'^\d+(\.+)?$').hasMatch(cleanedToken) ||
            cleanedToken == '1-0' ||
            cleanedToken == '0-1' ||
            cleanedToken == '1/2-1/2' ||
            cleanedToken == '*') {
          continue;
        }

        try {
          final tempGame = chess.Chess();
          tempGame.load(currentNode.fen);
          final success = tempGame.move(cleanedToken);
          if (success) {
            final lastMove = tempGame.history.last.move;
            final newNode = MoveNode(
              san: cleanedToken,
              fen: tempGame.fen,
              from: lastMove.fromAlgebraic,
              to: lastMove.toAlgebraic,
              parent: currentNode,
            );
            currentNode.children.add(newNode);
            currentNode = newNode;
          }
        } catch (_) {
          // Skip invalid move tokens in fallback parse
        }
      }
    }

    return tree;
  }

  /// Plays a line of long-algebraic moves ("e2e4", "e7e8q") onto [from].
  ///
  /// Replays them against [from]'s own position rather than trusting positions
  /// computed elsewhere: an engine line is calculated for the board's FEN and
  /// filed under a node's, and while those are the same position they are not
  /// guaranteed to be the same string. A move that is not legal from here ends
  /// the walk rather than writing a node nothing can reach.
  ///
  /// A move already among the children is stepped into rather than added a
  /// second time — the same rule a hand-played move follows, so filing the
  /// engine's first choice twice does not grow two identical branches.
  static AppendedLine appendLine(MoveNode from, List<String> lanMoves) {
    final game = chess.Chess();
    if (!game.load(from.fen)) {
      return AppendedLine(end: from, head: null, added: 0, rejected: true);
    }

    var node = from;
    MoveNode? head;
    var added = 0;

    for (final lan in lanMoves) {
      if (lan.length < 4) break;
      final fromSq = lan.substring(0, 2);
      final toSq = lan.substring(2, 4);
      final promotion = lan.length > 4 ? lan[4] : null;
      final move = {
        'from': fromSq,
        'to': toSq,
        if (promotion != null) 'promotion': promotion,
      };

      if (!game.move(move)) {
        return AppendedLine(
            end: node, head: head, added: added, rejected: true);
      }

      // The move has to be named from the position before it, which is why it
      // is played, taken back for the naming, and played again.
      final played = game.history.last.move;
      game.undo_move();
      final san = game.move_to_san(played);
      game.move(move);

      MoveNode? existing;
      for (final child in node.children) {
        if (child.from == fromSq && child.to == toSq) {
          existing = child;
          break;
        }
      }

      if (existing != null) {
        node = existing;
      } else {
        final child = MoveNode(
          san: san,
          fen: game.fen,
          from: fromSq,
          to: toSq,
          parent: node,
        );
        node.children.add(child);
        node = child;
        added++;
      }

      head ??= node;
    }

    return AppendedLine(end: node, head: head, added: added, rejected: false);
  }

  // Split PGN file into multiple games
  static List<PgnGameInfo> splitGames(String content) {
    final List<PgnGameInfo> games = [];
    final lines = content.split('\n');

    Map<String, String> currentHeaders = {};
    final List<String> currentBodyLines = [];
    bool inHeaders = true;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (currentHeaders.isNotEmpty) {
          inHeaders = false;
        }
        continue;
      }

      if (trimmed.startsWith('[')) {
        if (!inHeaders) {
          if (currentHeaders.isNotEmpty || currentBodyLines.isNotEmpty) {
            games.add(PgnGameInfo(
              headers: Map.from(currentHeaders),
              pgnBody: currentBodyLines.join(' '),
            ));
          }
          currentHeaders.clear();
          currentBodyLines.clear();
          inHeaders = true;
        }

        final match = RegExp(r'^\[(\w+)\s+"(.*)"\]$').firstMatch(trimmed);
        if (match != null) {
          final key = match.group(1)!;
          final val = match.group(2)!;
          currentHeaders[key] = val;
        }
      } else {
        inHeaders = false;
        currentBodyLines.add(trimmed);
      }
    }

    if (currentHeaders.isNotEmpty || currentBodyLines.isNotEmpty) {
      games.add(PgnGameInfo(
        headers: Map.from(currentHeaders),
        pgnBody: currentBodyLines.join(' '),
      ));
    }

    return games;
  }
}
