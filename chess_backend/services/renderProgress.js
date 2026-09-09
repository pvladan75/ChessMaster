// renderProgress.js — how far along a render is, for the screen that is waiting.
//
// A tutorial video takes tens of seconds to draw and the app had nothing to
// show for it but a spinner: „nema info o tome". The renderer knows exactly how
// many frames it has drawn of how many, so the only missing piece was somewhere
// to put that number where the client can read it.
//
// **The client names the job.** It sends a `jobId` with the export and polls
// for it while the request it already made is still in flight — which needs no
// change to the export's own answer, and no job queue, no background worker and
// no second way for a render to be started. The alternative was returning 202
// with an id and inventing a job model; this is a progress bar, not an
// infrastructure.
//
// **In memory, and that is a decision.** Progress is worth nothing a minute
// after the file is written, and a render belongs to one process — the same one
// that holds the ffmpeg pipe. A restart loses it, and losing it means a bar
// that stops moving on a request that is also gone.
const jobs = new Map();

/// How long a finished or abandoned job is kept before it is swept.
///
/// Long enough for the last poll of a render that has just answered, short
/// enough that a browser tab left open for a day cannot hold a map entry.
const TTL_MS = 5 * 60 * 1000;

function sweep(now = Date.now()) {
  for (const [id, job] of jobs) {
    if (now - job.touchedAt > TTL_MS) jobs.delete(id);
  }
}

/// A job id from a request body, or null when it is not one.
///
/// Bounded and pattern-checked because it comes from a client and is used as a
/// map key: an unbounded string is a way to grow a process's memory from
/// outside it.
function jobIdFrom(value) {
  const id = typeof value === 'string' ? value.trim() : '';
  return /^[A-Za-z0-9_-]{6,64}$/.test(id) ? id : null;
}

/// Note that [id] has drawn [drawn] of [total] frames.
///
/// **The estimate is measured, never assumed.** The rate is taken over the
/// stretch between the first report and this one, so it is this machine
/// rendering this film — a film with captions is drawn four times a second and
/// one without it once a second, and a number derived from anything but the
/// frames actually drawn would be a bar moving at a made-up speed with a clock
/// beside it. The first report therefore has no estimate to give: one point
/// says nothing about a rate.
function report(id, drawn, total) {
  if (!id) return;
  const now = Date.now();
  const percent = total > 0
    ? Math.max(0, Math.min(99, Math.round((drawn / total) * 100)))
    : 0;
  // `finish` writes an entry with no `first`, so a client that reuses an id for
  // a second render is timed from that render's own opening frame rather than
  // from the one before it.
  const started = jobs.get(id);
  const from = (started && started.first) || { at: now, drawn };
  const elapsed = now - from.at;
  const since = drawn - from.drawn;
  const left = total - drawn;
  // Round up rather than down: „0 s left" on a render that is still running is
  // the same lie as a bar sitting at 100 %.
  const etaSeconds = since > 0 && elapsed > 0 && left > 0
    ? Math.max(1, Math.ceil((elapsed / since) * left / 1000))
    : null;
  // Never 100 from here: the frames are drawn well before ffmpeg has finished
  // writing the file, and a bar that sits full while the app still waits is
  // worse than one that stops at 99.
  jobs.set(id, { percent, done: false, etaSeconds, first: from, touchedAt: now });
  sweep();
}

/// The render answered, one way or the other.
function finish(id, { ok = true } = {}) {
  if (!id) return;
  jobs.set(id, { percent: 100, done: true, ok, etaSeconds: 0, touchedAt: Date.now() });
  sweep();
}

/// What to tell a client that asks.
///
/// An unknown id is not an error: it is a poll that arrived before the render
/// started, or after it was swept. Both are „nothing to report" rather than
/// something for the app to draw a failure about.
function statusOf(id) {
  const job = jobs.get(id);
  if (!job) return { percent: 0, done: false, known: false, etaSeconds: null };
  return {
    percent: job.percent,
    done: job.done,
    known: true,
    // Seconds, or null when there is nothing to base a number on. Null is „no
    // estimate yet" and the screen says nothing; it is not zero.
    etaSeconds: job.etaSeconds == null ? null : job.etaSeconds,
  };
}

module.exports = { report, finish, statusOf, jobIdFrom, TTL_MS, _jobs: jobs };
