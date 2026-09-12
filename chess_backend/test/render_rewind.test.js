// render_rewind.test.js — the line under the board, and the three things it can
// say. `docs/PLAN-VRACANJE-NA-POZICIJU.md`.
//
// From the owner's requirement of 12.9.2026, after the first tutorial was
// rendered and published: a part that opens on a position the film has already
// shown must say so, because the board jumps and nothing on screen explains it.
// The published tutorial had four parts, and the same rule has to tell three
// cases apart — two of its parts continue from the board already on screen,
// where announcing anything would be words over a picture that did not change.
//
// **Why `underBoardText` is a function and not a line inside the drawing.**
// Text on a canvas cannot be read back out of a pixel: a frame of a returning
// beat and a frame of a fresh one both have ink under the board, so a test that
// looked at the picture could only say something was written there. Same reason
// `ffmpegArgsFor` was split out.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createCanvas } = require('@napi-rs/canvas');

const renderer = require('../videoRenderer');
const {
  underBoardText,
  applyEvent,
  initialFrameState,
  getResolutionParams,
} = renderer;

const FEN = '8/8/3k4/7R/8/5K2/8/8 w - - 6 4';

test('the line under the board answers three ways', () => {
  assert.equal(underBoardText({ lastMove: { san: 'Rh7' } }), 'Last move: Rh7');
  assert.equal(underBoardText({ lastMove: null }), 'Starting position');
  assert.equal(
    underBoardText({ lastMove: null, rewound: true, rewoundAfter: '12. Rh7' }),
    'Back to the position after 12. Rh7',
  );
  // A position that was only ever shown as some part's own opening has no move
  // to name — nothing arrived at it inside the film.
  assert.equal(
    underBoardText({ lastMove: null, rewound: true, rewoundAfter: null }),
    'Back to a position already shown',
  );
  // The note wins over a move left standing, which is what a return is.
  assert.equal(
    underBoardText({ lastMove: { san: 'Kc8' }, rewound: true, rewoundAfter: '3... Kd6' }),
    'Back to the position after 3... Kd6',
  );
});

test('a part that continues keeps the move that was lit under it', () => {
  // The parts join: the board does not move, and the previous part's last move
  // is exactly how this position was arrived at. Until 12.9.2026 every `init`
  // cleared it, so a tutorial cut into three parts went dark under the board
  // twice for no reason.
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'move',
    data: { fen: FEN, from: 'h5', to: 'h7', san: 'Rh7' },
  });
  state = applyEvent(state, {
    eventType: 'init',
    data: { fen: FEN, join: 'continues' },
  });

  assert.equal(state.lastMove.san, 'Rh7');
  assert.equal(state.rewound, false);
  assert.equal(underBoardText(state), 'Last move: Rh7');
});

test('a part that returns clears the move and says where it went back to', () => {
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'move',
    data: { fen: FEN, from: 'c6', to: 'c8', san: 'Kc8' },
  });
  state = applyEvent(state, {
    eventType: 'init',
    data: { fen: FEN, join: 'returns', afterMove: '3... Kd6' },
  });

  assert.equal(state.lastMove, null, 'no move arrived at this board in this part');
  assert.equal(state.rewound, true);
  assert.equal(underBoardText(state), 'Back to the position after 3... Kd6');
});

test('a fresh part clears both, and so does an init with no join at all', () => {
  // The recorded-lesson export sends one `init` and knows nothing about joins.
  // It must keep drawing exactly what it drew before this rule existed.
  for (const data of [{ fen: FEN, join: 'fresh' }, { fen: FEN }]) {
    let state = initialFrameState();
    state = applyEvent(state, {
      eventType: 'move',
      data: { fen: FEN, from: 'c6', to: 'c8', san: 'Kc8' },
    });
    state = applyEvent(state, { eventType: 'init', data });

    assert.equal(state.lastMove, null);
    assert.equal(state.rewound, false);
    assert.equal(state.rewoundAfter, null);
    assert.equal(underBoardText(state), 'Starting position');
  }
});

test('the note belongs to one beat', () => {
  // Like the caption and the marks: the first move out of the position it was
  // drawn about takes it away, or a film would carry „back to…" to its end.
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'init',
    data: { fen: FEN, join: 'returns', afterMove: '3... Kd6' },
  });
  state = applyEvent(state, {
    eventType: 'move',
    data: { fen: FEN, from: 'f3', to: 'e4', san: 'Ke4' },
  });

  assert.equal(state.rewound, false);
  assert.equal(state.rewoundAfter, null);
  assert.equal(underBoardText(state), 'Last move: Ke4');
});

test('the longest note fits the frame at every resolution', () => {
  // It is drawn centred under the board in `fontSizeMove`, and a caption that
  // runs off the edge is this repository's oldest recurring fault. „12. Rh7" is
  // as long as the label gets: „13... Qxh7+" is a move of a game nobody plays
  // on a rook-and-king board, so measure with something longer still.
  const note = underBoardText({ rewound: true, rewoundAfter: '188... Qxh7+' });
  for (const resolution of ['480p', '720p', '1080p']) {
    const cfg = getResolutionParams(resolution);
    const ctx = createCanvas(cfg.width, cfg.height).getContext('2d');
    ctx.font = `${cfg.fontSizeMove}px sans-serif`;
    assert.ok(ctx.measureText(note).width < cfg.width - 40,
      `${resolution}: the note is ${Math.round(ctx.measureText(note).width)} px of ${cfg.width}`);
  }
});
