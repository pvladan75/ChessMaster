/// The clock as a fact of a moment — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, §3
/// („The clock is a fact, not a filter") and phase 3.
///
/// A move's clock (`[%clk]`, [AnalysisNode.clockSeconds]) is what the mover
/// had **after** the move, increment included. So the time left is exact, and
/// the time the move took is the mover's previous clock minus this one, plus
/// the increment — which only the game's `TimeControl` header says. Without
/// the header only the time left is said (the owner's choice of 25.9.2026).
/// Nothing is dropped for time trouble; the words may name it.
library;

/// A game's `TimeControl`: [baseSeconds] each, [incrementSeconds] a move.
class TimeControl {
  const TimeControl(this.baseSeconds, this.incrementSeconds);

  final int baseSeconds;
  final int incrementSeconds;

  /// `180+2` or `600`, the forms online games write; null for anything else
  /// (`-`, `?`, the multi-period forms of over-the-board events), which leaves
  /// only the time left to be said.
  static TimeControl? parse(String? header) {
    final m = RegExp(r'^\s*(\d+)(?:\+(\d+))?\s*$').firstMatch(header ?? '');
    if (m == null) return null;
    return TimeControl(int.parse(m.group(1)!), int.parse(m.group(2) ?? '0'));
  }
}

/// The clock of move [index] of [clocks] (every move from the game's start,
/// null where it carried none): the time left, and the time spent when the
/// time control is known. Null when that move has no clock.
({double left, double? spent})? moveClock(
    List<double?> clocks, int index, TimeControl? control) {
  if (index < 0 || index >= clocks.length) return null;
  final left = clocks[index];
  if (left == null) return null;
  if (control == null) return (left: left, spent: null);
  // The mover's own previous clock is two moves back; before their first move
  // they had the base time.
  final before =
      index >= 2 ? clocks[index - 2] : control.baseSeconds.toDouble();
  if (before == null) return (left: left, spent: null);
  final spent = before - left + control.incrementSeconds;
  return (left: left, spent: spent < 0 ? 0 : spent);
}

String _duration(double seconds) {
  final whole = seconds.round();
  if (whole < 60) return whole == 1 ? '1 second' : '$whole seconds';
  final minutes = whole ~/ 60;
  final rest = whole % 60;
  final m = minutes == 1 ? '1 minute' : '$minutes minutes';
  if (rest == 0) return m;
  return '$m ${rest == 1 ? '1 second' : '$rest seconds'}';
}

/// The clock of a moment in words, for the facts the model is given:
/// „12 seconds left on White's clock; the move took under a second." Null
/// when the move has no clock.
String? clockWords(
    String mover, List<double?> clocks, int index, TimeControl? control) {
  final clock = moveClock(clocks, index, control);
  if (clock == null) return null;
  final left = '${_duration(clock.left)} left on $mover\'s clock';
  final spent = clock.spent;
  if (spent == null) return '$left.';
  final took = spent < 1 ? 'under a second' : _duration(spent);
  return '$left; the move took $took.';
}
