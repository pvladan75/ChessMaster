const test = require('node:test');
const assert = require('node:assert/strict');

const {
  judgeMove, bestLine, drillOutcome, flip, pieceCount,
} = require('../services/endgameDrill');
const { TablebaseUnavailable } = require('../services/tablebaseService');

// Bogoljubow-Alekhine 1922, the position the miner kept: Black to move and
// winning. Answers below are the real ones from the tables, not invented -
// three moves hold the win, two throw it away, and the shortest road is d5+.
const WON = '8/8/3pkp1p/7P/4KP2/8/8/8 b - - 6 53';
const AFTER_D5 = '8/8/4kp1p/3p3P/4KP2/8/8/8 w - - 0 54';
const AFTER_KD7 = '8/3k4/3p1p1p/7P/4KP2/8/8/8 w - - 7 54';

const PROBES = {
  [WON]: {
    category: 'win',
    dtz: 1,
    moves: [
      { uci: 'd6d5', san: 'd5+', category: 'loss', dtz: -4, zeroing: true },
      { uci: 'e6d7', san: 'Kd7', category: 'loss', dtz: -6, zeroing: false },
      { uci: 'e6f7', san: 'Kf7', category: 'loss', dtz: -6, zeroing: false },
      { uci: 'f6f5', san: 'f5+', category: 'draw', dtz: 0, zeroing: true },
      { uci: 'e6e7', san: 'Ke7', category: 'draw', dtz: 0, zeroing: false },
    ],
  },
  [AFTER_D5]: {
    category: 'loss',
    dtz: -4,
    moves: [
      { uci: 'e4d4', san: 'Kd4', category: 'win', dtz: 3, zeroing: false },
      { uci: 'e4d3', san: 'Kd3', category: 'win', dtz: 1, zeroing: false },
      { uci: 'e4e3', san: 'Ke3', category: 'win', dtz: 1, zeroing: false },
      { uci: 'e4f3', san: 'Kf3', category: 'win', dtz: 1, zeroing: false },
    ],
  },
  // And after Kd7, which also holds the win but walks nowhere.
  [AFTER_KD7]: {
    category: 'loss',
    dtz: -6,
    moves: [
      { uci: 'e4d5', san: 'Kd5', category: 'win', dtz: 5, zeroing: false },
      { uci: 'e4d4', san: 'Kd4', category: 'win', dtz: 3, zeroing: false },
      { uci: 'e4d3', san: 'Kd3', category: 'win', dtz: 1, zeroing: false },
      { uci: 'e4e3', san: 'Ke3', category: 'win', dtz: 1, zeroing: false },
      { uci: 'e4f3', san: 'Kf3', category: 'win', dtz: 1, zeroing: false },
      { uci: 'e4f5', san: 'Kf5', category: 'win', dtz: 1, zeroing: false },
      { uci: 'f4f5', san: 'f5', category: 'win', dtz: 3, zeroing: true },
    ],
  },
};

function fakeTablebase(probes = PROBES) {
  const asked = [];
  return {
    asked,
    probe: async (fen) => {
      asked.push(fen);
      if (!(fen in probes)) throw new TablebaseUnavailable(`nema odgovora za ${fen}`);
      return probes[fen];
    },
  };
}

test('a move that keeps the win is told so, and the opponent answers', async () => {
  const tb = fakeTablebase();
  const r = await judgeMove({ fen: WON, move: 'd5+', tablebase: tb });

  assert.equal(r.held, true);
  assert.equal(r.goal, 'win');
  assert.equal(r.outcome, 'win');
  assert.equal(r.playedSan, 'd5+');
  // Longest resistance: Kd4 runs three plies to the next zeroing move where
  // the other three run one, so a perfect defender picks it.
  assert.equal(r.reply.san, 'Kd4');
  assert.equal(r.finished, null);
});

test('a move that throws the win away says which result was lost', async () => {
  const tb = fakeTablebase();
  const r = await judgeMove({ fen: WON, move: 'Ke7', tablebase: tb });

  assert.equal(r.held, false);
  assert.equal(r.goal, 'win');
  assert.equal(r.outcome, 'draw');
  // No reply: the opponent does not get to defend a position they have already
  // saved, and the drill stops where the mistake was.
  assert.equal(r.reply, null);
  assert.equal(tb.asked.length, 1);
});

