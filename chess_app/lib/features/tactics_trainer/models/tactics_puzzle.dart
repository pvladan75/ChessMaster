/// A puzzle from the Lichess database, and the state machine for solving it.
///
/// The solving rules live here, away from any widget, because this is where the
/// costly mistakes are: replaying the wrong move as the starting position, or
/// accepting a move that merely looks right.
library;

/// One puzzle as the server sends it.
///
/// The important subtlety is [fen]: it is the position *before* the opponent's
/// mistake, not the position the user is asked about. Playing [setupMove] on it
/// produces the puzzle position. Getting this backwards shows the user a
/// position one move too early, which looks plausible and is always wrong.
class TacticsPuzzle {
  final String id;
  final String fen;
  final String? setupMove;

  /// The full line after [setupMove]: even indices are the user's moves, odd
  /// indices the opponent's forced replies.
  final List<String> solution;

  final int rating;
  final List<String> themes;
  final List<String> trainableThemes;
  final String? gameUrl;
  final List<String> openingTags;

  const TacticsPuzzle({
    required this.id,
    required this.fen,
    required this.setupMove,
    required this.solution,
    required this.rating,
    this.themes = const [],
    this.trainableThemes = const [],
    this.gameUrl,
    this.openingTags = const [],
  });

  /// How many moves the user has to find.
  int get userMoveCount => (solution.length / 2).ceil();

  bool get isPlayable => setupMove != null && solution.isNotEmpty;

  factory TacticsPuzzle.fromJson(Map<String, dynamic> json) {
    List<String> stringList(String key) =>
        ((json[key] as List?) ?? const []).map((e) => e.toString()).toList();

    return TacticsPuzzle(
      id: json['puzzle_id']?.toString() ?? '',
      fen: json['fen']?.toString() ?? '',
      setupMove: json['setup_move']?.toString(),
      solution: stringList('solution'),
      rating: (json['rating'] as num?)?.toInt() ?? 1500,
      themes: stringList('themes'),
      trainableThemes: stringList('trainable_themes'),
      gameUrl: json['game_url']?.toString(),
      openingTags: stringList('opening_tags'),
    );
  }
}

enum SolveStatus { solving, solved, failed }

/// What came back from submitting a move.
class MoveVerdict {
  final bool correct;

  /// The opponent's forced reply, when the puzzle continues.
  final String? opponentReply;

  final bool puzzleSolved;

  /// The move that was expected — shown only after a failure, never before.
  final String? expected;

  const MoveVerdict({
    required this.correct,
    this.opponentReply,
    this.puzzleSolved = false,
    this.expected,
  });
}

/// Tracks progress through one puzzle's solution line.
///
/// Deliberately free of board logic: the caller owns the chess position and
/// tells this class whether a move happened to deliver mate. That keeps the
/// sequencing rules testable without a board.
class TacticsSolveSession {
  TacticsSolveSession(this.puzzle);

  final TacticsPuzzle puzzle;

  int _cursor = 0;
  SolveStatus _status = SolveStatus.solving;
  bool _usedHint = false;
  int _mistakes = 0;
  String? _firstWrongSan;

  SolveStatus get status => _status;
  bool get isComplete => _status != SolveStatus.solving;
  bool get usedHint => _usedHint;
  int get mistakes => _mistakes;

  /// The first move the user tried that was not the one the puzzle wanted.
  ///
  /// A puzzle is not one shot — a wrong move is refused and the user tries
  /// again — so there is no single "the move they played" here as there is for
  /// a position the trainer set. What a trainer can actually use is the **first
  /// wrong idea**: it says what the child thought before they found it, or
  /// instead of finding it.
  ///
  /// Null when they got it right straight away, which is not the same as "not
  /// recorded" and must not be shown as such.
  String? get firstWrongSan => _firstWrongSan;

  /// Moves the user has already found.
  int get solvedMoveCount => (_cursor / 2).floor();

  /// The move currently expected from the user, or null when the puzzle is over.
  String? get expectedMove =>
      _cursor < puzzle.solution.length ? puzzle.solution[_cursor] : null;

  /// The origin square of the expected move — enough to unstick someone without
  /// handing them the answer. Marks the attempt as hinted so scoring can tell.
  String? revealHint() {
    final expected = expectedMove;
    if (expected == null) return null;
    _usedHint = true;
    return expected.substring(0, 2);
  }

  /// UCI moves carry an optional promotion suffix, and the same move can arrive
  /// as `e7e8` or `e7e8q` depending on who generated it. Comparing raw strings
  /// would reject a correct promotion.
  static bool _sameMove(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;
    if (a.substring(0, 4) != b.substring(0, 4)) return false;

    final promoA = a.length > 4 ? a[4].toLowerCase() : 'q';
    final promoB = b.length > 4 ? b[4].toLowerCase() : 'q';
    return promoA == promoB;
  }

  /// Submits the user's move.
  ///
  /// [givesCheckmate] lets a mate that differs from the recorded line count as a
  /// solution — a forced mate the database happened not to pick is still a
  /// solved puzzle, and rejecting it would be indefensible to the user.
  /// [san] is the same move in notation a person reads, when the caller has it.
  /// It is only kept for the first mistake; nothing else here needs it.
  MoveVerdict submit(String uci, {bool givesCheckmate = false, String? san}) {
    if (isComplete) {
      return const MoveVerdict(correct: false);
    }

    final expected = expectedMove;
    if (expected == null) {
      _status = SolveStatus.solved;
      return const MoveVerdict(correct: true, puzzleSolved: true);
    }

    if (!_sameMove(uci, expected)) {
      if (givesCheckmate) {
        _status = SolveStatus.solved;
        _cursor = puzzle.solution.length;
        return const MoveVerdict(correct: true, puzzleSolved: true);
      }

      _mistakes++;
      // Only the first: later tries are attempts at correcting the first idea,
      // and a list of them says less than the one that started it.
      if (_firstWrongSan == null && san != null && san.trim().isNotEmpty) {
        _firstWrongSan = san.trim();
      }
      _status = SolveStatus.failed;
      return MoveVerdict(correct: false, expected: expected);
    }

    _cursor++;

    // Nothing left in the line: the last user move finished it.
    if (_cursor >= puzzle.solution.length) {
      _status = SolveStatus.solved;
      return const MoveVerdict(correct: true, puzzleSolved: true);
    }

    // Otherwise the next entry is the opponent's forced reply.
    final reply = puzzle.solution[_cursor];
    _cursor++;

    final solvedNow = _cursor >= puzzle.solution.length;
    if (solvedNow) _status = SolveStatus.solved;

    return MoveVerdict(
        correct: true, opponentReply: reply, puzzleSolved: solvedNow);
  }

  /// Lets the user try again after a wrong move, keeping the mistake on record
  /// so a retried puzzle is not reported as a clean solve.
  void retryAfterMistake() {
    if (_status == SolveStatus.failed) {
      _status = SolveStatus.solving;
    }
  }

  /// True when the attempt should count as solved for rating purposes.
  /// A hinted or retried solve teaches something, but it is not evidence the
  /// user can find the move unaided, so it must not raise their rating.
  bool get countsAsSolved =>
      _status == SolveStatus.solved && !_usedHint && _mistakes == 0;
}
