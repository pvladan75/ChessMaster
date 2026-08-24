const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createPacer, MIN_REQUEST_GAP_MS, RATE_LIMIT_COOLDOWN_MS,
} = require('../services/lichessPacing');

/// A clock that moves only when something waits on it.
function fakeClock() {
  let atMs = 0;
  const waits = [];
  return {
    waits,
    at: () => atMs,
    advance: (ms) => { atMs += ms; },
    options: {
      now: () => atMs,
      sleep: async (ms) => { waits.push(ms); atMs += ms; },
    },
  };
}

test('the first request goes at once, and the rest are spaced', async () => {
  const clock = fakeClock();
  const pacer = createPacer(clock.options);
  const sentAt = [];

  await Promise.all([1, 2, 3].map(
    (n) => pacer.spaced(async () => { sentAt.push([n, clock.at()]); }),
  ));

  assert.deepEqual(sentAt.map(([n]) => n), [1, 2, 3], 'redom kojim su tražene');
  assert.deepEqual(clock.waits, [MIN_REQUEST_GAP_MS, MIN_REQUEST_GAP_MS]);
  assert.equal(sentAt[0][1], 0, 'prvi ne čeka');
});

test('a caller that waited long enough is not made to wait again', async () => {
  const clock = fakeClock();
  const pacer = createPacer(clock.options);

  await pacer.spaced(async () => {});
  clock.advance(MIN_REQUEST_GAP_MS * 3);
  await pacer.spaced(async () => {});

  assert.deepEqual(clock.waits, [], 'razmak je već prošao sam od sebe');
});

test('one failed request does not stall every one after it', async () => {
  // The queue is a promise chain, and a rejection in a chain stops everything
  // behind it unless it is swallowed. That would be the same silent stall this
  // module exists to prevent, only worse: nothing would ever be sent again.
  const clock = fakeClock();
  const pacer = createPacer(clock.options);

  await assert.rejects(
    () => pacer.spaced(async () => { throw new Error('mreža'); }),
  );
  const after = await pacer.spaced(async () => 'ok');

  assert.equal(after, 'ok');
});

test('a block is served here, and it expires', () => {
  const clock = fakeClock();
  const pacer = createPacer(clock.options);

  assert.equal(pacer.blockedForMs(), 0);
  pacer.block();
  assert.equal(pacer.blockedForMs(), RATE_LIMIT_COOLDOWN_MS);

  clock.advance(RATE_LIMIT_COOLDOWN_MS - 1);
  assert.equal(pacer.blockedForMs(), 1);
  clock.advance(1);
  assert.equal(pacer.blockedForMs(), 0);
});

test('reset clears the block and the gap', async () => {
  const clock = fakeClock();
  const pacer = createPacer(clock.options);

  pacer.block();
  pacer.reset();

  assert.equal(pacer.blockedForMs(), 0);
  await pacer.spaced(async () => {});
  assert.deepEqual(clock.waits, [], 'posle reset-a prvi upit opet ne čeka');
});
