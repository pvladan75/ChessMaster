import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/models/tactical_motif.dart';

class _HangingDetectionResult {
  final bool hasHanging;
  final List<String> affectedSquares;
  final String description;

  const _HangingDetectionResult({
    required this.hasHanging,
    required this.affectedSquares,
    required this.description,
  });
}

class _MateDetectionResult {
  final bool hasMate;
  final List<String> affectedSquares;
  final String description;

  const _MateDetectionResult({
    required this.hasMate,
    required this.affectedSquares,
    required this.description,
  });
}

/// Universal, pure stateless service for detecting tactical motifs across all app modules
/// (Training, Live Game, Lesson Replay, Analysis Studio).
class TacticalMotifDetector {
  const TacticalMotifDetector();

  /// Main entry point for detecting tactical motifs in a position.
  MotifResult detect({
    required String fen,
    String? lastMoveUci,
    String? evalText,
    int? mateIn,
    double? evalScore,
  }) {
    try {
      final game = chess.Chess.fromFEN(fen);

      // Determine colors: sideToMove is the defender/current player,
      // moverColor is the player who just moved (or side giving threats).
      final sideToMove = game.turn;
      final defenderColor = sideToMove;
      final moverColor = sideToMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;

      final hanging = _detectHangingPieces(
        game,
        targetColor: defenderColor,
        attackerColor: moverColor,
      );

      final mate = _detectMateThreat(
        game,
        evalText: evalText,
        mateIn: mateIn,
        evalScore: evalScore,
        moverColor: moverColor,
        defenderColor: defenderColor,
      );

      final motifs = <TacticalMotif>[];
      final affectedSquares = <String>{};
      final descriptions = <String>[];

      // Check for combined Double Attack: Mate Threat + Piece Attack
      if (mate.hasMate && hanging.affectedSquares.isNotEmpty) {
        motifs.add(TacticalMotif.mateThreatAndPieceAttack);
        motifs.add(TacticalMotif.doubleAttack);
        motifs.add(TacticalMotif.mateThreat);
        motifs.add(TacticalMotif.hangingPiece);

        affectedSquares.addAll(hanging.affectedSquares);
        affectedSquares.addAll(mate.affectedSquares);
        descriptions.add('Dvojni udar: Napad na nebranjenu figuru uz pretnju matom');
      } else {
        if (hanging.hasHanging) {
          motifs.add(TacticalMotif.hangingPiece);
          affectedSquares.addAll(hanging.affectedSquares);
          descriptions.add(hanging.description);
        }
        if (mate.hasMate) {
          motifs.add(TacticalMotif.mateThreat);
          affectedSquares.addAll(mate.affectedSquares);
          descriptions.add(mate.description);
        }
      }

      // Placeholder hooks for future motif expansion
      detectPin(game);
      detectFork(game);
      detectSkewer(game);
      detectDeflection(game);
      detectOverloading(game);

      if (motifs.isEmpty) {
        return MotifResult.empty();
      }

      return MotifResult(
        motifs: motifs,
        description: descriptions.join(' | '),
        affectedSquares: affectedSquares.toList(),
      );
    } catch (_) {
      return MotifResult.empty();
    }
  }

  // =========================================================================
  // DETECTORS & HELPERS
  // =========================================================================

  _HangingDetectionResult _detectHangingPieces(
    chess.Chess game, {
    required chess.Color targetColor,
    required chess.Color attackerColor,
  }) {
    final hangingSquares = <String>[];

    for (var fileIdx = 0; fileIdx < 8; fileIdx++) {
      for (var rankIdx = 0; rankIdx < 8; rankIdx++) {
        final sqName = _coordsToSq(fileIdx, rankIdx);
        final piece = game.get(sqName);
        if (piece == null || piece.color != targetColor) continue;

        // Kings can't be "hanging" in normal tactical sense
        if (piece.type == chess.PieceType.KING) continue;

        final attackers = _countAttackers(game, sqName, attackerColor);
        if (attackers == 0) continue;

        final defenders = _countDefenders(game, sqName, targetColor);

        // Hanging if undefended or attackers > defenders
        if (defenders == 0 || attackers > defenders) {
          hangingSquares.add(sqName);
        }
      }
    }

    if (hangingSquares.isEmpty) {
      return const _HangingDetectionResult(
        hasHanging: false,
        affectedSquares: [],
        description: '',
      );
    }

    final pieceDesc = hangingSquares.length == 1
        ? 'Napad na nebranjenu figuru na ${hangingSquares.first}'
        : 'Napad na nebranjene figure na ${hangingSquares.join(', ')}';

    return _HangingDetectionResult(
      hasHanging: true,
      affectedSquares: hangingSquares,
      description: pieceDesc,
    );
  }

