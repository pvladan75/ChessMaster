/// A move said the way players say it (D1) — the one place a move becomes
/// words (`docs/PLAN-GOVOR-IZ-KLIPOVA.md` §2). Nothing else turns a move into
/// tokens.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/legal_moves.dart'
    show legalMoves, playMove, promotionOf;
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';

/// What a move is, in the words a voice needs. [fromFile] and [fromRank] are
/// set only where another piece of the same kind and colour could reach [to]
/// (D11), and a pawn's capture always carries [fromFile].
class MoveFacts {
  const MoveFacts({
    required this.side,
    required this.piece,
    required this.to,
    this.capture = false,
    this.check = false,
    this.mate = false,
    this.castles,
    this.promotion,
    this.fromFile,
    this.fromRank,
  });

  /// `'white'` or `'black'`.
  final String side;

  /// One of [kPieces].
  final String piece;

  /// The destination square, `e4`.
  final String to;
  final bool capture;
  final bool check;
  final bool mate;

  /// `'kingside'`, `'queenside'` or null.
  final String? castles;

  /// One of [kPromotionPieces], or null.
  final String? promotion;
  final String? fromFile;
  final int? fromRank;
}

class MoveWords {
  MoveWords._();

  static SpokenLine line(MoveFacts f) {
    final tokens = <SpeechToken>[];
    final castles = f.castles;
    if (castles != null) {
      final white = f.side == 'white';
      tokens.add(castles == 'kingside'
          ? (white
              ? SpeechVocabulary.whiteCastlesKingside
              : SpeechVocabulary.blackCastlesKingside)
          : (white
              ? SpeechVocabulary.whiteCastlesQueenside
              : SpeechVocabulary.blackCastlesQueenside));
    } else {
      tokens.add(f.side == 'white'
          ? SpeechVocabulary.whitePlays
          : SpeechVocabulary.blackPlays);
      tokens.add(SpeechVocabulary.piece(f.piece));
      if (f.fromFile != null) {
        tokens.add(SpeechVocabulary.fileLetter(f.fromFile!));
      }
      if (f.fromRank != null) {
        tokens.add(SpeechVocabulary.rank(f.fromRank!));
      }
      if (f.capture) {
        tokens.add(SpeechVocabulary.takes);
      }
      tokens.add(SpeechVocabulary.square(f.to, afterTakes: f.capture));
      if (f.promotion != null) {
        tokens.add(SpeechVocabulary.promotesTo);
        tokens.add(SpeechVocabulary.promotionPiece(f.promotion!));
      }
    }
    if (f.mate) {
      tokens.add(SpeechVocabulary.checkmate);
    } else if (f.check) {
      tokens.add(SpeechVocabulary.check);
    }
    return SpokenLine(tokens);
  }

  /// A move to be said **inside** a sentence, after words of the sentence's
  /// own: the tokens of [line] without its first, the „White plays" head, so
  /// „In the game, White played" + king d5 reads as one sentence. A castling
  /// move has no head to drop — its one token is the whole sentence, side
  /// included — so it is returned whole.
  ///
  /// „Check" and „Checkmate" are left out: each is a sentence of its own in the
  /// carrier it was cut from, and in the middle of another sentence („In the
  /// game, White played rook d3. Check. and dropped the win.") it breaks it.
  /// A move said **as a move** keeps them, through [line].
  static List<SpeechToken> bare(MoveFacts f) {
    final tokens = line(f).tokens;
    if (f.castles != null) return tokens;
    return [
      for (final t in tokens.skip(1))
        if (t.id != 'check' && t.id != 'checkmate') t,
    ];
  }

  /// The facts of [san] played in [fenBefore], or null when it is not a legal
  /// move there. For a move a server or a stored game hands over as notation
  /// rather than as squares.
  static MoveFacts? factsOfSan(String fenBefore, String san) {
    try {
      final game = chess.Chess.fromFEN(fenBefore);
      if (!game.move(san)) return null;
      final played = game.history.last.move;
      return factsOf(
        fenBefore,
        played.fromAlgebraic,
        played.toAlgebraic,
        promotion: played.promotion?.name,
      );
    } catch (_) {
      return null;
    }
  }

  /// The same move as the opponent's *other* defence, said before it is
  /// drawn: „Now suppose Black plays pawn d4." Castling has no such form —
  /// its sentence carries the side in its own words — so a castling move is
  /// said as [line] says it.
  static SpokenLine supposeLine(MoveFacts f) {
    if (f.castles != null) return line(f);
    final plain = line(f);
    return SpokenLine(
        [SpeechVocabulary.nowSuppose(f.side), ...plain.tokens.skip(1)]);
  }

  /// The facts of the move [from]→[to] played in the position [fenBefore], or
  /// null when it is not a legal move there. Read off a copy of the position;
  /// nothing is played on the caller's board.
  ///
  /// The file letter is given when another piece of the same kind could reach
  /// [to] and no other shares this one's file; the rank when the file does not
  /// settle it. A pawn capture always names its file.
  static MoveFacts? factsOf(
    String fenBefore,
    String from,
    String to, {
    String? promotion,
  }) {
    final game = chess.Chess.fromFEN(fenBefore);
    final moves = legalMoves(game);
    Map<String, dynamic>? played;
    for (final m in moves) {
      if (m['from'] != from || m['to'] != to) continue;
      final promo = m['promotion'] as String? ?? '';
      // A promotion is asked for only to tell the four apart: a move that is not
      // one is found whatever piece the caller names.
      if (promo.isEmpty ||
          promotion == null ||
          promotion.isEmpty ||
          promo == promotion) {
        played = m;
        break;
      }
    }
    if (played == null) return null;

    final mover = game.get(from);
    if (mover == null) return null;
    final piece = _pieceNames[mover.type.name]!;
    final side = game.turn == chess.Color.WHITE ? 'white' : 'black';
    final flags = played['flags'] as String? ?? '';
    final promo = promotionOf(played);

    String? fromFile;
    int? fromRank;
    final capture = flags.contains('c') || flags.contains('e');
    if (piece == 'pawn') {
      if (capture) fromFile = from[0];
    } else {
      final rivals = <String>{
        for (final m in moves)
          if (m['to'] == to &&
              m['from'] != from &&
              game.get(m['from'] as String)?.type == mover.type)
            m['from'] as String,
      };
      if (rivals.isNotEmpty) {
        if (rivals.every((r) => r[0] != from[0])) {
          fromFile = from[0];
        } else if (rivals.every((r) => r[1] != from[1])) {
          fromRank = int.parse(from[1]);
        } else {
          fromFile = from[0];
          fromRank = int.parse(from[1]);
        }
      }
    }

    playMove(game, played);
    final mate = game.in_checkmate;
    return MoveFacts(
      side: side,
      piece: piece,
      to: to,
      capture: capture,
      check: !mate && game.in_check,
      mate: mate,
      castles: flags.contains('k')
          ? 'kingside'
          : (flags.contains('q') ? 'queenside' : null),
      promotion: promo.isEmpty ? null : _pieceNames[promo],
      fromFile: fromFile,
      fromRank: fromRank,
    );
  }

  static const Map<String, String> _pieceNames = {
    'k': 'king',
    'q': 'queen',
    'r': 'rook',
    'b': 'bishop',
    'n': 'knight',
    'p': 'pawn',
  };
}
