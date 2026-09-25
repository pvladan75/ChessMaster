// tutorialFilm.js — what a tutorial's film is, for whoever is sent it.
//
// docs/PLAN-TUTORIJAL-VIDEO.md: a tutorial is the trainer's material for a
// film, and **what reaches a student is the film**. Sending one alone, sending
// one inside a homework, the student's assignment and the student's download
// all ask the same question — is there a film, and which file is it — so it
// is answered here once rather than four times.
//
// No `middleware/auth` here: a service that imports it drags `JWT_SECRET` into
// every test that loads the service (CLAUDE.md, 5.9.2026).

const fs = require('fs');
const path = require('path');
const { EXPORTS_DIR } = require('./retentionService');

/// The columns [filmOf] reads, for a query to select — prefixed with a table
/// alias when the query joins.
function filmColumns(alias = '') {
  const p = alias ? `${alias}.` : '';
  return ['video_filename', 'video_rendered_at', 'video_resolution', 'video_seconds', 'video_narrated']
    .map((column) => p + column).join(', ');
}

/// The film a `saved_lessons` row names, or null.
///
/// Three answers are folded into two on purpose: a row that names no file and
/// a row whose file is not on disk are both „there is no film to give", and
/// the one thing a caller must never do is hand out a link to nothing. The
/// row's own name for the file is reduced to a basename, so a stored value can
/// never point outside `exports/`.
function filmOf(row, dir = EXPORTS_DIR) {
  const stored = row && row.video_filename;
  if (!stored) return null;
  const filename = path.basename(String(stored));
  if (!fs.existsSync(path.join(dir, filename))) return null;
  return {
    filename,
    renderedAt: row.video_rendered_at ?? null,
    resolution: row.video_resolution ?? null,
    seconds: row.video_seconds ?? null,
    narrated: row.video_narrated === true,
  };
}

/// What a student is told about the film, without its file name: the name is
/// only ever handed out inside a signed link.
function filmFacts(film) {
  if (!film) return { status: 'none' };
  return {
    status: 'ready',
    renderedAt: film.renderedAt,
    resolution: film.resolution,
    seconds: film.seconds,
    narrated: film.narrated,
  };
}

/// The refusal for sending a tutorial that has no film — one sentence for the
/// three doors (alone, from the student's page, inside a homework).
function noFilmReason(title) {
  const named = title ? ` "${title}"` : '';
  return `The tutorial${named} has no video yet. Export the video first — a tutorial is sent as its video.`;
}

/// Whether a finished response delivered the file's **last byte** (plan D3):
/// a whole download (200), or the tail of a resumed one (206 whose range ends
/// on the last byte). A range that stops short of the end is a part of the
/// file, not the file.
function deliveredLastByte(res, size) {
  if (res.statusCode === 200) return true;
  if (res.statusCode !== 206) return false;
  const range = String(res.getHeader('Content-Range') || '');
  const match = /^bytes (\d+)-(\d+)\/(\d+)$/.exec(range);
  if (!match) return false;
  return Number(match[2]) === size - 1 && Number(match[3]) === size;
}

module.exports = {
  filmColumns, filmOf, filmFacts, noFilmReason, deliveredLastByte, EXPORTS_DIR,
};