  _MateDetectionResult _detectMateThreat(
    chess.Chess game, {
    String? evalText,
    int? mateIn,
    double? evalScore,
    required chess.Color moverColor,
    required chess.Color defenderColor,
  }) {
    bool isMateThreat = false;
    final mateSquares = <String>[];

    // Check explicit eval text/mateIn inputs
    if (mateIn != null && mateIn.abs() <= 2) {
      isMateThreat = true;
    } else if (evalText != null && (evalText.contains('M') || evalText.contains('#'))) {
      isMateThreat = true;
    }

    // Check board state directly
    if (!isMateThreat) {
      if (game.in_checkmate) {
        isMateThreat = true;
      } else {
        // Check if there is an immediate mate threat or forced mate
        final defenderKingSq = _findKingSquare(game, defenderColor);
        if (defenderKingSq != null) {
          final attackersOnKing = _countAttackers(game, defenderKingSq, moverColor);
          if (game.in_check || attackersOnKing > 0) {
            isMateThreat = true;
            mateSquares.add(defenderKingSq);
          }
        }
      }
    }

    final kingSq = _findKingSquare(game, defenderColor);
    if (kingSq != null && !mateSquares.contains(kingSq)) {
      mateSquares.add(kingSq);
    }

    if (!isMateThreat) {
      return const _MateDetectionResult(
        hasMate: false,
        affectedSquares: [],
        description: '',
      );
    }

    return _MateDetectionResult(
      hasMate: true,
      affectedSquares: mateSquares,
      description: 'Pretnja matom',
    );
  }

  // =========================================================================
  // PLACEHOLDER EXTENSIONS FOR FUTURE MOTIFS
  // =========================================================================

  List<String> detectPin(chess.Chess game) => const [];
  List<String> detectFork(chess.Chess game) => const [];
  List<String> detectSkewer(chess.Chess game) => const [];
  List<String> detectDeflection(chess.Chess game) => const [];
  List<String> detectOverloading(chess.Chess game) => const [];

  // =========================================================================
  // LOW-LEVEL PIECE & ATTACK COMPUTATION
  // =========================================================================

  int _countAttackers(chess.Chess game, String targetSq, chess.Color attackerColor) {
    int count = 0;
    final toFile = targetSq.codeUnitAt(0) - 97;
    final toRank = targetSq.codeUnitAt(1) - 49;

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final fromSq = _coordsToSq(f, r);
        if (fromSq == targetSq) continue;
        final p = game.get(fromSq);
        if (p == null || p.color != attackerColor) continue;

        if (_canPieceAttack(game, p, f, r, toFile, toRank)) {
          count++;
        }
      }
    }
    return count;
  }

  int _countDefenders(chess.Chess game, String targetSq, chess.Color defenderColor) {
    int count = 0;
    final toFile = targetSq.codeUnitAt(0) - 97;
    final toRank = targetSq.codeUnitAt(1) - 49;

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final fromSq = _coordsToSq(f, r);
        if (fromSq == targetSq) continue;
        final p = game.get(fromSq);
        if (p == null || p.color != defenderColor) continue;

        if (_canPieceAttack(game, p, f, r, toFile, toRank)) {
          count++;
        }
      }
    }
    return count;
  }

  bool _canPieceAttack(
    chess.Chess game,
    chess.Piece piece,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    final df = (fromFile - toFile).abs();
    final dr = (fromRank - toRank).abs();

    switch (piece.type) {
      case chess.PieceType.PAWN:
        final direction = piece.color == chess.Color.WHITE ? 1 : -1;
        return (toRank - fromRank) == direction && df == 1;

      case chess.PieceType.KNIGHT:
        return (df == 1 && dr == 2) || (df == 2 && dr == 1);

      case chess.PieceType.KING:
        return df <= 1 && dr <= 1;

      case chess.PieceType.BISHOP:
        if (df != dr) return false;
        return _isRayClear(game, fromFile, fromRank, toFile, toRank);

      case chess.PieceType.ROOK:
        if (fromFile != toFile && fromRank != toRank) return false;
        return _isRayClear(game, fromFile, fromRank, toFile, toRank);

      case chess.PieceType.QUEEN:
        if (df != dr && (fromFile != toFile && fromRank != toRank)) return false;
        return _isRayClear(game, fromFile, fromRank, toFile, toRank);
    }
    return false;
  }

  bool _isRayClear(
    chess.Chess game,
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    final stepFile = (toFile - fromFile).sign;
    final stepRank = (toRank - fromRank).sign;

    var curFile = fromFile + stepFile;
    var curRank = fromRank + stepRank;

    while (curFile != toFile || curRank != toRank) {
      final sq = _coordsToSq(curFile, curRank);
      if (game.get(sq) != null) {
        return false;
      }
      curFile += stepFile;
      curRank += stepRank;
    }
    return true;
  }

  String? _findKingSquare(chess.Chess game, chess.Color color) {
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p != null && p.type == chess.PieceType.KING && p.color == color) {
          return sq;
        }
      }
    }
    return null;
  }

  String _coordsToSq(int fileIdx, int rankIdx) {
    final f = String.fromCharCode(97 + fileIdx);
    final r = String.fromCharCode(49 + rankIdx);
    return '$f$r';
  }
}
