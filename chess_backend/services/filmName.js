// filmName.js — what a rendered film is called on disk, and what it is called
// when somebody downloads it.
//
// Two names on purpose. **On disk** a film is `tutorial_<id>_…` or
// `recording_<id>_…`, ending in the moment the render started and four random
// bytes: that name is what `saved_lessons.video_filename` stores, what a
// download token is bound to, and what the retention timer keeps or deletes,
// and two renders that start in the same millisecond must never share it.
// **In the reader's Downloads folder** it is the title and the day it was
// rendered — „Rook endings, part 2 - 2026-09-29.mp4" — which is what the
// owner asked for on 29.9.2026, because a folder of `tutorial_12_wood_720p_
// 1759…_a3f9c21e.mp4` tells nobody which lesson is which.
//
// The writer and the reader of the on-disk name are both here, so the format
// has one home: the export routes call [filmFilename], the download routes
// read it back through [filmOfFilename].
//
// No `middleware/auth` here: a service that imports it drags `JWT_SECRET` into
// every test that loads the service (CLAUDE.md, 5.9.2026).

const crypto = require('crypto');
const logger = require('./logger');

const KINDS = ['tutorial', 'recording'];

/// The on-disk name of a new film of [kind] [id].
///
/// **A clock is not a name.** Two renders of one tutorial that start in the
/// same millisecond — the same trainer twice, or a trainer and the student
/// they share it with — used to agree on a filename, and the second one
/// overwrote the first while both download links pointed at it. Four random
/// bytes end that.
function filmFilename({ kind, id, boardTheme, resolution, now = Date.now(), random }) {
  if (!KINDS.includes(kind)) throw new Error(`Unknown film kind: ${kind}`);
  const tail = random || crypto.randomBytes(4).toString('hex');
  return `${kind}_${id}_${boardTheme || 'wood'}_${resolution || '720p'}_${now}_${tail}.mp4`;
}

const ON_DISK = /^(tutorial|recording)_(\d+)_.+_(\d{13})_[0-9a-f]{8}\.mp4$/;

/// What [filmFilename] wrote into [name]: its kind, its id and when its render
/// started — or null for a name it did not write.
function filmOfFilename(name) {
  const match = ON_DISK.exec(String(name || ''));
  if (!match) return null;
  return { kind: match[1], id: Number(match[2]), renderedAt: new Date(Number(match[3])) };
}

/// Characters no Windows file name may hold, and control characters.
// eslint-disable-next-line no-control-regex
const FORBIDDEN = /[<>:"/\\|?*\u0000-\u001f\u007f]/g;
/// Names Windows keeps for devices, whatever the extension.
const RESERVED = /^(con|prn|aux|nul|com\d|lpt\d)$/i;
/// Long enough for any title a trainer types, short enough that the date and
/// the extension are never what a file manager cuts off.
const MAX_TITLE = 80;

/// [title] made safe to be a file name on every system a reader downloads to:
/// no character Windows refuses, no run of spaces, no trailing dot (Windows
/// drops it), at most [MAX_TITLE] characters. Letters of any alphabet stay —
/// Express sends the name as UTF-8 beside an ASCII fallback. Empty when
/// nothing is left.
function cleanTitle(title) {
  let clean = String(title || '')
    .replace(FORBIDDEN, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  // Counted in characters, not UTF-16 units, so a cut never splits one.
  const chars = Array.from(clean);
  if (chars.length > MAX_TITLE) clean = chars.slice(0, MAX_TITLE).join('').trim();
  clean = clean.replace(/[.\s]+$/, '');
  if (RESERVED.test(clean)) clean = `${clean}_`;
  return clean;
}

/// The day of [date] as YYYY-MM-DD, in the server's own time zone — the one
/// its trainers live in — so a film rendered just after midnight is not dated
/// the day before.
function dayOf(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/// The name a film downloads under: „<title> - <day>.mp4", the title alone
/// when the day is not known, and null when there is no usable title — the
/// caller then keeps the on-disk name.
function downloadNameFor({ title, renderedAt }) {
  const clean = cleanTitle(title);
  if (!clean) return null;
  const known = renderedAt instanceof Date && !Number.isNaN(renderedAt.getTime());
  return known ? `${clean} - ${dayOf(renderedAt)}.mp4` : `${clean}.mp4`;
}

const TITLE_OF = {
  tutorial: 'SELECT title FROM saved_lessons WHERE id = $1',
  recording: 'SELECT title FROM session_recordings WHERE id = $1',
};

/// The name the file [filename] downloads under, asked of [pool] now — so a
/// tutorial renamed after its film was rendered downloads under its new title.
///
/// **A name never stops a download.** A name this module did not write, a row
/// that is gone, a title that cleans to nothing and a database that does not
/// answer all give back [filename] itself: the reader gets the file, under the
/// name it has on disk, and the failure is logged.
async function downloadNameOf(pool, filename) {
  const film = filmOfFilename(filename);
  if (!film) return filename;
  try {
    const result = await pool.query(TITLE_OF[film.kind], [film.id]);
    const row = result && result.rows && result.rows[0];
    return downloadNameFor({ title: row && row.title, renderedAt: film.renderedAt }) || filename;
  } catch (err) {
    logger.error(`[DOWNLOAD] Could not name ${filename} after its title: ${err.message}`);
    return filename;
  }
}

module.exports = {
  filmFilename,
  filmOfFilename,
  cleanTitle,
  downloadNameFor,
  downloadNameOf,
};
