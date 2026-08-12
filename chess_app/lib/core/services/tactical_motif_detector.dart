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

class _ForkResult {
  final bool hasFork;
  final List<String> affectedSquares;
  final String description;

  const _ForkResult({
    required this.hasFork,
    required this.affectedSquares,
    required this.description,
  });
}

class _PinSkewerResult {
  final bool hasPin;
  final bool hasSkewer;
  final List<String> pinSquares;
  final List<String> skewerSquares;
  final String pinDescription;
  final String skewerDescription;

  const _PinSkewerResult({
    required this.hasPin,
    required this.hasSkewer,
    required this.pinSquares,
    required this.skewerSquares,
    required this.pinDescription,
    required this.skewerDescription,
  });
}

class _DiscoveredAttackResult {
  final bool hasDiscoveredAttack;
  final bool isDiscoveredCheck;
  final List<String> affectedSquares;
  final String description;

  const _DiscoveredAttackResult({
    required this.hasDiscoveredAttack,
    required this.isDiscoveredCheck,
    required this.affectedSquares,
    required this.description,
  });
}

class _OverloadingResult {
  final bool hasOverloading;
  final List<String> affectedSquares;
  final String description;

  const _OverloadingResult({
    required this.hasOverloading,
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

      // Determine colors: defenderColor is the current side to move,
      // moverColor is the player who just moved.
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

      final fork = detectFork(game, attackerColor: moverColor, targetColor: defenderColor, lastMoveUci: lastMoveUci);
      final pinSkewer = _detectPinAndSkewer(game, attackerColor: moverColor, targetColor: defenderColor);
      final discovered = detectDiscoveredAttack(game, attackerColor: moverColor, targetColor: defenderColor, lastMoveUci: lastMoveUci);
      final overload = detectOverloading(game, attackerColor: moverColor, targetColor: defenderColor);

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

      if (fork.hasFork) {
        motifs.add(TacticalMotif.fork);
        if (!motifs.contains(TacticalMotif.doubleAttack)) {
          motifs.add(TacticalMotif.doubleAttack);
        }
        affectedSquares.addAll(fork.affectedSquares);
        descriptions.add(fork.description);
      }

      if (pinSkewer.hasPin) {
        motifs.add(TacticalMotif.pin);
        affectedSquares.addAll(pinSkewer.pinSquares);
        descriptions.add(pinSkewer.pinDescription);
      }

      if (pinSkewer.hasSkewer) {
        motifs.add(TacticalMotif.skewer);
        affectedSquares.addAll(pinSkewer.skewerSquares);
        descriptions.add(pinSkewer.skewerDescription);
      }

      if (discovered.hasDiscoveredAttack) {
        motifs.add(TacticalMotif.discoveredAttack);
        affectedSquares.addAll(discovered.affectedSquares);
        descriptions.add(discovered.description);
      }

      if (overload.hasOverloading) {
        motifs.add(TacticalMotif.overloading);
        affectedSquares.addAll(overload.affectedSquares);
        descriptions.add(overload.description);
      }

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
  // 1. FORK (VILJUŠKA)
  // =========================================================================

  _ForkResult detectFork(
    chess.Chess game, {
    chess.Color? attackerColor,
    chess.Color? targetColor,
    String? lastMoveUci,
  }) {
    attackerColor ??= game.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    targetColor ??= game.turn;

    // Destination of last move is prime suspect for fork
    String? moveDest;
    if (lastMoveUci != null && lastMoveUci.length >= 4) {
      moveDest = lastMoveUci.substring(2, 4);
    }

    final forkSquares = <String>{};
    final attackedTargets = <String>[];

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p == null || p.color != attackerColor) continue;

        // If lastMoveUci is specified, prioritize checking that piece first
        if (moveDest != null && sq != moveDest) continue;

        final targets = _getAttackedOpponentSquares(game, sq, p, targetColor);
        if (targets.length >= 2) {
          // Verify targets include valuable pieces or check on King
          bool hasKingCheck = false;
          int valuableTargets = 0;
          for (final tSq in targets) {
            final tPiece = game.get(tSq);
            if (tPiece != null) {
              if (tPiece.type == chess.PieceType.KING) {
                hasKingCheck = true;
              } else if (_pieceValue(tPiece.type) >= _pieceValue(p.type) || tPiece.type == chess.PieceType.ROOK || tPiece.type == chess.PieceType.QUEEN) {
                valuableTargets++;
              }
            }
          }

          if (hasKingCheck || valuableTargets >= 2 || targets.length >= 2) {
            forkSquares.add(sq);
            attackedTargets.addAll(targets);
          }
        }
      }
    }

