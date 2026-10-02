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
