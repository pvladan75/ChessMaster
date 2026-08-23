/// One judged move of a play-it-out drill, and how to say it to a child.
///
/// The sentence lives here rather than in the screen so it can be tested. What
/// the drill says is most of what it is: the same verdict phrased as "wrong"
/// instead of "that let the win go" teaches something different, and a child
/// told "eighteen moves to go" would be told something untrue.
library;

class DrillStep {
  const DrillStep({
    required this.held,
    required this.goal,
    required this.outcome,
    required this.playedSan,
    required this.fen,
    this.closer,
    this.replySan,
    this.finished,
  });

  /// Whether the move kept the result the position started with.
  final bool held;

  /// What there was to hold: 'win' or 'draw'.
  final String goal;

  /// What is there now: 'win', 'draw' or 'loss'.
  final String outcome;

  final String playedSan;

  /// The position after the opponent's reply, or after the move when the drill
  /// ended there.
  final String fen;

  /// Nearer to converting than before. Null when the question does not apply —
  /// in a drawn position there is nothing to get nearer to.
  final bool? closer;

  final String? replySan;

  /// 'mate', 'stalemate', 'insufficient', 'draw_rule', or null while it runs.
  final String? finished;

  /// True once the drill cannot continue, whichever way it went.
  bool get isOver => !held || finished != null;

  factory DrillStep.fromJson(Map<String, dynamic> json) => DrillStep(
        held: json['held'] == true,
        goal: json['goal']?.toString() ?? 'win',
        outcome: json['outcome']?.toString() ?? 'draw',
        playedSan: json['playedSan']?.toString() ?? '',
        fen: json['fen']?.toString() ?? '',
        closer: json['closer'] is bool ? json['closer'] as bool : null,
        replySan: (json['reply'] as Map<String, dynamic>?)?['san']?.toString(),
        finished: json['finished']?.toString(),
      );
}

/// What to tell the child after one judged move.
///
/// Never a number of moves left. DTZ counts half-moves to the next capture or
/// pawn move rather than moves to mate, and after a conversion it starts again,
/// so "eighteen moves to go" would be wrong twice over. What is true, and what
/// a child can act on, is whether the result held and whether they are nearer
/// than they were.
String drillFeedbackText(DrillStep step) {
  if (!step.held) {
    return step.goal == 'draw'
        ? '${step.playedSan} gubi remi. Ovde se prekida.'
        : '${step.playedSan} ispušta dobitak — ostaje remi.';
  }

  switch (step.finished) {
    case 'mate':
      return 'Mat! Završnicu ste odigrali do kraja.';
    case 'stalemate':
      return 'Pat — remi je održan.';
    case 'insufficient':
      return 'Nema dovoljno materijala za mat — remi.';
    case 'draw_rule':
      // The one ending that looks like success and is not. A win the tables
      // call a win is convertible inside the fifty moves, so running the count
      // out means the moves were spent, not that the position was not winning.
      return step.goal == 'draw'
          ? 'Pedeset poteza bez uzimanja — remi je održan.'
          : 'Pedeset poteza bez uzimanja i bez poteza pešaka — po pravilu je '
              'remi. Dobitak je bio tu, ali je potrošeno previše poteza.';
  }

  final reply =
      step.replySan == null ? '' : ' Protivnik igra ${step.replySan}.';
  if (step.goal == 'draw') return 'Tačno — remi je održan.$reply';
  if (step.closer == true) {
    return 'Tačno — dobitak je zadržan i prišli ste bliže.$reply';
  }
  if (step.closer == false) {
    // Correct and worth saying so, because a child who shuffles will otherwise
    // read "tačno" as "that was the move" and keep shuffling.
    return 'Tačno, dobitak je zadržan — ali niste prišli bliže.$reply';
  }
  return 'Tačno — dobitak je zadržan.$reply';
}