test('a conversion counts as progress even though the counter jumps', async () => {
  // d5+ is a pawn move, so DTZ resets from 1 to 4. Comparing the raw numbers
  // would report the one kind of progress that matters most as a step back.
  const tb = fakeTablebase();
  const r = await judgeMove({ fen: WON, move: 'd5+', tablebase: tb });

  assert.equal(r.zeroing, true);
  assert.equal(r.distanceBefore, 1);
  assert.equal(r.distanceAfter, 4);
  assert.equal(r.closer, true);
});

test('holding the win without getting nearer is not called progress', async () => {
  // Kd7 keeps the win and walks nowhere: six plies to the next zeroing move
  // where d5+ needed four. Correct, and worth saying that it gained nothing.
  const tb = fakeTablebase();
  const r = await judgeMove({ fen: WON, move: 'Kd7', tablebase: tb });

  assert.equal(r.held, true);
  assert.equal(r.zeroing, false);
  assert.equal(r.distanceBefore, 1);
  assert.equal(r.distanceAfter, 6);
  assert.equal(r.closer, false);
  // Kd5 is the longest resistance here, five plies against the others' one or
  // three, so the defender walks toward the pawn rather than away.
  assert.equal(r.reply.san, 'Kd5');
});

test('either notation is accepted', async () => {
  const tb = fakeTablebase();
  const san = await judgeMove({ fen: WON, move: 'd5+', tablebase: tb });
  const uci = await judgeMove({ fen: WON, move: 'd6d5', tablebase: tb });

  assert.equal(san.playedUci, uci.playedUci);
  assert.equal(san.held, uci.held);
});

test('an impossible move is refused rather than judged', async () => {
  const tb = fakeTablebase();
  await assert.rejects(
    () => judgeMove({ fen: WON, move: 'Qh8', tablebase: tb }),
    /nije moguć/
  );
});

test('a position past seven pieces is refused before anything is asked', async () => {
  // Asking anyway would get an answer no tablebase stands behind, and this
  // mode has no use for one.
  const tb = fakeTablebase();
  await assert.rejects(
    () => judgeMove({
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      move: 'e4',
      tablebase: tb,
    }),
    /sedam figura/
  );
  assert.equal(tb.asked.length, 0);
});

test('an unreachable tablebase stops the drill instead of guessing', async () => {
  const tb = {
    probe: async () => { throw new TablebaseUnavailable('nema mreze'); },
  };
  await assert.rejects(
    () => judgeMove({ fen: WON, move: 'd5+', tablebase: tb }),
    TablebaseUnavailable
  );
});

test('a cursed win is a draw here, not a win', () => {
  // Wins only if the fifty move rule is ignored. The collection already
  // excludes them, so letting one count would move the goalposts mid-drill.
  assert.equal(drillOutcome('win'), 'win');
  assert.equal(drillOutcome('cursed-win'), 'draw');
  assert.equal(drillOutcome('draw'), 'draw');
  assert.equal(drillOutcome('blessed-loss'), 'draw');
  assert.equal(drillOutcome('loss'), 'loss');
});

test('a result read from the other side is the same result', () => {
  assert.equal(flip('win'), 'loss');
  assert.equal(flip('loss'), 'win');
  assert.equal(flip('draw'), 'draw');
  assert.equal(pieceCount(WON), 7);
});

test('the line answers "why was that bad" with the punishment itself', async () => {
  // From the position after d5+, White is lost. Best play for both sides is
  // what refutes a move, and a line is a fact where an evaluation is an
  // opinion.
  const tb = fakeTablebase();
  const line = await bestLine({ fen: AFTER_D5, plies: 1, tablebase: tb });

  assert.equal(line.outcome, 'loss');
  // The losing side takes the longest road: Kd4 runs three plies to the next
  // zeroing move where the rest run one.
  assert.deepEqual(line.moves, ['Kd4']);
});

test('a line that walks off the tables stops loudly, not short', async () => {
  // Truncating would hand back a line that looks complete and is not, which is
  // the failure this project keeps meeting: a step that skips and reports
  // success. The fixture knows three positions; asking for twenty plies walks
  // past them.
  const tb = fakeTablebase();
  await assert.rejects(
    () => bestLine({ fen: AFTER_D5, plies: 20, tablebase: tb }),
    TablebaseUnavailable
  );
});

test('a position past seven pieces has no line', async () => {
  const tb = fakeTablebase();
  await assert.rejects(
    () => bestLine({
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      tablebase: tb,
    }),
    /sedam figura/
  );
});
