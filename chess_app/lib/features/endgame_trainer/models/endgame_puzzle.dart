/// An endgame position from the mined database, and the rules for solving it.
///
/// Kept apart from any widget for the same reason as the tactics session: the
/// expensive mistakes are in the sequencing, and they are only cheap to catch
/// when they can be tested without a board.
library;

/// What the position asks of the side to move.
enum EndgameMode {
  /// The position is won. Find a move that keeps it won.
  win,

  /// The position is drawn. Find a move that holds the draw; everything else
  /// loses. This is a different skill from converting, and often the harder
  /// one, which is why it is a mode and not a footnote.
  draw,
}

/// One endgame position as the server sends it.
///
/// Unlike a tactics puzzle, [fen] *is* the position to solve — there is no
/// setup move to replay first.
class EndgamePuzzle {
  final String id;
  final String fen;
  final String type;
  final EndgameMode mode;

  /// **Every** move that holds the result, not one designated answer.
  ///
  /// This is the whole point of the field. Across the mined set 68% of
  /// positions have more than one, and in a rook ending with two moves that
  /// both draw, telling a child the second one is wrong is simply false.
  final List<String> winningMoves;

  /// Best play from here, for showing the continuation after a correct move.
  /// Advisory: the opponent is not forced, so this is a demonstration line and
  /// not a solution the user must reproduce.
  final List<String> solution;
  final List<String> solutionSan;

  final int piecesOnBoard;
  final int pawnsOnBoard;

  /// 'syzygy' when the verdict came from a tablebase, 'engine' when it is a
  /// search estimate. Worth surfacing: with a tablebase the app can tell a
  /// child their move loses the win and be certain of it.
  final String source;

  final String difficulty;
  final int? difficultyScore;
  final int? dtz;
  final EndgameGame? game;

  /// The Syzygy table this position belongs to, normalised: 'KRPvKR'. A far
  /// finer grouping than [type]'s seven mined categories, and the one a trainer
  /// asking for "rook and pawn against rook" actually means.
  final String? material;

  /// When the position comes from a real mistake: how strong the player who
  /// made it was, and what they played instead. Neither is a solution; together
  /// they are what turns a diagram into something that happened to somebody.
  final int? blunderElo;
  final String? playedMove;

  const EndgamePuzzle({
    required this.id,
    required this.fen,
    required this.type,
    required this.mode,
    required this.winningMoves,
    this.solution = const [],
    this.solutionSan = const [],
    this.piecesOnBoard = 0,
    this.pawnsOnBoard = 0,
    this.source = 'engine',
    this.difficulty = 'medium',
    this.difficultyScore,
    this.dtz,
    this.game,
    this.material,
    this.blunderElo,
    this.playedMove,
  });

  bool get isPlayable => fen.isNotEmpty && winningMoves.isNotEmpty;

  /// Sources whose answer is a tablebase result rather than a search.
  ///
  /// 'lichess' is the same Syzygy data, asked over the network for positions
  /// past what we hold locally. 'blunder' is a position taken from a real game
  /// where a player changed the result: the verdict and the moves that held it
  /// are tablebase answers too. Leaving either out would show a position that
  /// is exact as an estimate, which is the wrong way round.
  static const _exactSources = {'syzygy', 'lichess', 'blunder'};

  /// True when the result is known exactly rather than estimated.
  bool get isExact => _exactSources.contains(source);

  /// Whether every move in this position can be judged against a tablebase,
  /// which is what a play-it-out drill needs.
  ///
  /// Seven, not five. The limit is how far the tables the server can reach go,
  /// and it asks Lichess rather than holding a set of its own — so the ceiling
  /// is the seven-piece one rather than the 940 MB a droplet could carry. Past
  /// seven no tablebase exists and the drill has nothing to promise.
  bool get canBePlayedOut => isExact && piecesOnBoard > 0 && piecesOnBoard <= 7;

  bool get whiteToMove {
    final parts = fen.split(' ');
    return parts.length < 2 || parts[1] == 'w';
  }

