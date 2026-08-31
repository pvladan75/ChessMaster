// repertoireNotes.js — what the engine said about a position, kept beside it.
//
// The number is **information, never a verdict**. This screen already has a
// judge: the opening judge, which answers "is this move sound, judged by the
// games real people played", and for a repertoire that is the better question —
// a repertoire is about what will actually be played against you. A second
// opinion from a different notion of "good", printed on the same card, is how a
// screen starts contradicting itself in front of a child.
//
// So the eval is not a flag on a move. What it buys instead is a **list**:
// `disagreements` — the positions where the engine's move is not the one that
// was chosen, worst first, gone through deliberately. Same information, no
// second judge on the card.
//
// Three rules hold here, and each of them is a decision:
//
//   * **Per user.** An eval is a fact about a position *and* an engine version,
//     a depth and a machine. A shared table would need all three in the key to
//     mean anything and would otherwise agree with nobody — unlike
//     `opening_replies`, which is about a position and a rating band and is
//     shared for exactly that reason.
//   * **A shallower answer never overwrites a deeper one.** The whole-line pass
//     runs at whatever depth the dials are on; a hand-run search at depth 30 on
//     one position must not be flattened by tomorrow's sweep at 18. The same
//     rule `AnalysisNode.evalDepth` keeps on the client, held here by the
//     database instead of by whoever writes the next caller.
//   * **The move is compared by UCI.** `best_line_san` is for reading; the
//     comparison runs on `best_uci`, because comparing two SAN strings produced
//     by two different chess libraries is exactly the silent mismatch this
//     codebase keeps meeting.
//
// One thing to be careful about, written down because it is the shape
// `tablebaseService` refuses for the endgame drill: the eval is computed on the
// client and stored by the server, so it is a number the server cannot check.
// It is acceptable **here** and only here — nobody cheats themselves out of an
// engine eval, and this number grades nothing. If it ever starts grading
// anything, that reasoning is void and the computation has to move.

const { fenKey, requireColor } = require('./repertoireService');
const { step } = require('./repertoireFrontier');
const { walkLines, subtree } = require('./repertoireLine');

/// How many notes one read hands back. A repertoire is a few hundred positions
/// at the outside; the cap is here so a table that somehow grew cannot turn one
/// screen into a download.
const MAX_NOTES = 2000;

/// How many rows the review list is worth. Past this nobody is going through
/// them deliberately, which is the only way this list is meant to be used.
const MAX_DISAGREEMENTS = 100;

function requireInt(value, what, { min = null, max = null } = {}) {
  const number = Number(value);
  if (!Number.isFinite(number) || !Number.isInteger(number)) {
    throw new RangeError(`${what} mora biti ceo broj.`);
  }
  if (min !== null && number < min) {
    throw new RangeError(`${what} ne može biti manje od ${min}.`);
  }
  if (max !== null && number > max) {
    throw new RangeError(`${what} ne može biti veće od ${max}.`);
  }
  return number;
}

function noteOf(row) {
  return {
    fenKey: row.fen_key,
    // White-relative centipawns, always present. A mate is collapsed into it
    // as well, so everything that sorts or subtracts has one number to use.
    evalCp: row.eval_cp === null ? null : Number(row.eval_cp),
    // Signed moves-to-mate, positive when White mates. Null for an ordinary
    // evaluation. Kept apart from `evalCp` because a forced mate written as a
    // large number of pawns reads as an evaluation, which it is not.
    mateIn: row.mate_in === null || row.mate_in === undefined
      ? null
      : Number(row.mate_in),
    evalDepth: Number(row.eval_depth ?? 0),
    bestUci: row.best_uci ?? null,
    bestLineSan: row.best_line_san ?? null,
    updatedAt: row.updated_at,
  };
}

