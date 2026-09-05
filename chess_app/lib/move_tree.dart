import 'package:chess/chess.dart' as chess;

class ChessArrow {
  final String from;
  final String to;
  final String colorCode; // 'G' (Green), 'R' (Red), 'B' (Blue), 'O' (Orange)

  ChessArrow({required this.from, required this.to, required this.colorCode});

  @override
  String toString() => '$colorCode$from$to';
}

/// A square the author coloured in — PGN's `[%csl]`.
///
/// The counterpart to [ChessArrow], and it uses the same colour codes so a
/// trainer drawing a red arrow and a red square is drawing in one palette.
///
/// It exists because half of what these lessons are about is a *square* rather
/// than a move: a weak square, an outpost, the hole a pawn left behind. Every
/// other chess tool records that as `[%csl]`; this one used to drop it, and
/// worse than drop it — the tag was not stripped from the comment either, so it
/// arrived on screen as words in the middle of the trainer's sentence.
class SquareMark {
  final String square;
  final String colorCode; // 'G', 'R', 'B', 'O', 'Y'

  SquareMark({required this.square, required this.colorCode});

  @override
  String toString() => '$colorCode$square';
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
  List<SquareMark> squares = [];

  MoveNode({
    required this.san,
    required this.fen,
    required this.from,
    required this.to,
    this.comment = '',
    this.parent,
    List<ChessArrow>? arrows,
    List<SquareMark>? squares,
  })  : arrows = arrows ?? [],
        squares = squares ?? [];

  @override
  String toString() {
    return 'MoveNode($san, comment: "$comment", arrowsCount: ${arrows.length}, childrenCount: ${children.length})';
  }
}

/// One line of a tree, flattened — with everything that hangs off each move.
///
/// The point of this type is that all six lists come out of **one walk**. The
/// lesson viewer used to take its moves from one parser and its notes from
/// another and then compare the lengths, throwing every note away when they
/// disagreed; a note under the wrong move is the trainer appearing to say
/// something they did not, so discarding them was right for a design that
/// should not have existed. Read once, and "they disagree" is not a state this
/// code can reach.
///
/// [fens] holds the position **before** the first move followed by one entry
/// per move, so it is always one longer than the other lists — that is the
/// shape [LinearMoveCursor] already expects.
class PgnLine {
  final List<String> fens;
  final List<String> movesSan;
  final List<String> comments;
  final List<List<ChessArrow>> arrows;
  final List<List<SquareMark>> squares;

  /// What the author wrote **before the first move**, about the position the
  /// line starts from.
  ///
  /// PGN puts it in a comment ahead of move one, and `parsePgn` has always
  /// attached it to the root — `mainLine()` simply did not carry it out, so it
  /// was parsed and then dropped one call later. That was invisible while
  /// nothing read arrows or squares at all.
  ///
  /// It is the only place an arrow or a coloured square about a *still*
  /// position can live, and a still position is most of what an interactive
  /// lesson is: „look at d5" is a step with no moves in it. Kept as three
  /// fields rather than by making the per-move lists one longer, because
  /// [fens] is already the odd one out at n+1 and a second list with a
  /// different length to its neighbours is how an off-by-one gets written.
  final String rootComment;
  final List<ChessArrow> rootArrows;
  final List<SquareMark> rootSquares;

  const PgnLine({
    required this.fens,
    required this.movesSan,
    required this.comments,
    required this.arrows,
    required this.squares,
    this.rootComment = '',
    this.rootArrows = const [],
    this.rootSquares = const [],
  });

  bool get isEmpty => movesSan.isEmpty;

  /// True when the trainer wrote nothing at all on this line.
  bool get hasNoNotes => comments.every((c) => c.isEmpty);
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

    _writeComment(mainChild, sb);

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

      _writeComment(varChild, sb);

      _writePgnNode(varChild, sb, false);
      sb.write(') ');
    }

    final nextShowMoveNumber = node.children.length > 1;
    _writePgnNode(mainChild, sb, nextShowMoveNumber);
  }

  /// Writes one node's `{ words [%cal …] [%csl …] }`, or nothing.
  ///
  /// One function rather than the two near-identical blocks that used to sit in
  /// [_writePgnNode] — one for the main line and one for variations. They were
  /// already the place where an annotation could be taught to half the tree:
  /// adding `[%csl]` to the first copy and not the second would have written
  /// squares on the main line and silently dropped them from every sideline,
  /// which is the sort of fault that only shows up in somebody's lesson.
  static void _writeComment(MoveNode node, StringBuffer sb) {
    final parts = <String>[];
    if (node.comment.isNotEmpty) parts.add(node.comment);
    if (node.arrows.isNotEmpty) {
      parts.add('[%cal ${node.arrows.map((a) => a.toString()).join(',')}]');
    }
    if (node.squares.isNotEmpty) {
      parts.add('[%csl ${node.squares.map((s) => s.toString()).join(',')}]');
    }
    if (parts.isEmpty) return;
    sb.write('{ ${parts.join(' ')} } ');
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

  /// The squares an author coloured in — PGN's `[%csl Rd5,Gf5]`.
  ///
  /// Three characters per token: the colour, then the square. Anything else is
  /// skipped rather than guessed at, the same way [parsePgnArrows] treats a
  /// token that is not five characters long.
  static List<SquareMark> parsePgnSquares(String commentText) {
    final List<SquareMark> result = [];
    final match = RegExp(r'\[%csl\s+([^\]]+)\]').firstMatch(commentText);
    if (match != null) {
      for (var token in match.group(1)!.split(',')) {
        token = token.trim();
        if (token.length == 3) {
          result.add(SquareMark(
            square: token.substring(1, 3),
            colorCode: token.substring(0, 1),
          ));
        }
      }
    }
    return result;
  }

  /// The words of a comment, with every annotation tag taken out.
  ///
  /// Both tags, and that is the fix: this stripped `[%cal]` and nothing else,
  /// so a PGN written in Lichess or ChessBase — where `[%csl]` is ordinary —
  /// put „[%csl Rd5]" on screen in the middle of the trainer's sentence.
  static String cleanPgnComment(String commentText) {
    return commentText
        .replaceAll(RegExp(r'\[%(cal|csl)\s+[^\]]+\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// The main line, with every move's words, arrows and squares beside it.
  ///
  /// First children all the way down — the same definition of "the main line"
  /// that [MoveTreeCursor.last] and the PGN export already use, so a lesson
  /// shows the line it was saved as.
  ///
  /// This is the function that ended the two-parser arrangement. Everything a
  /// step displays now comes from one walk of one tree, which is why there is
  /// no length check anywhere: the lists are built together and cannot come out
  /// different lengths.
  PgnLine mainLine() {
    final fens = <String>[root.fen];
    final movesSan = <String>[];
    final comments = <String>[];
    final arrows = <List<ChessArrow>>[];
    final squares = <List<SquareMark>>[];

    var node = root;
    while (node.children.isNotEmpty) {
      node = node.children.first;
      fens.add(node.fen);
      movesSan.add(node.san);
      comments.add(node.comment);
      arrows.add(node.arrows);
      squares.add(node.squares);
    }

    return PgnLine(
      fens: fens,
      movesSan: movesSan,
      comments: comments,
      arrows: arrows,
      squares: squares,
      rootComment: root.comment,
      rootArrows: root.arrows,
      rootSquares: root.squares,
    );
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
        currentNode.squares = parsePgnSquares(commentStr);
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
