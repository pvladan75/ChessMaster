/// Which position comes next when the student is free to choose.
///
/// Homework used to be a queue: the screen took the unanswered positions in the
/// trainer's order and walked through them one at a time, with no way to look
/// ahead, skip, or go back. A child stuck on the third position could not reach
/// the fourth — and homework that cannot be finished is homework that does not
/// get done.
///
/// Free order does not throw the trainer's order away. It is still the order
/// everything is listed and stepped through in; it just stops being a cage.
library;

/// The next position still to be answered, starting after [from].
///
/// Wraps to the beginning, so a position skipped early is still reachable from
/// the end — otherwise "next" would quietly run out with work left behind, and
/// the child would have to know to go back and look.
///
/// Returns null when nothing is left, which is the only honest way to say "you
/// are done" without pointing at a position.
int? nextUnanswered({
  required List<String> puzzleIds,
  required Set<String> answered,
  required int from,
}) {
  final count = puzzleIds.length;
  if (count == 0) return null;

  for (var step = 1; step <= count; step++) {
    final index = (from + step) % count;
    if (!answered.contains(puzzleIds[index])) return index;
  }
  return null;
}

/// Where to land when the assignment is opened: the first position not yet
/// answered, in the trainer's order.
///
/// Not "where they left off": a student who skipped position two and answered
/// three should be taken back to two, because that is the first thing still
/// waiting.
int? firstUnanswered({
  required List<String> puzzleIds,
  required Set<String> answered,
}) {
  for (var index = 0; index < puzzleIds.length; index++) {
    if (!answered.contains(puzzleIds[index])) return index;
  }
  return null;
}
