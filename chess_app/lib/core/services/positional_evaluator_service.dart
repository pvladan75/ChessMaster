import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/models/positional_factor.dart';

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
      final moverColor = defenderColor == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
      return PositionalResult(findings: _buildFindings(game, moverColor: moverColor));
    } catch (_) {
      return PositionalResult.empty();
    }
  }

  /// Explains what a move changed positionally, by diffing the position
  /// before and after it — mirrors [TacticalMotifDetector.explainMove].
  PositionalMoveDiff explainMove({required String beforeFen, required String afterFen}) {
    try {
      final afterGame = chess.Chess.fromFEN(afterFen);
      final defenderColor = afterGame.turn;
      final moverColor = defenderColor == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;

      final afterFindings = _buildFindings(afterGame, moverColor: moverColor);
      final beforeGame = chess.Chess.fromFEN(beforeFen);
      final beforeFindings = _buildFindings(beforeGame, moverColor: moverColor);

      final beforeKeys = beforeFindings.map((f) => f.diffKey).toSet();
      final afterKeys = afterFindings.map((f) => f.diffKey).toSet();

      final created = afterFindings.where((f) => !beforeKeys.contains(f.diffKey)).toList();
      final resolved = beforeFindings.where((f) => !afterKeys.contains(f.diffKey)).toList();

      return PositionalMoveDiff(created: created, resolved: resolved);
    } catch (_) {
      return const PositionalMoveDiff(created: [], resolved: []);
    }
  }

  String describeMoveDiff(PositionalMoveDiff diff) {
    final created = _mostNarratable(diff.created, _maxCreatedInComment);
    final resolved = _mostNarratable(diff.resolved.where((f) => !f.favorsMover).toList(), _maxResolvedInComment);

    final parts = <String>[
      ...created.map(_formatFinding),
      ...resolved.map((f) => _formatFinding(f, resolved: true)),
    ];
    return parts.join(' | ');
  }

  /// Every candidate comment line, unfiltered/uncapped — for a manual
  /// checklist UI, mirrors [TacticalMotifDetector.candidateCommentLines].
  List<String> candidateCommentLines(PositionalMoveDiff diff) {
    return [
      ...diff.created.map(_formatFinding),
      ...diff.resolved.where((f) => !f.favorsMover).map((f) => _formatFinding(f, resolved: true)),
    ];
  }

  String _formatFinding(PositionalFinding f, {bool resolved = false}) {
    if (resolved) return 'Rešeno — ${f.description}';
    return f.favorsMover ? f.description : 'Pažnja — ${f.description}';
  }

  List<PositionalFinding> _mostNarratable(List<PositionalFinding> findings, int max) {
    if (findings.isEmpty) return const [];
    final sorted = [...findings]..sort((a, b) => b.significance.compareTo(a.significance));
    final aboveBar = sorted.where((f) => f.significance >= _minSignificanceForComment);
    final pool = aboveBar.isNotEmpty ? aboveBar : sorted.take(1);
    return pool.take(max).toList();
  }

  // =========================================================================
  // ORCHESTRATION
  // =========================================================================

  List<PositionalFinding> _buildFindings(chess.Chess game, {required chess.Color moverColor}) {
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
  bool _favorsMover(chess.Color color, bool isStrength, chess.Color moverColor) {
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

  List<PositionalFinding> _pawnStructureFindings(chess.Chess game, {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    for (final color in [chess.Color.WHITE, chess.Color.BLACK]) {
      final pawns = _pawnsOf(game, color);
      if (pawns.isEmpty) continue;

      final byFile = <int, List<_PawnFacts>>{};
      for (final p in pawns) {
        byFile.putIfAbsent(p.file, () => []).add(p);
      }

      // Doubled pawns: 2+ of this color's pawns share a file.
      byFile.forEach((file, filePawns) {
        if (filePawns.length < 2) return;
        final squares = filePawns.map((p) => p.square).toList()..sort();
        findings.add(PositionalFinding(
          factors: const [PositionalFactor.doubledPawn],
          description:
              'Udvojeni pešaci: ${_colorAdj(color)} ima ${filePawns.length} pešaka na ${_fileLetter(file)}-liniji (${squares.join(', ')})',
          affectedSquares: squares,
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 2,
        ));
      });

      // Isolated pawns: no same-color pawn on an adjacent file, regardless of rank.
      byFile.forEach((file, filePawns) {
        final hasNeighbor = byFile.containsKey(file - 1) || byFile.containsKey(file + 1);
        if (hasNeighbor) return;
        final squares = filePawns.map((p) => p.square).toList()..sort();
        findings.add(PositionalFinding(
          factors: const [PositionalFactor.isolatedPawn],
          description: 'Izolovani pešak: ${_colorAdj(color)} pešak na ${_fileLetter(file)}-liniji (${squares.join(', ')}) nema susede da ga brane',
          affectedSquares: squares,
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 3,
        ));
      });

      // Backward / passed are per-pawn.
      for (final p in pawns) {
        if (_isBackwardPawn(game, p)) {
          findings.add(PositionalFinding(
            factors: const [PositionalFactor.backwardPawn],
            description: 'Zaostali pešak: ${_colorAdj(color)} pešak na ${p.square} je zaostao za susedima i ne sme bezbedno da napreduje',
            affectedSquares: [p.square],
            favorsMover: _favorsMover(color, false, moverColor),
            significance: 3,
          ));
        }
        if (_isPassedPawn(game, p)) {
          findings.add(PositionalFinding(
            factors: const [PositionalFactor.passedPawn],
            description: 'Prolazni pešak: ${_colorAdj(color)} pešak na ${p.square} nema protivničke pešake na putu do promocije',
            affectedSquares: [p.square],
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
        findings.add(PositionalFinding(
          factors: const [PositionalFactor.pawnIslands],
          description: '${_colorAdjCap(color)} pešačka struktura je razbijena u $islands ostrva',
          affectedSquares: pawns.map((p) => p.square).toList(),
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 2,
        ));
      }
    }

    return findings;
  }

  bool _isBackwardPawn(chess.Chess game, _PawnFacts p) {
    final forward = p.color == chess.Color.WHITE ? 1 : -1;
    final enemyColor = p.color == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;

    var hasAdjacentPawn = false;
    var hasSupport = false;
    for (final df in [-1, 1]) {
      final nf = p.file + df;
      if (nf < 0 || nf > 7) continue;
      for (var nr = 0; nr < 8; nr++) {
        final piece = game.get(_coordsToSq(nf, nr));
        if (piece == null || piece.type != chess.PieceType.PAWN || piece.color != p.color) continue;
        hasAdjacentPawn = true;
        final atOrBehind = p.color == chess.Color.WHITE ? nr <= p.rank : nr >= p.rank;
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
      if (piece != null && piece.type == chess.PieceType.PAWN && piece.color == enemyColor) {
        return true;
      }
    }
    return false;
  }

  bool _isPassedPawn(chess.Chess game, _PawnFacts p) {
    final enemyColor = p.color == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    for (final nf in [p.file - 1, p.file, p.file + 1]) {
      if (nf < 0 || nf > 7) continue;
      for (var nr = 0; nr < 8; nr++) {
        final piece = game.get(_coordsToSq(nf, nr));
        if (piece == null || piece.type != chess.PieceType.PAWN || piece.color != enemyColor) continue;
        final blocksOrCanCapture = p.color == chess.Color.WHITE ? nr > p.rank : nr < p.rank;
        if (blocksOrCanCapture) return false;
      }
    }
    return true;
  }

  // =========================================================================
  // 2. OPEN / SEMI-OPEN FILES
  // =========================================================================

  List<PositionalFinding> _fileControlFindings(chess.Chess game, {required chess.Color moverColor}) {
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
      final isSemiOpenForWhite = whitePawnFiles[f] == 0 && blackPawnFiles[f] > 0;
      final isSemiOpenForBlack = blackPawnFiles[f] == 0 && whitePawnFiles[f] > 0;
      if (!isOpen && !isSemiOpenForWhite && !isSemiOpenForBlack) continue;

      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final piece = game.get(sq);
        if (piece == null) continue;
        if (piece.type != chess.PieceType.ROOK && piece.type != chess.PieceType.QUEEN) continue;

        final relevantForThisColor = isOpen || (piece.color == chess.Color.WHITE ? isSemiOpenForWhite : isSemiOpenForBlack);
        if (!relevantForThisColor) continue;

        final noun = piece.type == chess.PieceType.ROOK ? 'top' : 'dama';
        final lineDesc = isOpen ? 'otvorenu' : 'poluotvorenu';
        findings.add(PositionalFinding(
          factors: [isOpen ? PositionalFactor.openFile : PositionalFactor.semiOpenFile],
          description: '${_colorAdjCap(piece.color)} $noun na $sq kontroliše $lineDesc ${_fileLetter(f)}-liniju',
          affectedSquares: [sq],
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

  List<PositionalFinding> _centerControlFindings(chess.Chess game, {required chess.Color moverColor}) {
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
        final whiteAttackerSq = rank - 1 >= 0 ? _coordsToSq(nf, rank - 1) : null;
        final blackAttackerSq = rank + 1 <= 7 ? _coordsToSq(nf, rank + 1) : null;
        if (whiteAttackerSq != null) {
          final p = game.get(whiteAttackerSq);
          if (p != null && p.type == chess.PieceType.PAWN && p.color == chess.Color.WHITE) whiteScore++;
        }
        if (blackAttackerSq != null) {
          final p = game.get(blackAttackerSq);
          if (p != null && p.type == chess.PieceType.PAWN && p.color == chess.Color.BLACK) blackScore++;
        }
      }
    }

    if (whiteScore == blackScore) return const [];

    final leadingColor = whiteScore > blackScore ? chess.Color.WHITE : chess.Color.BLACK;
    final margin = (whiteScore - blackScore).abs();
    if (margin < 2) return const [];

    return [
      PositionalFinding(
        factors: const [PositionalFactor.centerControl],
        description: '${_colorAdjCap(leadingColor)} ima veću kontrolu centra (d4/e4/d5/e5)',
        affectedSquares: centerSquares,
        favorsMover: _favorsMover(leadingColor, true, moverColor),
        // Fluid — the margin shifts with nearly every pawn/piece move.
        significance: 2,
      ),
    ];
  }

  // =========================================================================
  // 4. BISHOP PAIR
  // =========================================================================

  List<PositionalFinding> _bishopPairFindings(chess.Chess game, {required chess.Color moverColor}) {
    final bishopSquares = {chess.Color.WHITE: <String>[], chess.Color.BLACK: <String>[]};
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

    if (whiteCount >= 2 && blackCount < 2) {
      return [
        PositionalFinding(
          factors: const [PositionalFactor.bishopPair],
          description: 'Beli ima prednost lovačkog para',
          affectedSquares: bishopSquares[chess.Color.WHITE]!,
          favorsMover: _favorsMover(chess.Color.WHITE, true, moverColor),
          significance: 5,
        ),
      ];
    }
    if (blackCount >= 2 && whiteCount < 2) {
      return [
        PositionalFinding(
          factors: const [PositionalFactor.bishopPair],
          description: 'Crni ima prednost lovačkog para',
          affectedSquares: bishopSquares[chess.Color.BLACK]!,
          favorsMover: _favorsMover(chess.Color.BLACK, true, moverColor),
          significance: 5,
        ),
      ];
    }
    return const [];
  }

  // =========================================================================
  // 5. COLOR COMPLEX WEAKNESS
  // =========================================================================

  bool _isLightSquare(int file, int rank) => (file + rank) % 2 == 1;

  List<PositionalFinding> _colorComplexFindings(chess.Chess game, {required chess.Color moverColor}) {
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

      if (!hasLightBishop && lightPawns >= 3 && lightPawns >= darkPawns) {
        findings.add(PositionalFinding(
          factors: const [PositionalFactor.colorComplexWeakness],
          description: '${_colorAdjCap(color)} nema svetlopoljnog lovca, a $lightPawns pešaka je fiksirano na svetlim poljima — slab kompleks',
          affectedSquares: lightPawnSquares,
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 4,
        ));
      }
      if (!hasDarkBishop && darkPawns >= 3 && darkPawns >= lightPawns) {
        findings.add(PositionalFinding(
          factors: const [PositionalFactor.colorComplexWeakness],
          description: '${_colorAdjCap(color)} nema crnopoljnog lovca, a $darkPawns pešaka je fiksirano na tamnim poljima — slab kompleks',
          affectedSquares: darkPawnSquares,
          favorsMover: _favorsMover(color, false, moverColor),
          significance: 4,
        ));
      }
    }

    return findings;
  }

  // =========================================================================
  // 6. KNIGHT OUTPOST
  // =========================================================================

  List<PositionalFinding> _knightOutpostFindings(chess.Chess game, {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p == null || p.type != chess.PieceType.KNIGHT) continue;
        if (!_isKnightOutpost(game, f, r, p.color)) continue;

        findings.add(PositionalFinding(
          factors: const [PositionalFactor.knightOutpost],
          description: '${_colorAdjCap(p.color)} skakač na $sq je na trajnom uporištu — protivnički pešaci ga ne mogu oterati',
          affectedSquares: [sq],
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
      if (piece != null && piece.type == chess.PieceType.PAWN && piece.color == color) defended = true;
    }
    if (!defended) return false;

    final enemyColor = color == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    for (final df in [-1, 1]) {
      final nf = f + df;
      if (nf < 0 || nf > 7) continue;
      for (var nr = 0; nr < 8; nr++) {
        final piece = game.get(_coordsToSq(nf, nr));
        if (piece == null || piece.type != chess.PieceType.PAWN || piece.color != enemyColor) continue;
        final stillAThreat = color == chess.Color.WHITE ? nr > r : nr < r;
        if (stillAThreat) return false;
      }
    }
    return true;
  }

  // =========================================================================
  // 7. KING SAFETY (simple binary signals — not a composite score)
  // =========================================================================

  List<PositionalFinding> _kingSafetyFindings(chess.Chess game, {required chess.Color moverColor}) {
    final findings = <PositionalFinding>[];

    for (final color in [chess.Color.WHITE, chess.Color.BLACK]) {
      final kingSq = _findKingSquare(game, color);
      if (kingSq == null) continue;
      final kf = kingSq.codeUnitAt(0) - 97;
      final kr = kingSq.codeUnitAt(1) - 49;

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
            if (p != null && p.type == chess.PieceType.PAWN && p.color == color) {
              hasPawnOnFile = true;
              break;
            }
          }
          if (!hasPawnOnFile) missingShieldFiles++;
        }
        if (missingShieldFiles >= 2) {
          findings.add(PositionalFinding(
            factors: const [PositionalFactor.kingShield],
            description: '${_colorAdjCap(color)} kralj na $kingSq je ostao bez pešačkog štita',
            affectedSquares: [kingSq],
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

        findings.add(PositionalFinding(
          factors: const [PositionalFactor.kingShield],
          description: '${_fileLetterCap(f)}-linija pored ${_colorAdjGen(color)} kralja na $kingSq je otvorena',
          affectedSquares: [kingSq],
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
        if (p != null && p.type == chess.PieceType.KING && p.color == color) return sq;
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

  String _fileLetterCap(int file) => String.fromCharCode(65 + file);

  String _colorAdj(chess.Color color) => color == chess.Color.WHITE ? 'beli' : 'crni';

  String _colorAdjCap(chess.Color color) => color == chess.Color.WHITE ? 'Beli' : 'Crni';

  String _colorAdjGen(chess.Color color) => color == chess.Color.WHITE ? 'belog' : 'crnog';
}
