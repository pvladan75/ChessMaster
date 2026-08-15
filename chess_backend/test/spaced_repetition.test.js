// spaced_repetition.test.js
// Pins the SM-2 schedule.
//
// Every mistake in this algorithm is silent: a wrong interval does not throw, it
// just stops teaching — either burying something the student has forgotten or
// asking them again about a position they know cold. So the intervals, the ease
// floor, and what happens on a lapse are all nailed down here.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  GRADES,
  MIN_EASE,
  DEFAULT_EASE,
  isValidGrade,
  schedule,
  describeInterval,
} = require('../services/spacedRepetitionService');

const NOW = new Date('2026-08-15T12:00:00Z');

function daysBetween(from, to) {
  return Math.round((to.getTime() - from.getTime()) / (24 * 60 * 60 * 1000));
}

function fresh(overrides = {}) {
  return { ease_factor: DEFAULT_EASE, interval_days: 0, repetitions: 0, lapses: 0, ...overrides };
}

test('the first two intervals are fixed at 1 and 6 days', () => {
  const first = schedule(fresh(), GRADES.good, NOW);
  assert.equal(first.intervalDays, 1);
  assert.equal(first.repetitions, 1);

  const second = schedule(
    fresh({ repetitions: 1, interval_days: 1, ease_factor: first.easeFactor }),
    GRADES.good,
    NOW
  );
  assert.equal(second.intervalDays, 6, 'SM-2 fixes the second interval regardless of ease');
  assert.equal(second.repetitions, 2);
});

test('from the third review the interval compounds by the ease factor', () => {
  const third = schedule(
    fresh({ repetitions: 2, interval_days: 6, ease_factor: 2.5 }),
    GRADES.good,
    NOW
  );

  // 6 × 2.5 = 15
  assert.equal(third.intervalDays, 15);
  assert.equal(third.repetitions, 3);
});

test('the due date matches the interval it reports', () => {
  const result = schedule(fresh({ repetitions: 2, interval_days: 6 }), GRADES.good, NOW);
  assert.equal(daysBetween(NOW, result.dueAt), result.intervalDays);
});

test('a failed item comes back in the same session, not tomorrow', () => {
  const result = schedule(fresh({ repetitions: 5, interval_days: 40 }), GRADES.again, NOW);

  assert.equal(result.intervalDays, 0);
  assert.equal(result.repetitions, 0, 'the repetition count restarts on a lapse');
  // Minutes, not days: the point is to see it again today, but not instantly
  // after having just been shown the answer.
  const minutes = (result.dueAt.getTime() - NOW.getTime()) / 60000;
  assert.ok(minutes > 0 && minutes <= 60, `expected a short delay, got ${minutes} minutes`);
});

test('a lapse keeps the ease factor rather than resetting it', () => {
  const hardened = schedule(fresh({ repetitions: 5, interval_days: 40, ease_factor: 1.8 }), GRADES.again, NOW);

  // Resetting ease to the default would make a chronically forgotten position
  // drift back to long intervals as soon as it is remembered once.
  assert.ok(hardened.easeFactor < DEFAULT_EASE);
  assert.equal(hardened.lapses, 1);
});

test('lapses accumulate across failures', () => {
  const once = schedule(fresh({ lapses: 3 }), GRADES.again, NOW);
  assert.equal(once.lapses, 4);
});

test('the ease factor never falls below the SM-2 floor', () => {
  let state = fresh({ ease_factor: 1.35, repetitions: 4, interval_days: 20 });

  // Repeated failures must not drive ease toward zero; below the floor the
  // intervals collapse and the item is shown several times a day forever.
  for (let i = 0; i < 10; i++) {
    const next = schedule(state, GRADES.again, NOW);
    state = {
      ease_factor: next.easeFactor,
      interval_days: next.intervalDays,
      repetitions: next.repetitions,
      lapses: next.lapses,
    };
  }

  assert.equal(state.ease_factor, MIN_EASE);
});

test('"easy" raises the ease factor and "hard" lowers it', () => {
  const easy = schedule(fresh({ repetitions: 2, interval_days: 6 }), GRADES.easy, NOW);
  const good = schedule(fresh({ repetitions: 2, interval_days: 6 }), GRADES.good, NOW);
  const hard = schedule(fresh({ repetitions: 2, interval_days: 6 }), GRADES.hard, NOW);

  assert.ok(easy.easeFactor > good.easeFactor);
  assert.ok(good.easeFactor >= hard.easeFactor);
  // And the intervals follow, so the buttons do what their labels promise.
  assert.ok(easy.intervalDays > hard.intervalDays);
});

test('grade 3 passes while grade 2 fails, at the SM-2 boundary', () => {
  assert.ok(schedule(fresh({ repetitions: 3, interval_days: 10 }), 3, NOW).intervalDays > 0);
  assert.equal(schedule(fresh({ repetitions: 3, interval_days: 10 }), 2, NOW).intervalDays, 0);
});

test('an interval never rounds down to zero on a pass', () => {
  // A heavily-lapsed item at minimum ease with a 1-day interval: 1 × 1.3 = 1.3,
  // which must not round to a "due immediately" schedule.
  const result = schedule(
    fresh({ repetitions: 4, interval_days: 1, ease_factor: MIN_EASE }),
    GRADES.hard,
    NOW
  );
  assert.ok(result.intervalDays >= 1);
});

test('missing state is treated as a brand new item', () => {
  const fromNothing = schedule(undefined, GRADES.good, NOW);
  assert.equal(fromNothing.intervalDays, 1);
  assert.equal(fromNothing.repetitions, 1);
});

test('only whole grades 0 to 5 are accepted', () => {
  assert.ok(isValidGrade(0));
  assert.ok(isValidGrade(5));
  assert.ok(!isValidGrade(6));
  assert.ok(!isValidGrade(-1));
  assert.ok(!isValidGrade(3.5));
  assert.ok(!isValidGrade('4'));
});

test('intervals are described in natural Serbian', () => {
  assert.equal(describeInterval(0), 'za nekoliko minuta');
  assert.equal(describeInterval(1), 'sutra');
  assert.equal(describeInterval(3), 'za 3 dana');
  assert.equal(describeInterval(7), 'za nedelju dana');
  assert.equal(describeInterval(14), 'za 2 nedelje');
  assert.equal(describeInterval(30), 'za mesec dana');
  assert.equal(describeInterval(60), 'za 2 meseca');
});

test('a long-running schedule grows but stays finite', () => {
  let state = fresh();

  // Twelve consecutive "good" answers — roughly a year of reviews.
  for (let i = 0; i < 12; i++) {
    const next = schedule(state, GRADES.good, NOW);
    state = {
      ease_factor: next.easeFactor,
      interval_days: next.intervalDays,
      repetitions: next.repetitions,
      lapses: next.lapses,
    };
  }

  assert.ok(state.interval_days > 365, 'a well-known position should drift far out');
  assert.ok(Number.isFinite(state.interval_days));
});
