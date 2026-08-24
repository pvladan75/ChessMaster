const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createOpeningExplorer, ratingBucketsFrom, OpeningExplorerUnavailable, MAX_MOVES,
} = require('../services/openingExplorerService');

const ITALIAN = 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 5 4';

// One Explorer answer, trimmed to the fields the service reads.
const ANSWER = {
  white: 4200,
  draws: 900,
  black: 3600,
  opening: { eco: 'C50', name: 'Italian Game' },
  moves: [
    { uci: 'g8f6', san: 'Nf6', white: 2100, draws: 400, black: 1800, averageRating: 1834 },
    { uci: 'f8c5', san: 'Bc5', white: 1500, draws: 300, black: 1400, averageRating: 1790 },
  ],
};

/// Records what was asked, so the tests can look at the query rather than
/// trusting that the right thing was sent.
function stubFetch(responses) {
  const queue = Array.isArray(responses) ? [...responses] : null;
  const urls = [];
  const fetchImpl = async (url) => {
    urls.push(url);
    const next = queue ? queue.shift() : responses;
    if (next instanceof Error) throw next;
    if (typeof next === 'number') return { ok: false, status: next, json: async () => ({}) };
    return { ok: true, status: 200, json: async () => next };
  };
  return { fetchImpl, urls, calls: () => urls.length };
}

/// A clock that only moves when something waits on it, so the pacing between
/// requests costs the test nothing.
function fakeClock() {
  let atMs = 0;
  const waits = [];
  return {
    waits,
    advance: (ms) => { atMs += ms; },
    options: {
      now: () => atMs,
      sleep: async (ms) => { waits.push(ms); atMs += ms; },
    },
  };
}

function explorer(stub, opts = {}) {
  const clock = opts.clock ?? fakeClock();
  const { clock: _ignored, ...rest } = opts;
  return createOpeningExplorer({
    fetchImpl: stub.fetchImpl, token: 'lip_test', ...clock.options, ...rest,
  });
}

test('a position is asked about once, however often it is probed', async () => {
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub);

  await ex.probe(ITALIAN);
  await ex.probe(ITALIAN);
  await ex.probe(ITALIAN);

  assert.equal(stub.calls(), 1);
  assert.equal(ex.stats().cached, 1);
  assert.equal(ex.stats().hits, 2);
});

test('probes racing on the same position share one request', async () => {
  // One token serves everyone, so two children in the same opening must not
  // spend two requests on the same question.
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub);

  const [a, b] = await Promise.all([ex.probe(ITALIAN), ex.probe(ITALIAN)]);

  assert.equal(stub.calls(), 1);
  assert.equal(a.opening.eco, 'C50');
  assert.equal(b.opening.eco, 'C50');
});

test('the cache is bounded, so a long run does not grow without end', async () => {
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub, { cacheLimit: 3 });

  for (let i = 0; i < 10; i += 1) {
    await ex.probe(`${ITALIAN} ${i}`);
  }

  assert.equal(ex.stats().cached, 3);
});

test('the same position under different filters is a different question', async () => {
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub);

  await ex.probe(ITALIAN);
  await ex.probe(ITALIAN, { minRating: 2000 });
  await ex.probe(ITALIAN, { moves: 20 });

  assert.equal(stub.calls(), 3);
});

test('a rating floor asks for every bucket above it, not only that one', () => {
  // The panel says "1600+". Sending ratings=1600 answers with games between
  // 1600 and 1799 and looks entirely plausible while doing it.
  assert.deepEqual(ratingBucketsFrom(1600), [1600, 1800, 2000, 2200, 2500]);
  assert.deepEqual(ratingBucketsFrom(2500), [2500]);
  assert.equal(ratingBucketsFrom(null), null);
});

test('a rating floor that is not a bucket is refused, not rounded', () => {
  assert.throws(() => ratingBucketsFrom(1650), RangeError);
});

test('the request carries the filter and drops the game lists', async () => {
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub);

  await ex.probe(ITALIAN, { minRating: 2200 });

  const url = stub.urls[0];
  assert.match(url, /ratings=2200%2C2500/);
  assert.match(url, /topGames=0/);
  assert.match(url, /recentGames=0/);
});

test('an absurd move count is clamped rather than passed on', async () => {
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub);

  await ex.probe(ITALIAN, { moves: 5000 });

  assert.match(stub.urls[0], new RegExp(`moves=${MAX_MOVES}(&|$)`));
});

test('a move keeps its average rating whichever name Lichess gives it', async () => {
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub);

  const result = await ex.probe(ITALIAN);

  assert.equal(result.moves[0].averageOpponentRating, 1834);
});

