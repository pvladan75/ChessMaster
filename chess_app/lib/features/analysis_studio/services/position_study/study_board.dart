/// What a position study reads off a board without an engine —
/// `docs/PLAN-STUDIJA-POZICIJE.md`, §2.
///
/// Moves as data, the position with the other side to move, material in
/// words, and which captures and checks a reader would look at first. Pure:
/// a FEN goes in, facts come out.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/finding_sentences.dart'
    show countWord, joinAnd;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show boardAttacks, kSquares, pieceName, pieceValue;
import 'package:chess_app/services/fen_legality.dart' show fenIllegalReason;

/// One move of a study, with the two positions it stands between.
class StudyMove {
  const StudyMove({
    required this.san,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
    required this.whiteMoved,
    required this.piece,
    required this.taken,
    required this.captured,
    required this.check,
    required this.mate,
  });

  final String san;
  final String uci;
  final String fenBefore;
  final String fenAfter;
  final bool whiteMoved;

  /// The piece that moved: `pawn`, `knight`, …
  final String piece;

  /// The value of what it captured; 0 for a move that captures nothing.
  final int taken;

  /// What it captured — `rook`, `pawn` — or null.
  final String? captured;
  final bool check;
  final bool mate;

  bool get capture => taken > 0;
  String get from => uci.substring(0, 2);
  String get to => uci.substring(2, 4);
  String get mover => whiteMoved ? 'White' : 'Black';

  /// `14. Rd1`, `14... Rd8` — the number from the position it was played in.
  String get label {
    final number = fullmoveOf(fenBefore);
    return whiteMoved ? '$number. $san' : '$number... $san';
  }
}

int fullmoveOf(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  return fields.length > 5 ? int.tryParse(fields[5]) ?? 1 : 1;
}

bool whiteToMoveIn(String fen) => fen.trim().split(RegExp(r'\s+'))[1] == 'w';

String sideToMoveIn(String fen) => whiteToMoveIn(fen) ? 'White' : 'Black';

String otherSide(String side) => side == 'White' ? 'Black' : 'White';

int menIn(String fen) => fen
    .split(' ')
    .first
    .split('')
    .where((c) => RegExp('[a-zA-Z]').hasMatch(c))
    .length;

/// The legal move [uci] names in [fen], played; null when there is none.
StudyMove? playUci(String fen, String uci) {
  if (uci.length < 4) return null;
  final board = chess.Chess.fromFEN(fen);
  final from = uci.substring(0, 2);
  final to = uci.substring(2, 4);
  final promo = uci.length > 4 ? uci[4].toLowerCase() : null;
  for (final move in board.generate_moves()) {
    if (move.fromAlgebraic != from || move.toAlgebraic != to) continue;
    if ((move.promotion?.name ?? '') != (promo ?? '')) continue;
    return _played(board, move);
  }
  return null;
}

/// The legal move [san] names in [fen], played; null when there is none.
StudyMove? playSan(String fen, String san) {
  final board = chess.Chess.fromFEN(fen);
  final bare = san.replaceAll(RegExp(r'[+#?!]+$'), '');
  for (final move in board.generate_moves()) {
    final spelled = board.move_to_san(move);
    if (spelled == san || spelled.replaceAll(RegExp(r'[+#]+$'), '') == bare) {
      return _played(board, move);
    }
  }
  return null;
}

/// [sans] played from [fen], as far as they play — a line that stops short is
/// shorter, never wrong.
List<StudyMove> playLine(String fen, Iterable<String> sans) {
  final out = <StudyMove>[];
  var at = fen;
  for (final san in sans) {
    final move = playSan(at, san);
    if (move == null) break;
    out.add(move);
    at = move.fenAfter;
  }
  return out;
}

