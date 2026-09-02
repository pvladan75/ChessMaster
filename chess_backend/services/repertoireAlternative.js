// repertoireAlternative.js — "not that move, this one", in one transaction.
//
// The third answer the draft review needs. Confirming a drafted move is
// `confirmNode`; refusing to prepare the branch at all is `skipNode`; and this
// is the one in between — the student looks at what the spine wrote, disagrees,
// and plays their own move instead.
//
// It is two writes and they must not be able to happen apart:
//
//   * the rejected draft goes and the student's move takes its place;
//   * everything the rejected draft was holding up goes with it.
//
// Half of that is a repertoire with a decision at the top of a line the student
// has just said they will not play, and a queue that keeps offering the
// positions underneath it. The other half is a move that disappeared and took
// nothing with it. Both are worse than either write not happening, which is why
// there is a `BEGIN` here rather than three route calls from the screen.
//
// **What gets swept is what became unreachable, never "the subtree".** The
// store is a graph keyed by position, so a position under the rejected move may
// also stand on a line that is still played — `orphansOfRemoving` is the walk
// that tells the two apart, and it is reused rather than approximated here.
//
// **The new move is written first, and that is the whole subtlety.** The
// question is not "what did the old move reach" but "what will nothing reach
// once the new move is in", and those differ by every transposition the new
// move opens. Asking in the wrong order deletes work that the student's own
// choice had just made reachable again — the kind of loss that ends trust in a
// feature the first time it happens.
//
// **Decisions are counted, not deleted.** Drafts go without asking; a move the
// student made themselves is handed back as a number so the screen can ask. The
// same safety catch `pruneKeys` keeps, for the same reason.

const { fenKey, requireColor, addMove } = require('./repertoireService');
const {
  orphansOfRemoving, promoteWhereNoPrimary,
} = require('./repertoirePrune');
const logger = require('./logger');

/// Rejects one drafted move at a position and plays another in its place.
///
/// `rejectedUci` is required and is required to be a **draft**. A decision
/// changed is a different act with a different confirmation in front of it
/// (`/node/orphans`, then `DELETE /node/move`), and quietly accepting one here
/// would let a review wizard delete work the student had already agreed to
/// while showing them a screen about scaffolding.
async function playAlternative(pool, userId, {
  color, fen, uci, san, rejectedUci, minRating = 0, includeDecisions = false,
} = {}) {
  requireColor(color);
  const key = fenKey(fen);
  if (!uci || !san) throw new RangeError('Potez nije prosleđen.');
  if (!rejectedUci) throw new RangeError('Nije rečeno koji nacrt se odbija.');
  if (uci === rejectedUci) {
    throw new RangeError('Odbijeni i izabrani potez su isti.');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const draft = await client.query(
      `SELECT source FROM repertoire_moves
        WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND uci = $4`,
      [userId, color, key, rejectedUci],
    );
    if (draft.rowCount === 0) {
      throw new RangeError('Taj potez nije u repertoaru za ovu poziciju.');
    }
    if (draft.rows[0].source !== 'auto') {
      throw new RangeError('Taj potez je vaša odluka, a ne nacrt.');
    }

    // First, while the rejected move is still standing. The sweep below asks
    // what nothing reaches *afterwards*, and afterwards includes this.
    const played = await addMove(client, userId, {
      color, fen, uci, san, source: 'chosen',
    });

    const orphans = await orphansOfRemoving(client, userId, {
      color, fen, uci: rejectedUci, minRating,
    });

    await client.query(
      `DELETE FROM repertoire_moves
        WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND uci = $4`,
      [userId, color, key, rejectedUci],
    );

    // This position is never swept, whatever the walk said about it. A line
    // that transposes back to where the choice was made would otherwise put the
    // key in the orphan set and the delete would take the move that was just
    // played — the student's own answer, removed by the tidy-up that was
    // supposed to be about the one they refused.
    const stranded = orphans.keys.filter((one) => one !== key);
    let removed = 0;
    if (stranded.length > 0) {
      const gone = await client.query(
        `DELETE FROM repertoire_moves
          WHERE user_id = $1 AND color = $2 AND fen_key = ANY($3)
            AND ($4 = TRUE OR source = 'auto')`,
        [userId, color, stranded, includeDecisions === true],
      );
      removed = gone.rowCount;
      await promoteWhereNoPrimary(client, userId, color, stranded);
    }

    // The student's move is the answer here now, not an alternate beside the
    // draft it replaced. Demote then promote, the same two statements
    // `promoteMove` uses and for the same reason: the partial unique index is
    // checked per row, so one clever UPDATE can fail on the planner's whim.
    await client.query(
      `UPDATE repertoire_moves SET role = 'alternate'
        WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND role = 'primary'`,
      [userId, color, key],
    );
    await client.query(
      `UPDATE repertoire_moves SET role = 'primary'
        WHERE user_id = $1 AND color = $2 AND fen_key = $3 AND uci = $4`,
      [userId, color, key, uci],
    );

    await client.query('COMMIT');

    logger.info(
      {
        userId,
        color,
        rejected: rejectedUci,
        played: uci,
        orphans: stranded.length,
        removed,
      },
      'Repertoire draft replaced',
    );

    return {
      played: {
        uci: played.uci, san: played.san, role: 'primary', source: 'chosen',
      },
      rejected: rejectedUci,
      // How many positions the rejected draft was the only way to, and how many
      // moves went with it.
      orphans: stranded.length,
      removed,
      // Decisions found under the rejected draft. Left standing unless the
      // caller said otherwise, and reported either way — losing an evening's
      // work with no sentence about it is the thing this number is here to
      // prevent.
      decisions: orphans.decisions,
      drafts: orphans.drafts,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { playAlternative };
