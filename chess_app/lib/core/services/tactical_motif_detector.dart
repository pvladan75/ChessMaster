import 'package:chess_app/core/services/finding_sentences.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/models/tactical_motif.dart';

/// One instance of a motif as a scan finds it, before it is told whose move it
/// favours: the squares to draw, what is true, and what is said once it stops
/// being true. One pin is one of these, so two pins are two findings — and two
/// sentences — rather than one clause joining both.
class _Found {
  const _Found(this.squares, this.clause, this.goneClause,
      {required this.stake});

  final List<String> squares;
  final String clause;
  final String goneClause;

  /// The squares of the pieces this finding can win or cost — what its
  /// significance is the value of. Never the piece doing the attacking: until
  /// 13.9.2026 significance was the most valuable piece on any of [squares],
  /// so a queen pinning a pawn counted as nine pawns and crowded a hanging
  /// knight out of the comment. Required, so a new motif has to say.
  final List<String> stake;
}

// =============================================================================
// PHRASING HELPERS — a piece is named by its colour, its kind and its square
// ("the white knight on f5"), so a sentence can say "the white knight on f5
// attacks the black rook on d7" instead of a bare "piece". The Serbian this
// replaced needed a grammatical gender, a nominative and an accusative for
// every noun, and three plural forms for a count; English needs none of that,
// and the machinery for it is gone rather than translated.
// =============================================================================

