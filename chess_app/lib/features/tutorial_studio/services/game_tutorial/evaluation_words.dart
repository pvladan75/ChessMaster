/// The words a generated tutorial may use for an evaluation, and the steps
/// those words come in.
///
/// Ported from `tools/game_annotate/skeleton.py` — `words_for`, `LEVELS` and
/// `standing` — as the first piece of phase 1 of `docs/PLAN-SKELET.md`. The
/// harness is the reference implementation: every string here is held to what
/// it answered, for every evaluation the ten fixture games carry and for the
/// boundary cases in `test/fixtures/game_tutorial/evaluation_words_cases.json`,
/// which the harness wrote too.
///
/// **One list of thresholds for both functions.** The filler's lexicon judges a
/// move by the same steps the words are spoken in, and two copies of a
/// threshold are how a phrase comes to disagree with the evaluation printed
/// beside it.
library;

/// Where the words change, in pawns: under 0.5 about even, under 1.5 slightly
/// better, under 3.0 clearly better, winning from there.
const List<double> evaluationLevels = [0.5, 1.5, 3.0];

const _levelWords = ['slightly better', 'clearly better', 'winning'];

int _level(double size) =>
    evaluationLevels.where((step) => size >= step).length;

/// An evaluation from White's side — `+0.39`, `#-4`, `draw`, `checkmate` — as
/// the words a sentence may use.
///
/// Null and empty are `unknown`. Any other text that is not an evaluation
/// throws, as the harness does: a facts file that says something else is a
/// fault to see, not a sentence to guess.
String wordsFor(String? evalText) {
  if (evalText == null || evalText.isEmpty) return 'unknown';
  if (evalText == 'checkmate') return 'checkmate';
  if (evalText == 'draw') return 'a draw';
  if (evalText.startsWith('#')) {
    final moves = int.parse(evalText.substring(1));
    return moves > 0 ? 'White mates in $moves' : 'Black mates in ${-moves}';
  }
  final value = double.parse(evalText);
  final level = _level(value.abs());
  if (level == 0) return 'about even';
  return '${value > 0 ? 'White' : 'Black'} is ${_levelWords[level - 1]}';
}

/// An evaluation as [mover] (`White` or `Black`) sees it, in the steps
/// [wordsFor] speaks in.
///
/// From -4 to 4: 0 about even, 1 to 3 slightly better to winning, 4 a forced
/// mate; negative when the advantage is the other side's. Null when the
/// evaluation is unknown.
int? standing(String? evalText, String mover) {
  if (evalText == null || evalText.isEmpty || evalText == 'unknown') {
    return null;
  }
  if (evalText == 'draw') return 0;
  // Only ever the evaluation after a move that mates, by the side that moved:
  // a position whose side to move is mated has no candidates to be judged.
  if (evalText == 'checkmate') return 4;
  final bool white;
  final int level;
  if (evalText.startsWith('#')) {
    white = int.parse(evalText.substring(1)) > 0;
    level = 4;
  } else {
    final value = double.parse(evalText);
    white = value > 0;
    level = _level(value.abs());
  }
  if (level == 0) return 0;
  return white == (mover == 'White') ? level : -level;
}
