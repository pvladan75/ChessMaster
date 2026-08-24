// lichessPacing.js — how fast this server is allowed to ask Lichess anything.
//
// One implementation, because there are two callers and the rule is the same
// for both. A second copy of a limit is a second chance to get it wrong, and
// this one is invisible when it is wrong: too fast simply works, until the day
// it does not.
//
// What Lichess asks for, and what it does when it is not given:
//
//   * Anonymous callers get roughly one request a second; a token raises that
//     to fifteen or twenty. So the token is not only about being polite - it is
//     most of the allowance.
//   * The Explorer routes are computed rather than served from a file, and the
//     documented request is 100-200 ms of daylight between consecutive calls.
//   * Crossing the line answers 429 and blocks **the address** for a minute -
//     and for longer, up to an hour, for whoever keeps knocking during it.
//
// That last one is why this module exists at all rather than a `setTimeout`
// somewhere: this server has one address for every child in the app, so a retry
// into a 429 is not a wasted request, it is what turns one lost minute into a
// lost hour for everybody at once.

const MIN_REQUEST_GAP_MS = 150;
const RATE_LIMIT_COOLDOWN_MS = 60 * 1000;

/**
 * A queue that spaces out everything leaving one service, and serves the
 * cooldown after a 429 itself.
 *
 * `now` and `sleep` are injected so a test can spend a minute without waiting
 * one.
 */
function createPacer({
  minGapMs = MIN_REQUEST_GAP_MS,
  cooldownMs = RATE_LIMIT_COOLDOWN_MS,
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  let queue = Promise.resolve();
  // Behind by one gap, so the first request goes without waiting. Zero would
  // also work on a real clock, but only because Date.now() is a large number -
  // a right answer for the wrong reason, and one that stops being right the
  // moment anything hands this a clock of its own.
  let lastSentAt = now() - minGapMs;
  let blockedUntil = 0;

  return {
    /// Milliseconds left of a Lichess block, or 0. The caller throws its own
    /// error for it: the two services report unavailability in their own words,
    /// and pacing is not the place to decide what they say.
    blockedForMs: () => Math.max(0, blockedUntil - now()),

    /// Called on a 429, and only on a 429.
    block: () => {
      blockedUntil = now() + cooldownMs;
    },

    /// Sends one request, no sooner than `minGapMs` after the previous one.
    spaced(send) {
      const run = queue.then(async () => {
        const wait = minGapMs - (now() - lastSentAt);
        if (wait > 0) await sleep(wait);
        lastSentAt = now();
        return send();
      });
      // The chain has to survive a failed request. Without swallowing here, one
      // refused token would stop everything after it from ever being sent -
      // which is the same silent stall this module is meant to prevent.
      queue = run.then(() => {}, () => {});
      return run;
    },

    reset() {
      lastSentAt = now() - minGapMs;
      blockedUntil = 0;
    },
  };
}

module.exports = {
  createPacer,
  MIN_REQUEST_GAP_MS,
  RATE_LIMIT_COOLDOWN_MS,
};
