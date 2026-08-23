const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createTablebase, bestReply, wdlOf, TablebaseUnavailable,
} = require('../services/tablebaseService');

// A real seven-piece answer, trimmed to the fields the service reads. Black to
// move and winning; three of the five moves keep the win, two throw it away.
// The categories are written from the point of view of whoever moves next, so
// "loss" here means the mover wins after it.
const PAWN_ENDING = '8/8/3pkp1p/7P/4KP2/8/8/8 b - - 6 53';
const PAWN_ENDING_REPLY = {
  category: 'win',
  dtz: 1,
  moves: [
    { uci: 'd6d5', san: 'd5+', category: 'loss', dtz: -4, zeroing: true },
    { uci: 'e6d7', san: 'Kd7', category: 'loss', dtz: -6, zeroing: false },
    { uci: 'e6f7', san: 'Kf7', category: 'loss', dtz: -6, zeroing: false },
    { uci: 'e6e7', san: 'Ke7', category: 'draw', dtz: 0, zeroing: false },
    { uci: 'f6f5', san: 'f5+', category: 'draw', dtz: 0, zeroing: true },
  ],
};

function stubFetch(body, { failures = 0 } = {}) {
  let calls = 0;
  const fetchImpl = async () => {
    calls += 1;
    if (calls <= failures) throw new Error('mreza pukla');
    return { ok: true, json: async () => body };
  };
  return { fetchImpl, calls: () => calls };
}

test('a position is asked about once, however often it is probed', async () => {
  const stub = stubFetch(PAWN_ENDING_REPLY);
  const tb = createTablebase({ fetchImpl: stub.fetchImpl });

  await tb.probe(PAWN_ENDING);
  await tb.probe(PAWN_ENDING);
  await tb.probe(PAWN_ENDING);

  assert.equal(stub.calls(), 1);
  assert.equal(tb.stats().cached, 1);
});

test('probes racing on the same position share one request', async () => {
  // Two children on the same ending, or one client that retried, must not
  // become two requests to a donated service.
  const stub = stubFetch(PAWN_ENDING_REPLY);
  const tb = createTablebase({ fetchImpl: stub.fetchImpl });

  const [a, b] = await Promise.all([tb.probe(PAWN_ENDING), tb.probe(PAWN_ENDING)]);

  assert.equal(stub.calls(), 1);
  assert.equal(a.category, 'win');
  assert.equal(b.category, 'win');
});

test('the cache is bounded, so a long run does not grow without end', async () => {
  const stub = stubFetch(PAWN_ENDING_REPLY);
  const tb = createTablebase({ fetchImpl: stub.fetchImpl, cacheLimit: 2 });

  await tb.probe('a');
  await tb.probe('b');
  await tb.probe('c');

  assert.equal(tb.stats().cached, 2);
});

test('a dropped connection is retried, not reported as a lost position', async () => {
  const stub = stubFetch(PAWN_ENDING_REPLY, { failures: 2 });
  const tb = createTablebase({ fetchImpl: stub.fetchImpl, retries: 2 });

  const result = await tb.probe(PAWN_ENDING);

  assert.equal(result.category, 'win');
  assert.equal(stub.calls(), 3);
});

test('an unreachable tablebase throws rather than answering anyway', async () => {
  // The whole promise of this mode is that "you lost the win" is a fact. A
  // silent fallback to a search would keep the sentence and drop the fact.
  const tb = createTablebase({
    fetchImpl: async () => { throw new Error('nema mreze'); },
    retries: 1,
  });

  await assert.rejects(() => tb.probe(PAWN_ENDING), TablebaseUnavailable);
});

test('an HTTP error is not mistaken for an answer', async () => {
  const tb = createTablebase({
    fetchImpl: async () => ({ ok: false, status: 503, json: async () => ({}) }),
    retries: 0,
  });

  await assert.rejects(() => tb.probe(PAWN_ENDING), TablebaseUnavailable);
});

test('a category the tables will not commit to is refused', () => {
  // 'maybe-win' and 'unknown' are the service saying it does not know. Reading
  // either as a result would put a guess where the mode promises certainty.
  assert.equal(wdlOf('win'), 2);
  assert.equal(wdlOf('cursed-win'), 1);
  assert.equal(wdlOf('draw'), 0);
  assert.equal(wdlOf('loss'), -2);
  assert.throws(() => wdlOf('maybe-win'), TablebaseUnavailable);
  assert.throws(() => wdlOf('unknown'), TablebaseUnavailable);
  assert.throws(() => wdlOf(undefined), TablebaseUnavailable);
});

test('the side to move takes its win, and the shortest one', () => {
  // Black is winning here, so the three moves after which White is lost are
  // Black's. Kd7 and Kf7 run six plies to the next zeroing move and d5+ only
  // four: the shortest road is the one a perfect player takes.
  assert.equal(bestReply(PAWN_ENDING_REPLY.moves).uci, 'd6d5');
});

test('at DTZ 1 the winning move is the zeroing one, however far it looks', () => {
  // The bug this guards against was only visible in a game played to the end.
  // "Smallest DTZ" compares distances measured from different starting points,
  // because a capture or a pawn move resets the counter: here f5 wins and
  // zeroes, and the position it leaves happens to be eight plies from the next
  // reset, while Rc7 also wins and reads four. Taking Rc7 held the win and
  // made no progress, and the winner shuffled a rook back and forth forever.
  const atOne = [
    { uci: 'c1c7', san: 'Rc7', category: 'loss', dtz: -4, zeroing: false },
    { uci: 'f4f5', san: 'f5', category: 'loss', dtz: -8, zeroing: true },
  ];
  assert.equal(bestReply(atOne).san, 'f5');
});

test('a lost position is defended for as long as it can be', () => {
  // Every move here leaves the opponent winning, so the mover is lost. Taking
  // the shortest road would end the drill early and teach the child nothing
  // about converting; the longest is the honest defence.
  const lost = [
    { uci: 'a1a2', san: 'Ka2', category: 'win', dtz: 4, zeroing: false },
    { uci: 'a1b1', san: 'Kb1', category: 'win', dtz: 18, zeroing: false },
    { uci: 'a1b2', san: 'Kb2', category: 'win', dtz: 11, zeroing: false },
  ];
  assert.equal(bestReply(lost).uci, 'a1b1');
});

test('a defender who can draw does not lose on purpose', () => {
  const mixed = [
    { uci: 'a1a2', san: 'Ka2', category: 'win', dtz: 40, zeroing: false },
    { uci: 'a1b1', san: 'Kb1', category: 'draw', dtz: 0, zeroing: false },
  ];
  assert.equal(bestReply(mixed).category, 'draw');
});

test('two equally good replies do not alternate between runs', () => {
  // Without a stable tie-break the same drill would play out differently on
  // every attempt, and "you already tried this" would stop meaning anything.
  const tied = [
    { uci: 'e6f7', san: 'Kf7', category: 'loss', dtz: -6, zeroing: false },
    { uci: 'e6d7', san: 'Kd7', category: 'loss', dtz: -6, zeroing: false },
  ];
  assert.equal(bestReply(tied).uci, bestReply([...tied].reverse()).uci);
});

test('a position with no legal moves has no reply', () => {
  assert.equal(bestReply([]), null);
  assert.equal(bestReply(undefined), null);
});
