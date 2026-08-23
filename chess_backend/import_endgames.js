// Import mined endgame positions into endgame_puzzles.
//
// Replaces import_endgame_puzzles.js, which pointed at a folder that no longer
// exists and relied on ON CONFLICT DO NOTHING against a column with no unique
// index - so a second run appended the whole file again and reported success
// either way. Here the id is derived from the position, the index is unique,
// and the run reports inserted and skipped separately so "0 inserted" reads as
// "already imported" rather than as silence.
//
// Input: the JSON files written by puzzles/endgame_miner.py.
//
//   node import_endgames.js [--dir <folder>] [--dry-run] [--update]
//                            [--fill-source]
//
// --fill-source is for one thing only: rows imported before source_db existed,
// which is every blunder position up to 23.8.2026. It writes that one column
// and only where it is empty, rather than re-importing with --update, which
// would also push the files' verdicts back over any that were re-judged since.
//
// --update is for a re-judged file: puzzles/rejudge_endgames.py settles six
// pieces from the local tables and seven through the Lichess API, and without
// --update those corrected verdicts hit ON CONFLICT DO NOTHING and change
// nothing while the run reports success.

require('dotenv').config();
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { Chess } = require('chess.js');
const { pool, initDB } = require('./db');
const { oppositeBishops } = require('./services/endgameCatalog');

const DEFAULT_DIR = process.env.ENDGAME_MINING_DIR
  || path.join('D:', 'chess_base', '_mining');

// What a re-judge is allowed to overwrite: the verdict and everything derived
// from it. The game the position came from is not a verdict and is left alone.
const JUDGED_COLUMNS = [
  'evaluation', 'difficulty', 'difficulty_score', 'piece_tags',
  'endgame_type', 'mode', 'side_to_move', 'winning_moves', 'solution',
  'solution_san', 'piece_count', 'pawn_count', 'source', 'wdl', 'dtz',
  'material', 'blunder_elo', 'played_move', 'opposite_bishops',
  // Not a verdict, but it arrives with the file and the rows imported before
  // this column existed have it empty. Leaving it out of the update set would
  // mean a re-run that reports success and changes nothing - the exact shape
  // this importer was rewritten to stop.
  'source_db',
];

// The miner scores 1..10. The old column is a three-value string and the app
// still reads it, so both are kept: the string for existing consumers, the
// number for anything that wants a finer ladder.
function difficultyBand(score) {
  if (score <= 3) return 'easy';
  if (score <= 5) return 'medium';
  return 'hard';
}

// Same identity the miner uses for deduplication: the position without the
// move counters. Two databases holding the same game, or two unrelated games
// reaching the same board at a different move number, are one exercise.
function positionKey(fen) {
  return fen.split(' ').slice(0, 4).join(' ');
}

function puzzleId(fen) {
  return 'eg_' + crypto.createHash('sha1').update(positionKey(fen)).digest('hex').slice(0, 16);
}

function countPieces(fen) {
  const board = fen.split(' ')[0];
  let pieces = 0;
  let pawns = 0;
  for (const ch of board) {
    if (/[a-zA-Z]/.test(ch)) {
      pieces += 1;
      if (ch === 'p' || ch === 'P') pawns += 1;
    }
  }
  return { pieces, pawns };
}

function readPositions(dir) {
  if (!fs.existsSync(dir)) {
    // Loud: a wrong path must not look like an empty dataset.
    throw new Error(`Folder sa izrudarenim pozicijama ne postoji: ${dir}`);
  }
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.json'));
  if (files.length === 0) throw new Error(`Nema JSON fajlova u ${dir}`);

  const rows = [];
  for (const file of files) {
    const raw = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
    if (!Array.isArray(raw)) continue;
    for (const item of raw) {
      if (!item.fen) continue;
      rows.push({ item, file });
    }
  }
  return rows;
}

