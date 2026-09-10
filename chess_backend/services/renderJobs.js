// renderJobs.js — a tutorial's film is drawn after the request that asked for
// it has been answered. Item 5 of part two of docs/PLAN-SNIMANJE.md.
//
// The export used to be drawn inside the POST, and that request had a ceiling
// above it: nginx closes a proxied request after 300 s. It also held the
// trainer's whole screen — the progress dialog could not be dismissed, because
// inside the request dismissing it could not cancel anything („ekran se zamrzne
// kad pošaljem na renderovanje", 10.9.2026). Now the route answers 202 with a
// job id as soon as the film is accepted, and the drawing continues behind it.
//
// **The job is a row, not a map entry.** `renderProgress` is in memory and dies
// with the process — right for a bar watched inside one request, useless for a
// film that outlives it. The film itself was already durable (`saved_lessons.
// video_filename`); what a trainer is told about it has to be too, including
// „the server stopped under it", which a map cannot say because it is gone.
//
// **The same shape as the game import** (`user_game_imports`): a row that says
// 'running' until the work says otherwise, and a row left 'running' with
// nothing behind it is failed rather than left looking alive for ever.
//
// What stays in memory is what only this process can know: how far along the
// drawing is (`renderProgress`), and the handle that stops it.
const crypto = require('crypto');
const logger = require('./logger');
const { notify } = require('./notifications');
const renderQueue = require('./renderQueue');
const { RenderAborted } = require('./renderAbort');

/// How to stop each render this process holds, drawing or waiting, by job id.
///
/// The signal used to be fired by the client hanging up. **With a 202 that
/// cannot be the trigger**: the socket closes the moment the answer is sent, and
/// „the client is gone" would kill every render at birth. So the trainer's own
/// „Cancel" fires it, and everything under the signal — the frame loop, the
/// piper kill, the ffmpeg kill, the partial cleanup, the slot release — is as
/// it was.
///
/// Also the answer to „is anybody doing this job?": a row that says 'running'
/// with no entry here is a job nothing in this process will ever finish.
const controllers = new Map();

/// The work of every job that has not settled yet, by id. Read by the tests,
/// which have to wait for a film drawn after the response; nothing in the
/// server waits on it.
const pending = new Map();

/// What a trainer is told about a render that nothing is doing any more — the
/// process restarted under it, or its row could not be cleared when the queue
/// refused it. Not „the server restarted", because only one of those is.
const INTERRUPTED = 'The server stopped rendering this video before it was finished. Export it again.';

/// What a trainer is told about a render that failed for a reason nobody
/// planned for. The server log has the reason; the trainer has a next step.
const RENDER_FAILED = 'The video could not be rendered. Try again; if it keeps failing, the server log says why.';

/// Thrown by [create] when this trainer already has a render of this tutorial
/// running. [jobId] is that render, so the app can show it rather than start a
/// second one: one film per tutorial, and a second render of the same one would
/// replace the first the moment it finished.
class RenderAlreadyRunning extends Error {
  constructor(jobId) {
    super(`a render of this tutorial is already running (${jobId})`);
    this.name = 'RenderAlreadyRunning';
    this.jobId = jobId;
  }
}

/// Fails a 'running' row that nothing in this process is doing. Returns whether
/// it was one.
async function failIfOrphaned(pool, id) {
  if (controllers.has(id)) return false;
  const result = await pool.query(
    `UPDATE tutorial_render_jobs
        SET status = 'failed', error = $2, finished_at = NOW()
      WHERE id = $1 AND status = 'running'`,
    [id, INTERRUPTED],
  );
  return result.rowCount > 0;
}

/// The render of [lessonId] this trainer has running, or null.
///
/// A row nothing is doing does not count, and is failed on the way past: left
/// alone it would hold the unique index below and refuse every export of that
/// tutorial until the next restart.
async function runningFor(pool, { userId, lessonId }) {
  const { rows } = await pool.query(
    `SELECT id FROM tutorial_render_jobs
      WHERE user_id = $1 AND lesson_id = $2 AND status = 'running'
      LIMIT 1`,
    [userId, lessonId],
  );
  const id = rows[0] ? rows[0].id : null;
  if (id && await failIfOrphaned(pool, id)) return null;
  return id;
}

/// Writes the row for a new render and returns its id and the signal that
/// cancels it.
///
/// **One running render per tutorial and trainer, and the database says so** —
/// a partial unique index rather than a SELECT first, because two presses of
/// Export a millisecond apart would both find nothing running.
async function create(pool, { userId, lessonId }, attempt = 0) {
  const id = crypto.randomUUID();
  try {
    await pool.query(
      'INSERT INTO tutorial_render_jobs (id, user_id, lesson_id) VALUES ($1, $2, $3)',
      [id, userId, lessonId],
    );
  } catch (err) {
    if (!err || err.code !== '23505' || attempt > 0) throw err;
    const running = await runningFor(pool, { userId, lessonId });
    if (running) throw new RenderAlreadyRunning(running);
    // The one in the way finished, or was nobody's, between the two
    // statements: the tutorial is free again. Once — a second collision is a
    // fault to report, not a race to retry.
    return create(pool, { userId, lessonId }, attempt + 1);
  }
  const controller = new AbortController();
  controllers.set(id, controller);
  return { id, signal: controller.signal };
}

/// Removes a job the queue refused before it began — full, or this account had
/// its share. Nothing was drawn and the refusal is the answer, so there is
/// nothing for a row to remember.
///
/// A delete that fails leaves a 'running' row with nothing behind it; the next
/// look at it (`find`, `runningFor`) fails it, so it cannot block the tutorial.
async function discard(pool, id) {
  try {
    await pool.query('DELETE FROM tutorial_render_jobs WHERE id = $1', [id]);
  } catch (err) {
    logger.error(`[RENDER] Could not remove refused job ${id}: ${err.message}`);
  } finally {
    controllers.delete(id);
  }
}

