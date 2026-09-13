import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/models/positional_factor.dart';
import 'package:chess_app/core/services/finding_sentences.dart';

class _PawnFacts {
  final int file;
  final int rank;
  final String square;
  final chess.Color color;

  const _PawnFacts(this.file, this.rank, this.square, this.color);
}

/// Pure, stateless service that evaluates positional/strategic factors from
/// a FEN — pawn structure, open files, center control, the bishop pair, and
/// simple king-safety signals. Mirrors [TacticalMotifDetector]'s shape
/// (`evaluate`/`explainMove`/`describeMoveDiff`/`candidateCommentLines`) so
/// the two can share UI and combine into one comment.
///
/// This is narration, not a second evaluation: it never produces its own
/// positional "score" that could contradict the engine's centipawn eval —
/// only findings that explain *why* the position looks the way it does.
class PositionalEvaluatorService {
  const PositionalEvaluatorService();

  static const int _minSignificanceForComment = 3;
  static const int _maxCreatedInComment = 3;
  static const int _maxResolvedInComment = 2;

  /// Main entry point: every positional finding for the current position,
  /// tagged relative to whoever just moved (see [PositionalFinding.favorsMover]).
  PositionalResult evaluate({required String fen}) {
    try {
      final game = chess.Chess.fromFEN(fen);
      final defenderColor = game.turn;
      final moverColor = defenderColor == chess.Color.WHITE
          ? chess.Color.BLACK
          : chess.Color.WHITE;
      return PositionalResult(
          findings: _buildFindings(game, moverColor: moverColor));
    } catch (_) {
      return PositionalResult.empty();
    }
  }

  /// Explains what a move changed positionally, by diffing the position
  /// before and after it — mirrors [TacticalMotifDetector.explainMove].
  PositionalMoveDiff explainMove({
    required String beforeFen,
    required String afterFen,
    required String? lastMoveUci,
  }) {
    try {
      final afterGame = chess.Chess.fromFEN(afterFen);
      final defenderColor = afterGame.turn;
      final moverColor = defenderColor == chess.Color.WHITE
          ? chess.Color.BLACK
          : chess.Color.WHITE;

      final afterFindings = _buildFindings(afterGame, moverColor: moverColor);
      final beforeGame = chess.Chess.fromFEN(beforeFen);
      final beforeFindings = _buildFindings(beforeGame, moverColor: moverColor);

      // A finding from before the move is keyed as its squares stand after
      // it, so a king that walks keeps its missing shield
      // (finding_identity.dart). [lastMoveUci] is required, and null only for
      // two positions that are not one move apart.
      final beforeKeys =
          beforeFindings.map((f) => f.diffKeyAcross(lastMoveUci)).toSet();
      final afterKeys = afterFindings.map((f) => f.diffKey).toSet();

      final created =
          afterFindings.where((f) => !beforeKeys.contains(f.diffKey)).toList();
      final resolved = beforeFindings
          .where((f) => !afterKeys.contains(f.diffKeyAcross(lastMoveUci)))
          .toList();

      return PositionalMoveDiff(created: created, resolved: resolved);
    } catch (_) {
      return const PositionalMoveDiff(created: [], resolved: []);
    }
  }

  /// Sentences, as [TacticalMotifDetector.describeMoveDiff] writes them: what
  /// the move made true, then what it ended, with no prefix on either.
  String describeMoveDiff(PositionalMoveDiff diff) {
    final created = _mostNarratable(diff.created, _maxCreatedInComment);
    final resolved = _mostNarratable(
        diff.resolved.where((f) => !f.favorsMover).toList(),
        _maxResolvedInComment);

    return joinSentences([
      ...created.map((f) => f.description),
      ...resolved.map((f) => f.goneDescription),
    ]);
  }

  /// Every candidate comment line, unfiltered/uncapped — for a manual
  /// checklist UI, mirrors [TacticalMotifDetector.candidateCommentLines].
  List<String> candidateCommentLines(PositionalMoveDiff diff) {
    return [
      ...diff.created.map((f) => f.description),
      ...diff.resolved
          .where((f) => !f.favorsMover)
          .map((f) => f.goneDescription),
    ];
  }

  List<PositionalFinding> _mostNarratable(
      List<PositionalFinding> findings, int max) {
    if (findings.isEmpty) return const [];
    final sorted = [...findings]
      ..sort((a, b) => b.significance.compareTo(a.significance));
    final aboveBar =
        sorted.where((f) => f.significance >= _minSignificanceForComment);
    final pool = aboveBar.isNotEmpty ? aboveBar : sorted.take(1);
    return pool.take(max).toList();
  }

