// render_font.test.js — the letters a film is drawn with.
//
// „u renderovanom videu slova č, ć se ne vide" — reported live on 11.9.2026,
// with a still whose caption read „Ovo je po□etak". The renderer had asked for
// `sans-serif` since it was written, which is not a font but whatever the
// machine hands back, and on that machine it had no Latin Extended-A at all.
//
// **The test that could not fail is the interesting part.** A frame was already
// checked for ink, and a box is ink. Two letters that differ only in the
// diacritic are what tells a font from a row of boxes: a font that has neither
// draws the same box twice, so `č` and `ć` come out byte for byte identical.
const test = require('node:test');
const assert = require('node:assert/strict');

const renderFont = require('../services/renderFont');
const videoRenderer = require('../videoRenderer');

/// The environment this module reads, put back afterwards.
async function withFontEnv({ family = '', file = '' }, run) {
  const saved = {
    family: process.env.RENDER_FONT_FAMILY,
    file: process.env.RENDER_FONT_PATH,
  };
  try {
    process.env.RENDER_FONT_FAMILY = family;
    process.env.RENDER_FONT_PATH = file;
    renderFont.forgetFont();
    return await run();
  } finally {
    for (const [name, value] of [
      ['RENDER_FONT_FAMILY', saved.family],
      ['RENDER_FONT_PATH', saved.file],
    ]) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
    renderFont.forgetFont();
  }
}

test('two letters that differ only in the diacritic tell a font from a box', () => {
  // The whole mechanism, on its own. `sans-serif` is the state that shipped:
  // every accented letter is the same box, so the three stamps collapse to
  // two - and a font that really has them draws three different things.
  assert.equal(renderFont.draws(renderFont.LATIN, 'sans-serif'), false,
    'this is the fault that was reported, reproduced');
  assert.equal(renderFont.draws(['c'], 'sans-serif'), true,
    'and it is only the accented letters: plain c was always fine');
});

test('the family chosen draws Serbian, in both scripts', async () => {
  await withFontEnv({}, () => {
    const family = renderFont.fontFamily();
    assert.ok(family, 'a family was chosen');
    assert.notEqual(family, 'sans-serif',
      'a machine with no usable font is a loud log line, not a silent film of boxes');
    assert.equal(renderFont.draws(renderFont.LATIN, family), true, 'č, ć and c');
    assert.equal(renderFont.draws(renderFont.CYRILLIC, family), true, 'ж and ф');
  });
});

test('the family is chosen by what it can draw, not by what is installed first', () => {
  // **Written because a mutation survived.** „Take the first installed
  // candidate" left every test green on this machine, where the first one
  // happens to be right - and would have shipped a film of boxes to any machine
  // where it is not. The search is separated from the drawing for exactly that
  // reason: this asks the question with the fonts made up.
  const has = (...names) => new Set(names);
  const canDraw = (table) => (family, letters) =>
    (table[family] || []).includes(letters === renderFont.CYRILLIC ? 'cyrillic' : 'latin');

  const skipsTheEmptyOne = renderFont.pickFamily({
    candidates: ['Boxes', 'Good'],
    installed: has('Boxes', 'Good'),
    canDraw: canDraw({ Good: ['latin', 'cyrillic'] }),
  });
  assert.deepEqual(skipsTheEmptyOne, { family: 'Good', missing: null },
    'a font that draws none of it is not the font, however early it is listed');

  const prefersBothScripts = renderFont.pickFamily({
    candidates: ['LatinOnly', 'Both'],
    installed: has('LatinOnly', 'Both'),
    canDraw: canDraw({ LatinOnly: ['latin'], Both: ['latin', 'cyrillic'] }),
  });
  assert.equal(prefersBothScripts.family, 'Both');

  const settlesForLatin = renderFont.pickFamily({
    candidates: ['LatinOnly', 'Both'],
    installed: has('LatinOnly'),
    canDraw: canDraw({ LatinOnly: ['latin'], Both: ['latin', 'cyrillic'] }),
  });
  assert.deepEqual(settlesForLatin, { family: 'LatinOnly', missing: 'cyrillic' },
    'worth having, and worth saying out loud');

  const nothingUsable = renderFont.pickFamily({
    candidates: ['Boxes'],
    installed: has('Boxes'),
    canDraw: canDraw({}),
  });
  assert.deepEqual(nothingUsable, { family: 'sans-serif', missing: 'latin' },
    'the state that shipped, and it is an error line rather than a silence');
});

test('a family named in the environment is used as it was named', async () => {
  // An operator who names a font means it, and a silent second-guess is what
  // this module exists to stop.
  await withFontEnv({ family: 'Comic Sans MS' }, () => {
    assert.equal(renderFont.fontFamily(), 'Comic Sans MS');
  });
});

test('a font path that cannot be registered is loud', async () => {
  // Same instinct as DB_CA_PATH pointing at nothing: a typo in the environment
  // must not read as „the fonts are fine".
  await withFontEnv({ file: 'D:/nothing/here.ttf' }, () => {
    assert.throws(() => renderFont.fontFamily(), /RENDER_FONT_PATH/);
  });
});

test('a caption with č is not the same picture as one with ć', async () => {
  // End to end, through the renderer's own drawing: this is what „Ovo je
  // po□etak" looked like from the outside, and what proves the family reaches
  // the canvas rather than only the module that chose it.
  const beat = (text) => ({
    timestampMs: 0,
    eventType: 'init',
    data: {
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      text,
    },
  });
  const frameOf = (text) => videoRenderer.renderPreviewFrame({
    title: 'x',
    timelineEvents: [beat(text)],
    beatIndex: 0,
    durationSeconds: 6,
    resolution: '480p',
  });

  const caron = await frameOf('Ovo je počinje');
  const acute = await frameOf('Ovo je poćinje');
  const plain = await frameOf('Ovo je pocinje');

  assert.equal(caron.equals(acute), false,
    'č and ć are two letters; one box for both is the bug');
  assert.equal(caron.equals(plain), false,
    'and neither of them is a plain c');
});

test('the title is drawn with the same letters as the caption', async () => {
  // The title, the timer, the coordinates and the move strip are drawn by four
  // more `ctx.font` lines, and a fix applied to one of them would have left the
  // title reading „Po□etak" over a caption that was finally right.
  const beat = {
    timestampMs: 0,
    eventType: 'init',
    data: {
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      text: 'x',
    },
  };
  const frameOf = (title) => videoRenderer.renderPreviewFrame({
    title,
    timelineEvents: [beat],
    beatIndex: 0,
    durationSeconds: 6,
    resolution: '480p',
  });

  assert.equal((await frameOf('Počinje')).equals(await frameOf('Poćinje')), false);
});
