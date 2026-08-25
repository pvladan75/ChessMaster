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

class _MateSignal {
  final chess.Color matingColor;
  final int plies;

  const _MateSignal(this.matingColor, this.plies);
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

class _DeflectionResult {
  final bool hasDeflection;
  final List<String> affectedSquares;
  final String description;

  const _DeflectionResult({
    required this.hasDeflection,
    required this.affectedSquares,
    required this.description,
  });
}

// =============================================================================
// SERBIAN PHRASING HELPERS — piece names with grammatical gender/case, so
// descriptions can say "beli skakač na f5" / "napada damu na c3" instead of
// a generic, un-declined "figura". Every piece noun except "dama" is
// masculine; chess pieces are conventionally declined as animate nouns in
// Serbian chess speech (e.g. "uzeo je topa", not "uzeo je top").
// =============================================================================

enum _Gender { masculine, feminine }

class _PieceNoun {
  final String nominative; // subject form: "skakač", "dama"
  final String accusative; // object form: "skakača", "damu"
  final _Gender gender;

  const _PieceNoun(this.nominative, this.accusative, this.gender);
}

_PieceNoun _pieceNoun(chess.PieceType type) {
  switch (type) {
    case chess.PieceType.PAWN:
      return const _PieceNoun('pešak', 'pešaka', _Gender.masculine);
    case chess.PieceType.KNIGHT:
      return const _PieceNoun('skakač', 'skakača', _Gender.masculine);
    case chess.PieceType.BISHOP:
      return const _PieceNoun('lovac', 'lovca', _Gender.masculine);
    case chess.PieceType.ROOK:
      return const _PieceNoun('top', 'topa', _Gender.masculine);
    case chess.PieceType.QUEEN:
      return const _PieceNoun('dama', 'damu', _Gender.feminine);
    case chess.PieceType.KING:
      return const _PieceNoun('kralj', 'kralja', _Gender.masculine);
    default:
      return const _PieceNoun('figura', 'figuru', _Gender.feminine);
  }
}

String _agree(_Gender gender, String masculine, String feminine) =>
    gender == _Gender.feminine ? feminine : masculine;

String _colorAdj(chess.Color color, _Gender gender) {
  final isWhite = color == chess.Color.WHITE;
  return _agree(gender, isWhite ? 'beli' : 'crni', isWhite ? 'bela' : 'crna');
}

/// "beli skakač", "crna dama" — nominative, for the piece as subject.
String _pieceSubject(chess.Piece piece) {
  final noun = _pieceNoun(piece.type);
  return '${_colorAdj(piece.color, noun.gender)} ${noun.nominative}';
}

/// "belog skakača", "crnu damu" — accusative, for the piece as object
/// ("napada ${_pieceObject(...)}").
String _pieceObject(chess.Piece piece) {
  final noun = _pieceNoun(piece.type);
  final isWhite = piece.color == chess.Color.WHITE;
  final adj = _agree(
      noun.gender, isWhite ? 'belog' : 'crnog', isWhite ? 'belu' : 'crnu');
  return '$adj ${noun.accusative}';
}

const _serbianCounts = {
  2: 'dve',
  3: 'tri',
  4: 'četiri',
  5: 'pet',
  6: 'šest',
  7: 'sedam',
  8: 'osam'
};

/// "dve bele figure" (2-4) / "pet belih figura" (5+) — count + color + noun,
/// all correctly declined for how many there are.
String _countedFigures(int count, chess.Color color) {
  final countWord = _serbianCounts[count] ?? '$count';
  if (count <= 4) {
    return '$countWord ${color == chess.Color.WHITE ? 'bele' : 'crne'} figure';
  }
  return '$countWord ${color == chess.Color.WHITE ? 'belih' : 'crnih'} figura';
}

/// "a", "a i b", "a, b i c" — Serbian-style listing with "i" before the last item.
String _joinSerbian(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} i ${items.last}';
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

      final beforeKeys = beforeFindings.map((f) => f.diffKey).toSet();
      final afterKeys = afterFindings.map((f) => f.diffKey).toSet();