String _pieceName(chess.PieceType type) {
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

String _colorAdj(chess.Color color) =>
    color == chess.Color.WHITE ? 'white' : 'black';

/// Names the pieces of one sentence. A side's colour is said the first time
/// one of its pieces is named and not again — "the white bishop on b5 pins the
/// black knight on c6 to the king on e8" — so a fork of three pieces does not
/// say "black" three times. A fresh namer for every sentence.
class _Namer {
  final _named = <chess.Color>{};

  String call(chess.Piece piece, String square) {
    final colour = _named.add(piece.color) ? '${_colorAdj(piece.color)} ' : '';
    return 'the $colour${_pieceName(piece.type)} on $square';
  }
}

/// Universal, pure stateless service for detecting tactical motifs in a
/// position (`detect`) or explaining what a specific move changed
/// (`explainMove`) — meant to back engine-eval displays and auto-generated
/// move-tree comments.
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
      final defenderColor = game.turn;
      final moverColor = defenderColor == chess.Color.WHITE
          ? chess.Color.BLACK
          : chess.Color.WHITE;

      final findings = _buildFindings(
        game,
        moverColor: moverColor,
        defenderColor: defenderColor,
        lastMoveUci: lastMoveUci,
        evalText: evalText,
        mateIn: mateIn,
        evalScore: evalScore,
      );

      return MotifResult(findings: findings);
    } catch (_) {
      return MotifResult.empty();
    }
  }

  /// Explains a single move by diffing the tactical findings before and
  /// after it was played: `created` is what the move introduced (e.g. it
  /// hung a piece, or it forked two pieces), `resolved` is what it fixed
  /// (e.g. it escaped a pin). Findings that hold in both positions — a
  /// pre-existing problem the move didn't address — appear in neither list,
  /// so callers only surface what this specific move actually changed.
  ///
  /// [beforeFen] is the position before the move, [afterFen] the position
  /// after it, and [lastMoveUci] the move itself (e.g. "e2e4"). Pass
  /// [evalText]/[mateIn]/[evalScore] from the engine's evaluation of
  /// [afterFen] to feed the mate-threat check.
  MoveMotifDiff explainMove({
    required String beforeFen,
    required String afterFen,
    required String lastMoveUci,
    String? evalText,
    int? mateIn,
    double? evalScore,
  }) {
    try {
      final afterGame = chess.Chess.fromFEN(afterFen);
      final defenderColor = afterGame.turn;
      final moverColor = defenderColor == chess.Color.WHITE
          ? chess.Color.BLACK
          : chess.Color.WHITE;

      final afterFindings = _buildFindings(
        afterGame,
        moverColor: moverColor,
        defenderColor: defenderColor,
        lastMoveUci: lastMoveUci,
        evalText: evalText,
        mateIn: mateIn,
        evalScore: evalScore,
      );

      final beforeGame = chess.Chess.fromFEN(beforeFen);
      // Same color roles as the after-analysis (not derived from beforeGame's
      // own side to move) so the two finding sets are directly comparable.
      final beforeFindings = _buildFindings(
        beforeGame,
        moverColor: moverColor,
        defenderColor: defenderColor,
      );

      // A finding from before the move is keyed as its squares stand after
      // it, so a piece that moves keeps its finding (finding_identity.dart).
      final beforeKeys =
          beforeFindings.map((f) => f.diffKeyAcross(lastMoveUci)).toSet();
      final afterKeys = afterFindings.map((f) => f.diffKey).toSet();

      final created =
          afterFindings.where((f) => !beforeKeys.contains(f.diffKey)).toList();
      final resolved = beforeFindings
          .where((f) => !afterKeys.contains(f.diffKeyAcross(lastMoveUci)))
          .toList();

      return MoveMotifDiff(created: created, resolved: resolved);
    } catch (_) {
      return const MoveMotifDiff(created: [], resolved: []);
    }
  }

  /// Findings worth mentioning on their own — knight/bishop value or above
  /// (matches [_pieceValue]). A hanging pawn isn't newsworthy in the same
  /// breath as a king hunt or a hanging queen, so on a busy move it's
  /// dropped rather than crowding out what actually matters.
  static const int _minSignificanceForComment = 3;

  /// Caps on how many findings make it into one move's comment — even among
  /// significant findings, six sentences in a row isn't a readable comment.
  static const int _maxCreatedInComment = 3;
  static const int _maxResolvedInComment = 2;

  /// Renders a [MoveMotifDiff] as a move comment: what the move made true, in
  /// [MotifFinding.description]s, then what it ended, in
  /// [MotifFinding.goneDescription]s — sentences joined by a space.
  ///
  /// No prefix marks a threat against the side who moved: the sentence names
  /// whose pieces are in it, and [MotifFinding.favorsMover] keeps the polarity
  /// as data. „Watch out —" and „Resolved —" were copied into tutorials as
  /// words by every model that read them, and read out by the voice.
  ///
  /// A resolved threat the mover *had* against the opponent isn't worth
  /// narrating on its own, so it's left out. Low-significance findings (a lone
  /// hanging pawn) are dropped whenever something more significant is also
  /// present, and each list is capped so the comment stays readable. Returns
  /// '' when the move changed nothing tactically worth narrating.
  String describeMoveDiff(MoveMotifDiff diff) {
    final created = _mostNarratable(diff.created, _maxCreatedInComment);
    final resolved = _mostNarratable(
        diff.resolved.where((f) => !f.favorsMover).toList(),
        _maxResolvedInComment);

    return joinSentences([
      ...created.map((f) => f.description),
      ...resolved.map((f) => f.goneDescription),
    ]);
  }

  /// Every candidate comment line for a move — the same sentences
  /// [describeMoveDiff] uses, but unfiltered and uncapped, for UIs that let a
  /// human pick which findings to keep (e.g. a checklist) instead of applying
  /// the automatic significance filter.
  List<String> candidateCommentLines(MoveMotifDiff diff) {
    return [
      ...diff.created.map((f) => f.description),
      ...diff.resolved
          .where((f) => !f.favorsMover)
          .map((f) => f.goneDescription),
    ];
  }

  /// Highest-significance findings first, capped at [max]. Findings below
  /// [_minSignificanceForComment] are dropped as long as at least one
  /// findings clears the bar; if none do, the single best one is kept
  /// anyway so a pawn-only moment still gets a comment instead of going
  /// silent.
  List<MotifFinding> _mostNarratable(List<MotifFinding> findings, int max) {
    if (findings.isEmpty) return const [];

    final sorted = [...findings]
      ..sort((a, b) => b.significance.compareTo(a.significance));
    final aboveBar =
        sorted.where((f) => f.significance >= _minSignificanceForComment);
    final pool = aboveBar.isNotEmpty ? aboveBar : sorted.take(1);
    return pool.take(max).toList();
  }

  /// Builds findings for both directions: threats the mover's move created
  /// against the opponent (good for the move), and threats it exposed the
  /// mover to instead (bad for the move — e.g. it hung a piece or walked
  /// into a fork). See [MotifFinding.favorsMover].
  List<MotifFinding> _buildFindings(
    chess.Chess game, {
    required chess.Color moverColor,
    required chess.Color defenderColor,
    String? lastMoveUci,
    String? evalText,
    int? mateIn,
    double? evalScore,
  }) {
    final moverThreats = _buildDirectionalFindings(
      game,
      attackerColor: moverColor,
      targetColor: defenderColor,
      favorsMover: true,
      lastMoveUci: lastMoveUci,
      evalText: evalText,
      mateIn: mateIn,
      evalScore: evalScore,
      includeDiscovered: true,
    );

    // Mate-threat is evaluated in both directions now — `_detectMateThreat`
    // checks which color the eval/mateIn signal actually says is mating, so
    // passing the same signal into the reverse call correctly produces a
    // favorsMover=false finding when it's the mover who's getting mated.
    // Discovered-attack stays forward-only: it's inherently about the piece
    // that just vacated `lastMoveUci`'s origin square.
    final moverExposure = _buildDirectionalFindings(
      game,
      attackerColor: defenderColor,
      targetColor: moverColor,
      favorsMover: false,
      lastMoveUci: null,
      evalText: evalText,
      mateIn: mateIn,
      evalScore: evalScore,
      includeDiscovered: false,
    );

    return [...moverThreats, ...moverExposure];
  }

  List<MotifFinding> _buildDirectionalFindings(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
    required bool favorsMover,
    required bool includeDiscovered,
    String? lastMoveUci,
    String? evalText,
    int? mateIn,
    double? evalScore,
  }) {
    MotifFinding finding(
            List<TacticalMotif> motifs, _Found found, int significance) =>
        MotifFinding(
          motifs: motifs,
          description: sentence(found.clause),
          goneDescription: sentence(found.goneClause),
          affectedSquares: found.squares,
          favorsMover: favorsMover,
          significance: significance,
        );
    int worth(_Found found) => _significanceOf(game, found.stake);
    final kingValue = _pieceValue(chess.PieceType.KING);

    final hanging = _detectHangingPieces(game,
        targetColor: targetColor, attackerColor: attackerColor);
    final mate = _detectMateThreat(
      game,
      evalText: evalText,
      mateIn: mateIn,
      evalScore: evalScore,
      moverColor: attackerColor,
      defenderColor: targetColor,
    );

    final findings = <MotifFinding>[];

    // Combined Double Attack: Mate Threat + Piece Attack. Not on a board that
    // is already mate, where there is nothing left to be a threat.
    if (mate != null && hanging.isNotEmpty && !game.in_checkmate) {
      findings.add(finding(
        const [
          TacticalMotif.mateThreatAndPieceAttack,
          TacticalMotif.doubleAttack,
          TacticalMotif.mateThreat,
          TacticalMotif.hangingPiece,
        ],
        _Found(
          {for (final h in hanging) ...h.squares, ...mate.squares}.toList(),
          'two threats at once: ${mate.clause}, and '
              '${joinAnd([for (final h in hanging) h.clause])}',
          'the double attack on the ${_colorAdj(targetColor)} king is over',
          stake: const [],
        ),
        kingValue,
      ));
    } else {
      for (final h in hanging) {
        findings.add(finding(const [TacticalMotif.hangingPiece], h, worth(h)));
      }
      if (mate != null) {
        findings
            .add(finding(const [TacticalMotif.mateThreat], mate, kingValue));
      }
    }

    for (final fork in _detectForks(game,
        attackerColor: attackerColor,
        targetColor: targetColor,
        lastMoveUci: lastMoveUci)) {
      findings.add(finding(
          const [TacticalMotif.fork, TacticalMotif.doubleAttack],
          fork,
          worth(fork)));
    }

    final pinSkewer = _detectPinsAndSkewers(game,
        attackerColor: attackerColor, targetColor: targetColor);
    for (final pin in pinSkewer.pins) {
      findings.add(finding(const [TacticalMotif.pin], pin, worth(pin)));
    }
    for (final skewer in pinSkewer.skewers) {
      findings
          .add(finding(const [TacticalMotif.skewer], skewer, worth(skewer)));
    }

    if (includeDiscovered) {
      for (final discovered in _detectDiscoveredAttacks(game,
          attackerColor: attackerColor,
          targetColor: targetColor,
          lastMoveUci: lastMoveUci)) {
        findings.add(finding(const [TacticalMotif.discoveredAttack], discovered,
            worth(discovered)));
      }
    }

    for (final overload in _detectOverloading(game,
        attackerColor: attackerColor, targetColor: targetColor)) {
      findings.add(finding(
          const [TacticalMotif.overloading], overload, worth(overload)));
    }

    for (final deflection in _detectDeflection(game,
        attackerColor: attackerColor, targetColor: targetColor)) {
      findings.add(finding(
          const [TacticalMotif.deflection], deflection, worth(deflection)));
    }

    return findings;
  }

  // =========================================================================
  // 1. FORK
  // =========================================================================

  List<_Found> _detectForks(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
    String? lastMoveUci,
  }) {
    // Destination of last move is prime suspect for fork
    String? moveDest;
    if (lastMoveUci != null && lastMoveUci.length >= 4) {
      moveDest = lastMoveUci.substring(2, 4);
    }

    final found = <_Found>[];

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = _coordsToSq(f, r);
        final p = game.get(sq);
        if (p == null || p.color != attackerColor) continue;

        // If lastMoveUci is specified, prioritize checking that piece first
        if (moveDest != null && sq != moveDest) continue;

        final targets = _getAttackedOpponentSquares(game, sq, p, targetColor);
        if (targets.length < 2) continue;

        // A target counts only when the fork can win it: the king, whose
        // check forces the reply; a piece worth more than the forking piece;
        // or a piece nobody defends. A defended pawn is attacked, not forked —
        // counting every attacked piece turned a queen's fork of two loose
        // rooks into „attacks five black pieces", three of them defended pawns,
        // and made check plus a defended pawn a fork.
        final counted = [
          for (final t in targets)
            if (_forkCanWin(game, p, t, targetColor)) t
        ];
        if (counted.length < 2) continue;

        final namer = _Namer();
        final forker = namer(p, sq);
        final named = [
          for (final t in _mostValuableFirst(game, counted))
            namer(game.get(t)!, t)
        ];
        found.add(_Found(
          [sq, ...counted],
          '$forker forks ${joinAnd(named)}',
          'the fork by ${_Namer()(p, sq)} is over',
          stake: counted,
        ));
      }
    }

    return found;
  }

  // =========================================================================
  // 2. PIN & SKEWER
  // =========================================================================

  ({List<_Found> pins, List<_Found> skewers}) _detectPinsAndSkewers(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
  }) {
    final pins = <_Found>[];
    final skewers = <_Found>[];

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
        if (p.type != chess.PieceType.BISHOP &&
            p.type != chess.PieceType.ROOK &&
            p.type != chess.PieceType.QUEEN) {
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
          if (firstPiece == null ||
              secondPiece == null ||
              firstPiece.color != targetColor ||
              secondPiece.color != targetColor) {
            continue;
          }
          final front = firstSq!;
          final back = secondSq!;
          final val1 = _pieceValue(firstPiece.type);
          final val2 = _pieceValue(secondPiece.type);
          final attackerValue = _pieceValue(p.type);
          final namer = _Namer();

          // PIN: 2nd piece is King or higher value than 1st piece — and the
          // piece behind is one the pinned piece cannot leave: something worth
          // more than the pinning piece (the king always is), or something
          // nothing else defends. A pawn in front of a knight the rook holds,
          // pinned by a bishop, is an even trade on offer and not a pin.
          if (secondPiece.type == chess.PieceType.KING || val2 > val1) {
            final behindCannotBeLeft = val2 > attackerValue ||
                _undefended(game, back, targetColor, besides: front);
            if (behindCannotBeLeft) {
              pins.add(_Found(
                [attackerSq, front, back],
                '${namer(p, attackerSq)} pins ${namer(firstPiece, front)} '
                    'to ${namer(secondPiece, back)}',
                '${_Namer()(firstPiece, front)} is no longer pinned',
                // The pinned piece, and what stands behind it — unless that is
                // the king, which a pin never wins.
                stake: [
                  front,
                  if (secondPiece.type != chess.PieceType.KING) back,
                ],
              ));
            }
          }
          // SKEWER: 1st piece is King or higher value than 2nd piece — and it
          // is one only when the front piece must move (worth more than the
          // attacker, which the king always is, or defended by nothing) and the
          // piece behind is worth winning (a minor piece or more, or
          // undefended). Without both, „the queen has to move, exposing the
          // pawn" was said of a pawn two others held.
          else if (firstPiece.type == chess.PieceType.KING || val1 > val2) {
            final frontMustMove =
                val1 > attackerValue || _undefended(game, front, targetColor);
            final behindWorthWinning =
                val2 >= _pieceValue(chess.PieceType.KNIGHT) ||
                    _undefended(game, back, targetColor, besides: front);
            if (frontMustMove && behindWorthWinning) {
              skewers.add(_Found(
                [attackerSq, front, back],
                '${namer(p, attackerSq)} skewers ${namer(firstPiece, front)} '
                    'and ${namer(secondPiece, back)} behind it',
                '${_Namer()(firstPiece, front)} is no longer skewered',
                // What the skewer wins is the piece behind; the one in front
                // escapes, and if it is loose that is a hanging piece of its own.
                stake: [back],
              ));
            }
          }
        }
      }
    }

    return (pins: pins, skewers: skewers);
  }

  List<String> detectPin(chess.Chess game) {
    final sideToMove = game.turn;
    final defenderColor = sideToMove;
    final moverColor =
        sideToMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    final res = _detectPinsAndSkewers(game,
        attackerColor: moverColor, targetColor: defenderColor);
    return {for (final pin in res.pins) ...pin.squares}.toList();
  }

  List<String> detectSkewer(chess.Chess game) {
    final sideToMove = game.turn;
    final defenderColor = sideToMove;
    final moverColor =
        sideToMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    final res = _detectPinsAndSkewers(game,
        attackerColor: moverColor, targetColor: defenderColor);
    return {for (final skewer in res.skewers) ...skewer.squares}.toList();
  }

  // =========================================================================
  // 3. DISCOVERED ATTACK / CHECK
  // =========================================================================

  List<_Found> _detectDiscoveredAttacks(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
    String? lastMoveUci,
  }) {
    if (lastMoveUci == null || lastMoveUci.length < 4) return const [];

    final fromSq = lastMoveUci.substring(0, 2);
    final toSq = lastMoveUci.substring(2, 4);

    final fromF = fromSq.codeUnitAt(0) - 97;
    final fromR = fromSq.codeUnitAt(1) - 49;

    final found = <_Found>[];

    // Check slider pieces of attackerColor that now have a clear ray through fromSq
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sliderSq = _coordsToSq(f, r);
        if (sliderSq == toSq) {
          continue; // The moved piece itself isn't the discovered slider
        }
        final p = game.get(sliderSq);
        if (p == null || p.color != attackerColor) continue;

        if (p.type != chess.PieceType.BISHOP &&
            p.type != chess.PieceType.ROOK &&
            p.type != chess.PieceType.QUEEN) {
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
        final stepsToFromSq =
            isDiag ? df.abs() : (df == 0 ? dr.abs() : df.abs());

        var curF = f + stepF;
        var curR = r + stepR;
        var stepCount = 1;
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
          stepCount++;
        }

        // The first piece found must lie at or beyond fromSq — otherwise it was
        // already blocked before this move and the attack isn't newly discovered.
        if (hitPiece == null ||
            stepCount <= stepsToFromSq ||
            hitPiece.color != targetColor) {
          continue;
        }
        final isCheck = hitPiece.type == chess.PieceType.KING;
        if (!isCheck && _pieceValue(hitPiece.type) < 3) continue;

        final hit = hitSq!;
        final kind = isCheck ? 'check' : 'attack';
        final namer = _Namer();
        found.add(_Found(
          [sliderSq, fromSq, hit],
          'the move from $fromSq uncovers a discovered $kind: '
              '${namer(p, sliderSq)} now attacks ${namer(hitPiece, hit)}',
          'the discovered $kind on ${_Namer()(hitPiece, hit)} is over',
          stake: [hit],
        ));
      }
    }

    return found;
  }

  // =========================================================================
  // 4. OVERLOADING
  // =========================================================================

  List<_Found> _detectOverloading(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
  }) {
    final targetsBySoleDefender = _soleDefenderMap(game,
        attackerColor: attackerColor, targetColor: targetColor);

    final found = <_Found>[];
    targetsBySoleDefender.forEach((defSq, targets) {
      if (targets.length < 2) return;

      final defender = game.get(defSq)!;
      final namer = _Namer();
      final name = namer(defender, defSq);
      final named = [
        for (final t in _mostValuableFirst(game, targets))
          namer(game.get(t)!, t)
      ];
      found.add(_Found(
        [defSq, ...targets],
        '$name is overloaded: it alone defends ${joinAnd(named)}',
        '${_Namer()(defender, defSq)} is no longer overloaded',
        stake: targets,
      ));
    });

    return found;
  }

  // =========================================================================
  // 5. DEFLECTION (SKRETANJE)
  // =========================================================================

  List<_Found> _detectDeflection(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
  }) {
    final targetsBySoleDefender = _soleDefenderMap(game,
        attackerColor: attackerColor, targetColor: targetColor);

    // A defender with exactly one defensive duty (2+ is overloading, not
    // deflection) that is itself attacked can be forced/lured away from that
    // duty — deflecting it exposes whatever it was the sole defender of.
    final found = <_Found>[];
    targetsBySoleDefender.forEach((defSq, targets) {
      if (targets.length != 1) return;
      final attackers = _legalCapturerSquares(game, defSq, attackerColor);
      if (attackers.isEmpty) return;

      final defender = game.get(defSq)!;
      final targetSq = targets.first;
      final target = game.get(targetSq)!;
      final attackerSq = _cheapest(game, attackers);
      final namer = _Namer();
      found.add(_Found(
        [defSq, targetSq],
        '${namer(defender, defSq)} is the only defender of '
            '${namer(target, targetSq)}, and it is attacked by '
            '${namer(game.get(attackerSq)!, attackerSq)}',
        '${_Namer()(target, targetSq)} no longer depends on one attacked defender',
        stake: [targetSq],
      ));
    });

    return found;
  }

  // =========================================================================
  // HELPER METHODS
  // =========================================================================

  /// A piece the side attacking it comes out ahead on — by static exchange,
  /// not by counting — said in whichever of four forms is true of it. „Is
  /// undefended" was the one sentence for all of them, and it was false for
  /// every defended piece attacked by something cheaper.
  List<_Found> _detectHangingPieces(
    chess.Chess game, {
    required chess.Color targetColor,
    required chess.Color attackerColor,
  }) {
    final found = <_Found>[];

    for (var fileIdx = 0; fileIdx < 8; fileIdx++) {
      for (var rankIdx = 0; rankIdx < 8; rankIdx++) {
        final sqName = _coordsToSq(fileIdx, rankIdx);
        final piece = game.get(sqName);
        if (piece == null || piece.color != targetColor) continue;
        if (piece.type == chess.PieceType.KING) continue;

        final attackers = _legalCapturerSquares(game, sqName, attackerColor);
        if (attackers.isEmpty) continue;
        final defenders = _legalCapturerSquares(game, sqName, targetColor);

        final attackerValues = attackers
            .map((s) => _pieceValue(game.get(s)!.type))
            .toList()
          ..sort();
        final defenderValues = defenders
            .map((s) => _pieceValue(game.get(s)!.type))
            .toList()
          ..sort();

        // Static exchange evaluation: does the attacking side come out ahead
        // if the exchange on this square is carried out optimally?
        if (_seeGain(_pieceValue(piece.type), attackerValues, 0, defenderValues,
                0) <=
            0) {
          continue;
        }

        final namer = _Namer();
        final name = namer(piece, sqName);
        final cheapestSq = _cheapest(game, attackers);
        final cheapest = game.get(cheapestSq)!;
        final String clause;
        if (defenders.isEmpty) {
          clause = '$name is attacked by ${namer(cheapest, cheapestSq)} '
              'and has no defender';
        } else if (_pieceValue(cheapest.type) < _pieceValue(piece.type)) {
          clause =
              '$name is attacked by ${namer(cheapest, cheapestSq)}, a cheaper piece';
        } else if (attackers.length > defenders.length) {
          clause = '$name is attacked ${timesWord(attackers.length)} '
              'and defended only ${timesWord(defenders.length)}';
        } else {
          clause = '$name is attacked by ${namer(cheapest, cheapestSq)} '
              'and not defended well enough';
        }
        found.add(_Found(
          [sqName],
          clause,
          '${_Namer()(piece, sqName)} is no longer hanging',
          stake: [sqName],
        ));
      }
    }

    return found;
  }

  /// Mates an engine several moves deep aren't something a player can
  /// actually calculate over the board — flagging them as a "threat" isn't
  /// useful, so only mates within this horizon are surfaced.
  static const int _humanRelevantMatePlies = 2;

  _Found? _detectMateThreat(
    chess.Chess game, {
    String? evalText,
    int? mateIn,
    double? evalScore,
    required chess.Color moverColor,
    required chess.Color defenderColor,
  }) {
    final kingSq = _findKingSquare(game, defenderColor);
    final king = kingSq != null
        ? 'the ${_colorAdj(defenderColor)} king on $kingSq'
        : 'the ${_colorAdj(defenderColor)} king';
    final squares = [if (kingSq != null) kingSq];
    final gone =
        'the mate threat against the ${_colorAdj(defenderColor)} king is over';

    // Actual checkmate on the board only ever applies to whoever's turn it
    // is in `game` — only meaningful here when that's moverColor's target.
    if (game.in_checkmate && game.turn == defenderColor) {
      // A mate's significance is the king's, set where the finding is made.
      return _Found(squares, '$king is checkmated', gone, stake: const []);
    }

    final signal = _parseMateSignal(
        evalText: evalText, mateIn: mateIn, attackerColor: moverColor);
    if (signal == null ||
        signal.matingColor != moverColor ||
        signal.plies > _humanRelevantMatePlies) {
      return null;
    }

    final namedMateMove = signal.plies == 1 && game.turn == moverColor
        ? _findMateInOneMove(game)
        : null;
    return _Found(
      squares,
      namedMateMove != null
          ? '$king can be mated at once with $namedMateMove'
          : '$king is threatened with mate',
      gone,
      stake: const [],
    );
  }

  /// Reads a mate distance/direction out of [mateIn] (already relative to
  /// [attackerColor] by contract: positive means it mates) or, failing that,
  /// out of an engine [evalText] string like "M4"/"-M4". `StockfishService`
  /// normalizes that string to be White-relative regardless of whose turn it
  /// is (flips the raw UCI side-to-move-relative score when Black is to
  /// move) — so a bare "M`n`" always means White mates, "-M`n`" Black mates,
  /// and the caller must compare [_MateSignal.matingColor] against whichever
  /// side it's actually asking about before trusting it.
  _MateSignal? _parseMateSignal(
      {String? evalText, int? mateIn, required chess.Color attackerColor}) {
    if (mateIn != null) {
      return mateIn > 0 ? _MateSignal(attackerColor, mateIn) : null;
    }
    if (evalText == null) return null;

    final match = RegExp(r'(-)?M(\d+)').firstMatch(evalText);
    if (match == null) return null;

    final matingColor =
        match.group(1) != null ? chess.Color.BLACK : chess.Color.WHITE;
    return _MateSignal(matingColor, int.parse(match.group(2)!));
  }

  /// Finds a legal move for the side to move that delivers checkmate right
  /// now, so a mate-in-1 threat can be named (e.g. "Dg8#") instead of left
  /// generic. Returns null if none exists (including when it isn't that
  /// side's turn at all).
  String? _findMateInOneMove(chess.Chess game) {
    for (final move in legalMoves(game)) {
      final clone = chess.Chess.fromFEN(game.fen);
      // Through `playMove`, because the commonest mate in one of all is a
      // promotion — and played without naming the piece it is not played at
      // all, so "d8=Q#" was never among the mates this could find.
      final applied = playMove(clone, move);
      if (applied && clone.in_checkmate) {
        return (move['san'] as String?) ?? '${move['from']}${move['to']}';
      }
    }
    return null;
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

  /// Squares holding a [color] piece that can legally capture/recapture on
  /// [targetSq] — i.e. it geometrically attacks the square, isn't absolutely
  /// pinned along a different line, AND doesn't hand the opponent an
  /// immediate mate by doing so (a capture can be pseudo-legal and still be
  /// practically unplayable — e.g. a pawn "defending" a piece it can't
  /// actually take because the recapture opens a mate elsewhere on the
  /// board). Used for both attacker and defender counts so both sides of an
  /// exchange only count moves a rational player would actually make.
  List<String> _legalCapturerSquares(
      chess.Chess game, String targetSq, chess.Color color) {
    final squares = <String>[];
    final toFile = targetSq.codeUnitAt(0) - 97;
    final toRank = targetSq.codeUnitAt(1) - 49;

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final fromSq = _coordsToSq(f, r);
        if (fromSq == targetSq) continue;
        final p = game.get(fromSq);
        if (p == null || p.color != color) continue;
        if (!_canPieceAttack(game, p, f, r, toFile, toRank)) continue;
        if (_isAbsolutelyPinned(game, fromSq, color)) continue;
        if (_wouldWalkIntoMate(game, fromSq, targetSq)) continue;

        squares.add(fromSq);
      }
    }
    return squares;
  }

  /// Whether playing [fromSq]-to-[targetSq] would immediately hand the
  /// opponent a forced mate — checked via [_findMateInOneMove] on the
  /// resulting position, so it's only ever run for candidates that already
  /// passed the cheap geometric/pin filters above.
  bool _wouldWalkIntoMate(chess.Chess game, String fromSq, String targetSq) {
    final clone = chess.Chess.fromFEN(game.fen);
    if (!clone.move({'from': fromSq, 'to': targetSq})) return false;
    return _findMateInOneMove(clone) != null;
  }

  /// For every attacked [targetColor] piece that has exactly one legal
  /// [targetColor] defender, maps that defender's square to the list of
  /// attacked squares it alone defends. Shared by overloading (defender
  /// square maps to 2+ targets) and deflection (maps to exactly 1 target,
  /// and the defender itself is attacked) so both reuse the same scan.
  Map<String, List<String>> _soleDefenderMap(
    chess.Chess game, {
    required chess.Color attackerColor,
    required chess.Color targetColor,
  }) {
    final targetsBySoleDefender = <String, List<String>>{};

    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final tSq = _coordsToSq(f, r);
        final tPiece = game.get(tSq);
        if (tPiece == null || tPiece.color != targetColor) continue;
        // The king is not a piece a defender holds: a check is answered by
        // moving as often as by taking, and „the king is left undefended" is
        // not a chess sentence. It was being written.
        if (tPiece.type == chess.PieceType.KING) continue;
        if (_legalCapturerSquares(game, tSq, attackerColor).isEmpty) continue;

        final defenders = _legalCapturerSquares(game, tSq, targetColor);
        if (defenders.length != 1) continue;
        // A pawn guarding a pawn is the ordinary shape of a pawn chain, not a
        // defender to overload or deflect.
        if (tPiece.type == chess.PieceType.PAWN &&
            game.get(defenders.first)!.type == chess.PieceType.PAWN) {
          continue;
        }
        targetsBySoleDefender.putIfAbsent(defenders.first, () => []).add(tSq);
      }
    }

    return targetsBySoleDefender;
  }

  /// Whether the piece on [sq] is pinned against its own king — i.e. an
  /// enemy slider has a clear line through [sq] straight to the king, so
  /// moving/capturing off that line would illegally expose the king.
  bool _isAbsolutelyPinned(chess.Chess game, String sq, chess.Color color) {
    final kingSq = _findKingSquare(game, color);
    if (kingSq == null || kingSq == sq) return false;

    final kingF = kingSq.codeUnitAt(0) - 97;
    final kingR = kingSq.codeUnitAt(1) - 49;
    final sqF = sq.codeUnitAt(0) - 97;
    final sqR = sq.codeUnitAt(1) - 49;

    final df = sqF - kingF;
    final dr = sqR - kingR;
    final isDiag = df != 0 && df.abs() == dr.abs();
    final isOrtho = (df == 0) != (dr == 0);
    if (!isDiag && !isOrtho) return false;

    final stepF = df.sign;
    final stepR = dr.sign;

    // Walk out from the king; `sq` must be the very first piece encountered.
    var curF = kingF + stepF;
    var curR = kingR + stepR;
    while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
      final checkSq = _coordsToSq(curF, curR);
      if (checkSq == sq) break;
      if (game.get(checkSq) != null) return false;
      curF += stepF;
      curR += stepR;
    }
    if (curF < 0 || curF >= 8 || curR < 0 || curR >= 8) return false;

    // Continue past `sq` looking for a slider that pins it to the king.
    curF += stepF;
    curR += stepR;
    while (curF >= 0 && curF < 8 && curR >= 0 && curR < 8) {
      final checkSq = _coordsToSq(curF, curR);
      final p = game.get(checkSq);
      if (p != null) {
        if (p.color == color) return false;
        return isDiag
            ? (p.type == chess.PieceType.BISHOP ||
                p.type == chess.PieceType.QUEEN)
            : (p.type == chess.PieceType.ROOK ||
                p.type == chess.PieceType.QUEEN);
      }
      curF += stepF;
      curR += stepR;
    }
    return false;
  }

  /// Static exchange evaluation: given the value of the piece currently on
  /// the target square and each side's available capturers (ascending by
  /// value), returns the net material the capturing side gains by initiating
  /// the exchange and playing it out optimally (0 if it isn't worth starting).
  int _seeGain(
    int targetValue,
    List<int> capturingSideValues,
    int capturingIdx,
    List<int> otherSideValues,
    int otherIdx,
  ) {
    if (capturingIdx >= capturingSideValues.length) return 0;

    final capturingValue = capturingSideValues[capturingIdx];
    final continuation = _seeGain(capturingValue, otherSideValues, otherIdx,
        capturingSideValues, capturingIdx + 1);
    final gain = targetValue - continuation;
    return gain > 0 ? gain : 0;
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
        if (df != dr && (fromFile != toFile && fromRank != toRank)) {
          return false;
        }
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

  /// [squares] ordered so the most valuable piece is named first — "forks the
  /// black king on e8 and the rook on a8" — keeping the board's scan order
  /// between pieces of equal value.
  List<String> _mostValuableFirst(chess.Chess game, List<String> squares) {
    final indexed = [
      for (var i = 0; i < squares.length; i++) (index: i, square: squares[i])
    ];
    indexed.sort((a, b) {
      final byValue = _pieceValue(game.get(b.square)!.type) -
          _pieceValue(game.get(a.square)!.type);
      return byValue != 0 ? byValue : a.index - b.index;
    });
    return [for (final entry in indexed) entry.square];
  }

  /// Whether a fork attacking [square] can win what stands there — see the
  /// rule at the call in [_detectForks].
  bool _forkCanWin(chess.Chess game, chess.Piece forker, String square,
      chess.Color targetColor) {
    final target = game.get(square)!;
    // The king needs no clause of its own: nothing that can attack it is worth
    // more, so the comparison already counts it.
    return _pieceValue(target.type) > _pieceValue(forker.type) ||
        _undefended(game, square, targetColor);
  }

  /// Whether nothing of [color] could take back on [square]. [besides] is
  /// left out of the count: the piece standing in front on a pin's or a
  /// skewer's line is the one being driven off it, so it is not a defender
  /// the piece behind can rely on.
  bool _undefended(chess.Chess game, String square, chess.Color color,
          {String? besides}) =>
      _legalCapturerSquares(game, square, color).every((s) => s == besides);

  /// The square in [squares] holding the least valuable piece, the first of
  /// equals — the attacker a sentence names, since it is the one that makes
  /// the capture cheapest.
  String _cheapest(chess.Chess game, List<String> squares) {
    var best = squares.first;
    for (final sq in squares.skip(1)) {
      if (_pieceValue(game.get(sq)!.type) < _pieceValue(game.get(best)!.type)) {
        best = sq;
      }
    }
    return best;
  }

  /// The value of the most valuable piece sitting on any of [squares] — a
  /// finding's stake ([_Found.stake]) — used as its
  /// [MotifFinding.significance] so a hanging pawn and a hanging queen aren't
  /// treated as equally worth mentioning. Squares with no piece are ignored
  /// rather than counted as 0-and-therefore-lowest.
  int _significanceOf(chess.Chess game, List<String> squares) {
    var maxValue = 0;
    for (final sq in squares) {
      final piece = game.get(sq);
      if (piece == null) continue;
      final value = _pieceValue(piece.type);
      if (value > maxValue) maxValue = value;
    }
    return maxValue;
  }

  String _coordsToSq(int fileIdx, int rankIdx) {
    final f = String.fromCharCode(97 + fileIdx);
    final r = String.fromCharCode(49 + rankIdx);
    return '$f$r';
  }
}

class _MateSignal {
  final chess.Color matingColor;
  final int plies;

  const _MateSignal(this.matingColor, this.plies);
}
