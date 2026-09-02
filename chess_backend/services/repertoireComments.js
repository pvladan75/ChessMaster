// repertoireComments.js — what the student wrote about a position, in their
// own words.
//
// The one thing in the repertoire that nothing can recompute. An evaluation
// comes back at any depth on any machine; a book row comes back from Lichess; a
// move comes back by playing it again. A sentence somebody typed at a board
// comes back only if it was kept.
//
// Three rules, and each is a decision:
//
//   * **Its own table, not a column on `repertoire_notes`.** A note is the
//     engine's answer — overwritten by every deeper search and deleted with the
//     moves it belonged to. `putNote` also refuses a row that carries no
//     evaluation, which is exactly the row a comment on an un-analysed position
//     needs. One table would mean one lifetime for two things with opposite
//     ones.
//   * **Keyed by position**, like the moves and for the same reason: a sentence
//     written deep in the Smith-Morra is there the moment a 1.e4 line
//     transposes into that board.
//   * **Empty is a delete.** A screen that saves an emptied box must not leave
//     a row that renders as a comment panel with nothing in it — the tree would
//     draw a card for a position nobody has said anything about.
//
// Nothing here is judged, graded or shown to anybody else. A repertoire is the
// student's own business, and so is what they wrote in it.

const { fenKey, requireColor } = require('./repertoireService');

/// How long one comment may be.
///
/// Generous on purpose — this is where a whole plan for a position gets
/// written — but bounded, because the bulk read hands every comment for a
/// colour to a phone in one response.
const MAX_BODY = 4000;

/// How many comments one read hands back. Same reasoning as `MAX_NOTES`: a
/// table that somehow grew must not turn one screen into a download.
const MAX_COMMENTS = 2000;

function commentOf(row) {
  return {
    fenKey: row.fen_key,
    body: row.body,
    updatedAt: row.updated_at,
  };
}

/// Writes the comment on one position, or takes it away when it is emptied.
///
/// The answer says which of the two happened, so a screen can tell "saved" from
/// "cleared" without having to work it out from the text it just sent.
async function putComment(pool, userId, { color, fen, body } = {}) {
  requireColor(color);
  const key = fenKey(fen);
  const text = typeof body === 'string' ? body.trim() : '';

  if (text === '') {
    const gone = await pool.query(
      `DELETE FROM repertoire_comments
        WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
      [userId, color, key],
    );
    return { stored: false, removed: gone.rowCount, comment: null };
  }

  if (text.length > MAX_BODY) {
    throw new RangeError(`Komentar može imati najviše ${MAX_BODY} znakova.`);
  }

  const written = await pool.query(
    `INSERT INTO repertoire_comments (user_id, color, fen_key, body, updated_at)
     VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
     ON CONFLICT (user_id, color, fen_key) DO UPDATE
        SET body = EXCLUDED.body,
            updated_at = CURRENT_TIMESTAMP
     RETURNING fen_key, body, updated_at`,
    [userId, color, key, text],
  );
  return {
    stored: true,
    removed: 0,
    comment: commentOf(written.rows[0]),
  };
}

/// Takes the comment off a position.
///
/// The same thing an emptied box does, as its own door: a screen with a delete
/// button should not have to send an empty string and hope.
async function removeComment(pool, userId, { color, fen } = {}) {
  requireColor(color);
  const key = fenKey(fen);
  const gone = await pool.query(
    `DELETE FROM repertoire_comments
      WHERE user_id = $1 AND color = $2 AND fen_key = $3`,
    [userId, color, key],
  );
  return { removed: gone.rowCount };
}

/// The comments for a colour, or for the positions named.
///
/// Shaped exactly like `notesFor`, because the caller is the same one: the tree
/// draws a hundred cards and reads both in two calls rather than two hundred.
async function commentsFor(pool, userId, { color, keys = null } = {}) {
  requireColor(color);
  const wanted = Array.isArray(keys)
    ? keys.filter((key) => typeof key === 'string' && key.trim() !== '')
      .map((key) => key.trim())
      .slice(0, MAX_COMMENTS)
    : null;
  if (wanted !== null && wanted.length === 0) return { comments: [] };

  const result = await pool.query(
    `SELECT fen_key, body, updated_at
       FROM repertoire_comments
      WHERE user_id = $1 AND color = $2
        AND ($3::text[] IS NULL OR fen_key = ANY($3))
      ORDER BY updated_at DESC
      LIMIT $4`,
    [userId, color, wanted, MAX_COMMENTS],
  );
  return { comments: result.rows.map(commentOf) };
}

module.exports = {
  putComment, removeComment, commentsFor, MAX_BODY, MAX_COMMENTS,
};
