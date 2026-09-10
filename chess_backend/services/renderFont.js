// renderFont.js — the letters a film is drawn with, chosen by drawing them.
//
// **„u renderovanom videu slova č, ć se ne vide"**, reported live on 11.9.2026
// with a still of a film whose caption read „Ovo je po□etak". The renderer had
// asked for `sans-serif` since it was written, and `sans-serif` is not a font:
// it is whatever the machine hands back. On the owner's Windows box that was a
// family with no Latin Extended-A at all, so every š, đ, č, ć and ž in every
// caption of every film has been a box — and the two are indistinguishable from
// each other, which is exactly how it survived a pixel test that asked whether
// there was ink.
//
// So the family is not named here either. It is **chosen by drawing with it**:
// „č" and „ć" are two different glyphs, and a font that has neither draws the
// same box twice. Comparing the two answers the only question worth asking, on
// whichever machine is doing the drawing — and the same trick answers it for
// Cyrillic, which a trainer may write a caption in and which the Serbian voice
// words are written in.
//
// This is the fourth entry in this project's oldest family of faults: a step
// that skips silently and reports success. A missing glyph is not an error
// anywhere in the stack — freetype draws `.notdef` and the render finishes.
const { createCanvas, GlobalFonts } = require('@napi-rs/canvas');

const logger = require('./logger');

/// Families to try, best first. DejaVu is the one both targets have — Ubuntu
/// through `fonts-dejavu-core`, and it turned out to be on the owner's Windows
/// machine too — and it carries Latin Extended-A and Cyrillic in one file.
const CANDIDATES = [
  'DejaVu Sans',
  'Noto Sans',
  'Liberation Sans',
  'Arial',
  'Segoe UI',
  'Verdana',
];

/// The letters that have to come out as themselves.
///
/// Two of each, differing only in the diacritic, because a font that has
/// neither draws one box for both: `č`/`ć` for the Serbian Latin a caption is
/// written in, and `ж`/`ф` for the Cyrillic one. The plain `c` is there to
/// catch a font that quietly maps the accented letter onto its base.
const LATIN = ['č', 'ć', 'c'];
const CYRILLIC = ['ж', 'ф'];

let chosen = null;

/// What one glyph looks like in one family, as bytes that can be compared.
function stamp(text, family) {
  const canvas = createCanvas(64, 64);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#000000';
  ctx.fillRect(0, 0, 64, 64);
  ctx.fillStyle = '#ffffff';
  ctx.font = `40px ${family}`;
  ctx.fillText(text, 8, 48);
  return canvas.toBuffer('image/png').toString('base64');
}

/// Whether every one of [letters] is drawn as its own glyph in [family].
///
/// All of them pairwise different: two boxes are equal, and a box is not what
/// the letter beside it looks like either.
function draws(letters, family) {
  const stamps = letters.map((letter) => stamp(letter, family));
  return new Set(stamps).size === stamps.length;
}

/// The family a film is drawn with, chosen once per process.
///
/// `RENDER_FONT_FAMILY` overrides the search and is used as given — an operator
/// who names a font means it, and a silent second-guess is what this module
/// exists to stop. `RENDER_FONT_PATH` registers a font file first, for a
/// machine whose fonts are not installed system-wide.
function fontFamily() {
  if (chosen) return chosen;

  const named = (process.env.RENDER_FONT_FAMILY || '').trim();
  const file = (process.env.RENDER_FONT_PATH || '').trim();
  if (file) {
    // Loud on failure rather than a quiet fall back to the search: a path in
    // the environment is somebody's decision, and a typo in it must not read as
    // „the fonts are fine".
    const ok = GlobalFonts.registerFromPath(file, named || 'RenderFont');
    if (!ok) throw new Error(`RENDER_FONT_PATH could not be registered: ${file}`);
    chosen = named || 'RenderFont';
    return chosen;
  }
  if (named) {
    chosen = named;
    return chosen;
  }

  const picked = pickFamily({
    candidates: CANDIDATES,
    installed: new Set(GlobalFonts.families.map((f) => f.family)),
    canDraw: (family, letters) => draws(letters, family),
  });

  if (picked.missing === 'cyrillic') {
    logger.warn({ family: picked.family },
      '[RENDER] no installed font draws Cyrillic; captions in it will be boxes');
  }
  if (picked.missing === 'latin') {
    logger.error({ tried: CANDIDATES },
      '[RENDER] no installed font draws č and ć; captions will be boxes. '
      + 'Install fonts-dejavu-core, or set RENDER_FONT_PATH to a font file.');
  }
  chosen = picked.family;
  return chosen;
}

/// Which family to use, given what is installed and what each one can draw.
///
/// **Pure, and that is the point of it.** The search itself is only as
/// trustworthy as the machine it runs on: a mutation that took the first
/// installed candidate without asking whether it draws anything survived here,
/// because the first candidate on this machine happens to be the right one. It
/// would not survive on a machine without DejaVu — which is the local-versus-CI
/// shape this project has paid for three times, and the reason the choice is
/// separated from the drawing.
///
/// Serbian Latin is what the captions are written in and what the app ships;
/// Cyrillic is a caption a trainer may write, and the words a Cyrillic voice is
/// given. One without the other is worth having, and worth saying out loud.
function pickFamily({ candidates, installed, canDraw }) {
  const usable = candidates.filter((family) => installed.has(family));

  const full = usable.find(
    (family) => canDraw(family, LATIN) && canDraw(family, CYRILLIC));
  if (full) return { family: full, missing: null };

  const latinOnly = usable.find((family) => canDraw(family, LATIN));
  if (latinOnly) return { family: latinOnly, missing: 'cyrillic' };

  return { family: 'sans-serif', missing: 'latin' };
}

/// For the tests, and for anything that changes the environment mid-process.
function forgetFont() {
  chosen = null;
}

module.exports = {
  fontFamily, forgetFont, pickFamily, draws, stamp, CANDIDATES, LATIN, CYRILLIC,
};
