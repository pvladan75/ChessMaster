const test = require('node:test');
const assert = require('node:assert/strict');

const { Chess } = require('chess.js');
const {
  judgeMove, bestLine, drillOutcome, flip, pieceCount, readout, hangsAfter,
  endOf,
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

// --- The readout, and the dead draw ----------------------------------------

// Rook against rook, nothing else on the board. Every move draws except the
// ones that put the rook where it can be taken for nothing, and there are no
// pawns: the trainer's own description of a position that is over.
const RR = '3r2k1/8/8/8/8/8/8/3R2K1 w - - 0 1';

const RR_PROBE = {
  category: 'draw',
  dtz: 0,
  moves: [
    // Categories are read from the far side of the move, as the tables give
    // them: 'win' here means the opponent wins after it.
    { uci: 'd1d8', san: 'Rxd8+', category: 'draw', dtz: 0, zeroing: true },
    { uci: 'd1a1', san: 'Ra1', category: 'draw', dtz: 0, zeroing: false },
    { uci: 'g1f1', san: 'Kf1', category: 'draw', dtz: 0, zeroing: false },
    { uci: 'd1d4', san: 'Rd4', category: 'win', dtz: 12, zeroing: false },
    { uci: 'd1d5', san: 'Rd5', category: 'win', dtz: 10, zeroing: false },
  ],
};

test('the readout names every move, holders first and progress before them',
  async () => {
    const tb = fakeTablebase({ [RR]: RR_PROBE });
    const r = await readout({ fen: RR, goal: 'draw', tablebase: tb });

    assert.equal(r.outcome, 'draw');
    assert.equal(r.total, 5);
    assert.equal(r.holding, 3);
    // The capture zeroes the counter, so it comes first among the three that
    // hold; the two that drop the rook come last whatever their distance.
    // Equal distance and neither zeroing, so the tie falls to the notation.
    assert.deepEqual(r.moves.map((m) => m.san),
      ['Rxd8+', 'Kf1', 'Ra1', 'Rd5', 'Rd4']);
    assert.deepEqual(r.moves.map((m) => m.holds),
      [true, true, true, false, false]);
    assert.equal(r.moves[0].zeroing, true);
    assert.equal(r.moves[3].outcome, 'loss');
  });

test('a pawnless draw whose only losses give a piece away is finished',
  async () => {
    const tb = fakeTablebase({ [RR]: RR_PROBE });
    const r = await readout({ fen: RR, goal: 'draw', tablebase: tb });
    assert.equal(r.pawnless, true);
    assert.equal(r.deadDraw, true);
  });

test('a loss that is not a piece given away leaves the drill running',
  async () => {
    // A shape that is not on the list, so the computed rule decides: here the
    // king move loses and nothing is hanging, which means there is a decision
    // to get wrong and the draw is not over.
    const fen = '3r2k1/8/8/8/8/8/8/2BR2K1 w - - 0 1';
    const tb = fakeTablebase({
      [fen]: {
        category: 'draw',
        dtz: 0,
        moves: [
          { uci: 'd1a1', san: 'Ra1', category: 'draw', dtz: 0, zeroing: false },
          { uci: 'g1f1', san: 'Kf1', category: 'win', dtz: 8, zeroing: false },
        ],
      },
    });
    const r = await readout({ fen, goal: 'draw', tablebase: tb });
    assert.equal(r.deadDraw, false);
  });

test('a shape off the list is not finished, whatever the moves say', async () => {
  // Both tests have to pass, not either. Rook and bishop against a rook is
  // nobody's named ending, so even with nothing but gifts to lose by, the draw
  // stays open - the cautious way round on purpose: closing a draw that was not
  // finished takes the exercise away, leaving one open costs a few moves.
  const fen = '3r2k1/8/8/8/8/8/8/2BR2K1 w - - 0 1';
  const tb = fakeTablebase({
    [fen]: {
      category: 'draw',
      dtz: 0,
      moves: [
        { uci: 'd1a1', san: 'Ra1', category: 'draw', dtz: 0, zeroing: false },
        { uci: 'd1d4', san: 'Rd4', category: 'win', dtz: 8, zeroing: false },
      ],
    },
  });
  const r = await readout({ fen, goal: 'draw', tablebase: tb });
  assert.equal(r.deadDraw, false);
});

test('an oversight is also the piece lost a move later', () => {
  // Da Silva - Gazel Pereira 2010 with the pawn gone. Kc3 leaves nothing en
  // prise and loses the queen anyway: the king on c3 and the queen on e5 stand
  // on one diagonal, so Qa1+ takes it next move. A fork or a skewer is the
  // same oversight with a move's delay, which is why this looks two of the
  // opponent's moves ahead.
  const fen = '8/8/6K1/4q3/3k4/8/8/1Q6 b - - 0 1';
  const drill = require('../services/endgameDrill');
  assert.equal(drill.hangsAfter(fen, 'd4c3'), false, 'nista ne visi odmah');
  assert.equal(drill.losesPieceOutright(fen, 'd4c3'), true, 'dama pada na Qa1+');
  assert.equal(drill.losesPieceOutright(fen, 'd4d5'), false, 'bezbedan potez');
});

test('a pawn on the board is always something left to hold', async () => {
  const fen = '3r2k1/8/8/8/8/8/6P1/3R2K1 w - - 0 1';
  const tb = fakeTablebase({ [fen]: RR_PROBE });
  const r = await readout({ fen, goal: 'draw', tablebase: tb });
  assert.equal(r.pawnless, false);
  assert.equal(r.deadDraw, false);
});

test('a win being played out is never a finished draw', async () => {
  const tb = fakeTablebase({ [RR]: RR_PROBE });
  const r = await readout({ fen: RR, goal: 'win', tablebase: tb });
  assert.equal(r.deadDraw, false);
  // And with a win to keep, the moves that only draw no longer hold.
  assert.equal(r.holding, 0);
});

test('the shapes a draw cannot be lost from are recognised by name', () => {
  // The trainer's list, and the reason it is a list: these are endings a
  // player names on sight, and the set is closed rather than something the
  // next mining run adds to.
  const dead = require('../services/endgameDrill').deadDrawnMaterial;
  assert.equal(dead('3r2k1/8/8/8/8/8/8/3R2K1 w - - 0 1'), true, 'R vs R');
  assert.equal(dead('3q2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1'), true, 'Q vs Q');
  assert.equal(dead('3b2k1/8/8/8/8/8/8/3R2K1 w - - 0 1'), true, 'B vs R');
  assert.equal(dead('3n2k1/8/8/8/8/8/8/3R2K1 w - - 0 1'), true, 'N vs R');
  assert.equal(dead('6k1/8/8/8/8/8/8/3N2K1 w - - 0 1'), true, 'N vs K');
  assert.equal(dead('6k1/8/8/8/8/8/8/3B2K1 w - - 0 1'), true, 'B vs K');
  assert.equal(dead('6k1/8/8/8/8/8/8/1N1N2K1 w - - 0 1'), true, 'NN vs K');
});

test('two bishops are only dead when they share a colour', () => {
  // On one colour they cannot mate at all. On two they can, and the list must
  // not be the thing that says otherwise.
  const dead = require('../services/endgameDrill').deadDrawnMaterial;
  assert.equal(dead('6k1/8/8/8/8/8/8/2B1B1K1 w - - 0 1'), true, 'obe tamne');
  assert.equal(dead('6k1/8/8/8/8/8/8/2BB2K1 w - - 0 1'), false, 'raznobojni');
});

test('a shape the tables call won is won, list or no list', async () => {
  // Queen against rook is not on the list, and would not survive the verdict
  // if it were: the outcome from the tables guards every path to deadDraw.
  const fen = '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1';
  const tb = fakeTablebase({
    [fen]: {
      category: 'win',
      dtz: 12,
      moves: [{ uci: 'd1d8', san: 'Qxd8+', category: 'loss', dtz: 0, zeroing: true }],
    },
  });
  const r = await readout({ fen, goal: 'draw', tablebase: tb });
  assert.equal(r.deadDraw, false);
});

test('hanging is being taken for nothing, not being taken', () => {
  // Rd4 can be taken by the rook on d8 and nothing defends it.
  assert.equal(hangsAfter(RR, 'd1d4'), true);
  // Rxd8+ is a capture the king answers - an exchange, not a gift, and in this
  // ending the exchange is the draw itself.
  assert.equal(hangsAfter(RR, 'd1d8'), false);
  // A king cannot be left en prise, so a king move never hangs.
  assert.equal(hangsAfter(RR, 'g1f1'), false);
});

test('a position past seven pieces has no readout to give', async () => {
  const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  await assert.rejects(
    () => readout({ fen, goal: 'win', tablebase: fakeTablebase({}) }),
    /sedam figura/
  );
});

// --- How a draw actually ended ---------------------------------------------

test('a repetition is not reported as fifty moves without a capture', () => {
  // The two are both draws and are not the same thing to say. A dead drawn
  // rook ending repeats in a few moves, and saying "fifty moves" there names a
  // counter that has barely started.
  const board = new Chess('3r2k1/8/8/8/8/8/8/3R2K1 w - - 0 1');
  for (const move of ['Rd2', 'Rd7', 'Rd1', 'Rd8', 'Rd2', 'Rd7', 'Rd1', 'Rd8']) {
    board.move(move);
  }
  assert.equal(endOf(board), 'repetition');
});

test('a counter that really ran out says so', () => {
  const board = new Chess('3r2k1/8/8/8/8/8/8/3R2K1 w - - 100 80');
  assert.equal(endOf(board), 'fifty_moves');
});
