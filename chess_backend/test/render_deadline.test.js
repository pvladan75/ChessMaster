// render_deadline.test.js — a place in the queue is a promise about time.
//
// Item 4 of part two of docs/PLAN-SNIMANJE.md. The render happens inside the
// request that asked for it, and nginx closes that request after 300 s — so a
// film admitted behind others it cannot finish after is a trainer watching a bar
// for five minutes and getting nothing. A job may say how long it will take and
// when its client stops waiting; the queue then refuses what it cannot keep.
const test = require('node:test');
const assert = require('node:assert/strict');

const queue = require('../services/renderQueue');

const SECOND = 1000;

/// A task that finishes when the test says so.
function held() {
  let release;
  const done = new Promise((resolve) => { release = resolve; });
  return { task: () => done, release };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

/// **A refusal races a deadline.** Deleting the check does not make the call
/// fail — it makes it *queue*, and an `assert.rejects` on a promise that never
/// settles hangs the file with no message. Twice already in this repository.
function within(promise, ms = 2000) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('HUNG: the call was queued instead of refused')), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

test('a film that cannot finish behind the one being drawn is refused, and told when', async () => {
  const drawing = held();
  const first = queue.run('dl-a', drawing.task, () => {}, { owner: 1, estimateMs: 200 * SECOND });
  await settle();
  try {
    const now = Date.now();
    let refused = null;
    await assert.rejects(
      within(queue.run('dl-b', async () => {}, () => {}, {
        owner: 2, estimateMs: 150 * SECOND, deadline: now + 300 * SECOND,
      })),
      (err) => { refused = err; return err instanceof queue.RenderWontFit; },
    );
    // 200 s left of the first, 150 s of its own, 300 s to do both in: it would
    // be 50 s late, so in 50 s it would fit.
    assert.ok(refused.waitMs > 40 * SECOND && refused.waitMs <= 50 * SECOND,
      `told to come back in ${refused.waitMs} ms`);
    assert.equal(queue.snapshot().waiting, 0, 'and nothing was left in the queue');
  } finally {
    drawing.release();
    await first;
  }
});

test('a film that fits behind it waits, as every film did before', async () => {
  const drawing = held();
  const first = queue.run('dl-c', drawing.task, () => {}, { owner: 1, estimateMs: 100 * SECOND });
  await settle();
  const second = queue.run('dl-d', async () => 'drawn', () => {}, {
    owner: 2, estimateMs: 150 * SECOND, deadline: Date.now() + 300 * SECOND,
  });
  await settle();
  assert.equal(queue.snapshot().waiting, 1);
  drawing.release();
  await first;
  assert.equal(await second, 'drawn');
});

test('a newcomer that would make a waiting film late is refused, though it fits itself', async () => {
  // Round-robin puts an account that has not been served in front of one that
  // has — so letting a newcomer in can move a film that was already promised
  // its time. 100 s drawing, then the promised film's 150 s: done at 250 of its
  // 300. With the newcomer's 100 s in front of it, done at 350.
  const drawing = held();
  const first = queue.run('dl-e', drawing.task, () => {}, { owner: 1, estimateMs: 100 * SECOND });
  await settle();
  const promised = queue.run('dl-f', async () => 'drawn', () => {}, {
    owner: 1, estimateMs: 150 * SECOND, deadline: Date.now() + 300 * SECOND,
  });
  await settle();
  try {
    await assert.rejects(
      within(queue.run('dl-g', async () => {}, () => {}, {
        owner: 2, estimateMs: 100 * SECOND, deadline: Date.now() + 300 * SECOND,
      })),
      queue.RenderWontFit,
    );
    assert.equal(queue.positionOf('dl-f'), 1, 'the promised film is still next');
  } finally {
    drawing.release();
    await first;
  }
  assert.equal(await promised, 'drawn');
});

test('a film that learns it is longer says so, and the films behind it are judged by that', async () => {
  // The narrated export: admitted on the app's reading-speed length, and told
  // its real one only when the voice has spoken.
  const drawing = held();
  const first = queue.run('dl-h', drawing.task, () => {}, { owner: 1, estimateMs: 10 * SECOND });
  await settle();
  queue.revise('dl-h', 200 * SECOND);
  try {
    await assert.rejects(
      within(queue.run('dl-i', async () => {}, () => {}, {
        owner: 2, estimateMs: 150 * SECOND, deadline: Date.now() + 300 * SECOND,
      })),
      queue.RenderWontFit,
      'judged on 10 s in front of it, it would have been let in',
    );
  } finally {
    drawing.release();
    await first;
  }
});