      final created =
          afterFindings.where((f) => !beforeKeys.contains(f.diffKey)).toList();
      final resolved =
          beforeFindings.where((f) => !afterKeys.contains(f.diffKey)).toList();

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
  /// significant findings, six clauses in a row isn't a readable comment.
  static const int _maxCreatedInComment = 3;
  static const int _maxResolvedInComment = 2;

  /// Renders a [MoveMotifDiff] as a short Serbian move-comment: what the
  /// move threatens (as-is), what it left exposed (prefixed "Pažnja"), and
  /// what pre-existing exposure it fixed (prefixed "Rešeno"). A resolved
  /// threat the mover *had* against the opponent isn't worth narrating on
  /// its own, so it's left out. Low-significance findings (a lone hanging
  /// pawn) are dropped whenever something more significant is also present,
  /// and each list is capped so the comment stays readable. Returns '' when
  /// the move changed nothing tactically worth narrating.
  String describeMoveDiff(MoveMotifDiff diff) {
    final created = _mostNarratable(diff.created, _maxCreatedInComment);
    final resolved = _mostNarratable(
        diff.resolved.where((f) => !f.favorsMover).toList(),
        _maxResolvedInComment);

    final parts = <String>[
      ...created.map(_formatFinding),
      ...resolved.map((f) => _formatFinding(f, resolved: true)),
    ];
    return parts.join(' | ');
  }

  /// Every candidate comment line for a move — the same "Pažnja —"/"Rešeno —"
  /// phrasing [describeMoveDiff] uses, but unfiltered and uncapped, for UIs
  /// that let a human pick which findings to keep (e.g. a checklist) instead
  /// of applying the automatic significance filter.
  List<String> candidateCommentLines(MoveMotifDiff diff) {
    return [
      ...diff.created.map(_formatFinding),
      ...diff.resolved
          .where((f) => !f.favorsMover)
          .map((f) => _formatFinding(f, resolved: true)),
    ];
  }