/// Writes source_db onto rows that predate the column, and nothing else.
async function fillSource(rows, dryRun) {
  const byDatabase = new Map();
  for (const { item } of rows) {
    if (!item.database) continue;
    if (!byDatabase.has(item.database)) byDatabase.set(item.database, []);
    byDatabase.get(item.database).push(puzzleId(item.fen));
  }

  await initDB();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    let filled = 0;
    for (const [database, ids] of byDatabase) {
      // Only where it is empty. A row that already names its base is not to be
      // renamed by whichever file happens to be read last - the same position
      // can sit in two bases, and the first one to claim it keeps it.
      const result = await client.query(
        `UPDATE endgame_puzzles SET source_db = $1
          WHERE puzzle_id = ANY($2) AND source_db IS NULL`,
        [database, ids]
      );
      console.log(`${database}: ${result.rowCount} od ${ids.length}`);
      filled += result.rowCount;
    }
    if (dryRun) {
      await client.query('ROLLBACK');
      console.log('\n--- PROBNI PROLAZ, nista nije upisano ---');
    } else {
      await client.query('COMMIT');
    }
    console.log(`dopunjeno: ${filled}`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

async function run() {
  const args = process.argv.slice(2);
  const dirFlag = args.indexOf('--dir');
  const dir = dirFlag >= 0 ? args[dirFlag + 1] : DEFAULT_DIR;
  const dryRun = args.includes('--dry-run');
  const update = args.includes('--update');

  const rows = readPositions(dir);
  if (args.includes('--fill-source')) {
    console.log(`Pronadjeno ${rows.length} pozicija u ${dir}`);
    return fillSource(rows, dryRun);
  }
  console.log(`Pronadjeno ${rows.length} pozicija u ${dir}`);

  await initDB();
  const client = await pool.connect();
  let inserted = 0;
  let updated = 0;
  let skipped = 0;
  let rejected = 0;
  const pending = [];

  try {
    await client.query('BEGIN');
    for (const { item, file } of rows) {
      // Validate before writing. A position the client cannot load is worse
      // than a missing one: it reaches a child as a blank board.
      let chess;
      try {
        chess = new Chess(item.fen);
      } catch (err) {
        console.warn(`  neispravan FEN u ${file}: ${item.fen}`);
        rejected += 1;
        continue;
      }

      const { pieces, pawns } = countPieces(item.fen);
      const score = Number.isInteger(item.difficulty) ? item.difficulty : null;

      pending.push([
        puzzleId(item.fen),
        item.fen,
        item.eval === null || item.eval === undefined ? null : String(item.eval),
        score === null ? 'medium' : difficultyBand(score),
        score,
        item.type || null,
        item.type || null,
        item.mode || null,
        chess.turn(),
        item.winning_moves || [],
        item.solution || [],
        item.solution_san || [],
        pieces,
        pawns,
        item.source || 'engine',
        item.wdl === undefined ? null : item.wdl,
        item.dtz === undefined ? null : item.dtz,
        item.material || null,
        Number.isInteger(item.blunder_elo) ? item.blunder_elo : null,
        item.played || null,
        oppositeBishops(item.fen),
        item.white || null,
        item.black || null,
        item.date || null,
        item.database || null,
      ]);
    }

    // In chunks, not one statement per position. The database is remote, so a
    // row at a time is a network round trip at a time: 1119 of them ran past
    // two minutes, while the same rows in chunks take seconds.
    const CHUNK = 200;
    for (let start = 0; start < pending.length; start += CHUNK) {
      const chunk = pending.slice(start, start + CHUNK);
      const values = [];
      const params = [];
      chunk.forEach((row) => {
        const base = params.length;
        values.push('(' + row.map((_, i) => `$${base + i + 1}`).join(',') + ')');
        params.push(...row);
      });
      // DO NOTHING is right for a re-run of the same data and wrong for a
      // re-judged file: the position keeps its old verdict, the run reports
      // "0 upisano, N preskoceno", and that reads exactly like "already
      // imported". Hence --update, and xmax to tell the two apart afterwards.
      //
      // The WHERE is what makes "azurirano" a fact rather than a row count.
      // Without it every conflicting row is rewritten with the values it
      // already had, and a re-import of an untouched file reports the whole
      // collection as updated - a number that looks like work and describes
      // none.
      const conflict = update
        ? `DO UPDATE SET ${JUDGED_COLUMNS.map((c) => `${c} = EXCLUDED.${c}`).join(', ')}
           WHERE (${JUDGED_COLUMNS.map((c) => `t.${c}`).join(', ')})
                 IS DISTINCT FROM (${JUDGED_COLUMNS.map((c) => `EXCLUDED.${c}`).join(', ')})`
        : 'DO NOTHING';
      const result = await client.query(
        `INSERT INTO endgame_puzzles AS t
           (puzzle_id, fen, evaluation, difficulty, difficulty_score, piece_tags,
            endgame_type, mode, side_to_move, winning_moves, solution, solution_san,
            piece_count, pawn_count, source, wdl, dtz, material, blunder_elo, played_move,
            opposite_bishops,
            game_white, game_black, game_date, source_db)
         VALUES ${values.join(',')}
         ON CONFLICT (puzzle_id) WHERE puzzle_id IS NOT NULL ${conflict}
         RETURNING (xmax = 0) AS is_new`,
        params
      );
      const fresh = result.rows.filter((r) => r.is_new).length;
      inserted += fresh;
      updated += result.rows.length - fresh;
      skipped += chunk.length - result.rows.length;
    }

    if (dryRun) {
      await client.query('ROLLBACK');
      console.log('\n--- PROBNI PROLAZ, nista nije upisano ---');
    } else {
      await client.query('COMMIT');
    }

    console.log(`upisano:    ${inserted}`);
    console.log(`azurirano:  ${updated}${update ? '' : '  (--update nije zadat)'}`);
    console.log(`preskoceno: ${skipped}  (vec u bazi, nedirnuto)`);
    console.log(`odbaceno:   ${rejected}  (neispravan FEN)`);

    const { rows: summary } = await pool.query(
      `SELECT endgame_type, mode, COUNT(*)::int AS n,
              MIN(piece_count) AS min_fig, MAX(piece_count) AS max_fig
         FROM endgame_puzzles
        WHERE endgame_type IS NOT NULL
        GROUP BY endgame_type, mode
        ORDER BY endgame_type, mode`
    );
    console.log('\n--- U BAZI ---');
    for (const r of summary) {
      console.log(
        `${(r.endgame_type || '?').padEnd(28)} ${(r.mode || '?').padEnd(5)} ` +
        `${String(r.n).padStart(5)}  figura ${r.min_fig}-${r.max_fig}`
      );
    }
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch((err) => {
  console.error('Uvoz nije uspeo:', err.message);
  process.exit(1);
});