test('a film too long to finish even alone is left to the route', async () => {
  // Its sentence is „split the tutorial", not „try again in a few minutes" —
  // and only the route knows the ways out of it. The route refuses it before it
  // reaches the queue; the queue does not refuse it for the wrong reason.
  const drawing = held();
  const first = queue.run('dl-j', drawing.task, () => {}, { owner: 1, estimateMs: 10 * SECOND });
  await settle();
  const long = queue.run('dl-k', async () => 'drawn', () => {}, {
    owner: 2, estimateMs: 400 * SECOND, deadline: Date.now() + 300 * SECOND,
  });
  await settle();
  assert.equal(queue.snapshot().waiting, 1);
  drawing.release();
  await first;
  assert.equal(await long, 'drawn');
});

test('a film whose client waits on its connection goes before films drawn in the background', async () => {
  // Item 5 of part two: a tutorial's film is drawn after its request and has no
  // deadline; the recorded-lesson export is still drawn inside its request and
  // has one. Behind 500 s of background film it could not finish in its 300;
  // in front of it, it can — and the background film loses only a minute.
  const drawing = held();
  const first = queue.run('lane-a', drawing.task, () => {}, { owner: 1, estimateMs: 10 * SECOND });
  await settle();
  const background = queue.run('lane-b', async () => 'drawn', () => {}, { owner: 2, estimateMs: 500 * SECOND });
  await settle();
  const connected = queue.run('lane-c', async () => 'drawn', () => {}, {
    owner: 3, estimateMs: 60 * SECOND, deadline: Date.now() + 300 * SECOND,
  });
  connected.catch(() => {});
  await settle();
  try {
    assert.equal(queue.positionOf('lane-c'), 1, 'the film whose client is waiting is next');
    assert.equal(queue.positionOf('lane-b'), 2);
  } finally {
    drawing.release();
    await first;
  }
  assert.equal(await within(connected), 'drawn');
  assert.equal(await within(background), 'drawn');
});

test('a film its client waits for is refused at its turn when the queue made it late', async () => {
  // Admitted on the estimate of the film in front of it — which then drew for
  // 80 s rather than 10. Started now it would be cut off by the proxy half-way,
  // with the slot spent for nothing, so it is told while its client is still
  // connected. The clock is the queue's own, frozen and moved by hand.
  const realNow = Date.now;
  let now = realNow();
  Date.now = () => now;
  try {
    const drawing = held();
    const first = queue.run('turn-a', drawing.task, () => {}, { owner: 1, estimateMs: 10 * SECOND });
    await settle();
    let drawn = false;
    const late = queue.run('turn-b', async () => { drawn = true; }, () => {}, {
      owner: 2, estimateMs: 60 * SECOND, deadline: now + 100 * SECOND,
    });
    late.catch(() => {});
    await settle();
    assert.equal(queue.snapshot().waiting, 1, 'admitted: 10 s in front, 60 of its own, 100 to do both');

    now += 80 * SECOND;
    drawing.release();
    await first;
    await assert.rejects(within(late), queue.RenderWontFit);
    assert.equal(drawn, false, 'a film that would be cut off half-way was started');
    assert.equal(queue.snapshot().running, 0, 'and the slot was not spent on it');
  } finally {
    Date.now = realNow;
  }
});

test('a film with no deadline is counted in front of others, and never refused for time', async () => {
  // The recorded-lesson export: it says how long it will take, so a tutorial
  // behind it is judged by the real work in front of it, and it has no
  // deadline, so it is judged as it always was.
  const drawing = held();
  const first = queue.run('dl-l', drawing.task, () => {}, { owner: 1, estimateMs: 250 * SECOND });
  await settle();
  let untimed = null;
  try {
    await assert.rejects(
      within(queue.run('dl-m', async () => {}, () => {}, {
        owner: 2, estimateMs: 100 * SECOND, deadline: Date.now() + 300 * SECOND,
      })),
      queue.RenderWontFit,
      'the 250 s in front of it were counted',
    );
    untimed = queue.run('dl-n', async () => 'drawn', () => {}, { owner: 3, estimateMs: 400 * SECOND });
    await settle();
    assert.equal(queue.snapshot().waiting, 1, 'a job with no deadline cannot be late');
  } finally {
    drawing.release();
    await first;
  }
  assert.equal(await untimed, 'drawn');
});
