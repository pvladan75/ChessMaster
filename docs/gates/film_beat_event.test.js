// The gate for phase 6 of docs/PLAN-PRIPREMA.md, the film's half on the server.
//
// Drafted by the lead on 27.9.2026. It moves to
// chess_backend/test/film_beat_event.test.js when the phase is briefed. Not yet
// run.
//
// A position may hold several beats — a sentence and the marks that stand
// while it is said. In a film the first beat of a position is the `init` or
// the `move` that put the position on the board, as ever; every beat after it
// is an event of kind `beat`, which changes what is said and what is drawn and
// **nothing else**.
//
// Read on master before this was written: `applyEvent` already leaves the
// position and the last move alone for a kind it does not know, and takes the
// caption, the arrows and the squares from any event. What it does **not**
// leave alone is the note under the board — `rewound` is cleared at the top of
// every event — so the second sentence on a position the film went back to
// would stand over „Starting position". That is this file's red.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  applyEvent,
  initialFrameState,
  underBoardText,
} = require('../videoRenderer');

const FEN = '2k5/8/2K5/8/8/8/8/7R w - - 0 1';
const NEXT = '2k5/7R/2K5/8/8/8/8/8 b - - 1 1';

test('a beat changes the words and the marks, and leaves the board alone', () => {
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'move',
    data: {
      fen: NEXT, from: 'h1', to: 'h7', san: 'Rh7',
      text: 'The rook cuts the king off.',
      arrows: [{ from: 'h1', to: 'h7', color: 'G' }],
      orientation: 'white',
    },
  });
  state = applyEvent(state, {
    eventType: 'beat',
    data: {
      fen: NEXT,
      text: 'Now the seventh rank is closed.',
      arrows: [{ from: 'h7', to: 'a7', color: 'R' }],
      squares: [{ square: 'c8', color: 'R' }],
      orientation: 'white',
    },
  });

  assert.equal(state.fen, NEXT);
  assert.deepEqual(state.lastMove, { from: 'h1', to: 'h7', san: 'Rh7' },
    'the move that arrived at the position is still the last move');
  assert.equal(state.caption, 'Now the seventh rank is closed.');
  assert.deepEqual(state.arrows, [{ from: 'h7', to: 'a7', color: 'R' }]);
  assert.deepEqual(state.squares, [{ square: 'c8', color: 'R' }]);
  assert.equal(underBoardText(state), 'Last move: Rh7');
});

test('a beat with nothing drawn clears what the beat before it drew', () => {
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'init',
    data: { fen: FEN, text: 'Look at the rook.', arrows: [{ from: 'h1', to: 'h8', color: 'G' }] },
  });
  state = applyEvent(state, { eventType: 'beat', data: { fen: FEN, text: 'And at the king.' } });
  assert.deepEqual(state.arrows, []);
  assert.deepEqual(state.squares, []);
  assert.equal(state.caption, 'And at the king.');
});

test('a beat on a position the film went back to keeps saying where it went back to', () => {
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'move',
    data: { fen: NEXT, from: 'h1', to: 'h7', san: 'Rh7' },
  });
  state = applyEvent(state, {
    eventType: 'init',
    data: { fen: FEN, join: 'returns', afterMove: '3... Kd6', text: 'Back here.' },
  });
  assert.equal(underBoardText(state), 'Back to the position after 3... Kd6');

  state = applyEvent(state, { eventType: 'beat', data: { fen: FEN, text: 'There was another way.' } });
  assert.equal(state.rewound, true);
  assert.equal(state.rewoundAfter, '3... Kd6');
  assert.equal(underBoardText(state), 'Back to the position after 3... Kd6',
    'the second sentence stood over „Starting position"');
});

test('the move after the beats clears the note, as a move always has', () => {
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'init',
    data: { fen: FEN, join: 'returns', afterMove: '3... Kd6' },
  });
  state = applyEvent(state, { eventType: 'beat', data: { fen: FEN, text: 'Once more.' } });
  state = applyEvent(state, {
    eventType: 'move',
    data: { fen: NEXT, from: 'h1', to: 'h7', san: 'Rh7' },
  });
  assert.equal(state.rewound, false);
  assert.equal(underBoardText(state), 'Last move: Rh7');
});

test('a recorded lesson\'s change of marks is drawn as it always was', () => {
  // `arrow_drawn` is the recording's kind and is not this phase's to change.
  let state = initialFrameState();
  state = applyEvent(state, { eventType: 'init', data: { fen: FEN } });
  state = applyEvent(state, {
    eventType: 'arrow_drawn',
    data: { arrows: [{ from: 'h1', to: 'h8', color: 'G' }] },
  });
  assert.equal(state.fen, FEN);
  assert.deepEqual(state.arrows, [{ from: 'h1', to: 'h8', color: 'G' }]);
  assert.equal(state.rewound, false);
});
