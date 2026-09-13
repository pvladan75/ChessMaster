import 'package:chess/chess.dart' as chess;

/// Square order matching python-chess `chess.SQUARES`: a1, b1 .. h1, a2 .. h8.
const List<String> kSquares = [
  'a1',
  'b1',
  'c1',
  'd1',
  'e1',
  'f1',
  'g1',
  'h1',
  'a2',
  'b2',
  'c2',
  'd2',
  'e2',
  'f2',
  'g2',
  'h2',
  'a3',
  'b3',
  'c3',
  'd3',
  'e3',
  'f3',
  'g3',
  'h3',
  'a4',
  'b4',
  'c4',
  'd4',
  'e4',
  'f4',
  'g4',
  'h4',
  'a5',
  'b5',
  'c5',
  'd5',
  'e5',
  'f5',
  'g5',
  'h5',
  'a6',
  'b6',
  'c6',
  'd6',
  'e6',
  'f6',
  'g6',
  'h6',
  'a7',
  'b7',
  'c7',
  'd7',
  'e7',
  'f7',
  'g7',
  'h7',
  'a8',
  'b8',
  'c8',
  'd8',
  'e8',
  'f8',
  'g8',
  'h8',
];

String pieceName(chess.PieceType type) {
  switch (type) {
    case chess.PieceType.PAWN:
      return 'pawn';
    case chess.PieceType.KNIGHT:
      return 'knight';
    case chess.PieceType.BISHOP:
      return 'bishop';
    case chess.PieceType.ROOK:
      return 'rook';
    case chess.PieceType.QUEEN:
      return 'queen';
    case chess.PieceType.KING:
      return 'king';
    default:
      return 'piece';
  }
}

int pieceValue(chess.PieceType? type) {
  if (type == null) return 0;
  switch (type) {
    case chess.PieceType.PAWN:
      return 1;
    case chess.PieceType.KNIGHT:
    case chess.PieceType.BISHOP:
      return 3;
    case chess.PieceType.ROOK:
      return 5;
    case chess.PieceType.QUEEN:
      return 9;
    default:
      return 0;
  }
}

int materialOf(chess.Chess board) {
  var white = 0;
  var black = 0;
  for (final sq in kSquares) {
    final p = board.get(sq);
    if (p != null) {
      final val = pieceValue(p.type);
      if (p.color == chess.Color.WHITE) {
        white += val;
      } else {
        black += val;
      }
    }
  }
  return white - black;
}

List<String> boardAttacks(chess.Chess board, String square) {
  final piece = board.get(square);
  if (piece == null) return const [];
  final f = square.codeUnitAt(0) - 97;
  final r = square.codeUnitAt(1) - 49;
  final attackedSquares = <String>{};

  void addIfValid(int curF, int curR) {
    if (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
      attackedSquares.add(
        '${String.fromCharCode(97 + curF)}${String.fromCharCode(49 + curR)}',
      );
    }
  }

  switch (piece.type) {
    case chess.PieceType.PAWN:
      final stepR = piece.color == chess.Color.WHITE ? 1 : -1;
      addIfValid(f - 1, r + stepR);
      addIfValid(f + 1, r + stepR);
      break;

    case chess.PieceType.KNIGHT:
      const knightOffsets = [
        (-2, -1),
        (-2, 1),
        (-1, -2),
        (-1, 2),
        (1, -2),
        (1, 2),
        (2, -1),
        (2, 1),
      ];
      for (final (df, dr) in knightOffsets) {
        addIfValid(f + df, r + dr);
      }
      break;

    case chess.PieceType.KING:
      for (var df = -1; df <= 1; df++) {
        for (var dr = -1; dr <= 1; dr++) {
          if (df == 0 && dr == 0) continue;
          addIfValid(f + df, r + dr);
        }
      }
      break;

    case chess.PieceType.BISHOP:
      const bishopDirs = [(1, 1), (-1, 1), (1, -1), (-1, -1)];
      for (final (df, dr) in bishopDirs) {
        var curF = f + df;
        var curR = r + dr;
        while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
          final sq =
              '${String.fromCharCode(97 + curF)}${String.fromCharCode(49 + curR)}';
          attackedSquares.add(sq);
          if (board.get(sq) != null) break;
          curF += df;
          curR += dr;
        }
      }
      break;

    case chess.PieceType.ROOK:
      const rookDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
      for (final (df, dr) in rookDirs) {
        var curF = f + df;
        var curR = r + dr;
        while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
          final sq =
              '${String.fromCharCode(97 + curF)}${String.fromCharCode(49 + curR)}';
          attackedSquares.add(sq);
          if (board.get(sq) != null) break;
          curF += df;
          curR += dr;
        }
      }
      break;

    case chess.PieceType.QUEEN:
      const queenDirs = [
        (1, 1),
        (-1, 1),
        (1, -1),
        (-1, -1),
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ];
      for (final (df, dr) in queenDirs) {
        var curF = f + df;
        var curR = r + dr;
        while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
          final sq =
              '${String.fromCharCode(97 + curF)}${String.fromCharCode(49 + curR)}';
          attackedSquares.add(sq);
          if (board.get(sq) != null) break;
          curF += df;
          curR += dr;
        }
      }
      break;

    default:
      break;
  }

  // Sort by python-chess square order: a1, b1..h1, a2..h2, ..., a8..h8
  final list = attackedSquares.toList();
  list.sort((a, b) {
    final fa = a.codeUnitAt(0) - 97;
    final ra = a.codeUnitAt(1) - 49;
    final fb = b.codeUnitAt(0) - 97;
    final rb = b.codeUnitAt(1) - 49;
    return (ra * 8 + fa).compareTo(rb * 8 + fb);
  });
  return list;
}

