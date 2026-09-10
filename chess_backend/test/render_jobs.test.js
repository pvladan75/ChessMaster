// render_jobs.test.js — item 5 of part two of docs/PLAN-SNIMANJE.md: a
// tutorial's film is drawn after its request has been answered, and the job
// that says what became of it is a row rather than a map entry.
//
// The table is faked with its partial unique index, because „one running
// render per tutorial and trainer" is enforced by the database and a fake that
// accepted a second row would prove nothing about the code that relies on it.
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const realtime = require('../services/realtime');
const renderJobs = require('../services/renderJobs');
const renderQueue = require('../services/renderQueue');
const { RenderAborted } = require('../services/renderAbort');

const quietIo = { to: () => ({ emit: () => {} }) };
realtime.init(quietIo);

const tick = () => new Promise((resolve) => setImmediate(resolve));

/// Races [promise] against a deadline, so a mutation that makes it wait for
/// ever fails with a word rather than stalling the file.
function within(promise, ms = 2000) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('HUNG')), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

/// tutorial_render_jobs, the notification rows, and a way to stand inside one
/// statement while something else happens.
function fakeDb({ titles = {} } = {}) {
  const rows = [];
  const notices = [];
  let hold = null;

  const pool = {
    async query(sql, values = []) {
      const flat = sql.replace(/\s+/g, ' ').trim();
      if (hold && hold.match.test(flat)) await hold.gate;

      if (/^INSERT INTO tutorial_render_jobs/.test(flat)) {
        const [id, userId, lessonId] = values;
        const clash = rows.some((r) => r.status === 'running'
          && r.user_id === userId && r.lesson_id === lessonId);
        if (clash) {
          const err = new Error('duplicate key value violates unique constraint "ux_tutorial_render_jobs_running"');
          err.code = '23505';
          throw err;
        }
        rows.push({
          id, user_id: userId, lesson_id: lessonId, status: 'running', message: null, error: null, filename: null,
        });
        return { rows: [], rowCount: 1 };
      }
      if (/^SELECT id FROM tutorial_render_jobs/.test(flat)) {
        const [userId, lessonId] = values;
        return {
          rows: rows.filter((r) => r.user_id === userId && r.lesson_id === lessonId && r.status === 'running')
            .slice(0, 1).map((r) => ({ id: r.id })),
        };
      }
      if (/^SELECT id, lesson_id, status, message, error, filename FROM tutorial_render_jobs/.test(flat)) {
        const [id, userId] = values;
        const row = rows.find((r) => r.id === id && r.user_id === userId);
        return { rows: row ? [{ ...row }] : [] };
      }
      if (/FROM saved_lessons l/.test(flat)) {
        const running = rows.filter((r) => r.status === 'running');
        for (const r of running) Object.assign(r, { status: 'failed', error: values[0] });
        return {
          rows: running.map((r) => ({ id: r.id, user_id: r.user_id, lesson_id: r.lesson_id, title: titles[r.lesson_id] })),
        };
      }
      if (/SET status = 'failed', error = \$2/.test(flat)) {
        const row = rows.find((r) => r.id === values[0] && r.status === 'running');
        if (row) Object.assign(row, { status: 'failed', error: values[1] });
        return { rows: [], rowCount: row ? 1 : 0 };
      }
      if (/SET status = \$2, message = \$3/.test(flat)) {
        const [id, status, message, error, filename] = values;
        const row = rows.find((r) => r.id === id && r.status === 'running');
        if (row) Object.assign(row, { status, message, error, filename });
        return { rows: [], rowCount: row ? 1 : 0 };
      }
      if (/^DELETE FROM tutorial_render_jobs/.test(flat)) {
        const at = rows.findIndex((r) => r.id === values[0]);
        if (at !== -1) rows.splice(at, 1);
        return { rows: [], rowCount: at === -1 ? 0 : 1 };
      }
      if (/^INSERT INTO user_notifications/.test(flat)) {
        notices.push({ user: values[0], title: values[3], message: values[4], kind: values[5], ref: values[6] });
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`fake database was not taught: ${flat}`);
    },
  };

  return {
    pool,
    rows,
    notices,
    /// Holds every statement matching [match] until the returned function is
    /// called.
    holdOn(match) {
      let release;
      hold = { match, gate: new Promise((resolve) => { release = resolve; }) };
      return () => { hold = null; release(); };
    },
  };
}

