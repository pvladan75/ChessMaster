// gameArchive.js — one PGN game in, one `user_games` row out, or a reason why not.
//
// Pure: no database, no network, no clock. It is the shape half of section 0 of
// docs/PLAN-MOJE-PARTIJE.md, split out from the importer so the row shape can be
// tested against real PGN text without either.
//
// Why a game is ever *refused* rather than stored with holes: every aggregation
// downstream — the opening report, the endgame audit, the mistake extractor —
// starts by trusting that a row means "a finished standard game the subject
// played". A row with no result, or one the subject is not in, satisfies none of
// the queries and is found much later, by a number being slightly wrong.
//
// And why the refusals are *counted* rather than logged: an archive of four
// thousand games will always contain some the importer cannot use. The failure
// mode this codebase keeps meeting is not losing them, it is losing them
// silently and reporting success. [createTally] is that count, and it refuses to
// close if the numbers do not add up.

const crypto = require('crypto');
const { Chess } = require('chess.js');

/// Every reason a game does not become a row. Frozen because these strings are
/// written into `user_game_imports.skipped_by_reason` and shown to the user —
/// a typo here is a second bucket that looks like a third kind of failure.
const SKIP = Object.freeze({
  UNPARSABLE: 'unparsable-pgn',
  NOT_STANDARD: 'not-standard-variant',
  NO_RESULT: 'unfinished-game',
  SUBJECT_ABSENT: 'subject-not-in-game',
  NO_MOVES: 'no-moves',
});

const RESULTS = new Set(['1-0', '0-1', '1/2-1/2']);

/// chess.js fills absent headers with placeholders ('?', '????.??.??') rather
/// than leaving them out, so "missing" has to be recognised rather than assumed.
function headerOrNull(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed === '?' || /^[?.]+$/.test(trimmed)) return null;
  return trimmed;
}

/// Men on the board, counted off a FEN's placement field.
function menInFen(fen) {
  const placement = String(fen).split(' ')[0];
  return placement.replace(/[^a-zA-Z]/g, '').length;
}

/// Lichess's own speed bands, computed from the time control rather than read
/// out of the Event line: "rated blitz game" is a Lichess sentence, and
/// Chess.com PGN does not write one. Base + 40×increment is how Lichess
/// estimates a game's length before classifying it.
function speedFromTimeControl(timeControl) {
  const raw = headerOrNull(timeControl);
  if (!raw || raw === '-') return null;
  const match = /^(\d+)(?:\+(\d+))?$/.exec(raw);
  if (!match) return null;
  const base = Number(match[1]);
  const increment = Number(match[2] || 0);
  const estimated = base + 40 * increment;
  if (estimated < 29) return 'ultrabullet';
  if (estimated < 179) return 'bullet';
  if (estimated < 479) return 'blitz';
  if (estimated < 1499) return 'rapid';
  return 'classical';
}

/// `[%clk 0:02:58]` and `[%clk 0:02:58.5]` in centiseconds. Returns null for a
/// comment that carries no clock, which is most of them.
function clockToCentiseconds(comment) {
  const match = /\[%clk\s+(\d+):(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]/.exec(comment || '');
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  const seconds = Number(match[3]);
  return Math.round((hours * 3600 + minutes * 60 + seconds) * 100);
}

/// `2026.07.05` + `13:04:55` → a Date, or null when either is a placeholder.
/// UTC because both headers are UTC and a server in another zone must not shift
/// a game into the previous day — `played_at` is what the incremental import
/// resumes from.
function playedAt(headers) {
  const date = headerOrNull(headers.UTCDate) || headerOrNull(headers.Date);
  if (!date) return null;
  const parts = date.split('.');
  if (parts.length !== 3 || parts.some((p) => !/^\d+$/.test(p))) return null;
  const time = headerOrNull(headers.UTCTime) || '00:00:00';
  const [h = '0', m = '0', s = '0'] = time.split(':');
  const stamp = Date.UTC(
    Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]),
    Number(h), Number(m), Number(s),
  );
  return Number.isFinite(stamp) ? new Date(stamp) : null;
}

/// The archive's own id for a game. Lichess gives one; Chess.com and a pasted
/// file may not, so the fallback is derived from the moves themselves — the
/// same reasoning as import_blunder_games.js, where one game appears under
/// several spellings of the players' names and the moves are the game.
function externalId(headers, startFen, uciMoves) {
  const given = headerOrNull(headers.GameId)
    || (headerOrNull(headers.Site) || '').split('/').filter(Boolean).pop();
  if (given && /^[A-Za-z0-9_-]{4,64}$/.test(given)) return given;
  const material = [startFen, ...uciMoves].join(' ');
  return 'g_' + crypto.createHash('sha1').update(material).digest('hex').slice(0, 20);
}