StudyMove _played(chess.Chess board, chess.Move move) {
  final fenBefore = board.fen;
  final white = board.turn == chess.Color.WHITE;
  final san = board.move_to_san(move);
  final piece = board.get(move.fromAlgebraic)!;
  final enPassant = (move.flags & chess.Chess.BITS_EP_CAPTURE) != 0;
  final captured = enPassant ? null : board.get(move.toAlgebraic);
  final taken = enPassant ? 1 : pieceValue(captured?.type);
  board.make_move(move);
  return StudyMove(
    san: san,
    uci: '${move.fromAlgebraic}${move.toAlgebraic}'
        '${move.promotion?.name ?? ''}',
    fenBefore: fenBefore,
    fenAfter: board.fen,
    whiteMoved: white,
    piece: pieceName(piece.type),
    taken: taken,
    captured: enPassant
        ? 'pawn'
        : captured == null
            ? null
            : pieceName(captured.type),
    check: board.in_check,
    mate: board.in_checkmate,
  );
}

/// [fen] with the other side to move — what the side to move would face if it
/// passed. Null when no such position can be: [fenIllegalReason] refuses it —
/// as it does when the side to move is in check, since the other side would
/// be taking a king — or the side passed to has no move.
///
/// The check has no guard of its own here. It had one, and removing it
/// changed nothing: one fact guarded in two places survives the removal of
/// either, so the second went.
///
/// The en passant square goes, since the pawn that made it moved a move ago;
/// the move number turns over after Black.
String? passedFen(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.length < 6) return null;
  final white = fields[1] == 'w';
  final number = int.tryParse(fields[5]) ?? 1;
  final halfmoves = int.tryParse(fields[4]) ?? 0;
  final passed = [
    fields[0],
    white ? 'b' : 'w',
    fields[2],
    '-',
    '${halfmoves + 1}',
    '${white ? number : number + 1}',
  ].join(' ');
  if (fenIllegalReason(passed) != null) return null;
  if (chess.Chess.fromFEN(passed).moves().isEmpty) return null;
  return passed;
}

// --- Material ----------------------------------------------------------------

const _order = ['q', 'r', 'b', 'n', 'p'];
const _names = {
  'q': 'queen',
  'r': 'rook',
  'b': 'bishop',
  'n': 'knight',
  'p': 'pawn',
};
const _points = {'q': 9, 'r': 5, 'b': 3, 'n': 3, 'p': 1};

/// How many of each piece a side has: `{'q': 1, 'r': 2, …}`.
Map<String, int> _count(String fen, {required bool white}) {
  final out = {for (final k in _order) k: 0};
  for (final ch in fen.split(' ').first.split('')) {
    final kind = ch.toLowerCase();
    if (!out.containsKey(kind)) continue;
    if ((ch == ch.toUpperCase()) == white) out[kind] = out[kind]! + 1;
  }
  return out;
}

/// Material from White's side, in points.
int balanceOf(String fen) {
  var total = 0;
  for (final k in _order) {
    total += _points[k]! *
        (_count(fen, white: true)[k]! - _count(fen, white: false)[k]!);
  }
  return total;
}

String _pieces(Map<String, int> extra) {
  final said = <String>[];
  for (final k in _order) {
    final n = extra[k] ?? 0;
    if (n <= 0) continue;
    said.add(n == 1 ? 'a ${_names[k]}' : '${countWord(n)} ${_names[k]}s');
  }
  return joinAnd(said);
}

/// What one side has that the other does not, each way.
({Map<String, int> white, Map<String, int> black}) _surplus(String fen) {
  final w = _count(fen, white: true);
  final b = _count(fen, white: false);
  return (
    white: {for (final k in _order) k: w[k]! > b[k]! ? w[k]! - b[k]! : 0},
    black: {for (final k in _order) k: b[k]! > w[k]! ? b[k]! - w[k]! : 0},
  );
}

bool _none(Map<String, int> m) => m.values.every((n) => n == 0);

/// Whether [a] is one rook and [b] one bishop or knight, pawns aside.
bool _exchange(Map<String, int> a, Map<String, int> b) =>
    a['r'] == 1 &&
    a['q'] == 0 &&
    a['b'] == 0 &&
    a['n'] == 0 &&
    b['r'] == 0 &&
    b['q'] == 0 &&
    (b['b']! + b['n']!) == 1;