test('no token configured is its own answer, and costs no request', async () => {
  const stub = stubFetch(ANSWER);
  const ex = createOpeningExplorer({ fetchImpl: stub.fetchImpl, token: '' });

  await assert.rejects(() => ex.probe(ITALIAN), (err) => {
    assert.ok(err instanceof OpeningExplorerUnavailable);
    assert.equal(err.reason, 'not-configured');
    return true;
  });
  assert.equal(stub.calls(), 0);
  assert.equal(ex.isConfigured(), false);
});

test('a refused token is reported as refused and not asked twice', async () => {
  const stub = stubFetch([401, 401]);
  const ex = explorer(stub);

  await assert.rejects(() => ex.probe(ITALIAN), (err) => {
    assert.equal(err.reason, 'unauthorized');
    return true;
  });
  // Retrying a rejected token only spends time; the second call would fail the
  // same way and would hide the first reason behind a network message.
  assert.equal(stub.calls(), 1);
});

test('a spent allowance is not made worse by asking again', async () => {
  const stub = stubFetch([429, 429]);
  const ex = explorer(stub);

  await assert.rejects(() => ex.probe(ITALIAN), (err) => {
    assert.equal(err.reason, 'rate-limited');
    return true;
  });
  assert.equal(stub.calls(), 1);
});

test('a dropped connection is retried, and then reported as network', async () => {
  const stub = stubFetch([new Error('mreza pukla'), new Error('mreza pukla')]);
  const ex = explorer(stub, { retries: 1 });

  await assert.rejects(() => ex.probe(ITALIAN), (err) => {
    assert.equal(err.reason, 'network');
    return true;
  });
  assert.equal(stub.calls(), 2);
});

test('a retry that succeeds answers normally', async () => {
  const stub = stubFetch([new Error('mreza pukla'), ANSWER]);
  const ex = explorer(stub, { retries: 1 });

  const result = await ex.probe(ITALIAN);

  assert.equal(stub.calls(), 2);
  assert.equal(result.moves.length, 2);
});

test('a failed lookup is not remembered as an answer', async () => {
  // Otherwise one bad minute would keep answering "no games" from the cache
  // long after Lichess came back.
  const stub = stubFetch([new Error('mreza pukla'), new Error('mreza pukla'), ANSWER]);
  const ex = explorer(stub, { retries: 1 });

  await assert.rejects(() => ex.probe(ITALIAN));
  const result = await ex.probe(ITALIAN);

  assert.equal(result.white, 4200);
  assert.equal(ex.stats().cached, 1);
});

test('a broken request is judged before the server\'s own configuration', async () => {
  // Otherwise a client sending a filter that does not exist is answered "the
  // server has no token", goes looking in .env, and finds nothing wrong there.
  const stub = stubFetch(ANSWER);
  const ex = createOpeningExplorer({ fetchImpl: stub.fetchImpl, token: '' });

  await assert.rejects(() => ex.probe(ITALIAN, { minRating: 1650 }), RangeError);
});

test('a missing position is the caller\'s mistake, not the upstream\'s', async () => {
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub);

  await assert.rejects(() => ex.probe(''), RangeError);
  assert.equal(stub.calls(), 0);
});

test('two different positions are asked about with a gap between them', async () => {
  // The Explorer is computed rather than served from a file, and Lichess asks
  // for 100-200 ms between calls. One child clicking through an opening is
  // slower than that; a screen that fetches on every node is not.
  const clock = fakeClock();
  const stub = stubFetch(ANSWER);
  const ex = explorer(stub, { clock });

  await ex.probe(ITALIAN);
  await ex.probe('rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2');

  assert.equal(stub.calls(), 2);
  assert.equal(clock.waits.length, 1);
  assert.ok(clock.waits[0] >= 100, `razmak je bio ${clock.waits[0]} ms`);
});

test('after a 429 the book stops asking until the block has passed', async () => {
  // The token spent here is the server's, so a block earned by one child would
  // otherwise be knocked into an hour by the next twenty.
  const clock = fakeClock();
  let sent = 0;
  const stub = {
    fetchImpl: async () => {
      sent += 1;
      return { ok: false, status: 429, json: async () => ({}) };
    },
    calls: () => sent,
  };
  const ex = explorer(stub, { clock });

  await assert.rejects(() => ex.probe(ITALIAN), (err) => {
    assert.equal(err.reason, 'rate-limited');
    return true;
  });
  assert.equal(sent, 1, 'na 429 se ne pokušava ponovo');
  assert.ok(ex.stats().blockedForMs > 0);

  await assert.rejects(
    () => ex.probe('rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2'),
    (err) => {
      assert.equal(err.reason, 'rate-limited');
      return true;
    },
  );
  assert.equal(sent, 1, 'za vreme blokade ne izlazi nijedan upit');

  clock.advance(61 * 1000);
  assert.equal(ex.stats().blockedForMs, 0);
  await assert.rejects(() => ex.probe(ITALIAN));
  assert.equal(sent, 2, 'posle isteka blokade se opet pita');
});