    if (forkSquares.isEmpty) {
      return const _ForkResult(hasFork: false, affectedSquares: [], description: '');
    }

    final allSquares = {...forkSquares, ...attackedTargets}.toList();
    return _ForkResult(
      hasFork: true,
      affectedSquares: allSquares,
      description: 'Viljuška: Figura napada više protivničkih meta istovremeno',
    );
  }

  // =========================================================================
  // 2. PIN (VEZIVANJE) & SKEWER (RAŽANJ)
  // =========================================================================

  _PinSkewerResult _detectPinAndSkewer(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
  }) {
    final pinSquares = <String>{};
    final skewerSquares = <String>{};

    final directions = [
      [1, 0], [-1, 0], [0, 1], [0, -1], // Orthogonal
      [1, 1], [1, -1], [-1, 1], [-1, -1], // Diagonal
    ];

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final attackerSq = _coordsToSq(f, r);
        final p = game.get(attackerSq);
        if (p == null || p.color != attackerColor) continue;

        // Only sliders can pin or skewer
        if (p.type != chess.PieceType.BISHOP && p.type != chess.PieceType.ROOK && p.type != chess.PieceType.QUEEN) {
          continue;
        }

        for (final dir in directions) {
          final df = dir[0];
          final dr = dir[1];

          final isDiagonal = df != 0 && dr != 0;
          if (isDiagonal && p.type == chess.PieceType.ROOK) continue;
          if (!isDiagonal && p.type == chess.PieceType.BISHOP) continue;

          // Raycast to find 1st and 2nd pieces along ray
          String? firstSq;
          chess.Piece? firstPiece;
          String? secondSq;
          chess.Piece? secondPiece;

          var curF = f + df;
          var curR = r + dr;

          while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
            final checkSq = _coordsToSq(curF, curR);
            final checkPiece = game.get(checkSq);
            if (checkPiece != null) {
              if (firstPiece == null) {
                firstSq = checkSq;
                firstPiece = checkPiece;
              } else {
                secondSq = checkSq;
                secondPiece = checkPiece;
                break; // Found 2nd piece, stop raycast
              }
            }
            curF += df;
            curR += dr;
          }

          // Both 1st and 2nd pieces must belong to targetColor
          if (firstPiece != null && secondPiece != null && firstPiece.color == targetColor && secondPiece.color == targetColor) {
            final val1 = _pieceValue(firstPiece.type);
            final val2 = _pieceValue(secondPiece.type);

            // PIN: 2nd piece is King or higher value than 1st piece
            if (secondPiece.type == chess.PieceType.KING || val2 > val1) {
              pinSquares.addAll([attackerSq, firstSq!, secondSq!]);
            }
            // SKEWER: 1st piece is King or higher value than 2nd piece
            else if (firstPiece.type == chess.PieceType.KING || val1 > val2) {
              skewerSquares.addAll([attackerSq, firstSq!, secondSq!]);
            }
          }
        }
      }
    }

    return _PinSkewerResult(
      hasPin: pinSquares.isNotEmpty,
      hasSkewer: skewerSquares.isNotEmpty,
      pinSquares: pinSquares.toList(),
      skewerSquares: skewerSquares.toList(),
      pinDescription: 'Vezivanje: Figura je prikovana i ne može se bezbedno pomeriti',
      skewerDescription: 'Ražanj: Vrednija figura je napadnuta ispred nezaštićene figure',
    );
  }

  List<String> detectPin(chess.Chess game) {
    final sideToMove = game.turn;
    final defenderColor = sideToMove;
    final moverColor = sideToMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    final res = _detectPinAndSkewer(game, attackerColor: moverColor, targetColor: defenderColor);
    return res.pinSquares;
  }

  List<String> detectSkewer(chess.Chess game) {
    final sideToMove = game.turn;
    final defenderColor = sideToMove;
    final moverColor = sideToMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    final res = _detectPinAndSkewer(game, attackerColor: moverColor, targetColor: defenderColor);
    return res.skewerSquares;
  }

  // =========================================================================
  // 3. DISCOVERED ATTACK / CHECK (OTKRIVENI NAPAD / ŠAH)
  // =========================================================================

  _DiscoveredAttackResult detectDiscoveredAttack(
    chess.Chess game, {
    chess.Color? attackerColor,
    chess.Color? targetColor,
    String? lastMoveUci,
  }) {
    attackerColor ??= game.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    targetColor ??= game.turn;

    if (lastMoveUci == null || lastMoveUci.length < 4) {
      return const _DiscoveredAttackResult(
        hasDiscoveredAttack: false,
        isDiscoveredCheck: false,
        affectedSquares: [],
        description: '',
      );
    }

    final fromSq = lastMoveUci.substring(0, 2);
    final toSq = lastMoveUci.substring(2, 4);

    final fromF = fromSq.codeUnitAt(0) - 97;
    final fromR = fromSq.codeUnitAt(1) - 49;

    final discSquares = <String>{};
    bool isCheck = false;

    // Check slider pieces of attackerColor that now have a clear ray through fromSq
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sliderSq = _coordsToSq(f, r);
        if (sliderSq == toSq) continue; // The moved piece itself isn't the discovered slider
        final p = game.get(sliderSq);
        if (p == null || p.color != attackerColor) continue;

        if (p.type != chess.PieceType.BISHOP && p.type != chess.PieceType.ROOK && p.type != chess.PieceType.QUEEN) {
          continue;
        }

        // Is fromSq strictly along the line of sight from sliderSq?
        final df = (fromF - f);
        final dr = (fromR - r);
        if (df == 0 && dr == 0) continue;

        final isDiag = df.abs() == dr.abs();
        final isOrtho = (df == 0 && dr != 0) || (df != 0 && dr == 0);

        if (isDiag && p.type == chess.PieceType.ROOK) continue;
        if (isOrtho && p.type == chess.PieceType.BISHOP) continue;
        if (!isDiag && !isOrtho) continue;

        // Trace past fromSq to see what target is attacked
        final stepF = df.sign;
        final stepR = dr.sign;

        var curF = f + stepF;
        var curR = r + stepR;
        String? hitSq;
        chess.Piece? hitPiece;

        while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
          final checkSq = _coordsToSq(curF, curR);
          final checkPiece = game.get(checkSq);
          if (checkPiece != null) {
            hitSq = checkSq;
            hitPiece = checkPiece;
            break;
          }
          curF += stepF;
          curR += stepR;
        }

        if (hitPiece != null && hitPiece.color == targetColor) {
          if (hitPiece.type == chess.PieceType.KING) {
            isCheck = true;
            discSquares.addAll([sliderSq, fromSq, hitSq!]);
          } else if (_pieceValue(hitPiece.type) >= 3) {
            discSquares.addAll([sliderSq, fromSq, hitSq!]);
          }
        }
      }
    }

    if (discSquares.isEmpty) {
      return const _DiscoveredAttackResult(
        hasDiscoveredAttack: false,
        isDiscoveredCheck: false,
        affectedSquares: [],
        description: '',
      );
    }

    final desc = isCheck
        ? 'Otkriveni šah: Pomeranjem figure otvorena je linija napada na Kralja'
        : 'Otkriveni napad: Pomeranjem figure otvorena je linija napada na protivničku figuru';

    return _DiscoveredAttackResult(
      hasDiscoveredAttack: true,
      isDiscoveredCheck: isCheck,
      affectedSquares: discSquares.toList(),
      description: desc,
    );
  }

  // =========================================================================
  // 4. OVERLOADING (PREOPTEREĆENA FIGURA)
  // =========================================================================

  _OverloadingResult detectOverloading(
    chess.Chess game, {
    chess.Color? attackerColor,
    chess.Color? targetColor,
  }) {
    attackerColor ??= game.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    targetColor ??= game.turn;

    final overloadedSquares = <String>{};

    // Find pieces of targetColor that are sole defenders for >= 2 attacked pieces/squares
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final defSq = _coordsToSq(f, r);
        final defPiece = game.get(defSq);
        if (defPiece == null || defPiece.color != targetColor) continue;

        final defendedTargetsUnderAttack = <String>[];

        for (var tf = 0; tf < 8; tf++) {
          for (var tr = 0; tr < 8; tr++) {
            final tSq = _coordsToSq(tf, tr);
            if (tSq == defSq) continue;
            final tPiece = game.get(tSq);
            if (tPiece == null || tPiece.color != targetColor) continue;

            final attackers = _countAttackers(game, tSq, attackerColor);
            if (attackers > 0) {
              final defenders = _countDefenders(game, tSq, targetColor);
              // Check if defPiece is a defender and it is sole defender or critical
              if (defenders == 1 && _canPieceAttack(game, defPiece, f, r, tf, tr)) {
                defendedTargetsUnderAttack.add(tSq);
              }
            }
          }
        }

        if (defendedTargetsUnderAttack.length >= 2) {
          overloadedSquares.add(defSq);
          overloadedSquares.addAll(defendedTargetsUnderAttack);
        }
      }
    }

    if (overloadedSquares.isEmpty) {
      return const _OverloadingResult(hasOverloading: false, affectedSquares: [], description: '');
    }

    return _OverloadingResult(
      hasOverloading: true,
      affectedSquares: overloadedSquares.toList(),
      description: 'Preopterećena figura: Jedna figura brani više napadnutih pozicija',
    );
  }

  // =========================================================================
  // HELPER METHODS
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
        if (piece.type == chess.PieceType.KING) continue;

        final attackers = _countAttackers(game, sqName, attackerColor);
        if (attackers == 0) continue;

        final defenders = _countDefenders(game, sqName, targetColor);

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

    if (mateIn != null && mateIn.abs() <= 2) {
      isMateThreat = true;
    } else if (evalText != null && (evalText.contains('M') || evalText.contains('#'))) {
      isMateThreat = true;
    }

    if (!isMateThreat) {
      if (game.in_checkmate) {
        isMateThreat = true;
      } else {
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

  List<String> _getAttackedOpponentSquares(
    chess.Chess game,
    String fromSq,
    chess.Piece piece,
    chess.Color targetColor,
  ) {
    final targets = <String>[];
    final fromFile = fromSq.codeUnitAt(0) - 97;
    final fromRank = fromSq.codeUnitAt(1) - 49;

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final toSq = _coordsToSq(f, r);
        if (toSq == fromSq) continue;
        final targetPiece = game.get(toSq);
        if (targetPiece == null || targetPiece.color != targetColor) continue;

        if (_canPieceAttack(game, piece, fromFile, fromRank, f, r)) {
          targets.add(toSq);
        }
      }
    }
    return targets;
  }

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

  int _pieceValue(chess.PieceType type) {
    switch (type) {
      case chess.PieceType.PAWN:
        return 1;
      case chess.PieceType.KNIGHT:
        return 3;
      case chess.PieceType.BISHOP:
        return 3;
      case chess.PieceType.ROOK:
        return 5;
      case chess.PieceType.QUEEN:
        return 9;
      case chess.PieceType.KING:
        return 1000;
      default:
        return 0;
    }
  }

  String _coordsToSq(int fileIdx, int rankIdx) {
    final f = String.fromCharCode(97 + fileIdx);
    final r = String.fromCharCode(49 + rankIdx);
    return '$f$r';
  }
}
