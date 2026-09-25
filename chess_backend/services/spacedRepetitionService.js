// spacedRepetitionService.js
// SM-2 scheduling — the arithmetic the mistake drill and the repertoire drill
// share. It once also kept a schedule over a tutorial's parts (`review_items`),
// which went with the parts (docs/PLAN-TUTORIJAL-VIDEO.md, D9).
//
// The algorithm is SuperMemo 2, the same one Anki and Chessable's MoveTrainer
// descend from. It is kept as a pure function because every mistake in it is
// invisible: a wrong interval does not throw, it just quietly stops teaching —
// either burying a position the student has forgotten, or asking them about one
// they know cold.

/// How a student rates their recall, mapped to SM-2's 0–5 quality scale.
///
/// Four buttons rather than six: asking a child to distinguish six shades of
/// remembering produces noise, not data. Anything below 3 counts as a failure in
/// SM-2, which is why "again" sits at 1 and the other three sit above the line.
const GRADES = {
  again: 1,
  hard: 3,
  good: 4,
  easy: 5,
};

/// SM-2's floor. Below this the intervals collapse and an item that a student
/// genuinely finds hard would be shown several times a day forever.
const MIN_EASE = 1.3;
const DEFAULT_EASE = 2.5;

/// First two intervals are fixed by the algorithm; only from the third does the
/// ease factor start compounding.
const FIRST_INTERVAL = 1;
const SECOND_INTERVAL = 6;

function isValidGrade(quality) {
  return Number.isInteger(quality) && quality >= 0 && quality <= 5;
}

/// Computes the next schedule for one item.
///
/// Pure: takes the current state and the grade, returns the new state. `now` is
/// a parameter so the interval boundaries are testable without waiting a day.
function schedule(current, quality, now = new Date()) {
  const ease = Number(current?.ease_factor ?? DEFAULT_EASE);
  const repetitions = Number(current?.repetitions ?? 0);
  const lapses = Number(current?.lapses ?? 0);

  // SM-2's ease adjustment. Applied on every review, including failures — a
  // repeatedly forgotten item should get easier to re-encounter, not just reset.
  const delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
  const nextEase = Math.max(MIN_EASE, Math.round((ease + delta) * 100) / 100);

  let nextRepetitions;
  let intervalDays;
  let nextLapses = lapses;

  if (quality < 3) {
    // Failed. The repetition count restarts, but the ease factor carries over,
    // so an item that keeps being forgotten stays permanently more frequent.
    nextRepetitions = 0;
    intervalDays = 0; // due again in this same session
    nextLapses = lapses + 1;
  } else if (repetitions === 0) {
    nextRepetitions = 1;
    intervalDays = FIRST_INTERVAL;
  } else if (repetitions === 1) {
    nextRepetitions = 2;
    intervalDays = SECOND_INTERVAL;
  } else {
    nextRepetitions = repetitions + 1;
    const previous = Number(current?.interval_days ?? SECOND_INTERVAL);
    intervalDays = Math.max(1, Math.round(previous * nextEase));
  }

  // A failed item comes back after a short delay rather than instantly, so the
  // student is not shown the answer they just saw.
  const dueAt = new Date(
    intervalDays === 0
      ? now.getTime() + 10 * 60 * 1000
      : now.getTime() + intervalDays * 24 * 60 * 60 * 1000
  );

  return {
    easeFactor: nextEase,
    intervalDays,
    repetitions: nextRepetitions,
    lapses: nextLapses,
    dueAt,
  };
}

/// Human-readable "next review in ...", for the button that produced it.
function describeInterval(intervalDays) {
  if (intervalDays === 0) return 'in a few minutes';
  if (intervalDays === 1) return 'tomorrow';
  if (intervalDays < 7) return `in ${intervalDays} days`;
  if (intervalDays < 30) {
    const weeks = Math.round(intervalDays / 7);
    return weeks === 1 ? 'in a week' : `in ${weeks} weeks`;
  }
  const months = Math.round(intervalDays / 30);
  return months === 1 ? 'in a month' : `in ${months} months`;
}

module.exports = {
  GRADES,
  MIN_EASE,
  DEFAULT_EASE,
  isValidGrade,
  schedule,
  describeInterval,
};
