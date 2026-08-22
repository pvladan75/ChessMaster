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
  });

  bool get isPlayable => fen.isNotEmpty && winningMoves.isNotEmpty;

  /// True when the result is known exactly rather than estimated.
  bool get isExact => source == 'syzygy';

  /// Whether the position is small enough for the engine to be judged against
  /// a tablebase on every move, which is what a play-it-out drill needs.
  bool get canBePlayedOut => isExact && piecesOnBoard > 0 && piecesOnBoard <= 5;

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

  /// Shown only after a failure. Plural on purpose: there is rarely exactly one
  /// right answer, and naming a single "the" move would misrepresent the
  /// position.
  final List<String> accepted;

  const EndgameVerdict({
    required this.correct,
    this.opponentReply,
    this.finished = false,
    this.accepted = const [],
  });
}

/// Tracks one attempt at one position.
///
/// Board logic stays outside, as in [TacticsSolveSession]: the caller owns the
/// position and only reports what happened.
class EndgameSolveSession {
  EndgameSolveSession(this.puzzle);

  final EndgamePuzzle puzzle;

  EndgameSolveStatus _status = EndgameSolveStatus.solving;
  bool _usedHint = false;
  int _mistakes = 0;
  String? _firstWrongSan;

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

  /// One square, not the move: enough to unstick a child without answering for
  /// them. Marks the attempt as hinted so scoring can tell.
  ///
  /// Deliberately the destination and not the origin, unlike tactics. In an
  /// endgame the piece to move is usually obvious — there are three of them —
  /// and the question is *where*.
  String? revealHint() {
    if (puzzle.winningMoves.isEmpty) return null;
    _usedHint = true;
    return puzzle.winningMoves.first.substring(2, 4);
  }

  EndgameVerdict submit(String uci, {String? san}) {
    if (isComplete) return const EndgameVerdict(correct: false);

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
