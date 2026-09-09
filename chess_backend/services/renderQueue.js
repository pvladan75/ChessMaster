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

const waiting = [];
let running = 0;

/// Thrown by [run] when the queue is full. The route turns it into a 429.
class RenderQueueFull extends Error {
  constructor(waitingCount) {
    super(`render queue is full (${waitingCount} waiting)`);
    this.name = 'RenderQueueFull';
    this.waiting = waitingCount;
  }
}

/// How many films are in front of [id]: 0 while it is being drawn.
function positionOf(id) {
  const index = waiting.findIndex((entry) => entry.id === id);
  return index === -1 ? 0 : index + 1;
}

/// What every waiting job has been told, told again.
///
/// Called whenever the queue moves, because a trainer who is second wants to
/// see themselves become first — a place in a queue that never changes is
/// indistinguishable from a queue that is stuck.
function announce() {
  waiting.forEach((entry, index) => entry.onPosition(index + 1));
}

function pump() {
  while (running < concurrency() && waiting.length > 0) {
    const next = waiting.shift();
    running += 1;
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
async function run(id, task, onPosition = () => {}) {
  if (running >= concurrency() && waiting.length >= maxWaiting()) {
    throw new RenderQueueFull(waiting.length);
  }

  if (running < concurrency()) {
    running += 1;
    onPosition(0);
  } else {
    await new Promise((start) => {
      waiting.push({
        id,
        onPosition,
        start: () => {
          onPosition(0);
          start();
        },
      });
      onPosition(waiting.length);
      logger.info({ id, waiting: waiting.length }, '[RENDER] queued behind another film');
    });
  }

  try {
    return await task();
  } finally {
    running -= 1;
    pump();
  }
}

/// What the queue looks like right now. For tests and for a log line.
function snapshot() {
  return { running, waiting: waiting.length, concurrency: concurrency(), maxWaiting: maxWaiting() };
}

module.exports = { run, positionOf, snapshot, RenderQueueFull };
