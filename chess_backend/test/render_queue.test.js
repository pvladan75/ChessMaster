// render_queue.test.js — one film at a time, and the rest wait their turn.
//
// „Ja bih ih stavio u red, jer neko od korisnika će time svoj video dobiti pre,
// a ovaj drugi kasnije (kao što bi i dobio da rade paralelno)." Measured before
// the queue existed: three renders started together took 6.8 s and all three
// finished at 6.8 s, against 2.4 s for one alone. Nobody was served early and
// everybody paid for the sharing.
const test = require('node:test');
const assert = require('node:assert/strict');

const queue = require('../services/renderQueue');

/// A task that finishes when the test says so.
function held() {
  let release;
  const done = new Promise((resolve) => { release = resolve; });
  return { task: () => done, release };
}

/// Lets every already-scheduled microtask and timer callback run.
const settle = () => new Promise((resolve) => setImmediate(resolve));

/// The two numbers these tests are about.
///
/// **Not the whole snapshot.** Comparing the object entire is a claim about its
/// *shape*, and every field added to it for a log line — `accountMax`,
/// `accounts` — failed four tests that had nothing to do with either. Same
/// family as `retention.test.js` asserting „exactly one query".
const busy = () => {
  const { running, waiting } = queue.snapshot();
  return { running, waiting };
};

test('the second film waits, and is told where it stands', async () => {
  const first = held();
  const second = held();
  const seen = [];

  const running = queue.run('job-a', first.task, (at) => seen.push(['a', at]));
  await settle();
  assert.deepEqual(queue.snapshot().running, 1);

  const queued = queue.run('job-b', second.task, (at) => seen.push(['b', at]));
  await settle();

  assert.deepEqual(busy(), { running: 1, waiting: 1 });
  assert.equal(queue.positionOf('job-b'), 1, 'one film in front of it');
  assert.deepEqual(seen, [['a', 0], ['b', 1]],
    'the first starts at once, the second is told it is one back');

  first.release();
  await settle();
  assert.deepEqual(seen[seen.length - 1], ['b', 0], 'and told again when it starts');
  assert.deepEqual(queue.snapshot().waiting, 0);

  second.release();
  await running;
  await queued;
  assert.deepEqual(busy(), { running: 0, waiting: 0 });
});

test('a queue that moves says so, so second becomes first', async () => {
  // A place in a queue that never changes is indistinguishable from a queue
  // that is stuck, and a trainer watching „2 ahead of you" for a minute has no
  // way to tell which they are looking at.
  const first = held();
  const second = held();
  const third = held();
  const positions = [];

  const a = queue.run('a', first.task);
  await settle();
  const b = queue.run('b', second.task, (at) => positions.push(`b=${at}`));
  const c = queue.run('c', third.task, (at) => positions.push(`c=${at}`));
  await settle();
  assert.deepEqual(positions, ['b=1', 'c=2']);

  first.release();
  await settle();
  // b starts; c moves up to first in line.
  assert.deepEqual(positions.slice(2), ['b=0', 'c=1']);

  second.release();
  await settle();
  assert.deepEqual(positions[positions.length - 1], 'c=0');

  third.release();
  await Promise.all([a, b, c]);
});

test('a full queue refuses before doing any work', async () => {
  // The render happens inside the request the client already made, and that
  // request dies on the wire after 300 s at nginx. „You are fourth" is a
  // promise this server cannot keep, so it is not made.
  const jobs = [held(), held(), held()];
  const runs = jobs.map((job, i) => queue.run(`full-${i}`, job.task));
  await settle();
  assert.deepEqual(queue.snapshot().waiting, 2, 'one drawing, two waiting');

  let ran = false;
  await assert.rejects(
    () => queue.run('full-3', async () => { ran = true; }),
    (err) => err instanceof queue.RenderQueueFull && err.waiting === 2,
  );
  assert.equal(ran, false, 'the task never started');

  jobs.forEach((job) => job.release());
  await Promise.all(runs);
});

test('a film that throws still lets the next one start', async () => {
  // The `finally` is the whole queue: a render that fails half way through must
  // not take the queue with it, or one bad tutorial stops every trainer on the
  // server until it is restarted.
  const second = held();
  const failing = queue.run('bad', async () => { throw new Error('ffmpeg died'); });
  await assert.rejects(() => failing, /ffmpeg died/);

  const seen = [];
  const next = queue.run('good', second.task, (at) => seen.push(at));
  await settle();
  assert.deepEqual(seen, [0], 'the next film started immediately');
  second.release();
  await next;
  assert.deepEqual(busy(), { running: 0, waiting: 0 });
});

test('one at a time, and never two', async () => {
  // The reason the queue exists: two films drawn side by side share one CPU and
  // finish together, both late.
  let atOnce = 0;
  let most = 0;
  const work = async () => {
    atOnce += 1;
    most = Math.max(most, atOnce);
    await settle();
    atOnce -= 1;
  };
  await Promise.all([queue.run('1', work), queue.run('2', work), queue.run('3', work)]);
  assert.equal(most, 1);
});