/// Bishops and knights set against each other, a pair at a time: what is
/// left of [a] and [b] once they are, and the note that says what went —
/// „a bishop for a knight". In points they are the same piece.
({Map<String, int> a, Map<String, int> b, String? note}) _minorsOff(
  Map<String, int> a,
  Map<String, int> b,
  String aName,
) {
  final left = {...a};
  final right = {...b};
  final mine = <String, int>{'b': 0, 'n': 0};
  final theirs = <String, int>{'b': 0, 'n': 0};
  for (final (x, y) in const [('b', 'n'), ('n', 'b')]) {
    final pairs = left[x]! < right[y]! ? left[x]! : right[y]!;
    left[x] = left[x]! - pairs;
    right[y] = right[y]! - pairs;
    mine[x] = mine[x]! + pairs;
    theirs[y] = theirs[y]! + pairs;
  }
  final note = mine.values.every((n) => n == 0)
      ? null
      : '$aName has ${_pieces(mine)} for ${_pieces(theirs)}.';
  return (a: left, b: right, note: note);
}

/// The material on the board as a sentence: „Material is level.", „White is
/// a pawn up.", „Black is the exchange up.", „White has a queen for a rook
/// and a bishop." A bishop against a knight is level, and said beside it.
String materialWords(String fen) {
  final raw = _surplus(fen);
  final off = _minorsOff(raw.white, raw.black, 'White');
  final white = off.a;
  final black = off.b;
  String withNote(String words) =>
      off.note == null ? words : '$words ${off.note}';

  if (_none(white) && _none(black)) return withNote('Material is level.');
  if (_none(black)) return withNote('White is ${_pieces(white)} up.');
  if (_none(white)) return withNote('Black is ${_pieces(black)} up.');
  for (final (side, mine, theirs) in [
    ('White', white, black),
    ('Black', black, white),
  ]) {
    if (!_exchange(mine, theirs)) continue;
    final myPawns = mine['p']!;
    final theirPawns = theirs['p']!;
    if (myPawns == 0 && theirPawns == 0) {
      return withNote('$side is the exchange up.');
    }
    if (theirPawns > 0) {
      return withNote('$side is the exchange up, for '
          '${theirPawns == 1 ? 'a pawn' : '${countWord(theirPawns)} pawns'}.');
    }
    return withNote('$side is the exchange and '
        '${myPawns == 1 ? 'a pawn' : '${countWord(myPawns)} pawns'} up.');
  }
  final ahead = balanceOf(fen) >= 0 ? 'White' : 'Black';
  final mine = ahead == 'White' ? white : black;
  final theirs = ahead == 'White' ? black : white;
  return withNote('$ahead has ${_pieces(mine)} for ${_pieces(theirs)}.');
}

/// What [side] won between two positions, in points and in words.
///
/// The points are the change in the balance, never below zero. The words name
/// the pieces when nothing was promoted on the way („a knight", „the
/// exchange", „a rook for a bishop"); with a promotion they fall back on the
/// points, which is all that can be said without telling the line's story.
({int points, String? words}) wonBetween(
    String before, String after, String side) {
  final sign = side == 'White' ? 1 : -1;
  final points = sign * (balanceOf(after) - balanceOf(before));
  if (points <= 0) return (points: 0, words: null);

  final white = side == 'White';
  final mineBefore = _count(before, white: white);
  final mineAfter = _count(after, white: white);
  final theirsBefore = _count(before, white: !white);
  final theirsAfter = _count(after, white: !white);
  final took = {for (final k in _order) k: theirsBefore[k]! - theirsAfter[k]!};
  final gave = {for (final k in _order) k: mineBefore[k]! - mineAfter[k]!};
  final promoted =
      took.values.any((n) => n < 0) || gave.values.any((n) => n < 0);
  if (promoted) return (points: points, words: _pointsWords(points));

  // What both sides lost alike is an exchange of equals and is not said.
  for (final k in _order) {
    final both = took[k]! < gave[k]! ? took[k]! : gave[k]!;
    took[k] = took[k]! - both;
    gave[k] = gave[k]! - both;
  }
  final off = _minorsOff(took, gave, side);
  took
    ..clear()
    ..addAll(off.a);
  gave
    ..clear()
    ..addAll(off.b);
  if (_none(took)) return (points: points, words: _pointsWords(points));
  if (_none(gave)) return (points: points, words: _pieces(took));
  if (_exchange(took, gave) && took['p'] == 0 && gave['p'] == 0) {
    return (points: points, words: 'the exchange');
  }
  return (points: points, words: '${_pieces(took)} for ${_pieces(gave)}');
}