/// What to tell a trainer about a render that ended, or null for nothing.
///
/// A cancelled one is nothing: the trainer pressed the button, and a
/// notification telling them what they did is noise.
function noticeFor(status, title, error) {
  if (status === 'done') {
    return {
      kind: 'video_ready',
      title: 'Video ready',
      message: `Your video of "${title}" is ready. Download it from Saved tutorials.`,
    };
  }
  if (status === 'failed') {
    return {
      kind: 'video_failed',
      title: 'Video not rendered',
      message: `Your video of "${title}" could not be rendered. ${error}`,
    };
  }
  return null;
}

/// Tells [userId] about a render, and never throws.
///
/// **Do the thing, then say it.** The row is already written by the time this
/// runs, and a notification that fails — `realtime` throws on purpose when it
/// was never wired — must not turn a finished film into a failed job.
async function tell(pool, userId, lessonId, notice) {
  if (!notice) return;
  try {
    await notify(pool, { recipientId: userId, refId: Number(lessonId) || null, ...notice });
  } catch (err) {
    logger.error(`[RENDER] Could not tell user ${userId} about their video: ${err.message}`);
  }
}

/// Writes what became of a render, and tells its trainer.
///
/// Guarded by `status = 'running'` so the first answer stands. **The handle is
/// dropped after the write, never before**: in between, the row would say
/// 'running' with nothing behind it, and a poll landing there would fail a film
/// that had just been finished.
async function settle(pool, id, outcome, { userId, lessonId, title }) {
  const { status, message = null, error = null, filename = null } = outcome;
  let written = false;
  try {
    const result = await pool.query(
      `UPDATE tutorial_render_jobs
          SET status = $2, message = $3, error = $4, filename = $5, finished_at = NOW()
        WHERE id = $1 AND status = 'running'`,
      [id, status, message, error, filename],
    );
    written = result.rowCount > 0;
  } catch (err) {
    logger.error(`[RENDER] Could not record how job ${id} ended (${status}): ${err.message}`);
  } finally {
    controllers.delete(id);
  }

  // Only a row that was written: nothing is written when the tutorial was
  // deleted while its film was being drawn, and its trainer does not need to
  // hear about a video of something they threw away.
  if (written) await tell(pool, userId, lessonId, noticeFor(status, title, error));
}

/// Lets [work] finish after the response, and settles its row with whatever it
/// comes to.
///
/// [work] resolves to an outcome — `{ status, message?, error?, filename? }` —
/// and the route turns every ending into one, so the one thing caught here is a
/// fault in that translation. It is still a failed film rather than an
/// unhandled rejection that takes the process down with it.
function detach(pool, id, work, context) {
  const done = Promise.resolve(work)
    .catch((err) => {
      logger.error(`[RENDER] Job ${id} ended in an unexpected error: ${err && err.message}`);
      return { status: 'failed', error: RENDER_FAILED };
    })
    .then(async (outcome) => {
      await settle(pool, id, outcome, context);
      return outcome;
    })
    .finally(() => pending.delete(id));
  pending.set(id, done);
  return done;
}

/// What [id] came to, once it has come to something. For tests: a film drawn
/// after the response is otherwise invisible to the code that asked for it.
function settled(id) {
  return pending.get(id) || Promise.resolve(null);
}

/// Stops a render its trainer no longer wants.
///
/// A film still waiting leaves the queue at once — a place held for a film
/// nobody wants is a place somebody else waits behind, and it counts against
/// this trainer's own share until its turn — and one being drawn stops at its
/// next frame. Returns false when this process holds no such render.
function cancel(id) {
  const controller = controllers.get(id);
  if (!controller) return false;
  controller.abort();
  renderQueue.withdraw(id, new RenderAborted('render cancelled by its trainer'));
  return true;
}

/// [id], if it belongs to [userId]: `{ id, lesson_id, status, message, error,
/// filename }`, or null.
///
/// A row that says 'running' with nothing behind it is answered as the failure
/// it is, and written as one, so a trainer watching it is told rather than left
/// with a bar that never moves.
async function find(pool, { id, userId }) {
  const { rows } = await pool.query(
    `SELECT id, lesson_id, status, message, error, filename
       FROM tutorial_render_jobs
      WHERE id = $1 AND user_id = $2`,
    [id, userId],
  );
  const row = rows[0] || null;
  if (row && row.status === 'running' && await failIfOrphaned(pool, id)) {
    return { ...row, status: 'failed', error: INTERRUPTED };
  }
  return row;
}

/// At startup: every render still 'running' belongs to a process that is gone,
/// so each is failed and its trainer told — the half of „you will get it later"
/// that a restart would otherwise swallow. Returns how many there were.
async function reapInterrupted(pool) {
  const { rows } = await pool.query(
    `UPDATE tutorial_render_jobs j
        SET status = 'failed', error = $1, finished_at = NOW()
       FROM saved_lessons l
      WHERE j.status = 'running' AND l.id = j.lesson_id
    RETURNING j.id, j.user_id, j.lesson_id, l.title`,
    [INTERRUPTED],
  );
  for (const row of rows) {
    await tell(pool, row.user_id, row.lesson_id, noticeFor('failed', row.title || 'Tutorial', INTERRUPTED));
  }
  return rows.length;
}

module.exports = {
  create,
  runningFor,
  discard,
  detach,
  settled,
  cancel,
  find,
  reapInterrupted,
  RenderAlreadyRunning,
  INTERRUPTED,
  RENDER_FAILED,
};
