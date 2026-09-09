// renderQueue.js — one film at a time, and the rest wait their turn.
//
// „Ja bih ih stavio u red, jer neko od korisnika će time svoj video dobiti pre,
// a ovaj drugi kasnije (kao što bi i dobio da rade paralelno)."
//
// That is the whole argument and it is right: two renders running side by side
// finish together, both late, and each has been sharing one CPU with the other.
// In a queue the first is done in its own time and the second is no later than
// it would have been — the same total, differently distributed, and now with a
// bar that means something. Rendering is CPU work with an ffmpeg process
// attached, so there is nothing to gain by overlapping it.
//
// **The waiting is bounded, and that is not a detail.** The render happens
// inside the request the client already made, and that request has two ceilings
// above it: nginx gives up on a proxied request after 300 s (`deploy/
// app-setup.sh`) and the app's own HTTP timeout is five minutes. A queue with
// no limit turns „you are third" into a request that dies on the wire while the
// server carries on rendering a film nobody will collect. So a queue that is
// already full refuses immediately and says so, which is a sentence a trainer
// can act on.
const logger = require('./logger');

/// How many films may be drawn at once.
///
/// One, deliberately. Two renders on one CPU take twice as long each and finish
/// together; the machine this runs on has a small number of cores and an ffmpeg
/// process per film on top. Raise it only with a measurement.
function concurrency() {
  const n = Number(process.env.RENDER_CONCURRENCY);
  return Number.isInteger(n) && n > 0 ? n : 1;
}

/// How many may be waiting before the next one is turned away.
///
/// Two. A long tutorial takes a minute or two to draw, and the request waiting
/// for it has 300 s before nginx closes it — so a third in the queue is a
/// promise this server cannot keep.
function maxWaiting() {
  const n = Number(process.env.RENDER_QUEUE_MAX);
  return Number.isInteger(n) && n >= 0 ? n : 2;
}

/// How many films one account may have here at once, drawing plus waiting.
///
/// Two. **Without this, one trainer pressing „Export" three times fills the
/// whole queue and every other trainer is refused with a 429** until it drains
/// — measured, not supposed: with `RENDER_CONCURRENCY` 1 and `RENDER_QUEUE_MAX`
/// 2, three is the number that fits, and first-come-first-served has no idea
/// who is asking. A trainer who queues five tutorials should slow themselves
/// and nobody else.
function accountMax() {
  const n = Number(process.env.RENDER_ACCOUNT_MAX);
  return Number.isInteger(n) && n > 0 ? n : 2;
}

const waiting = [];
let running = 0;

/// How many films each account has drawing right now, and when each was last
/// given a turn. Both are keyed by [ownerKey] and both are forgotten the moment
/// an account has nothing here — fairness is a question about who is competing
/// *now*, and a map that remembered every account that ever rendered would grow
/// for ever.
const runningByOwner = new Map();
const servedAt = new Map();
let tick = 0;

/// The bucket a job competes in.
///
/// A job with no owner is its own bucket rather than sharing one: the recorded
/// lesson export passes an account, but anything that does not must not be able
/// to block an unrelated job by accident.
function ownerKey(owner, id) {
  return owner === null || owner === undefined ? `job:${id}` : `account:${owner}`;
}

function inFlightFor(key) {
  const drawing = runningByOwner.get(key) || 0;
  return drawing + waiting.filter((entry) => entry.key === key).length;
}

/// Thrown by [run] when the queue is full. The route turns it into a 429.
class RenderQueueFull extends Error {
  constructor(waitingCount) {
    super(`render queue is full (${waitingCount} waiting)`);
    this.name = 'RenderQueueFull';
    this.waiting = waitingCount;
  }
}

/// Thrown when **this account** already has its share here.
///
/// A different type from [RenderQueueFull] on purpose, because it needs a
/// different sentence: „the server is busy with other videos" is a lie when the
/// other videos are your own, and a trainer who is told that will wait for
/// somebody else to finish instead of for themselves.
class RenderAccountBusy extends Error {
  constructor(count) {
    super(`this account already has ${count} render(s) here`);
    this.name = 'RenderAccountBusy';
    this.count = count;
  }
}

/// Which waiting job goes next: the one belonging to the account that has gone
/// longest without a turn, and the earliest of that account's if it has more
/// than one.
///
/// **Round-robin rather than first-come-first-served.** Twelve chunks of one
/// big tutorial queued together would otherwise run ahead of a two-minute film
/// that arrived later — which is the whole complaint this exists to answer.
/// An account that is not in [ticks] has never been served and therefore goes
/// first; strict `<` keeps arrival order among equals.
function nextIndex(entries, ticks) {
  let best = -1;
  let bestTick = Infinity;
  entries.forEach((entry, index) => {
    const served = ticks.has(entry.key) ? ticks.get(entry.key) : -1;
    if (served < bestTick) {
      bestTick = served;
      best = index;
    }
  });
  return best;
}