  factory EndgamePuzzle.fromJson(Map<String, dynamic> json) {
    List<String> stringList(String key) =>
        ((json[key] as List?) ?? const []).map((e) => e.toString()).toList();

    final gameJson = json['game'];

    return EndgamePuzzle(
      id: json['puzzle_id']?.toString() ?? '',
      fen: json['fen']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      mode: json['mode']?.toString() == 'draw'
          ? EndgameMode.draw
          : EndgameMode.win,
      winningMoves: stringList('winning_moves'),
      solution: stringList('solution'),
      solutionSan: stringList('solution_san'),
      piecesOnBoard: (json['piece_count'] as num?)?.toInt() ?? 0,
      pawnsOnBoard: (json['pawn_count'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? 'engine',
      difficulty: json['difficulty']?.toString() ?? 'medium',
      difficultyScore: (json['difficulty_score'] as num?)?.toInt(),
      dtz: (json['dtz'] as num?)?.toInt(),
      material: json['material']?.toString(),
      blunderElo: (json['blunder_elo'] as num?)?.toInt(),
      playedMove: json['played_move']?.toString(),
      game: gameJson is Map<String, dynamic>
          ? EndgameGame.fromJson(gameJson)
          : null,
    );
  }
}

/// Where the position came from. Children care, and it is true.
class EndgameGame {
  final String white;
  final String black;
  final String date;

  const EndgameGame(
      {required this.white, required this.black, required this.date});

  factory EndgameGame.fromJson(Map<String, dynamic> json) => EndgameGame(
        white: json['white']?.toString() ?? '',
        black: json['black']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
      );

  /// "Fischer, Robert James - Sherwin, James T, 1958"
  String get label {
    final year = date.length >= 4 ? date.substring(0, 4) : date;
    final names = '$white - $black';
    return year.contains('?') || year.isEmpty ? names : '$names, $year';
  }
}

enum EndgameSolveStatus { solving, solved, failed }

/// What came back from submitting a move.
class EndgameVerdict {
  final bool correct;

  /// Best reply from the demonstration line, when there is one.
  final String? opponentReply;

  final bool finished;

  /// True when the move holds the result but the user has already found this
  /// one. Not a mistake and not progress: they are hunting for the *other*
  /// answers, so the attempt stays open and the board goes back.
  final bool alreadyFound;

  /// Shown only after a failure. Plural on purpose: there is rarely exactly one
  /// right answer, and naming a single "the" move would misrepresent the
  /// position.
  final List<String> accepted;

  const EndgameVerdict({
    required this.correct,
    this.opponentReply,
    this.finished = false,
    this.alreadyFound = false,
    this.accepted = const [],
  });
}

/// Tracks one attempt at one position.
///
/// Board logic stays outside, as in [TacticsSolveSession]: the caller owns the
/// position and only reports what happened.
class EndgameSolveSession {
  /// [alreadyFound] holds moves the user has already produced for this position
  /// in an earlier attempt. They are still correct - they are simply not what
  /// is being looked for now, because the point of replaying a position with
  /// several answers is to find the ones you did not.
  EndgameSolveSession(this.puzzle, {Set<String>? alreadyFound})
      : _alreadyFound = alreadyFound ?? const {};

  final EndgamePuzzle puzzle;
  final Set<String> _alreadyFound;

  EndgameSolveStatus _status = EndgameSolveStatus.solving;
  bool _usedHint = false;
  int _mistakes = 0;
  String? _firstWrongSan;
  String? _foundMove;

  EndgameSolveStatus get status => _status;
  bool get isComplete => _status != EndgameSolveStatus.solving;
  bool get usedHint => _usedHint;
  int get mistakes => _mistakes;

  /// The first move the user tried that does not hold the result. Kept for the
  /// same reason as in the tactics session: it is what the child thought before
  /// they found it, and a list of later tries says less.
  String? get firstWrongSan => _firstWrongSan;

  /// UCI carries an optional promotion suffix and the same move arrives as
  /// `e7e8` or `e7e8q` depending on who wrote it. Raw string comparison would
  /// reject a correct promotion.
  static bool sameMove(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;
    if (a.substring(0, 4) != b.substring(0, 4)) return false;
    final promoA = a.length > 4 ? a[4].toLowerCase() : 'q';
    final promoB = b.length > 4 ? b[4].toLowerCase() : 'q';
    return promoA == promoB;
  }

  bool holdsResult(String uci) =>
      puzzle.winningMoves.any((m) => sameMove(uci, m));

  bool _isAlreadyFound(String uci) =>
      _alreadyFound.any((m) => sameMove(uci, m));

  /// Accepted moves still to be found. Empty once they are all in.
  List<String> get remainingMoves =>
      puzzle.winningMoves.where((m) => !_isAlreadyFound(m)).toList();

  /// The move that solved this attempt, once it has.
  String? get foundMove => _foundMove;

  /// One square, not the move: enough to unstick a child without answering for
  /// them. Marks the attempt as hinted so scoring can tell.
  ///
  /// Deliberately the destination and not the origin, unlike tactics. In an
  /// endgame the piece to move is usually obvious — there are three of them —
  /// and the question is *where*.
  String? revealHint() {
    // Points at one still to be found, not at one already in hand.
    final target = remainingMoves.isNotEmpty
        ? remainingMoves.first
        : (puzzle.winningMoves.isNotEmpty ? puzzle.winningMoves.first : null);
    if (target == null) return null;
    _usedHint = true;
    return target.substring(2, 4);
  }

  EndgameVerdict submit(String uci, {String? san}) {
    if (isComplete) return const EndgameVerdict(correct: false);

    if (holdsResult(uci) && _isAlreadyFound(uci)) {
      // Correct, but they are looking for a different one. Not counted as a
      // mistake: penalising a right move would be plainly unfair.
      return const EndgameVerdict(correct: true, alreadyFound: true);
    }

    if (!holdsResult(uci)) {
      _mistakes++;
      if (_firstWrongSan == null && san != null && san.trim().isNotEmpty) {
        _firstWrongSan = san.trim();
      }
      _status = EndgameSolveStatus.failed;
      return EndgameVerdict(
        correct: false,
        accepted: List.unmodifiable(puzzle.winningMoves),
      );
    }

    _status = EndgameSolveStatus.solved;
    _foundMove = uci;

    // The demonstration line starts with the engine's own choice. If the user
    // played a different but equally good move, the rest of that line no longer
    // applies to the position on the board, so no reply is offered.
    final line = puzzle.solution;
    final followsLine =
        line.isNotEmpty && sameMove(uci, line.first) && line.length > 1;

    return EndgameVerdict(
      correct: true,
      finished: true,
      opponentReply: followsLine ? line[1] : null,
    );
  }

  void retryAfterMistake() {
    if (_status == EndgameSolveStatus.failed) {
      _status = EndgameSolveStatus.solving;
    }
  }

  /// Solved unaided. A hinted or retried solve teaches something but is not
  /// evidence the child can find the move alone, so it must not raise a rating.
  bool get countsAsSolved =>
      _status == EndgameSolveStatus.solved && !_usedHint && _mistakes == 0;
}
