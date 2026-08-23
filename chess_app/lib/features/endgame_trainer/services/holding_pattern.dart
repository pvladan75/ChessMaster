/// Why the moves that hold are the ones that hold.
///
/// The trainer could already say "correct" and "that loses", which is the fact
/// and not the lesson. What a child can carry to the next position is the shape
/// of the answer: that only the king may move, that the rook has to stay on its
/// rank, that nothing but a check survives.
///
/// Everything here is read off the board and the list of moves that hold, both
/// of which the app already has — so this costs no request and no engine, and
/// it works on every position in the collection.
///
/// The rule the whole file obeys: a pattern is only stated when it is true of
/// **every** move that holds. "Mostly rook moves" is not a lesson, it is a
/// coincidence, and a child told it once will look for it forever.
library;

import 'package:chess/chess.dart' as chess;

/// What kind of thing a pattern says, which is what decides the order.
///
/// How many moves a pattern rules out turned out to be the wrong measure. Two
/// king moves that happen to land on the same rank make "only a move to the
/// second rank holds" true, and it rules out more moves than "only the king may
/// move" — while teaching a child to look for a coincidence.
enum HoldingKind {
  /// Where the piece has to stay: a rook on its rank, a bishop on its
  /// diagonal. First because it is the strongest of the four - it already
  /// implies which piece moves, and it is the one that reads as a rule about
  /// the ending rather than about this board.
  line,

  /// Which piece is allowed to move at all.
  piece,

  /// Only a check, only a capture.
  forcing,

  /// Every move that holds lands on one rank or file. True, and the weakest of
  /// the four, because it is the one most easily true by accident.
  destination,
}

/// One thing that is true of all the moves that hold.
class HoldingPattern {
  const HoldingPattern({
    required this.text,
    required this.kind,
    required this.excluded,
    this.explainsPlayed = false,
    this.playedWasSamePiece = false,
  });

  /// The sentence, in Serbian.
  final String text;

  final HoldingKind kind;

  /// How many legal moves this rules out. A tie-break, not the measure.
  final int excluded;

  /// True when the move actually played breaks this pattern — which makes it
  /// the answer to "why was mine wrong" rather than only "what do they share".
  final bool explainsPlayed;

  /// Whether the move played was by the piece the pattern is about. It decides
  /// which of two true explanations is the useful one: a king move against a
  /// set of rook moves is answered by "only the rook may move", while a rook
  /// move that left its rank is answered by "the rook must stay on it".
  final bool playedWasSamePiece;
}

/// Best first.
int _compare(HoldingPattern a, HoldingPattern b) {
  if (a.explainsPlayed != b.explainsPlayed) return a.explainsPlayed ? -1 : 1;
  if (a.explainsPlayed) {
    // Among explanations, the one aimed at the move that was actually made.
    final aFit =
        a.kind == (a.playedWasSamePiece ? HoldingKind.line : HoldingKind.piece);
    final bFit =
        b.kind == (b.playedWasSamePiece ? HoldingKind.line : HoldingKind.piece);
    if (aFit != bFit) return aFit ? -1 : 1;
  }
  if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
  return b.excluded.compareTo(a.excluded);
}

class _Move {
  _Move({
    required this.uci,
    required this.piece,
    required this.from,
    required this.to,
    required this.isCapture,
    required this.isCheck,
  });

  final String uci;
  final chess.PieceType piece;
  final String from;
  final String to;
  final bool isCapture;
  final bool isCheck;

  int get fromFile => from.codeUnitAt(0);
  int get fromRank => from.codeUnitAt(1);
  int get toFile => to.codeUnitAt(0);
  int get toRank => to.codeUnitAt(1);
}

// Not const: PieceType overrides ==, which a constant map key may not.
final _pieceNames = {
  chess.PieceType.KING: 'kralja',
  chess.PieceType.QUEEN: 'dame',
  chess.PieceType.ROOK: 'topa',
  chess.PieceType.BISHOP: 'lovca',
  chess.PieceType.KNIGHT: 'skakača',
  chess.PieceType.PAWN: 'pešaka',
};

final _pieceSubjects = {
  chess.PieceType.KING: 'Kralj',
  chess.PieceType.QUEEN: 'Dama',
  chess.PieceType.ROOK: 'Top',
  chess.PieceType.BISHOP: 'Lovac',
  chess.PieceType.KNIGHT: 'Skakač',
  chess.PieceType.PAWN: 'Pešak',
};

List<_Move> _legalMoves(String fen) {
  final board = chess.Chess.fromFEN(fen);
  final out = <_Move>[];
  for (final move in board.generate_moves()) {
    final from = chess.Chess.algebraic(move.from);
    final to = chess.Chess.algebraic(move.to);
    final probe = chess.Chess.fromFEN(fen);
    probe.move({
      'from': from,
      'to': to,
      if (move.promotion != null) 'promotion': 'q',
    });
    out.add(_Move(
      uci: '$from$to',
      piece: move.piece,
      from: from,
      to: to,
      isCapture: move.captured != null,
      isCheck: probe.in_check,
    ));
  }
  return out;
}