String _pointsWords(int points) => switch (points) {
      1 => 'a pawn',
      2 => 'two pawns',
      3 => "a piece's worth of material",
      5 => "a rook's worth of material",
      9 => "a queen's worth of material",
      _ => '$points points of material',
    };

/// Every piece on the board, side by side: „White: Kg1, Qe2, Rc1, Rf1, Bc4,
/// Nf3, pawns a2 b2 e4. Black: …" — what the model is given in place of a
/// FEN, which it reads badly.
String pieceList(String fen) {
  final board = chess.Chess.fromFEN(fen);
  String side(chess.Color color) {
    final pieces = <String>[];
    final pawns = <String>[];
    for (final kind in const [
      chess.PieceType.KING,
      chess.PieceType.QUEEN,
      chess.PieceType.ROOK,
      chess.PieceType.BISHOP,
      chess.PieceType.KNIGHT,
      chess.PieceType.PAWN,
    ]) {
      for (final sq in kSquares) {
        final p = board.get(sq);
        if (p == null || p.color != color || p.type != kind) continue;
        if (kind == chess.PieceType.PAWN) {
          pawns.add(sq);
        } else {
          pieces.add('${kind.name.toUpperCase()}$sq');
        }
      }
    }
    return [
      ...pieces,
      if (pawns.isNotEmpty) 'pawns ${pawns.join(' ')}',
    ].join(', ');
  }

  return 'White: ${side(chess.Color.WHITE)}. '
      'Black: ${side(chess.Color.BLACK)}.';
}

// --- What a reader looks at first --------------------------------------------

enum NaturalKind { capture, check, attack }

/// A check, a capture or an attack in a position that looks worth playing,
/// with how much it looks worth — „checks, captures, threats" is the order a
/// club player is taught to look in.
class NaturalMove {
  const NaturalMove(this.move, this.kind, this.appeal, this.aim);

  final StudyMove move;
  final NaturalKind kind;

  /// Higher is more natural: twice what a capture takes, what an attack
  /// threatens to take, one for a check.
  final int appeal;

  /// The capture this move makes possible — what it is played *for* — as it
  /// would be played if the other side passed; null when it prepares none.
  /// A bishop that goes to e4 to take on h1 has `e4h1` here.
  final StudyMove? aim;
}

/// An attack has to threaten at least this much to be what the eye goes to:
/// a piece. Every other move attacks some pawn.
const int kNaturalAttackValue = 3;