  String _formatFinding(MotifFinding f, {bool resolved = false}) {
    if (resolved) return 'Rešeno — ${f.description}';
    return f.favorsMover ? f.description : 'Pažnja — ${f.description}';
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
    final hanging = _detectHangingPieces(game,
        targetColor: targetColor, attackerColor: attackerColor);
    final fork = _detectFork(game,
        attackerColor: attackerColor,
        targetColor: targetColor,
        lastMoveUci: lastMoveUci);
    final pinSkewer = _detectPinAndSkewer(game,
        attackerColor: attackerColor, targetColor: targetColor);
    final overload = _detectOverloading(game,
        attackerColor: attackerColor, targetColor: targetColor);
    final deflection = _detectDeflection(game,
        attackerColor: attackerColor, targetColor: targetColor);

    final mate = _detectMateThreat(
      game,
      evalText: evalText,
      mateIn: mateIn,
      evalScore: evalScore,
      moverColor: attackerColor,
      defenderColor: targetColor,
    );

    var discovered = const _DiscoveredAttackResult(
      hasDiscoveredAttack: false,
      isDiscoveredCheck: false,
      affectedSquares: [],
      description: '',
    );

    if (includeDiscovered) {
      discovered = _detectDiscoveredAttack(game,
          attackerColor: attackerColor,
          targetColor: targetColor,
          lastMoveUci: lastMoveUci);
    }

    final findings = <MotifFinding>[];

    // Combined Double Attack: Mate Threat + Piece Attack
    if (mate.hasMate && hanging.affectedSquares.isNotEmpty) {
      findings.add(MotifFinding(
        motifs: const [
          TacticalMotif.mateThreatAndPieceAttack,
          TacticalMotif.doubleAttack,
          TacticalMotif.mateThreat,
          TacticalMotif.hangingPiece,
        ],
        description:
            'Dvojni udar: ${hanging.description}, uz ${mate.description.substring(0, 1).toLowerCase()}${mate.description.substring(1)}',
        affectedSquares:
            {...hanging.affectedSquares, ...mate.affectedSquares}.toList(),
        favorsMover: favorsMover,
        significance: _pieceValue(chess.PieceType.KING),
      ));
    } else {
      if (hanging.hasHanging) {
        findings.add(MotifFinding(
          motifs: const [TacticalMotif.hangingPiece],
          description: hanging.description,
          affectedSquares: hanging.affectedSquares,
          favorsMover: favorsMover,
          significance: _significanceOf(game, hanging.affectedSquares),
        ));
      }
      if (mate.hasMate) {
        findings.add(MotifFinding(
          motifs: const [TacticalMotif.mateThreat],
          description: mate.description,
          affectedSquares: mate.affectedSquares,
          favorsMover: favorsMover,
          significance: _pieceValue(chess.PieceType.KING),
        ));
      }
    }

    if (fork.hasFork) {
      findings.add(MotifFinding(
        motifs: const [TacticalMotif.fork, TacticalMotif.doubleAttack],
        description: fork.description,
        affectedSquares: fork.affectedSquares,
        favorsMover: favorsMover,
        significance: _significanceOf(game, fork.affectedSquares),
      ));
    }

    if (pinSkewer.hasPin) {
      findings.add(MotifFinding(
        motifs: const [TacticalMotif.pin],
        description: pinSkewer.pinDescription,
        affectedSquares: pinSkewer.pinSquares,
        favorsMover: favorsMover,
        significance: _significanceOf(game, pinSkewer.pinSquares),
      ));
    }

    if (pinSkewer.hasSkewer) {
      findings.add(MotifFinding(
        motifs: const [TacticalMotif.skewer],
        description: pinSkewer.skewerDescription,
        affectedSquares: pinSkewer.skewerSquares,
        favorsMover: favorsMover,
        significance: _significanceOf(game, pinSkewer.skewerSquares),
      ));
    }

    if (discovered.hasDiscoveredAttack) {
      findings.add(MotifFinding(
        motifs: const [TacticalMotif.discoveredAttack],
        description: discovered.description,
        affectedSquares: discovered.affectedSquares,
        favorsMover: favorsMover,
        significance: _significanceOf(game, discovered.affectedSquares),
      ));
    }

    if (overload.hasOverloading) {
      findings.add(MotifFinding(
        motifs: const [TacticalMotif.overloading],
        description: overload.description,
        affectedSquares: overload.affectedSquares,
        favorsMover: favorsMover,
        significance: _significanceOf(game, overload.affectedSquares),
      ));
    }

    if (deflection.hasDeflection) {
      findings.add(MotifFinding(
        motifs: const [TacticalMotif.deflection],
        description: deflection.description,
        affectedSquares: deflection.affectedSquares,
        favorsMover: favorsMover,
        significance: _significanceOf(game, deflection.affectedSquares),
      ));
    }

    return findings;
  }

  // =========================================================================
  // 1. FORK (VILJUŠKA)
  // =========================================================================