/// The order the waiting jobs will actually be served in.
///
/// Computed by playing the rule forward over a copy, because **the number a
/// trainer is shown has to be the number that comes true.** Announcing an
/// array index would have been right while the queue was first-come-first-
/// served and is a lie the moment it is not.
function plannedOrder() {
  const rest = [...waiting];
  const ticks = new Map(servedAt);
  let at = tick;
  const order = [];
  while (rest.length > 0) {
    const [entry] = rest.splice(nextIndex(rest, ticks), 1);
    ticks.set(entry.key, (at += 1));
    order.push(entry);
  }
  return order;
}

/// How many films are in front of [id]: 0 while it is being drawn.
function positionOf(id) {
  const index = plannedOrder().findIndex((entry) => entry.id === id);
  return index === -1 ? 0 : index + 1;
}

/// What every waiting job has been told, told again.
///
/// Called whenever the queue moves, because a trainer who is second wants to
/// see themselves become first — a place in a queue that never changes is
/// indistinguishable from a queue that is stuck.
function announce() {
  plannedOrder().forEach((entry, index) => {
    const at = index + 1;
    // **Only when it changed.** Every arrival re-computes the order, because
    // under round-robin a newcomer really can move somebody else — but a job
    // whose place is the same as it was has not moved, and saying so again is
    // noise in the log and a repeated write to the progress map. „You are told
    // when your place changes" is the contract; „you are told whenever anything
    // happens" is not.
    if (entry.told === at) return;
    entry.told = at;
    entry.onPosition(at);
  });
}

/// Marks a job as started: one more drawing for its account, and its account as
/// having just had a turn.
function claim(key) {
  running += 1;
  runningByOwner.set(key, (runningByOwner.get(key) || 0) + 1);
  servedAt.set(key, (tick += 1));
}

function release(key) {
  running -= 1;
  const left = (runningByOwner.get(key) || 1) - 1;
  if (left > 0) runningByOwner.set(key, left);
  else runningByOwner.delete(key);
  // Nothing of this account's is here any more, so it stops competing — and
  // stops being remembered. It returns as a newcomer, which is the right way
  // round: an account coming back should not queue behind the twelve chunks of
  // somebody who has been drawing all along.
  if (inFlightFor(key) === 0) servedAt.delete(key);
}

function pump() {
  while (running < concurrency() && waiting.length > 0) {
    const [next] = waiting.splice(nextIndex(waiting, servedAt), 1);
    claim(next.key);
    next.start();
  }
  announce();
}

/// Run [task] when it is this job's turn.
///
/// [onPosition] is called with the number of films in front of this one — first
/// when it joins the queue, again every time the queue moves, and with 0 the
/// moment it starts drawing. A job that never waits is called once, with 0.
///
/// Throws [RenderQueueFull] **before** the task runs when too many are already
/// waiting; the caller has done no work at that point and can answer at once.
async function run(id, task, onPosition = () => {}, { owner = null } = {}) {
  const key = ownerKey(owner, id);

  // **This account's own share, asked first.** Before the queue's ceiling,
  // because the two refusals need different sentences and the account's own is
  // the more specific one: a trainer told „the server is busy" when the server
  // is busy with their own two films will wait for the wrong thing.
  const mine = inFlightFor(key);
  if (mine >= accountMax()) {
    throw new RenderAccountBusy(mine);
  }

  if (running >= concurrency() && waiting.length >= maxWaiting()) {
    throw new RenderQueueFull(waiting.length);
  }

  if (running < concurrency()) {
    claim(key);
    onPosition(0);
  } else {
    await new Promise((start) => {
      waiting.push({
        id,
        key,
        onPosition,
        start: () => {
          onPosition(0);
          start();
        },
      });
      // Everyone is told again, not just the arrival: a job that joins can
      // change where the others stand, because the order is round-robin and the
      // newcomer's account may be the one that has waited longest.
      announce();
      logger.info({ id, waiting: waiting.length }, '[RENDER] queued behind another film');
    });
  }

  try {
    return await task();
  } finally {
    release(key);
    pump();
  }
}

/// What the queue looks like right now. For tests and for a log line.
function snapshot() {
  return {
    running,
    waiting: waiting.length,
    concurrency: concurrency(),
    maxWaiting: maxWaiting(),
    accountMax: accountMax(),
    accounts: runningByOwner.size,
  };
}

module.exports = { run, positionOf, snapshot, RenderQueueFull, RenderAccountBusy };
