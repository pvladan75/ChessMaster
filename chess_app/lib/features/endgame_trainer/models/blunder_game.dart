import 'endgame_puzzle.dart' show EndgameSolveSession;

/// One mistake inside a walked game.
class GameBlunder {
  const GameBlunder({
    required this.ply,
    required this.fen,
    required this.side,
    required this.played,
    required this.shouldPlay,
    required this.shouldPlayUci,
    required this.outcomeBefore,
    required this.outcomeAfter,
    this.material,
    this.cause,
  });

  /// Where in [BlunderGame.moves] it sits. The first is always 0, because the
  /// record starts at the position where the game first went wrong.
  final int ply;

  final String fen;

  /// 'white' or 'black' — which of them made it. It alternates in real games,
  /// which is why the board is not turned automatically at every stop.
  final String side;

  final String played;
  final List<String> shouldPlay;
  final List<String> shouldPlayUci;

  /// 'win' or 'draw' before, one worse after.
  final String outcomeBefore;
  final String outcomeAfter;

  final String? material;

  /// 'outcome' when the result changed whatever the counter said, 'fifty_move'
  /// when the win was there the whole time and the fifty moves ran out under
  /// it. Different lessons, and worth saying differently.
  final String? cause;

  bool get lostAWin => outcomeBefore == 'win';

  factory GameBlunder.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) =>
        ((json[key] as List?) ?? const []).map((e) => e.toString()).toList();
    return GameBlunder(
      ply: (json['ply'] as num?)?.toInt() ?? 0,
      fen: json['fen']?.toString() ?? '',
      side: json['side']?.toString() ?? 'white',
      played: json['played']?.toString() ?? '',
      shouldPlay: list('should_play'),
      shouldPlayUci: list('should_play_uci'),
      outcomeBefore: json['outcome_before']?.toString() ?? 'win',
      outcomeAfter: json['outcome_after']?.toString() ?? 'draw',
      material: json['material']?.toString(),
      cause: json['cause']?.toString(),
    );
  }
}

/// A game from where it first went wrong to the end, with every mistake in it.
class BlunderGame {
  const BlunderGame({
    required this.id,
    required this.startFen,
    required this.moves,
    required this.blunders,
    this.white = '',
    this.black = '',
    this.whiteElo,
    this.blackElo,
    this.date = '',
    this.event = '',
    this.result = '',
  });

  final String id;

  /// The board the walk opens on, which is also the first mistake's position.
  final String startFen;

  /// The game as it was actually played from there, in SAN.
  final List<String> moves;

  final List<GameBlunder> blunders;

  final String white;
  final String black;
  final int? whiteElo;
  final int? blackElo;
  final String date;
  final String event;
  final String result;

  bool get isPlayable =>
      startFen.isNotEmpty && moves.isNotEmpty && blunders.isNotEmpty;

  /// "Seger, Ruediger (2416) - Lambert, Andreas (2204), 2005"
  String get label {
    String named(String name, int? elo) =>
        elo == null || elo == 0 ? name : '$name ($elo)';
    final year = date.length >= 4 ? date.substring(0, 4) : date;
    final pair = '${named(white, whiteElo)} - ${named(black, blackElo)}';
    return year.contains('?') || year.isEmpty ? pair : '$pair, $year';
  }

  factory BlunderGame.fromJson(Map<String, dynamic> json) => BlunderGame(
        id: json['game_id']?.toString() ?? '',
        startFen: json['start_fen']?.toString() ?? '',
        moves: ((json['moves'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        blunders: ((json['blunders'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GameBlunder.fromJson)
            .toList(),
        white: json['white']?.toString() ?? '',
        black: json['black']?.toString() ?? '',
        whiteElo: (json['white_elo'] as num?)?.toInt(),
        blackElo: (json['black_elo'] as num?)?.toInt(),
        date: json['date']?.toString() ?? '',
        event: json['event']?.toString() ?? '',
        result: json['result']?.toString() ?? '',
      );
}

/// What came back from trying a move at a stop.
class WalkVerdict {
  const WalkVerdict({
    required this.correct,
    this.alreadyOver = false,
    this.playedSan,
  });

  final bool correct;

  /// The stop had already been answered, so nothing was judged.
  final bool alreadyOver;

  final String? playedSan;
}

/// Walking one game: where the cursor is, and how far it may go.
///
/// Board logic stays outside, as everywhere else here — this owns the rules and
/// nothing else, which is what makes them testable without a board.
///
/// The rule that shapes the whole thing: moves already seen can be stepped
/// through freely, and an unanswered mistake is a wall. Free navigation without
/// the wall would let a child page past the question to the answer, and a wall
/// without navigation would make them replay from the start to look at what
/// just happened.
class BlunderWalk {
  BlunderWalk(this.game);

  final BlunderGame game;

  int _cursor = 0;
  final Set<int> _answered = {};
  final Set<int> _revealed = {};

  /// Plies played from [BlunderGame.startFen]. Zero means the opening board.
  int get cursor => _cursor;

  /// How far forward the cursor may go: the next unanswered mistake, or the end
  /// of the game once they are all done.
  int get frontier {
    for (final blunder in game.blunders) {
      if (!_answered.contains(blunder.ply)) return blunder.ply;
    }
    return game.moves.length;
  }

  /// The mistake standing at the cursor and still waiting for an answer.
  GameBlunder? get pending {
    for (final blunder in game.blunders) {
      if (blunder.ply == _cursor && !_answered.contains(blunder.ply)) {
        return blunder;
      }
    }
    return null;
  }

  /// The mistake at the cursor whether or not it has been answered, so a walk
  /// back over one can still say what happened there.
  GameBlunder? get atCursor {
    for (final blunder in game.blunders) {
      if (blunder.ply == _cursor) return blunder;
    }
    return null;
  }

  bool get canGoForward => _cursor < frontier;
  bool get canGoBack => _cursor > 0;

  /// True once every mistake has been answered and the cursor has run out.
  bool get isFinished =>
      _answered.length == game.blunders.length && _cursor >= game.moves.length;

  int get answeredCount => _answered.length;
  int get totalCount => game.blunders.length;

  /// Answered by finding it rather than by being shown it.
  int get solvedCount =>
      _answered.where((ply) => !_revealed.contains(ply)).length;

  bool wasRevealed(int ply) => _revealed.contains(ply);

  bool forward() {
    if (!canGoForward) return false;
    _cursor++;
    return true;
  }

  bool back() {
    if (!canGoBack) return false;
    _cursor--;
    return true;
  }

  /// Jumps to the wall, which is where the work is.
  void toPending() => _cursor = frontier;

  /// Try a move at the current stop.
  WalkVerdict submit(String uci, {String? san}) {
    final blunder = pending;
    if (blunder == null) {
      return WalkVerdict(correct: false, alreadyOver: true, playedSan: san);
    }
    final correct =
        blunder.shouldPlayUci.any((m) => EndgameSolveSession.sameMove(uci, m));
    if (correct) _answered.add(blunder.ply);
    return WalkVerdict(correct: correct, playedSan: san);
  }

  /// Gives up on this stop and opens the way past it.
  ///
  /// Counted apart from a solve rather than refused: a child who cannot find it
  /// should still get to see the rest of the game, and a wall with no door is
  /// how a session ends with the app closed.
  GameBlunder? reveal() {
    final blunder = pending;
    if (blunder == null) return null;
    _revealed.add(blunder.ply);
    _answered.add(blunder.ply);
    return blunder;
  }
}