/// Turns one game's PGN text into a `user_games` row.
///
/// [subject] is whose archive this is — the owner's handle for their own games,
/// somebody else's for match preparation. Colour, score and rating in the
/// returned row are all from the subject's side, which is what makes the same
/// row shape usable for both.
///
/// Returns `{ ok: true, row }` or `{ ok: false, reason }` where reason is one of
/// [SKIP]. It never throws for bad input: a four-thousand-game archive with one
/// broken game in it must import three thousand nine hundred and ninety-nine,
/// and say so.
function normaliseGame(pgnText, { subject, source, subjectIsOwner = true } = {}) {
  if (!subject || !String(subject).trim()) {
    throw new TypeError('normaliseGame requires the subject whose archive this is');
  }
  if (!['lichess', 'chesscom', 'pgn'].includes(source)) {
    throw new TypeError(`unknown archive source: ${source}`);
  }

  const game = new Chess();
  try {
    game.loadPgn(String(pgnText || ''));
  } catch {
    return { ok: false, reason: SKIP.UNPARSABLE };
  }

  const headers = game.getHeaders() || {};

  const variant = headerOrNull(headers.Variant);
  if (variant && variant.toLowerCase() !== 'standard') {
    return { ok: false, reason: SKIP.NOT_STANDARD };
  }

  const result = headerOrNull(headers.Result);
  if (!result || !RESULTS.has(result)) return { ok: false, reason: SKIP.NO_RESULT };

  const wanted = String(subject).trim().toLowerCase();
  const white = headerOrNull(headers.White);
  const black = headerOrNull(headers.Black);
  let color = null;
  if (white && white.toLowerCase() === wanted) color = 'w';
  else if (black && black.toLowerCase() === wanted) color = 'b';
  if (!color) return { ok: false, reason: SKIP.SUBJECT_ABSENT };

  const history = game.history({ verbose: true });
  if (history.length === 0) return { ok: false, reason: SKIP.NO_MOVES };

  const startFen = history[0].before;

  // One walk for three things the aggregations would otherwise each recompute:
  // the moves in UCI, the fewest men the game ever reached, and the ply it
  // first entered tablebase range.
  const uciMoves = [];
  let minMen = menInFen(startFen);
  // 0 rather than null when the game *starts* inside tablebase range — a
  // position set up from a FEN. Null has to keep meaning "never got there".
  let tbEntryPly = minMen <= 7 ? 0 : null;
  history.forEach((move, index) => {
    uciMoves.push(`${move.from}${move.to}${move.promotion || ''}`);
    const men = menInFen(move.after);
    if (men < minMen) minMen = men;
    if (tbEntryPly === null && men <= 7) tbEntryPly = index + 1;
  });

  // Clocks are keyed by the position they follow, so they align to plies
  // through each move's resulting FEN. Left null entirely when the export
  // carried none — an array of nulls would read as "the clocks are known and
  // they are empty".
  let clocks = null;
  const comments = typeof game.getComments === 'function' ? game.getComments() : [];
  if (comments.length > 0) {
    const byFen = new Map();
    for (const entry of comments) {
      const centiseconds = clockToCentiseconds(entry.comment);
      if (centiseconds !== null) byFen.set(entry.fen, centiseconds);
    }
    if (byFen.size > 0) {
      clocks = history.map((move) => (byFen.has(move.after) ? byFen.get(move.after) : null));
    }
  }

  const scores = { '1-0': 1, '0-1': 0, '1/2-1/2': 0.5 };
  const subjectScore = color === 'w' ? scores[result] : 1 - scores[result];

  const eventLine = headerOrNull(headers.Event) || '';
  let rated = null;
  if (/\brated\b/i.test(eventLine)) rated = true;
  else if (/\bcasual\b|\bunrated\b/i.test(eventLine)) rated = false;

  const eco = headerOrNull(headers.ECO);

  return {
    ok: true,
    row: {
      source,
      external_id: externalId(headers, startFen, uciMoves),
      subject: String(subject).trim(),
      subject_is_owner: Boolean(subjectIsOwner),
      played_at: playedAt(headers),
      subject_color: color,
      result,
      subject_score: subjectScore,
      subject_elo: toElo(color === 'w' ? headers.WhiteElo : headers.BlackElo),
      opponent: (color === 'w' ? black : white) || null,
      opponent_elo: toElo(color === 'w' ? headers.BlackElo : headers.WhiteElo),
      speed: speedFromTimeControl(headers.TimeControl),
      time_control: headerOrNull(headers.TimeControl),
      rated,
      eco: eco && /^[A-E]\d{2}$/.test(eco) ? eco : null,
      opening: headerOrNull(headers.Opening),
      termination: headerOrNull(headers.Termination),
      start_fen: startFen,
      moves: uciMoves,
      clocks,
      ply_count: uciMoves.length,
      min_men: minMen,
      tb_entry_ply: tbEntryPly,
    },
  };
}

function toElo(raw) {
  const value = Number(headerOrNull(raw));
  return Number.isInteger(value) && value > 0 && value < 4000 ? value : null;
}

/// The count that closes the loop: every game read is stored, already known, or
/// skipped for a named reason, and nothing falls between.
///
/// [assertBalanced] throws rather than returning false. A run whose numbers do
/// not add up has lost games it cannot name, and the one thing that must not
/// happen next is writing 'done' next to it — the same instinct as DB_CA_PATH
/// killing the process instead of downgrading the connection.
function createTally() {
  const counts = { read: 0, stored: 0, duplicate: 0, skipped: 0 };
  const byReason = Object.create(null);

  return {
    read() { counts.read += 1; },
    stored() { counts.stored += 1; },
    duplicate() { counts.duplicate += 1; },
    skipped(reason) {
      if (!Object.values(SKIP).includes(reason)) {
        throw new RangeError(`unnamed skip reason: ${reason}`);
      }
      counts.skipped += 1;
      byReason[reason] = (byReason[reason] || 0) + 1;
    },
    snapshot() {
      return { ...counts, skipped_by_reason: { ...byReason } };
    },
    assertBalanced() {
      const accounted = counts.stored + counts.duplicate + counts.skipped;
      if (accounted !== counts.read) {
        throw new Error(
          `import lost games: read ${counts.read}, accounted ${accounted} `
          + `(stored ${counts.stored}, duplicate ${counts.duplicate}, skipped ${counts.skipped})`,
        );
      }
      return this.snapshot();
    },
  };
}

module.exports = {
  SKIP,
  normaliseGame,
  createTally,
  speedFromTimeControl,
  clockToCentiseconds,
};
