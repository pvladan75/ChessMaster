// render_fairness.test.js — one trainer cannot take the whole machine.
//
// **This was a live fault, not a future one.** With `RENDER_CONCURRENCY` 1 and
// `RENDER_QUEUE_MAX` 2, three renders is the number that fits — so one trainer
// pressing „Export" three times filled the queue and every other trainer was
// refused with a 429 until it drained. First-come-first-served has no idea who
// is asking.
//
// Two rules answer it, and they are different questions. **Round-robin** decides
// *order*: the next film comes from the account that has gone longest without a
// turn. **The per-account cap** decides *admission*: two films from one account
// at a time, drawing plus waiting.

const test = require('node:test');
const assert = require('node:assert/strict');

const queue = require('../services/renderQueue');

/// A task that finishes when the test says so.
function held() {
  let release;
  const done = new Promise((resolve) => { release = resolve; });
  return { task: () => done, release };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

/// Fails rather than hangs.
///
/// **A refusal that does not happen is a promise that never settles**, not a
/// promise that resolves: without the cap, the third film simply joins the
/// queue and waits for a release that the test never reaches. `assert.rejects`
/// on that hangs the whole file until the runner gives up, and a mutation run
/// against it reports „survived" — which is the least useful thing a test can
/// say. Same lesson as `render_abort.test.js`.
function refusedWithin(promiseFn, ms = 2000) {
  return Promise.race([
    promiseFn(),
    new Promise((_, reject) => {
      const timer = setTimeout(
        () => reject(new Error('not refused: the job was accepted and is waiting')), ms);
      if (timer.unref) timer.unref();
    }),
  ]);
}

test('the next film comes from the account that has waited longest', async () => {
  // Anna is drawing and has two more queued; Bojan arrives last. Under
  // first-come-first-served Bojan waits for all three of Anna's — which is the
  // complaint. He goes next.
  const jobs = [held(), held(), held(), held()];
  const started = [];

  const runs = [
    queue.run('anna-1', async () => { started.push('anna-1'); return jobs[0].task(); }, () => {}, { owner: 1 }),
    queue.run('anna-2', async () => { started.push('anna-2'); return jobs[1].task(); }, () => {}, { owner: 1 }),
  ];
  await settle();

  // Anna is at her cap now (one drawing, one waiting), so her third has to be a
  // different account's — which is exactly the point of the cap.
  runs.push(queue.run('bojan-1', async () => { started.push('bojan-1'); return jobs[2].task(); }, () => {}, { owner: 2 }));
  await settle();

  assert.deepEqual(started, ['anna-1'], 'one at a time, as always');

  jobs[0].release();
  await settle();

  assert.deepEqual(started, ['anna-1', 'bojan-1'],
    'Bojan goes before Anna\'s second, because Anna has just had a turn');

  jobs[2].release();
  await settle();
  assert.deepEqual(started, ['anna-1', 'bojan-1', 'anna-2']);

  jobs[1].release();
  await Promise.all(runs);
  assert.equal(queue.snapshot().waiting, 0);
});

test('one account cannot hold more than its share', async () => {
  const jobs = [held(), held()];
  const runs = [
    queue.run('mine-1', jobs[0].task, () => {}, { owner: 7 }),
    queue.run('mine-2', jobs[1].task, () => {}, { owner: 7 }),
  ];
  await settle();

  let ran = false;
  await assert.rejects(
    () => refusedWithin(() => queue.run('mine-3', async () => { ran = true; }, () => {}, { owner: 7 })),
    (err) => err instanceof queue.RenderAccountBusy && err.count === 2,
  );
  assert.equal(ran, false, 'the task never started, so nothing is metered');

  jobs.forEach((job) => job.release());
  await Promise.all(runs);
});

test('the cap is this account\'s, and does not touch anybody else', async () => {
  // The refusal above must not be a refusal for the server. Somebody else's
  // film still goes in — that is the whole difference between the two errors.
  const jobs = [held(), held(), held()];
  const runs = [
    queue.run('a-1', jobs[0].task, () => {}, { owner: 1 }),
    queue.run('a-2', jobs[1].task, () => {}, { owner: 1 }),
  ];
  await settle();

  await assert.rejects(
    () => refusedWithin(() => queue.run('a-3', async () => {}, () => {}, { owner: 1 })),
    (err) => err instanceof queue.RenderAccountBusy,
  );

  // Bojan is not at any cap and the queue still has room.
  runs.push(queue.run('b-1', jobs[2].task, () => {}, { owner: 2 }));
  await settle();
  assert.equal(queue.snapshot().waiting, 2, 'his film is in the queue, not refused');

  jobs.forEach((job) => job.release());
  await Promise.all(runs);
});

test('the two refusals are different, because they need different sentences',
  async () => {
    // „The server is busy with other videos" is a lie when the other videos are
    // your own, and a trainer told that will wait for somebody else to finish
    // instead of for themselves.
    const jobs = [held(), held(), held()];
    const runs = [
      queue.run('x-1', jobs[0].task, () => {}, { owner: 1 }),
      queue.run('y-1', jobs[1].task, () => {}, { owner: 2 }),
      queue.run('z-1', jobs[2].task, () => {}, { owner: 3 }),
    ];
    await settle();
    assert.equal(queue.snapshot().waiting, 2, 'one drawing, two waiting');

    // A fourth account: the queue itself is full, and nothing about this
    // account is the reason.
    await assert.rejects(
      () => refusedWithin(() => queue.run('w-1', async () => {}, () => {}, { owner: 4 })),
      (err) => err instanceof queue.RenderQueueFull && !(err instanceof queue.RenderAccountBusy),
    );

    jobs.forEach((job) => job.release());
    await Promise.all(runs);
  });

test('a job with no owner competes as itself', async () => {
  // The recorded-lesson export passes an account; anything that does not must
  // not be able to block an unrelated job by sharing a bucket with it.
  const jobs = [held(), held(), held()];
  const runs = [
    queue.run('nobody-1', jobs[0].task),
    queue.run('nobody-2', jobs[1].task),
    queue.run('nobody-3', jobs[2].task),
  ];
  await settle();

  assert.equal(queue.snapshot().waiting, 2,
    'three unowned jobs are three buckets, not one account at its cap');

  jobs.forEach((job) => job.release());
  await Promise.all(runs);
});

test('the place a trainer is told is the place that comes true', async () => {
  // The number is computed by playing the rule forward, not read off an array
  // index — which was right while the queue was first-come-first-served and is
  // a lie the moment it is not. Anna's second film is told „2" while Bojan's
  // is told „1", because that is the order they will actually be served in.
  const jobs = [held(), held(), held()];
  const seen = [];

  const runs = [
    queue.run('anna-1', jobs[0].task, () => {}, { owner: 1 }),
  ];
  await settle();

  runs.push(queue.run('anna-2', jobs[1].task, (at) => seen.push(`anna-2=${at}`), { owner: 1 }));
  await settle();
  assert.deepEqual(seen, ['anna-2=1'], 'alone in the queue, so first in line');

  runs.push(queue.run('bojan-1', jobs[2].task, (at) => seen.push(`bojan-1=${at}`), { owner: 2 }));
  await settle();

  // Bojan arrived second and is served first, so both numbers move.
  assert.ok(seen.includes('bojan-1=1'), `Bojan is told he is first: ${seen}`);
  assert.ok(seen.includes('anna-2=2'), `Anna's second is told it slipped to 2: ${seen}`);

  jobs.forEach((job) => job.release());
  await Promise.all(runs);
});