bool _same(String a, String b) {
  if (a.length < 4 || b.length < 4) return a == b;
  return a.substring(0, 4) == b.substring(0, 4);
}

/// What the moves that hold have in common, best first.
///
/// [playedUci] is the move that lost the result, when there is one. A pattern
/// it breaks is promoted, because that is the one that answers the question a
/// child actually asked.
List<HoldingPattern> describeHolding({
  required String fen,
  required List<String> holdingUci,
  String? playedUci,
}) {
  if (holdingUci.isEmpty) return const [];

  final List<_Move> legal;
  try {
    legal = _legalMoves(fen);
  } catch (_) {
    return const [];
  }
  if (legal.isEmpty) return const [];

  final holding =
      legal.where((m) => holdingUci.any((h) => _same(h, m.uci))).toList();
  if (holding.isEmpty || holding.length == legal.length) return const [];

  final played = playedUci == null
      ? null
      : legal.where((m) => _same(m.uci, playedUci)).firstOrNull;

  final found = <HoldingPattern>[];

  final holdingPiece = holding.map((m) => m.piece).toSet().length == 1
      ? holding.first.piece
      : null;

  void add(HoldingKind kind, String text, bool Function(_Move) matches) {
    // With a single move that holds, "only king moves hold" is a plural about
    // one thing, and the screen already names that move. What survives is the
    // rule the move obeys - a rook that has to stay on its file says something
    // even when there is one way to do it.
    if (holding.length == 1 &&
        (kind == HoldingKind.piece || kind == HoldingKind.destination)) {
      return;
    }
    if (!holding.every(matches)) return;
    final excluded = legal.where((m) => !matches(m)).length;
    if (excluded == 0) return;
    found.add(HoldingPattern(
      text: text,
      kind: kind,
      excluded: excluded,
      explainsPlayed: played != null && !matches(played),
      playedWasSamePiece: played != null && played.piece == holdingPiece,
    ));
  }

  // Only one piece may move. The sharpest of the lot, and the one a child can
  // carry to the next position of the same shape.
  final pieces = holding.map((m) => m.piece).toSet();
  if (pieces.length == 1) {
    final piece = pieces.first;
    add(HoldingKind.piece, 'Drže samo potezi ${_pieceNames[piece]}.',
        (m) => m.piece == piece);

    // And where that piece has to stay. A rook that must not leave its rank is
    // a rule about rook endings, not about this position.
    if (piece != chess.PieceType.KING && piece != chess.PieceType.PAWN) {
      final origin = holding.first.from;
      if (holding.every((m) => m.from == origin)) {
        if (holding.every((m) => m.toRank == m.fromRank)) {
          add(
            HoldingKind.line,
            '${_pieceSubjects[piece]} mora da ostane na ${origin[1]}. redu.',
            (m) => m.piece == piece && m.toRank == m.fromRank,
          );
        } else if (holding.every((m) => m.toFile == m.fromFile)) {
          add(
            HoldingKind.line,
            '${_pieceSubjects[piece]} mora da ostane na '
            '${origin[0].toUpperCase()}-liniji.',
            (m) => m.piece == piece && m.toFile == m.fromFile,
          );
        }
      }
    }
  }

  // Everything that holds lands on one line. Says where the piece belongs even
  // when more than one of them may go there.
  final ranks = holding.map((m) => m.toRank).toSet();
  if (ranks.length == 1 && holding.length > 1) {
    final rank = String.fromCharCode(ranks.first);
    add(HoldingKind.destination, 'Drži samo potez na $rank. red.',
        (m) => m.toRank == ranks.first);
  }
  final files = holding.map((m) => m.toFile).toSet();
  if (files.length == 1 && holding.length > 1) {
    final file = String.fromCharCode(files.first).toUpperCase();
    add(HoldingKind.destination, 'Drži samo potez na $file-liniju.',
        (m) => m.toFile == files.first);
  }

  if (holding.every((m) => m.isCheck)) {
    add(HoldingKind.forcing, 'Drži samo šah.', (m) => m.isCheck);
  }
  if (holding.every((m) => m.isCapture)) {
    add(HoldingKind.forcing, 'Drži samo uzimanje.', (m) => m.isCapture);
  }

  found.sort(_compare);
  return found;
}

/// The coordinates of a move written in notation, or null when this board
/// cannot play it.
///
/// The collection stores what was played as SAN, because that is what a person
/// reads, while everything here works in from-and-to squares.
String? uciForSan(String fen, String san) {
  try {
    final board = chess.Chess.fromFEN(fen);
    if (board.move(san) == false) return null;
    final last = board.history.last.move;
    return chess.Chess.algebraic(last.from) + chess.Chess.algebraic(last.to);
  } catch (_) {
    return null;
  }
}

/// The one sentence worth showing, or null when nothing is true of every move
/// that holds.
///
/// One rather than a list: a paragraph of properties is a puzzle of its own,
/// and the second-best pattern is usually the first one said differently.
String? holdingLesson({
  required String fen,
  required List<String> holdingUci,
  String? playedUci,
}) {
  final patterns = describeHolding(
    fen: fen,
    holdingUci: holdingUci,
    playedUci: playedUci,
  );
  return patterns.isEmpty ? null : patterns.first.text;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