/// The checks, captures and attacks of [fen] that look sound on their face,
/// the most appealing first.
///
/// A capture looks sound when it takes something worth at least the capturer,
/// or something nothing defends. A check looks sound when the checking piece
/// lands where nothing attacks it, or where a friend covers it. An attack is a
/// quiet move after which a new capture of that kind, worth a piece or more,
/// is there to be played. None of it is a judgement — the engine gives that —
/// only a guess at what the eye goes to.
List<NaturalMove> naturalMoves(String fen) {
  final board = chess.Chess.fromFEN(fen);
  final us = board.turn;
  final before = {for (final c in soundCaptures(fen)) c.to};
  final out = <NaturalMove>[];
  for (final raw in board.generate_moves()) {
    // Under-promotions are never what the eye goes to.
    if (raw.promotion != null && raw.promotion != chess.PieceType.QUEEN) {
      continue;
    }
    final move = playUci(
      fen,
      '${raw.fromAlgebraic}${raw.toAlgebraic}${raw.promotion?.name ?? ''}',
    );
    if (move == null || move.mate) continue;
    final aim = _aimOf(move, before);
    final NaturalKind kind;
    final int worth;
    if (move.capture) {
      if (!_sound(board, move)) continue;
      kind = NaturalKind.capture;
      worth = move.taken;
    } else {
      final after = chess.Chess.fromFEN(move.fenAfter);
      final attacked = _attackers(after, move.to, by: _other(us)).isNotEmpty;
      final covered = _attackers(after, move.to, by: us).isNotEmpty;
      if (attacked && !covered) continue;
      if (move.check) {
        kind = NaturalKind.check;
        worth = 1;
      } else if (aim != null && aim.taken >= kNaturalAttackValue) {
        kind = NaturalKind.attack;
        worth = aim.taken;
      } else {
        continue;
      }
    }
    // A move that leaves something bigger to be taken is not what a player
    // looks at: with a rook hanging, nobody goes after a bishop.
    final left = soundCaptures(move.fenAfter)
        .fold<int>(0, (most, c) => c.taken > most ? c.taken : most);
    if (left > worth) continue;
    out.add(NaturalMove(
      move,
      kind,
      kind == NaturalKind.capture ? 2 * worth : worth,
      aim,
    ));
  }
  out.sort((a, b) {
    final byAppeal = b.appeal.compareTo(a.appeal);
    return byAppeal != 0 ? byAppeal : a.move.uci.compareTo(b.move.uci);
  });
  return out;
}

/// The most valuable capture [move] makes possible that wins material on its
/// face — it takes more than the capturer is worth, or something nothing
/// defends — on a square nothing could be taken on before it ([before]),
/// read from the position after it with the other side passing. Null when the
/// move gives check — nobody passes out of one — or prepares nothing.
StudyMove? _aimOf(StudyMove move, Set<String> before) {
  final passed = passedFen(move.fenAfter);
  if (passed == null) return null;
  final board = chess.Chess.fromFEN(passed);
  StudyMove? best;
  for (final c in soundCaptures(passed)) {
    if (before.contains(c.to)) continue;
    final capturer = board.get(c.from)!;
    final after = chess.Chess.fromFEN(c.fenAfter);
    final wins = c.taken > pieceValue(capturer.type) ||
        _attackers(after, c.to, by: after.turn).isEmpty;
    if (!wins) continue;
    if (best == null || c.taken > best.taken) best = c;
  }
  return best;
}

/// The captures of [fen] that look sound, for whoever is to move: each takes
/// something worth at least the capturer, or something nothing defends.
List<StudyMove> soundCaptures(String fen) {
  final board = chess.Chess.fromFEN(fen);
  final out = <StudyMove>[];
  for (final raw in board.generate_moves()) {
    if (raw.promotion != null && raw.promotion != chess.PieceType.QUEEN) {
      continue;
    }
    final move = playUci(
      fen,
      '${raw.fromAlgebraic}${raw.toAlgebraic}${raw.promotion?.name ?? ''}',
    );
    if (move != null && move.capture && _sound(board, move)) out.add(move);
  }
  return out;
}

/// Whether the capture [move], played on [board], takes something worth at
/// least the capturer or something nothing defends.
bool _sound(chess.Chess board, StudyMove move) {
  final mover = board.get(move.from)!;
  if (move.taken >= pieceValue(mover.type)) return true;
  final after = chess.Chess.fromFEN(move.fenAfter);
  return _attackers(after, move.to, by: after.turn).isEmpty;
}

chess.Color _other(chess.Color c) =>
    c == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;

/// The squares of [by]'s pieces that attack [square] on [board].
List<String> _attackers(chess.Chess board, String square,
    {required chess.Color by}) {
  final out = <String>[];
  for (final sq in kSquares) {
    final p = board.get(sq);
    if (p == null || p.color != by || sq == square) continue;
    if (boardAttacks(board, sq).contains(square)) out.add(sq);
  }
  return out;
}