  _ForkResult _detectFork(
    chess.Chess game, {
    chess.Color? attackerColor,
    chess.Color? targetColor,
    String? lastMoveUci,
  }) {
    attackerColor ??=
        game.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    targetColor ??= game.turn;

    // Destination of last move is prime suspect for fork
    String? moveDest;
    if (lastMoveUci != null && lastMoveUci.length >= 4) {
      moveDest = lastMoveUci.substring(2, 4);
    }

    final forksByPiece =
        <String, List<String>>{}; // forker square -> target squares

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
              } else if (_pieceValue(tPiece.type) >= _pieceValue(p.type) ||
                  tPiece.type == chess.PieceType.ROOK ||
                  tPiece.type == chess.PieceType.QUEEN) {
                valuableTargets++;
              }
            }
          }

          if (hasKingCheck || valuableTargets >= 2) {
            forksByPiece[sq] = targets;
          }
        }
      }
    }

    if (forksByPiece.isEmpty) {
      return const _ForkResult(
          hasFork: false, affectedSquares: [], description: '');
    }

    final allSquares = <String>{};
    final sentences = <String>[];
    forksByPiece.forEach((forkerSq, targets) {
      allSquares.add(forkerSq);
      allSquares.addAll(targets);

      final forker = game.get(forkerSq)!;
      final targetPhrases = targets
          .map((tSq) => '${_pieceObject(game.get(tSq)!)} na $tSq')
          .toList();

      sentences.add(
        '${_pieceSubject(forker)} sa $forkerSq napada ${_countedFigures(targets.length, targetColor!)}: '
        '${_joinSerbian(targetPhrases)}',
      );
    });

    return _ForkResult(
      hasFork: true,
      affectedSquares: allSquares.toList(),
      description: 'Viljuška: ${sentences.join(' | ')}',
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
    final pinSentences = <String>[];
    final skewerSentences = <String>[];

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
          if (firstPiece != null &&
              secondPiece != null &&
              firstPiece.color == targetColor &&
              secondPiece.color == targetColor) {
            final val1 = _pieceValue(firstPiece.type);
            final val2 = _pieceValue(secondPiece.type);

            // PIN: 2nd piece is King or higher value than 1st piece
            if (secondPiece.type == chess.PieceType.KING || val2 > val1) {
              pinSquares.addAll([attackerSq, firstSq!, secondSq!]);
              pinSentences.add(
                '${_pieceSubject(firstPiece)} na $firstSq je ${_agree(_pieceNoun(firstPiece.type).gender, 'vezan', 'vezana')} '
                'za ${_pieceObject(secondPiece)} na $secondSq',
              );
            }
            // SKEWER: 1st piece is King or higher value than 2nd piece
            else if (firstPiece.type == chess.PieceType.KING || val1 > val2) {
              skewerSquares.addAll([attackerSq, firstSq!, secondSq!]);
              skewerSentences.add(
                '${_pieceSubject(firstPiece)} na $firstSq mora da se pomeri, otkrivajući '
                '${_pieceObject(secondPiece)} na $secondSq',
              );
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
      pinDescription:
          pinSentences.isEmpty ? '' : 'Vezivanje: ${pinSentences.join(' | ')}',
      skewerDescription: skewerSentences.isEmpty
          ? ''
          : 'Ražanj: ${skewerSentences.join(' | ')}',
    );
  }

  List<String> detectPin(chess.Chess game) {
    final sideToMove = game.turn;
    final defenderColor = sideToMove;
    final moverColor =
        sideToMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    final res = _detectPinAndSkewer(game,
        attackerColor: moverColor, targetColor: defenderColor);
    return res.pinSquares;
  }

  List<String> detectSkewer(chess.Chess game) {
    final sideToMove = game.turn;
    final defenderColor = sideToMove;
    final moverColor =
        sideToMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    final res = _detectPinAndSkewer(game,
        attackerColor: moverColor, targetColor: defenderColor);
    return res.skewerSquares;
  }

  // =========================================================================
  // 3. DISCOVERED ATTACK / CHECK (OTKRIVENI NAPAD / ŠAH)
  // =========================================================================

  _DiscoveredAttackResult _detectDiscoveredAttack(
    chess.Chess game, {
    chess.Color? attackerColor,
    chess.Color? targetColor,
    String? lastMoveUci,
  }) {
    attackerColor ??=
        game.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
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
    final sentences = <String>[];
    bool isCheck = false;

    // Check slider pieces of attackerColor that now have a clear ray through fromSq
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sliderSq = _coordsToSq(f, r);
        if (sliderSq == toSq)
          continue; // The moved piece itself isn't the discovered slider
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
        if (hitPiece != null &&
            stepCount > stepsToFromSq &&
            hitPiece.color == targetColor) {
          if (hitPiece.type == chess.PieceType.KING) {
            isCheck = true;
            discSquares.addAll([sliderSq, fromSq, hitSq!]);
            sentences.add(
                '${_pieceSubject(p)} sa $sliderSq sada napada ${_pieceObject(hitPiece)} na $hitSq (otkriveno pomeranjem figure sa $fromSq)');
          } else if (_pieceValue(hitPiece.type) >= 3) {
            discSquares.addAll([sliderSq, fromSq, hitSq!]);
            sentences.add(
                '${_pieceSubject(p)} sa $sliderSq sada napada ${_pieceObject(hitPiece)} na $hitSq (otkriveno pomeranjem figure sa $fromSq)');
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
        ? 'Otkriveni šah: ${sentences.join(' | ')}'
        : 'Otkriveni napad: ${sentences.join(' | ')}';

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

  _OverloadingResult _detectOverloading(
    chess.Chess game, {
    chess.Color? attackerColor,
    chess.Color? targetColor,
  }) {
    attackerColor ??=
        game.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    targetColor ??= game.turn;

    final targetsBySoleDefender = _soleDefenderMap(game,
        attackerColor: attackerColor, targetColor: targetColor);

    final overloadedSquares = <String>{};
    final sentences = <String>[];
    targetsBySoleDefender.forEach((defSq, targets) {
      if (targets.length < 2) return;
      overloadedSquares.add(defSq);
      overloadedSquares.addAll(targets);

      final defender = game.get(defSq)!;
      final targetPhrases = targets
          .map((tSq) => '${_pieceObject(game.get(tSq)!)} na $tSq')
          .toList();
      sentences.add(
        '${_pieceSubject(defender)} na $defSq brani ${_countedFigures(targets.length, defender.color)} istovremeno '
        '(${_joinSerbian(targetPhrases)}) — ne može da odbrani sve',
      );
    });

    if (overloadedSquares.isEmpty) {
      return const _OverloadingResult(
          hasOverloading: false, affectedSquares: [], description: '');
    }

    return _OverloadingResult(
      hasOverloading: true,
      affectedSquares: overloadedSquares.toList(),
      description: 'Preopterećena figura: ${sentences.join(' | ')}',
    );
  }

  // =========================================================================
  // 5. DEFLECTION (SKRETANJE)
  // =========================================================================

  _DeflectionResult _detectDeflection(
    chess.Chess game, {
    chess.Color? attackerColor,
    chess.Color? targetColor,
  }) {
    final chess.Color resolvedAttackerColor = attackerColor ??
        (game.turn == chess.Color.WHITE
            ? chess.Color.BLACK
            : chess.Color.WHITE);
    final chess.Color resolvedTargetColor = targetColor ?? game.turn;

    final targetsBySoleDefender = _soleDefenderMap(game,
        attackerColor: resolvedAttackerColor, targetColor: resolvedTargetColor);

    // A defender with exactly one defensive duty (2+ is overloading, not
    // deflection) that is itself attacked can be forced/lured away from that
    // duty — deflecting it exposes whatever it was the sole defender of.
    final deflectionSquares = <String>{};
    final sentences = <String>[];
    targetsBySoleDefender.forEach((defSq, targets) {
      if (targets.length != 1) return;
      if (_legalCapturerSquares(game, defSq, resolvedAttackerColor).isEmpty)
        return;

      deflectionSquares.add(defSq);
      deflectionSquares.addAll(targets);

      final defender = game.get(defSq)!;
      final target = game.get(targets.first)!;
      sentences.add(
        '${_pieceSubject(defender)} na $defSq je jedini branilac za ${_pieceObject(target)} na ${targets.first}, '
        'a sam je napadnut — ako se skloni, ${_pieceSubject(target)} ostaje ${_agree(_pieceNoun(target.type).gender, 'nebranjen', 'nebranjena')}',
      );
    });

    if (deflectionSquares.isEmpty) {
      return const _DeflectionResult(
          hasDeflection: false, affectedSquares: [], description: '');
    }

    return _DeflectionResult(
      hasDeflection: true,
      affectedSquares: deflectionSquares.toList(),
      description: 'Skretanje: ${sentences.join(' | ')}',
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

        final attackerValues =
            _legalCapturerSquares(game, sqName, attackerColor)
                .map((s) => _pieceValue(game.get(s)!.type))
                .toList()
              ..sort();
        if (attackerValues.isEmpty) continue;

        final defenderValues = _legalCapturerSquares(game, sqName, targetColor)
            .map((s) => _pieceValue(game.get(s)!.type))
            .toList()
          ..sort();

        // Static exchange evaluation: does the attacking side come out ahead
        // if the exchange on this square is carried out optimally?
        if (_seeGain(
                _pieceValue(piece.type), attackerValues, 0, defenderValues, 0) >
            0) {
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

    String pieceDesc;
    if (hangingSquares.length == 1) {
      final sq = hangingSquares.first;
      final piece = game.get(sq)!;
      final noun = _pieceNoun(piece.type);
      pieceDesc =
          '${_pieceSubject(piece)} na $sq je ${_agree(noun.gender, 'nebranjen', 'nebranjena')}';
    } else {
      final phrases = hangingSquares
          .map((sq) => '${_pieceSubject(game.get(sq)!)} na $sq')
          .toList();
      pieceDesc = '${_joinSerbian(phrases)} su nebranjeni';
    }

    return _HangingDetectionResult(
      hasHanging: true,
      affectedSquares: hangingSquares,
      description: pieceDesc,
    );
  }

  /// Mates an engine several moves deep aren't something a player can
  /// actually calculate over the board — flagging them as a "threat" isn't
  /// useful, so only mates within this horizon are surfaced.
  static const int _humanRelevantMatePlies = 2;

  _MateDetectionResult _detectMateThreat(
    chess.Chess game, {
    String? evalText,
    int? mateIn,
    double? evalScore,
    required chess.Color moverColor,
    required chess.Color defenderColor,
  }) {
    bool isMateThreat = false;
    String? namedMateMove;

    final signal = _parseMateSignal(
        evalText: evalText, mateIn: mateIn, attackerColor: moverColor);
    if (signal != null &&
        signal.matingColor == moverColor &&
        signal.plies <= _humanRelevantMatePlies) {
      isMateThreat = true;
      if (signal.plies == 1 && game.turn == moverColor) {
        namedMateMove = _findMateInOneMove(game);
      }
    }

    // Actual checkmate on the board only ever applies to whoever's turn it
    // is in `game` — only meaningful here when that's moverColor's target.
    if (!isMateThreat && game.in_checkmate && game.turn == defenderColor) {
      isMateThreat = true;
    }

    if (!isMateThreat) {
      return const _MateDetectionResult(
          hasMate: false, affectedSquares: [], description: '');
    }

    final mateSquares = <String>[];
    final kingSq = _findKingSquare(game, defenderColor);
    if (kingSq != null) {
      mateSquares.add(kingSq);
    }

    final kingPhrase = kingSq != null
        ? '${_colorAdj(defenderColor, _Gender.masculine)} kralj na $kingSq'
        : 'Kralj';
    final desc = namedMateMove != null
        ? '$kingPhrase je pod pretnjom mata: $namedMateMove sledećim potezom'
        : '$kingPhrase je pod pretnjom mata';

    return _MateDetectionResult(
      hasMate: true,
      affectedSquares: mateSquares,
      description: desc,
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
    for (final move in game.moves({'verbose': true})) {
      final clone = chess.Chess.fromFEN(game.fen);
      final applied = clone.move({
        'from': move['from'],
        'to': move['to'],
        if (move['promotion'] != null) 'promotion': move['promotion'],
      });
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
        if (_legalCapturerSquares(game, tSq, attackerColor).isEmpty) continue;

        final defenders = _legalCapturerSquares(game, tSq, targetColor);
        if (defenders.length == 1) {
          targetsBySoleDefender.putIfAbsent(defenders.first, () => []).add(tSq);
        }
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
        if (df != dr && (fromFile != toFile && fromRank != toRank))
          return false;
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

  /// The value of the most valuable piece sitting on any of [squares] —
  /// used as a finding's [MotifFinding.significance] so a hanging pawn and a
  /// hanging queen aren't treated as equally worth mentioning. Squares with
  /// no piece (e.g. a discovered attack's now-vacated origin square) are
  /// ignored rather than counted as 0-and-therefore-lowest.
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
