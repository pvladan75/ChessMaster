// Import whole games from puzzles/blunder_detector.py into blunder_games.
//
// The detector writes one record per game: the position where it first went
// wrong, the moves from there to the end, and every mistake in between. That is
// already the shape the walkthrough needs, so nothing is converted on the way -
// unlike the positions, which go through blunders_to_puzzles.py because they
// are being reshaped into a different exercise.
//
// JSONL, one game per line, appended by the detector as it runs. So this is
// meant to be re-run after every batch: the id is derived from the game itself
// and ON CONFLICT DO NOTHING leaves what is already here alone.
//
//   node import_blunder_games.js [--dir <folder>] [--dry-run] [--max-blunders N]

require('dotenv').config();
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { Chess } = require('chess.js');
const { pool, initDB } = require('./db');

const DEFAULT_DIR = process.env.BLUNDER_DIR
  || path.join('D:', 'chess_base', '_blunders');

// A game with thirty mistakes in it is not a lesson, it is a collapse: the walk
// would stop every other move and none of the stops would mean anything. The
// cap is high enough to keep everything that reads as a game played badly.
const DEFAULT_MAX_BLUNDERS = 12;

// From the game rather than from its headers. The same game appears in a
// gigabase under several spellings of the players' names, and the moves are
// the game.
function gameId(record) {
  const material = [record.start_fen, ...(record.moves || [])].join(' ');
  return 'bg_' + crypto.createHash('sha1').update(material).digest('hex').slice(0, 20);
}

function readGames(dir) {
  if (!fs.existsSync(dir)) {
    throw new Error(`Folder sa greskama ne postoji: ${dir}`);
  }
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.jsonl'));
  if (files.length === 0) throw new Error(`Nema .jsonl fajlova u ${dir}`);
  return files.map((f) => path.join(dir, f));
}

/// Every material key the game passes through, so a lesson can ask for one.
function materialsOf(record) {
  const seen = new Set();
  for (const b of record.blunders || []) {
    if (b.material) seen.add(b.material);
  }
  return [...seen];
}

function elos(record) {
  const w = Number.isInteger(record.white_elo) ? record.white_elo : null;
  const b = Number.isInteger(record.black_elo) ? record.black_elo : null;
  if (w && b) return { w, b, min: Math.min(w, b) };
  return { w: w || null, b: b || null, min: w || b || null };
}

async function run() {
  const args = process.argv.slice(2);
  const dirFlag = args.indexOf('--dir');
  const dir = dirFlag >= 0 ? args[dirFlag + 1] : DEFAULT_DIR;
  const dryRun = args.includes('--dry-run');
  const capFlag = args.indexOf('--max-blunders');
  const maxBlunders = capFlag >= 0
    ? parseInt(args[capFlag + 1], 10)
    : DEFAULT_MAX_BLUNDERS;

  await initDB();
  const client = await pool.connect();
  let read = 0;
  let inserted = 0;
  let skipped = 0;
  let rejected = 0;
  let tooMany = 0;
  const pending = [];

  try {
    for (const file of readGames(dir)) {
      const stream = readline.createInterface({
        input: fs.createReadStream(file, 'utf8'),
        crlfDelay: Infinity,
      });
      for await (const line of stream) {
        const text = line.trim();
        if (!text) continue;
        let record;
        try {
          record = JSON.parse(text);
        } catch {
          // The detector appends as it runs, so the last line of a file it is
          // still writing is half a record. Skipping it is right; calling the
          // file broken is not.
          continue;
        }
        read += 1;

        const blunders = record.blunders || [];
        if (!record.start_fen || blunders.length === 0) {
          rejected += 1;
          continue;
        }
        if (blunders.length > maxBlunders) {
          tooMany += 1;
          continue;
        }
        // A position the client cannot load reaches a child as a blank board.
        try {
          new Chess(record.start_fen);
        } catch {
          rejected += 1;
          continue;
        }

        const { w, b, min } = elos(record);
        pending.push([
          gameId(record),
          record.database || path.basename(file),
          record.white || null,
          record.black || null,
          w,
          b,
          record.date || null,
          record.event || null,
          record.result || null,
          record.start_fen,
          record.moves || [],
          JSON.stringify(blunders),
          blunders.length,
          min,
          materialsOf(record),
        ]);
      }
    }

    console.log(`Procitano ${read} partija iz ${dir}`);

    await client.query('BEGIN');
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
      const result = await client.query(
        `INSERT INTO blunder_games
           (game_id, source_db, white, black, white_elo, black_elo, played_on,
            event, result, start_fen, moves, blunders, blunder_count, min_elo,
            materials)
         VALUES ${values.join(',')}
         ON CONFLICT (game_id) DO NOTHING
         RETURNING id`,
        params
      );
      inserted += result.rowCount;
      skipped += chunk.length - result.rowCount;
    }

    if (dryRun) {
      await client.query('ROLLBACK');
      console.log('\n--- PROBNI PROLAZ, nista nije upisano ---');
    } else {
      await client.query('COMMIT');
    }

    console.log(`upisano:    ${inserted}`);
    console.log(`preskoceno: ${skipped}  (vec u bazi)`);
    console.log(`odbaceno:   ${rejected}  (bez pozicije ili greske)`);
    console.log(`preteske:   ${tooMany}  (vise od ${maxBlunders} gresaka)`);

    const { rows } = await pool.query(
      `SELECT blunder_count, COUNT(*)::int AS n
         FROM blunder_games GROUP BY blunder_count ORDER BY blunder_count`
    );
    console.log('\n--- U BAZI, po broju gresaka ---');
    for (const row of rows) {
      console.log(`  ${String(row.blunder_count).padStart(2)}: ${row.n}`);
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
  console.error(err);
  process.exit(1);
});