  /// A finding whose two sentences are written as clauses and ended here, so
  /// no call site can forget the capital or the full stop.
  PositionalFinding _finding({
    required PositionalFactor factor,
    required String says,
    required String whenGone,
    required List<String> squares,
    required bool favorsMover,
    required int significance,
  }) =>
      PositionalFinding(
        factors: [factor],
        description: sentence(says),
        goneDescription: sentence(whenGone),
        affectedSquares: squares,
        favorsMover: favorsMover,
        significance: significance,
      );

  // =========================================================================
  // ORCHESTRATION
  // =========================================================================

  List<PositionalFinding> _buildFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    findings.addAll(_pawnStructureFindings(game, moverColor: moverColor));
    findings.addAll(_fileControlFindings(game, moverColor: moverColor));
    findings.addAll(_centerControlFindings(game, moverColor: moverColor));
    findings.addAll(_bishopPairFindings(game, moverColor: moverColor));
    findings.addAll(_colorComplexFindings(game, moverColor: moverColor));
    findings.addAll(_knightOutpostFindings(game, moverColor: moverColor));
    findings.addAll(_kingSafetyFindings(game, moverColor: moverColor));

    return findings;
  }

  /// [isStrength]=true means this is good for [color]; converts to the
  /// mover-relative polarity every finding is stored with.
  bool _favorsMover(
      chess.Color color, bool isStrength, chess.Color moverColor) {
    final isMoverColor = color == moverColor;
    return isStrength == isMoverColor;
  }

  // =========================================================================
  // 1. PAWN STRUCTURE
  // =========================================================================

  List<_PawnFacts> _pawnsOf(chess.Chess game, chess.Color color) {
    final pawns = <_PawnFacts>[];
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p != null && p.type == chess.PieceType.PAWN && p.color == color) {
          pawns.add(_PawnFacts(f, r, sq, color));
        }
      }
    }
    return pawns;
  }

  List<PositionalFinding> _pawnStructureFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    for (final color in [chess.Color.WHITE, chess.Color.BLACK]) {
      final pawns = _pawnsOf(game, color);
      if (pawns.isEmpty) continue;

      final side = _colorAdjCap(color);
      final colour = _colorAdj(color);
      final enemy = _colorAdj(_other(color));

      final byFile = <int, List<_PawnFacts>>{};
      for (final p in pawns) {
        byFile.putIfAbsent(p.file, () => []).add(p);
      }

      // Doubled pawns: 2+ of this color's pawns share a file.
      byFile.forEach((file, filePawns) {
        if (filePawns.length < 2) return;
        final squares = filePawns.map((p) => p.square).toList()..sort();
        findings.add(_finding(
          factor: PositionalFactor.doubledPawn,
          says: '$side has doubled pawns on ${joinAnd(squares)}',
          whenGone:
              '$side no longer has doubled pawns on the ${_fileLetter(file)}-file',
          squares: squares,
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 2,
        ));
      });

      // Isolated pawns: no same-color pawn on an adjacent file, regardless of rank.
      byFile.forEach((file, filePawns) {
        final hasNeighbor =
            byFile.containsKey(file - 1) || byFile.containsKey(file + 1);
        if (hasNeighbor) return;
        final squares = filePawns.map((p) => p.square).toList()..sort();
        final one = squares.length == 1;
        final pawnsHere =
            'the $colour ${one ? 'pawn' : 'pawns'} on ${joinAnd(squares)}';
        findings.add(_finding(
          factor: PositionalFactor.isolatedPawn,
          says: '$pawnsHere ${one ? 'is' : 'are'} isolated: '
              'no pawn on a neighbouring file can defend ${one ? 'it' : 'them'}',
          whenGone: '$pawnsHere ${one ? 'is' : 'are'} no longer isolated',
          squares: squares,
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 3,
        ));
      });

      // Backward / passed are per-pawn.
      for (final p in pawns) {
        if (_isBackwardPawn(game, p)) {
          findings.add(_finding(
            factor: PositionalFactor.backwardPawn,
            says: 'the $colour pawn on ${p.square} is backward: it has fallen '
                'behind its neighbours and cannot advance safely',
            whenGone: 'the $colour pawn on ${p.square} is no longer backward',
            squares: [p.square],
            favorsMover: _favorsMover(color, false, moverColor),
            significance: 3,
          ));
        }
        if (_isPassedPawn(game, p)) {
          findings.add(_finding(
            factor: PositionalFactor.passedPawn,
            says: 'the $colour pawn on ${p.square} is a passed pawn: '
                'no $enemy pawn can block or capture it',
            whenGone:
                'the $colour pawn on ${p.square} is no longer a passed pawn',
            squares: [p.square],
            favorsMover: _favorsMover(color, true, moverColor),
            significance: 5,
          ));
        }
      }

      // Pawn islands: maximal runs of consecutive occupied files.
      final occupiedFiles = byFile.keys.toList()..sort();
      var islands = 1;
      for (var i = 1; i < occupiedFiles.length; i++) {
        if (occupiedFiles[i] != occupiedFiles[i - 1] + 1) islands++;
      }
      if (islands >= 3) {
        findings.add(_finding(
          factor: PositionalFactor.pawnIslands,
          says: "$side's pawns are split into ${countWord(islands)} islands",
          whenGone:
              "$side's pawns are no longer split into ${countWord(islands)} islands",
          squares: pawns.map((p) => p.square).toList(),
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 2,
        ));
      }
    }

    return findings;
  }

  bool _isBackwardPawn(chess.Chess game, _PawnFacts p) {
    final forward = p.color == chess.Color.WHITE ? 1 : -1;
    final enemyColor =
        p.color == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;

    var hasAdjacentPawn = false;
    var hasSupport = false;
    for (final df in [-1, 1]) {
      final nf = p.file + df;
      if (nf < 0 || nf > 7) continue;
      for (var nr = 0; nr < 8; nr++) {
        final piece = game.get(_coordsToSq(nf, nr));
        if (piece == null ||
            piece.type != chess.PieceType.PAWN ||
            piece.color != p.color) continue;
        hasAdjacentPawn = true;
        final atOrBehind =
            p.color == chess.Color.WHITE ? nr <= p.rank : nr >= p.rank;
        if (atOrBehind) hasSupport = true;
      }
    }
    if (!hasAdjacentPawn || hasSupport) return false;

    final frontRank = p.rank + forward;
    if (frontRank < 0 || frontRank > 7) return false;
    // An enemy pawn "controls" frontRank by being able to capture into it —
    // i.e. it sits one more step further along its own forward direction.
    final enemyForward = enemyColor == chess.Color.WHITE ? 1 : -1;
    final enemyRank = frontRank - enemyForward;
    if (enemyRank < 0 || enemyRank > 7) return false;
    for (final df in [-1, 1]) {
      final nf = p.file + df;
      if (nf < 0 || nf > 7) continue;
      final piece = game.get(_coordsToSq(nf, enemyRank));
      if (piece != null &&
          piece.type == chess.PieceType.PAWN &&
          piece.color == enemyColor) {
        return true;
      }
    }
    return false;
  }

  bool _isPassedPawn(chess.Chess game, _PawnFacts p) {
    final enemyColor =
        p.color == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    for (final nf in [p.file - 1, p.file, p.file + 1]) {
      if (nf < 0 || nf > 7) continue;
      for (var nr = 0; nr < 8; nr++) {
        final piece = game.get(_coordsToSq(nf, nr));
        if (piece == null ||
            piece.type != chess.PieceType.PAWN ||
            piece.color != enemyColor) continue;
        final blocksOrCanCapture =
            p.color == chess.Color.WHITE ? nr > p.rank : nr < p.rank;
        if (blocksOrCanCapture) return false;
      }
    }
    return true;
  }

  // =========================================================================
  // 2. OPEN / SEMI-OPEN FILES
  // =========================================================================

  List<PositionalFinding> _fileControlFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    final whitePawnFiles = List.filled(8, 0);
    final blackPawnFiles = List.filled(8, 0);
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final p = game.get(_coordsToSq(f, r));
        if (p == null || p.type != chess.PieceType.PAWN) continue;
        if (p.color == chess.Color.WHITE) {
          whitePawnFiles[f]++;
        } else {
          blackPawnFiles[f]++;
        }
      }
    }

    for (var f = 0; f < 8; f++) {
      final isOpen = whitePawnFiles[f] == 0 && blackPawnFiles[f] == 0;
      final isSemiOpenForWhite =
          whitePawnFiles[f] == 0 && blackPawnFiles[f] > 0;
      final isSemiOpenForBlack =
          blackPawnFiles[f] == 0 && whitePawnFiles[f] > 0;
      if (!isOpen && !isSemiOpenForWhite && !isSemiOpenForBlack) continue;

      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final piece = game.get(sq);
        if (piece == null) continue;
        if (piece.type != chess.PieceType.ROOK &&
            piece.type != chess.PieceType.QUEEN) continue;

        final relevantForThisColor = isOpen ||
            (piece.color == chess.Color.WHITE
                ? isSemiOpenForWhite
                : isSemiOpenForBlack);
        if (!relevantForThisColor) continue;

        final noun = piece.type == chess.PieceType.ROOK ? 'rook' : 'queen';
        final lineDesc = isOpen ? 'open' : 'half-open';
        final piecePhrase = 'the ${_colorAdj(piece.color)} $noun on $sq';
        final fileName = '$lineDesc ${_fileLetter(f)}-file';
        findings.add(_finding(
          factor: isOpen
              ? PositionalFactor.openFile
              : PositionalFactor.semiOpenFile,
          // Standing on the file is what was checked. Nothing here asks
          // whether the piece controls it.
          says: '$piecePhrase stands on the $fileName',
          whenGone: '$piecePhrase no longer stands on the $fileName',
          squares: [sq],
          favorsMover: _favorsMover(piece.color, true, moverColor),
          // Fluid/contested — file control shifts with nearly every trade or
          // pawn push, so it isn't worth auto-narrating on its own.
          significance: 2,
        ));
      }
    }

    return findings;
  }

  // =========================================================================
  // 3. CENTER CONTROL (pawn occupation + pawn attacks on d4/e4/d5/e5)
  // =========================================================================

  List<PositionalFinding> _centerControlFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    const centerSquares = ['d4', 'e4', 'd5', 'e5'];

    var whiteScore = 0;
    var blackScore = 0;

    for (final sq in centerSquares) {
      final piece = game.get(sq);
      if (piece != null && piece.type == chess.PieceType.PAWN) {
        if (piece.color == chess.Color.WHITE) {
          whiteScore += 2;
        } else {
          blackScore += 2;
        }
      }

      final file = sq.codeUnitAt(0) - 97;
      final rank = sq.codeUnitAt(1) - 49;
      for (final df in [-1, 1]) {
        final nf = file + df;
        if (nf < 0 || nf > 7) continue;
        // A white pawn attacks `sq` from one rank below it; a black pawn from one rank above.
        final whiteAttackerSq =
            rank - 1 >= 0 ? _coordsToSq(nf, rank - 1) : null;
        final blackAttackerSq =
            rank + 1 <= 7 ? _coordsToSq(nf, rank + 1) : null;
        if (whiteAttackerSq != null) {
          final p = game.get(whiteAttackerSq);
          if (p != null &&
              p.type == chess.PieceType.PAWN &&
              p.color == chess.Color.WHITE) whiteScore++;
        }
        if (blackAttackerSq != null) {
          final p = game.get(blackAttackerSq);
          if (p != null &&
              p.type == chess.PieceType.PAWN &&
              p.color == chess.Color.BLACK) blackScore++;
        }
      }
    }

    if (whiteScore == blackScore) return const [];

    final leadingColor =
        whiteScore > blackScore ? chess.Color.WHITE : chess.Color.BLACK;
    final margin = (whiteScore - blackScore).abs();
    if (margin < 2) return const [];

    final side = _colorAdjCap(leadingColor);
    return [
      _finding(
        factor: PositionalFactor.centerControl,
        // The score counts pawns only, so the sentence says pawns. No list of
        // the four squares: a voice reads the slashes between them.
        says: "$side's pawns hold more of the centre",
        whenGone: "$side's pawns no longer hold more of the centre",
        squares: centerSquares,
        favorsMover: _favorsMover(leadingColor, true, moverColor),
        // Fluid — the margin shifts with nearly every pawn/piece move.
        significance: 2,
      ),
    ];
  }

  // =========================================================================
  // 4. BISHOP PAIR
  // =========================================================================

  List<PositionalFinding> _bishopPairFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    final bishopSquares = {
      chess.Color.WHITE: <String>[],
      chess.Color.BLACK: <String>[]
    };
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p != null && p.type == chess.PieceType.BISHOP) {
          bishopSquares[p.color]!.add(sq);
        }
      }
    }

    final whiteCount = bishopSquares[chess.Color.WHITE]!.length;
    final blackCount = bishopSquares[chess.Color.BLACK]!.length;

    chess.Color? holder;
    if (whiteCount >= 2 && blackCount < 2) holder = chess.Color.WHITE;
    if (blackCount >= 2 && whiteCount < 2) holder = chess.Color.BLACK;
    if (holder == null) return const [];

    final side = _colorAdjCap(holder);
    return [
      _finding(
        factor: PositionalFactor.bishopPair,
        says: '$side has the bishop pair',
        whenGone: '$side no longer has the bishop pair',
        squares: bishopSquares[holder]!,
        favorsMover: _favorsMover(holder, true, moverColor),
        significance: 5,
      ),
    ];
  }

  // =========================================================================
  // 5. COLOR COMPLEX WEAKNESS
  // =========================================================================

  bool _isLightSquare(int file, int rank) => (file + rank) % 2 == 1;

  List<PositionalFinding> _colorComplexFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    for (final color in [chess.Color.WHITE, chess.Color.BLACK]) {
      var hasLightBishop = false;
      var hasDarkBishop = false;
      var lightPawns = 0;
      var darkPawns = 0;
      final lightPawnSquares = <String>[];
      final darkPawnSquares = <String>[];

      for (var f = 0; f < 8; f++) {
        for (var r = 0; r < 8; r++) {
          final sq = _coordsToSq(f, r);
          final p = game.get(sq);
          if (p == null || p.color != color) continue;
          final isLight = _isLightSquare(f, r);
          if (p.type == chess.PieceType.BISHOP) {
            if (isLight) {
              hasLightBishop = true;
            } else {
              hasDarkBishop = true;
            }
          } else if (p.type == chess.PieceType.PAWN) {
            if (isLight) {
              lightPawns++;
              lightPawnSquares.add(sq);
            } else {
              darkPawns++;
              darkPawnSquares.add(sq);
            }
          }
        }
      }

      // A pawn guards squares of its own colour, so pawns on light squares
      // leave the dark squares to the pieces — and the piece made for them is
      // the dark-squared bishop. Until 13.9.2026 this paired the missing
      // bishop with the pawns' own colour, which is the one complex the pawns
      // themselves cover.
      if (!hasDarkBishop && lightPawns >= 3 && lightPawns >= darkPawns) {
        findings.add(_colorComplex(color,
            missingBishop: 'dark',
            pawnSquares: 'light',
            pawnCount: lightPawns,
            squares: lightPawnSquares,
            moverColor: moverColor));
      }
      if (!hasLightBishop && darkPawns >= 3 && darkPawns >= lightPawns) {
        findings.add(_colorComplex(color,
            missingBishop: 'light',
            pawnSquares: 'dark',
            pawnCount: darkPawns,
            squares: darkPawnSquares,
            moverColor: moverColor));
      }
    }

    return findings;
  }

  PositionalFinding _colorComplex(
    chess.Color color, {
    required String missingBishop,
    required String pawnSquares,
    required int pawnCount,
    required List<String> squares,
    required chess.Color moverColor,
  }) {
    final side = _colorAdjCap(color);
    return _finding(
      factor: PositionalFactor.colorComplexWeakness,
      says: '$side has no $missingBishop-squared bishop, and '
          '${countWord(pawnCount)} of its pawns stand on $pawnSquares squares, '
          'so the $missingBishop squares are weak',
      whenGone: "$side's $missingBishop squares are no longer weak",
      squares: squares,
      favorsMover: _favorsMover(color, false, moverColor),
      significance: 4,
    );
  }

  // =========================================================================
  // 6. KNIGHT OUTPOST
  // =========================================================================

  List<PositionalFinding> _knightOutpostFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p == null || p.type != chess.PieceType.KNIGHT) continue;
        if (!_isKnightOutpost(game, f, r, p.color)) continue;

        final knight = 'the ${_colorAdj(p.color)} knight on $sq';
        findings.add(_finding(
          factor: PositionalFactor.knightOutpost,
          says: '$knight stands on an outpost: '
              'no ${_colorAdj(_other(p.color))} pawn can drive it away',
          whenGone: '$knight is no longer on an outpost',
          squares: [sq],
          favorsMover: _favorsMover(p.color, true, moverColor),
          significance: 4,
        ));
      }
    }

    return findings;
  }

  bool _isKnightOutpost(chess.Chess game, int f, int r, chess.Color color) {
    if (color == chess.Color.WHITE && r < 4) return false;
    if (color == chess.Color.BLACK && r > 3) return false;

    final forward = color == chess.Color.WHITE ? 1 : -1;
    var defended = false;
    for (final df in [-1, 1]) {
      final nf = f + df;
      final nr = r - forward;
      if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
      final piece = game.get(_coordsToSq(nf, nr));
      if (piece != null &&
          piece.type == chess.PieceType.PAWN &&
          piece.color == color) defended = true;
    }
    if (!defended) return false;

    final enemyColor =
        color == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    for (final df in [-1, 1]) {
      final nf = f + df;
      if (nf < 0 || nf > 7) continue;
      for (var nr = 0; nr < 8; nr++) {
        final piece = game.get(_coordsToSq(nf, nr));
        if (piece == null ||
            piece.type != chess.PieceType.PAWN ||
            piece.color != enemyColor) continue;
        final stillAThreat = color == chess.Color.WHITE ? nr > r : nr < r;
        if (stillAThreat) return false;
      }
    }
    return true;
  }

  // =========================================================================
  // 7. KING SAFETY (simple binary signals — not a composite score)
  // =========================================================================

  List<PositionalFinding> _kingSafetyFindings(chess.Chess game,
      {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    for (final color in [chess.Color.WHITE, chess.Color.BLACK]) {
      final kingSq = _findKingSquare(game, color);
      if (kingSq == null) continue;
      final kf = kingSq.codeUnitAt(0) - 97;
      final kr = kingSq.codeUnitAt(1) - 49;
      final colour = _colorAdj(color);

      // Only judge the pawn shield while the king is still on its home rank —
      // a king out in the open in an endgame or a hunt is a different (and
      // already-obvious) kind of danger, not a "damaged shield" finding.
      final onHomeRank = color == chess.Color.WHITE ? kr <= 1 : kr >= 6;
      if (onHomeRank) {
        var missingShieldFiles = 0;
        for (final f in [kf - 1, kf, kf + 1]) {
          if (f < 0 || f > 7) continue;
          var hasPawnOnFile = false;
          for (var r = 0; r < 8; r++) {
            final p = game.get(_coordsToSq(f, r));
            if (p != null &&
                p.type == chess.PieceType.PAWN &&
                p.color == color) {
              hasPawnOnFile = true;
              break;
            }
          }
          if (!hasPawnOnFile) missingShieldFiles++;
        }
        if (missingShieldFiles >= 2) {
          findings.add(_finding(
            factor: PositionalFactor.kingShield,
            says: 'the $colour king on $kingSq has lost its pawn shield',
            // No square: the finding is keyed to the square the king stood
            // on, so it also ends when the king steps off it.
            whenGone: 'the $colour king is no longer without a pawn shield',
            squares: [kingSq],
            favorsMover: _favorsMover(color, false, moverColor),
            significance: 5,
          ));
        }
      }

      // Open file within one file of the king, regardless of rank.
      for (final f in [kf - 1, kf, kf + 1]) {
        if (f < 0 || f > 7) continue;
        var hasAnyPawn = false;
        for (var r = 0; r < 8; r++) {
          final p = game.get(_coordsToSq(f, r));
          if (p != null && p.type == chess.PieceType.PAWN) {
            hasAnyPawn = true;
            break;
          }
        }
        if (hasAnyPawn) continue;

        final file = '${_fileLetter(f)}-file';
        findings.add(_finding(
          factor: PositionalFactor.kingShield,
          says: 'the $file beside the $colour king on $kingSq is open',
          whenGone: 'the $file beside the $colour king is no longer open',
          squares: [kingSq],
          favorsMover: _favorsMover(color, false, moverColor),
          // Fluid — retriggers on almost every step while a king is running,
          // since it's keyed to whichever square it currently stands on.
          // The pawn-shield-loss finding above already tells that story once.
          significance: 2,
        ));
        break; // one mention is enough even if more than one file qualifies
      }
    }

    return findings;
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  String? _findKingSquare(chess.Chess game, chess.Color color) {
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p != null && p.type == chess.PieceType.KING && p.color == color)
          return sq;
      }
    }
    return null;
  }

  String _coordsToSq(int fileIdx, int rankIdx) {
    final f = String.fromCharCode(97 + fileIdx);
    final r = String.fromCharCode(49 + rankIdx);
    return '$f$r';
  }

  String _fileLetter(int file) => String.fromCharCode(97 + file);

  chess.Color _other(chess.Color color) =>
      color == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;

  String _colorAdj(chess.Color color) =>
      color == chess.Color.WHITE ? 'white' : 'black';

  /// Sentence-initial form. English needs no genitive, so the third helper
  /// the Serbian phrasing required is gone rather than translated.
  String _colorAdjCap(chess.Color color) =>
      color == chess.Color.WHITE ? 'White' : 'Black';
}