const context = (extra = {}) => ({ userId: 4, lessonId: 15, title: 'Weak squares', ...extra });

test('a render gets an id the server chose, and one running render per tutorial', async () => {
  const db = fakeDb();
  const first = await renderJobs.create(db.pool, { userId: 4, lessonId: 15 });
  assert.match(first.id, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
  assert.ok(first.signal instanceof AbortSignal);

  // The second press of Export names the render already running, so the app
  // can show that one rather than start a film that would replace it.
  await assert.rejects(
    renderJobs.create(db.pool, { userId: 4, lessonId: 15 }),
    (err) => err instanceof renderJobs.RenderAlreadyRunning && err.jobId === first.id,
  );

  // Another trainer's render of the same tutorial is not in the way, nor is
  // this trainer's render of another one.
  const theirs = await renderJobs.create(db.pool, { userId: 5, lessonId: 15 });
  const another = await renderJobs.create(db.pool, { userId: 4, lessonId: 16 });
  assert.equal(new Set([first.id, theirs.id, another.id]).size, 3);

  for (const id of [first.id, theirs.id, another.id]) {
    await renderJobs.detach(db.pool, id, Promise.resolve({ status: 'cancelled' }), context());
  }
});

test('a running row that nothing is doing does not block the tutorial', async () => {
  // Left by a refusal whose row could not be deleted, or by a process that
  // stopped: it says 'running', it holds the unique index, and nothing will
  // ever finish it. Left alone it would refuse every export of that tutorial.
  const db = fakeDb();
  db.rows.push({ id: 'ghost-job-1', user_id: 4, lesson_id: 16, status: 'running' });

  const fresh = await renderJobs.create(db.pool, { userId: 4, lessonId: 16 });

  assert.equal(db.rows.find((r) => r.id === 'ghost-job-1').status, 'failed');
  assert.equal(db.rows.find((r) => r.id === 'ghost-job-1').error, renderJobs.INTERRUPTED);
  assert.equal(db.rows.find((r) => r.id === fresh.id).status, 'running');
  await renderJobs.detach(db.pool, fresh.id, Promise.resolve({ status: 'cancelled' }), context());
});

test('a finished render is written, and its trainer told', async () => {
  const db = fakeDb();
  const { id } = await renderJobs.create(db.pool, { userId: 4, lessonId: 15 });

  const outcome = await renderJobs.detach(db.pool, id,
    Promise.resolve({ status: 'done', message: 'Video rendered.', filename: 'tutorial_15.mp4' }), context());

  assert.equal(outcome.status, 'done');
  assert.deepEqual(
    (({ status, message, filename }) => ({ status, message, filename }))(db.rows[0]),
    { status: 'done', message: 'Video rendered.', filename: 'tutorial_15.mp4' },
  );
  assert.equal(db.notices.length, 1);
  assert.equal(db.notices[0].kind, 'video_ready');
  assert.equal(db.notices[0].user, 4);
  assert.equal(db.notices[0].ref, 15, 'the notification points at the tutorial');
  assert.match(db.notices[0].message, /"Weak squares" is ready/);
});

test('a failed render tells its trainer why, and a cancelled one tells nobody', async () => {
  const db = fakeDb();
  const failed = await renderJobs.create(db.pool, { userId: 4, lessonId: 15 });
  await renderJobs.detach(db.pool, failed.id,
    Promise.resolve({ status: 'failed', error: 'Split the tutorial into two shorter ones.' }), context());
  assert.equal(db.notices.length, 1);
  assert.equal(db.notices[0].kind, 'video_failed');
  assert.match(db.notices[0].message, /could not be rendered\. Split the tutorial/);

  // The trainer pressed the button; a notification telling them so is noise.
  const cancelled = await renderJobs.create(db.pool, { userId: 4, lessonId: 15 });
  await renderJobs.detach(db.pool, cancelled.id, Promise.resolve({ status: 'cancelled' }), context());
  assert.equal(db.rows.find((r) => r.id === cancelled.id).status, 'cancelled');
  assert.equal(db.notices.length, 1, 'nobody is told about their own cancel');
});

test('a notification that cannot be sent does not undo the film', async () => {
  // Do the thing, then say it. `realtime` throws on purpose when it was never
  // wired, and that throw arrives after the row is written.
  const db = fakeDb();
  const { id } = await renderJobs.create(db.pool, { userId: 4, lessonId: 15 });
  realtime.init(null);
  try {
    const outcome = await within(renderJobs.detach(db.pool, id,
      Promise.resolve({ status: 'done', message: 'ok', filename: 'f.mp4' }), context()));
    assert.equal(outcome.status, 'done');
    assert.equal(db.rows[0].status, 'done');
  } finally {
    realtime.init(quietIo);
  }
});

test('a render that throws past the route is still a failed film, not a crash', async () => {
  const db = fakeDb();
  const { id } = await renderJobs.create(db.pool, { userId: 4, lessonId: 15 });
  const outcome = await renderJobs.detach(db.pool, id, Promise.reject(new Error('boom')), context());
  assert.equal(outcome.status, 'failed');
  assert.equal(outcome.error, renderJobs.RENDER_FAILED);
  assert.equal(db.rows[0].status, 'failed');
  assert.equal(db.notices[0].kind, 'video_failed');
});

test('a poll during the last write does not fail a film that was just finished', async () => {
  // The handle is dropped after the write, never before. In between, the row
  // says 'running' with nothing behind it, and a poll landing there would fail
  // a film the trainer is about to be told they have.
  const db = fakeDb();
  const { id } = await renderJobs.create(db.pool, { userId: 4, lessonId: 15 });
  const release = db.holdOn(/SET status = \$2, message = \$3/);

  const settling = renderJobs.detach(db.pool, id,
    Promise.resolve({ status: 'done', message: 'ok', filename: 'f.mp4' }), context());
  await tick();

  const seen = await renderJobs.find(db.pool, { id, userId: 4 });
  assert.equal(seen.status, 'running', 'a finished film was failed by the poll that raced its write');

  release();
  await settling;
  assert.equal(db.rows[0].status, 'done');
});

test('a running row that nothing is doing is answered as the failure it is', async () => {
  const db = fakeDb();
  db.rows.push({ id: 'ghost-job-2', user_id: 4, lesson_id: 15, status: 'running' });

  const seen = await renderJobs.find(db.pool, { id: 'ghost-job-2', userId: 4 });
  assert.equal(seen.status, 'failed');
  assert.equal(seen.error, renderJobs.INTERRUPTED);
  assert.equal(db.rows[0].status, 'failed', 'and written, so the next look agrees');

  assert.equal(await renderJobs.find(db.pool, { id: 'ghost-job-2', userId: 5 }), null,
    'somebody else\'s render is not found, whatever its id');
});

test('cancel takes a waiting film out of the queue at once', async () => {
  // Left to wait for its turn and stop there, it would hold a place somebody
  // else waits behind — and count against its own trainer's share, so a
  // trainer cancelling to change the resolution could be refused the film
  // they meant instead.
  const db = fakeDb();
  let open;
  const gate = new Promise((resolve) => { open = resolve; });
  const ahead = renderQueue.run('cancel-ahead', () => gate, () => {}, { owner: 901 });

  const job = await renderJobs.create(db.pool, { userId: 902, lessonId: 20 });
  let drawn = false;
  const waiting = renderQueue.run(job.id, async () => { drawn = true; }, () => {}, { owner: 902 });
  await tick();
  assert.equal(renderQueue.snapshot().waiting, 1);

  assert.equal(renderJobs.cancel(job.id), true);
  // Without the film in front of it finishing: that film is still drawing.
  await assert.rejects(within(waiting), RenderAborted);
  assert.equal(job.signal.aborted, true, 'and the signal a started film listens to has fired');
  assert.equal(renderQueue.snapshot().waiting, 0);
  assert.equal(drawn, false);

  open();
  await ahead;
  await renderJobs.detach(db.pool, job.id, Promise.resolve({ status: 'cancelled' }), context());
});

test('a film that leaves the queue moves the ones behind it up', async () => {
  let open;
  const gate = new Promise((resolve) => { open = resolve; });
  const ahead = renderQueue.run('move-ahead', () => gate, () => {}, { owner: 911 });
  const leaving = renderQueue.run('move-leaving', async () => {}, () => {}, { owner: 912 });
  const told = [];
  const behind = renderQueue.run('move-behind', async () => {}, (at) => told.push(at), { owner: 913 });
  await tick();
  assert.deepEqual(told, [2]);

  assert.equal(renderQueue.withdraw('move-leaving', new RenderAborted('cancelled')), true);
  await assert.rejects(within(leaving), RenderAborted);
  assert.deepEqual(told, [2, 1], 'a place that does not change after the queue moved is a queue that looks stuck');

  open();
  await Promise.all([ahead, within(behind)]);
});

test('withdraw leaves alone a film being drawn, and one it does not know', async () => {
  let open;
  const gate = new Promise((resolve) => { open = resolve; });
  const drawing = renderQueue.run('withdraw-drawing', () => gate, () => {}, { owner: 921 });
  await tick();

  assert.equal(renderQueue.withdraw('withdraw-drawing', new RenderAborted('x')), false,
    'a film being drawn is stopped by its own signal, not pulled out from under the slot');
  assert.equal(renderQueue.withdraw('never-queued', new RenderAborted('x')), false);
  assert.equal(renderQueue.snapshot().running, 1);

  open();
  await drawing;
  assert.equal(renderJobs.cancel('never-created'), false, 'a render this process does not hold says so');
});

test('an account that withdrew its last waiting film comes back as a newcomer', async () => {
  // Round-robin forgets an account the moment it has nothing here (`release`),
  // and a withdrawal is one more way of having nothing here. Remembered, the
  // account would queue behind somebody it should have gone in front of.
  const told = {};
  const place = (name) => (at) => { (told[name] ||= []).push(at); };
  let openA1;
  const gateA1 = new Promise((resolve) => { openA1 = resolve; });
  let openB1;
  const gateB1 = new Promise((resolve) => { openB1 = resolve; });

  const a1 = renderQueue.run('rr-a1', () => gateA1, () => {}, { owner: 931 });
  const b1 = renderQueue.run('rr-b1', () => gateB1, () => {}, { owner: 932 });
  const a2 = renderQueue.run('rr-a2', async () => {}, () => {}, { owner: 931 });
  await tick();

  // A1 finishes; B1, never served, goes before A2 and is drawing now. A is
  // remembered as served, because A2 is still here.
  openA1();
  await a1;
  await tick();
  assert.equal(renderQueue.withdraw('rr-a2', new RenderAborted('cancelled')), true);
  await assert.rejects(within(a2), RenderAborted);

  // A comes back first, then C. Both have nothing here, so arrival decides.
  const a3 = renderQueue.run('rr-a3', async () => {}, place('a3'), { owner: 931 });
  const c1 = renderQueue.run('rr-c1', async () => {}, place('c1'), { owner: 933 });
  await tick();
  assert.equal(told.a3.at(-1), 1,
    'the account that withdrew was still remembered as served, and was put behind a newcomer');
  assert.equal(told.c1.at(-1), 2);

  openB1();
  await Promise.all([b1, within(a3), within(c1)]);
});

test('at startup, every render still running is failed and its trainer told', async () => {
  const db = fakeDb({ titles: { 15: 'Weak squares', 16: 'Opposition' } });
  db.rows.push(
    { id: 'left-1', user_id: 4, lesson_id: 15, status: 'running' },
    { id: 'left-2', user_id: 5, lesson_id: 16, status: 'running' },
    { id: 'done-1', user_id: 4, lesson_id: 15, status: 'done', filename: 'kept.mp4' },
  );

  assert.equal(await renderJobs.reapInterrupted(db.pool), 2);

  assert.deepEqual(db.rows.map((r) => r.status), ['failed', 'failed', 'done']);
  assert.equal(db.rows[0].error, renderJobs.INTERRUPTED);
  assert.deepEqual(db.notices.map((n) => [n.user, n.kind, n.ref]), [
    [4, 'video_failed', 15],
    [5, 'video_failed', 16],
  ]);
  assert.match(db.notices[1].message, /"Opposition" could not be rendered/);
});