String? findKingSquare(chess.Chess board, chess.Color color) {
  for (final sq in kSquares) {
    final p = board.get(sq);
    if (p != null && p.type == chess.PieceType.KING && p.color == color) {
      return sq;
    }
  }
  return null;
}

bool isPinned(chess.Chess board, chess.Color color, String square) {
  final kingSq = findKingSquare(board, color);
  if (kingSq == null || kingSq == square) return false;

  final kf = kingSq.codeUnitAt(0) - 97;
  final kr = kingSq.codeUnitAt(1) - 49;
  final sf = square.codeUnitAt(0) - 97;
  final sr = square.codeUnitAt(1) - 49;

  final df = sf - kf;
  final dr = sr - kr;
  final isDiag = df != 0 && df.abs() == dr.abs();
  final isOrtho = (df == 0) != (dr == 0);
  if (!isDiag && !isOrtho) return false;

  final stepF = df.sign;
  final stepR = dr.sign;

  // Walk out from the king; `square` must be the very first piece encountered.
  var curF = kf + stepF;
  var curR = kr + stepR;
  while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
    final checkSq =
        '${String.fromCharCode(97 + curF)}${String.fromCharCode(49 + curR)}';
    if (checkSq == square) break;
    if (board.get(checkSq) != null) return false;
    curF += stepF;
    curR += stepR;
  }
  if (curF < 0 || curF >= 8 || curR < 0 || curR >= 8) return false;

  // Continue past `square` looking for a slider that pins it to the king.
  curF += stepF;
  curR += stepR;
  while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
    final checkSq =
        '${String.fromCharCode(97 + curF)}${String.fromCharCode(49 + curR)}';
    final p = board.get(checkSq);
    if (p != null) {
      if (p.color == color) return false;
      return isDiag
          ? (p.type == chess.PieceType.BISHOP ||
              p.type == chess.PieceType.QUEEN)
          : (p.type == chess.PieceType.ROOK || p.type == chess.PieceType.QUEEN);
    }
    curF += stepF;
    curR += stepR;
  }
  return false;
}

Map<String, dynamic> playMoveOnBoard(
  chess.Chess board,
  String san, {
  String verb = 'plays',
}) {
  final moves = board.generate_moves();
  chess.Move? moveObj;
  for (var i = 0; i < moves.length; i++) {
    if (board.move_to_san(moves[i]) == san) {
      moveObj = moves[i];
      break;
    }
  }
  if (moveObj == null) {
    final cleanSan = san.replaceAll(RegExp(r'[+#?!=]+$'), '');
    for (var i = 0; i < moves.length; i++) {
      if (board.move_to_san(moves[i]).replaceAll(RegExp(r'[+#?!=]+$'), '') ==
          cleanSan) {
        moveObj = moves[i];
        break;
      }
    }
  }
  if (moveObj == null) {
    throw ArgumentError('Cannot play $san from ${board.fen}');
  }

  final mover = board.turn == chess.Color.WHITE ? 'White' : 'Black';
  final fromSq = moveObj.fromAlgebraic;
  final toSq = moveObj.toAlgebraic;
  final piece = board.get(fromSq)!;
  final isEp = (moveObj.flags & chess.Chess.BITS_EP_CAPTURE) != 0;
  final chess.Piece? captured = isEp
      ? chess.Piece(
          chess.PieceType.PAWN,
          board.turn == chess.Color.WHITE
              ? chess.Color.BLACK
              : chess.Color.WHITE,
        )
      : board.get(toSq);

  final words = <String>[
    '$mover $verb $san: the ${pieceName(piece.type)} from $fromSq to $toSq',
  ];
  var gain = 0;
  if (captured != null) {
    words.add('it captures a ${pieceName(captured.type)}');
    gain = pieceValue(captured.type);
  }
  if (moveObj.promotion != null) {
    words.add('it promotes to a ${pieceName(moveObj.promotion!)}');
    gain += pieceValue(moveObj.promotion!) - 1;
  }

  board.make_move(moveObj);

  final mate = board.in_checkmate;
  if (mate) {
    words.add('it is checkmate');
  } else if (board.in_check) {
    words.add('it gives check');
  }

  final targets = <String>[];
  for (final sq in boardAttacks(board, toSq)) {
    final other = board.get(sq);
    if (other != null &&
        other.color == board.turn &&
        other.type != chess.PieceType.PAWN) {
      targets.add('${pieceName(other.type)} on $sq');
    }
  }
  if (targets.isNotEmpty) {
    words.add('the moved piece now attacks: ${targets.join(', ')}');
  }
  final fork = targets.length >= 2;

  final pinned = <String>[];
  for (final sq in kSquares) {
    final p = board.get(sq);
    if (p != null &&
        p.color == board.turn &&
        p.type != chess.PieceType.KING &&
        isPinned(board, board.turn, sq)) {
      pinned.add(sq);
    }
  }
  if (pinned.isNotEmpty) {
    words.add('pinned to their king afterwards: ${pinned.join(', ')}');
  }

  return {
    'words': words.join('; '),
    'gain': gain,
    'mate': mate,
    'fork': fork,
    'pin': pinned.isNotEmpty,
    'to': toSq,
  };
}