/// Writes what the engine said about one position — unless a deeper answer is
/// already there.
///
/// The answer says which of the two is now stored, so a screen can tell "yours
/// was kept because it was deeper" from "nothing happened", which look
/// identical from the outside and are not.
async function putNote(pool, userId, {
  color, fen, evalCp, mateIn = null, evalDepth = 0,
  bestUci = null, bestLineSan = null,
} = {}) {
  requireColor(color);
  const key = fenKey(fen);
  // A note with no number in it is not a note. Refused rather than stored,
  // because a row that exists and says nothing is worse than no row: the tree
  // would draw a card for it and the line pass would count it as done.
  if (evalCp === null || evalCp === undefined) {
    throw new RangeError('Ocena (eval_cp) nije prosleđena.');
  }
  const cp = requireInt(evalCp, 'Ocena', { min: -100000, max: 100000 });
  const mate = mateIn === null || mateIn === undefined
    ? null
    : requireInt(mateIn, 'Mat u', { min: -500, max: 500 });
  const depth = requireInt(evalDepth ?? 0, 'Dubina', { min: 0, max: 100 });
  const uci = typeof bestUci === 'string' && bestUci.trim() !== ''
    ? bestUci.trim().slice(0, 6)
    : null;
  const line = typeof bestLineSan === 'string' && bestLineSan.trim() !== ''
    ? bestLineSan.trim().slice(0, 400)
    : null;

  const written = await pool.query(
    `INSERT INTO repertoire_notes
       (user_id, color, fen_key, eval_cp, mate_in, eval_depth,
        best_uci, best_line_san, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP)
     ON CONFLICT (user_id, color, fen_key) DO UPDATE
        SET eval_cp = EXCLUDED.eval_cp,
            mate_in = EXCLUDED.mate_in,
            eval_depth = EXCLUDED.eval_depth,
            best_uci = EXCLUDED.best_uci,
            best_line_san = EXCLUDED.best_line_san,
            updated_at = CURRENT_TIMESTAMP
      WHERE EXCLUDED.eval_depth >= repertoire_notes.eval_depth
     RETURNING fen_key, eval_cp, mate_in, eval_depth, best_uci, best_line_san,
               updated_at`,
    [userId, color, key, cp, mate, depth, uci, line],
  );

  if (written.rowCount > 0) {
    return { stored: true, note: noteOf(written.rows[0]) };
  }

  // The row that won. Read back rather than assumed: the caller is about to
  // draw it, and drawing the answer that was refused would be a lie about
  // what is on the node.
  const kept = await pool.query(
    `SELECT fen_key, eval_cp, mate_in, eval_depth, best_uci, best_line_san,
            updated_at
       FROM repertoire_notes
      WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
    [userId, color, key],
  );
  return {
    stored: false,
    note: kept.rowCount > 0 ? noteOf(kept.rows[0]) : null,
  };
}

/// The notes for a colour, or for the positions named.
///
/// Without `keys` it is everything this student has evaluated for that side,
/// which is one call per tree draw rather than one per card. With them it is
/// the positions asked about — the same answer, for a caller that knows which
/// ones it needs.
async function notesFor(pool, userId, { color, keys = null } = {}) {
  requireColor(color);
  const wanted = Array.isArray(keys)
    ? keys.filter((key) => typeof key === 'string' && key.trim() !== '')
      .map((key) => key.trim())
      .slice(0, MAX_NOTES)
    : null;
  if (wanted !== null && wanted.length === 0) return { notes: [] };

  const result = await pool.query(
    `SELECT fen_key, eval_cp, mate_in, eval_depth, best_uci, best_line_san,
            updated_at
       FROM repertoire_notes
      WHERE user_id = $1 AND color = $2
        AND ($3::text[] IS NULL OR fen_key = ANY($3))
      ORDER BY updated_at DESC
      LIMIT $4`,
    [userId, color, wanted, MAX_NOTES],
  );
  return { notes: result.rows.map(noteOf) };
}

/// The evaluation as the student reads it: positive means good for them.
///
/// Everything stored is White-relative, which is right for storage and wrong
/// for a list about somebody's own moves — a Black repertoire sorted by
/// White-relative loss puts the student's best moves at the top.
function forStudent(cp, color) {
  return color === 'w' ? cp : -cp;
}

/// The positions where the engine's move is not the one that was chosen, worst
/// first.
///
/// Derived entirely from the notes and the moves — no new judgement anywhere,
/// and no Lichess request, like everything else that reads what was built. A
/// position with no note is not in the list at all: "the engine has not been
/// asked" and "the engine agrees" are different answers, and only one of them
/// is silence.
///
/// The **size** of a disagreement needs two notes: the one on the position and
/// the one on the position after the student's move. The whole-line pass writes
/// both, since it evaluates every position along the line. Where only the first
/// exists the row still belongs in the list — the engine plainly plays
/// something else — and it goes below the measured ones, carrying `loss: null`
/// rather than a zero that would read as "no difference".
///
/// Drafts are included and marked. A generated move is exactly what somebody
/// wants a second look at before confirming it, and the row says `source` so
/// the screen can tell the two apart.
async function disagreements(pool, userId, {
  color, rootFen, rootPath = [], minRating = 0, fromFen = null,
  limit = MAX_DISAGREEMENTS,
} = {}) {
  requireColor(color);
  const { nodes, kept, truncated } = await walkLines(pool, userId, {
    color, rootFen, minRating,
  });

  let within = null;
  if (fromFen != null && String(fromFen).trim() !== '') {
    const from = fenKey(fromFen);
    // A position the walk never reached — cut since, or under a move that is
    // no longer kept. An empty list rather than a 400: the request was well
    // formed and "there is nothing there any more" is the answer.
    within = new Set(nodes.has(from) ? subtree(nodes, from) : []);
  }

  const keys = [...nodes.keys()].filter(
    (key) => within === null || within.has(key),
  );

  // Every position that could carry a note: the ones the student moves in, and
  // the one each of their primary moves leads to. Both in one read.
  const afterPrimary = new Map();
  for (const key of keys) {
    const node = nodes.get(key);
    const primary = (kept.get(key) ?? [])[0];
    if (!primary) continue;
    const played = step(node.fen, primary.uci);
    if (played === null) continue;
    afterPrimary.set(key, { primary, ...played });
  }

  const wanted = [
    ...keys,
    ...[...afterPrimary.values()].map((played) => fenKey(played.fen)),
  ];
  const { notes } = await notesFor(pool, userId, { color, keys: wanted });
  const byKey = new Map(notes.map((note) => [note.fenKey, note]));

  const base = Array.isArray(rootPath)
    ? rootPath.filter((san) => typeof san === 'string' && san !== '')
    : [];

  const rows = [];
  let looked = 0;
  for (const key of keys) {
    const note = byKey.get(key);
    if (!note || note.bestUci === null || note.evalCp === null) continue;
    looked += 1;
    const played = afterPrimary.get(key);
    if (!played) continue;
    if (played.primary.uci === note.bestUci) continue;

    const node = nodes.get(key);
    const after = byKey.get(fenKey(played.fen));
    const loss = after && after.evalCp !== null
      ? forStudent(note.evalCp, color) - forStudent(after.evalCp, color)
      : null;
    // The engine's move as this position names it, spelled by the same library
    // that spells every other move here. `best_line_san` is what it goes on to
    // play and is for reading, not for comparing.
    const engine = step(node.fen, note.bestUci);

    rows.push({
      fenKey: key,
      fen: node.fen,
      path: node.path,
      ply: node.ply,
      mine: {
        uci: played.primary.uci,
        san: played.san,
        role: played.primary.role,
        source: played.primary.source,
      },
      engine: {
        uci: note.bestUci,
        san: engine === null ? null : engine.san,
        line: note.bestLineSan,
      },
      evalCp: note.evalCp,
      mateIn: note.mateIn,
      evalDepth: note.evalDepth,
      updatedAt: note.updatedAt,
      // In centipawns, from the student's side: how much the engine thinks
      // their move gives up. Null when the position after their move has never
      // been evaluated, and null is not zero.
      loss,
    });
  }

  rows.sort((a, b) => {
    if (a.loss === null && b.loss === null) return b.ply - a.ply;
    if (a.loss === null) return 1;
    if (b.loss === null) return -1;
    return b.loss - a.loss;
  });

  const cap = Math.min(Math.max(Number(limit) || MAX_DISAGREEMENTS, 1),
    MAX_DISAGREEMENTS);

  return {
    root: { fen: rootFen, path: base },
    from: within === null ? null : fenKey(fromFen),
    // How many positions in this branch the student has a move in, and how many
    // of those the engine has been asked about. Without the second number a
    // short list reads as "the engine agrees with almost everything", when it
    // may only mean nobody has run it yet.
    positions: afterPrimary.size,
    evaluated: looked,
    disagreements: rows.slice(0, cap),
    truncated: truncated || rows.length > cap,
  };
}

module.exports = {
  putNote,
  notesFor,
  disagreements,
  MAX_NOTES,
  MAX_DISAGREEMENTS,
};
