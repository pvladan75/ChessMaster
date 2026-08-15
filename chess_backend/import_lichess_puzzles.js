// import_lichess_puzzles.js
// Loads the Lichess puzzle database into `lichess_puzzles`.
//
// The dataset is CC0 and ships as a zstd-compressed CSV of roughly 4–5 million
// rows, so everything here streams: nothing is ever fully in memory, and rows go
// out in batches rather than one statement each.
//
// Usage:
//   node import_lichess_puzzles.js
//   node import_lichess_puzzles.js --limit 50000            # quick partial load
//   node import_lichess_puzzles.js --min-rating 800 --max-rating 2200
//   node import_lichess_puzzles.js --min-popularity 80      # well-liked puzzles only
//   node import_lichess_puzzles.js --file /path/to/other.csv.zst
//   node import_lichess_puzzles.js --dry-run --limit 200000   # parse only, no database
//
// Re-running is safe: rows are upserted on puzzle_id, so an interrupted import
// can simply be started again.

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool, initializeDatabase } = require('./db');
const { readLines } = require('./services/zstdMultiFrame');

const DEFAULT_FILE = path.join(__dirname, '..', 'puzzles', 'lichess_db_puzzle.csv.zst');
const BATCH_SIZE = 1000;
const COLUMN_COUNT = 10; // values bound per row; batch × this must stay under pg's 65535 parameter cap

function parseArgs(argv) {
  const args = {
    file: DEFAULT_FILE,
    limit: Infinity,
    minRating: 0,
    maxRating: Infinity,
    minPopularity: -Infinity,
    batch: BATCH_SIZE,
    dryRun: false,
  };

  for (let i = 2; i < argv.length; i += 2) {
    const key = argv[i];
    const value = argv[i + 1];
    // A flag takes no value, so it must not consume the next argument.
    if (key === '--dry-run') {
      args.dryRun = true;
      i -= 1;
      continue;
    }
    switch (key) {
      case '--file': args.file = value; break;
      case '--limit': args.limit = parseInt(value, 10); break;
      case '--min-rating': args.minRating = parseInt(value, 10); break;
      case '--max-rating': args.maxRating = parseInt(value, 10); break;
      case '--min-popularity': args.minPopularity = parseInt(value, 10); break;
      case '--batch': args.batch = parseInt(value, 10); break;
      default:
        console.error(`Unknown argument: ${key}`);
        process.exit(1);
    }
  }
  return args;
}

/// Lichess writes plain comma-separated values with no quoting: no field in the
/// dataset contains a comma, so a split is correct and far cheaper than a real
/// CSV parser over five million rows.
function parseRow(line) {
  const parts = line.split(',');
  if (parts.length < 8) return null;

  const [puzzleId, fen, moves, rating, ratingDeviation, popularity, nbPlays, themes, gameUrl, openingTags] = parts;
  const parsedRating = parseInt(rating, 10);
  if (!puzzleId || !fen || !moves || Number.isNaN(parsedRating)) return null;

  return {
    puzzleId,
    fen,
    moves,
    rating: parsedRating,
    ratingDeviation: parseInt(ratingDeviation, 10) || null,
    popularity: parseInt(popularity, 10) || 0,
    nbPlays: parseInt(nbPlays, 10) || 0,
    themes: (themes || '').trim().split(/\s+/).filter(Boolean),
    gameUrl: gameUrl || null,
    openingTags: (openingTags || '').trim().split(/\s+/).filter(Boolean),
  };
}

/// One multi-row INSERT per batch. Individual statements would make this import
/// take hours; a single giant statement would exceed the parameter limit.
async function flushBatch(rows) {
  if (rows.length === 0) return;

  const values = [];
  const tuples = rows.map((row, index) => {
    const base = index * COLUMN_COUNT;
    values.push(
      row.puzzleId, row.fen, row.moves, row.rating, row.ratingDeviation,
      row.popularity, row.nbPlays, row.themes, row.gameUrl, row.openingTags
    );
    return `(${Array.from({ length: COLUMN_COUNT }, (_, c) => `$${base + c + 1}`).join(', ')})`;
  });

  await pool.query(
    `INSERT INTO lichess_puzzles
       (puzzle_id, fen, moves, rating, rating_deviation, popularity, nb_plays, themes, game_url, opening_tags)
     VALUES ${tuples.join(', ')}
     ON CONFLICT (puzzle_id) DO UPDATE SET
       rating = EXCLUDED.rating,
       rating_deviation = EXCLUDED.rating_deviation,
       popularity = EXCLUDED.popularity,
       nb_plays = EXCLUDED.nb_plays,
       themes = EXCLUDED.themes`,
    values
  );
}

async function run() {
  const args = parseArgs(process.argv);

  if (!fs.existsSync(args.file)) {
    console.error(`Puzzle file not found: ${args.file}`);
    console.error('Download it from https://database.lichess.org/#puzzles');
    process.exit(1);
  }

  console.log(`${args.dryRun ? 'Dry run over' : 'Importing from'} ${args.file}`);
  if (!args.dryRun) {
    await initializeDatabase();
  }

  let isHeader = true;
  let seen = 0;
  let imported = 0;
  let skipped = 0;
  let batch = [];
  const startedAt = Date.now();

  for await (const line of readLines(args.file)) {
    if (isHeader) {
      isHeader = false;
      continue;
    }
    if (imported >= args.limit) break;

    seen++;
    const row = parseRow(line);
    if (!row) {
      skipped++;
      continue;
    }
    if (row.rating < args.minRating || row.rating > args.maxRating || row.popularity < args.minPopularity) {
      skipped++;
      continue;
    }

    batch.push(row);
    if (batch.length >= args.batch) {
      if (!args.dryRun) await flushBatch(batch);
      imported += batch.length;
      batch = [];

      if (imported % 100000 === 0) {
        const perSecond = Math.round(imported / ((Date.now() - startedAt) / 1000));
        console.log(`  ${imported.toLocaleString()} imported (${perSecond.toLocaleString()}/s, ${skipped.toLocaleString()} skipped)`);
      }
    }
  }

  if (!args.dryRun) await flushBatch(batch);
  imported += batch.length;

  const seconds = Math.round((Date.now() - startedAt) / 1000);
  const verb = args.dryRun ? 'parsed' : 'imported';
  console.log(`\nDone: ${imported.toLocaleString()} puzzles ${verb} in ${seconds}s (${seen.toLocaleString()} rows read, ${skipped.toLocaleString()} skipped).`);

  if (args.dryRun) {
    console.log('Dry run — nothing was written to the database.');
    return;
  }

  const counts = await pool.query(
    'SELECT COUNT(*)::int AS total, MIN(rating) AS min_rating, MAX(rating) AS max_rating FROM lichess_puzzles'
  );
  const { total, min_rating, max_rating } = counts.rows[0];
  console.log(`Table now holds ${total.toLocaleString()} puzzles, ratings ${min_rating}–${max_rating}.`);

  await pool.end();
}

if (require.main === module) {
  run().catch((err) => {
    console.error('Import failed:', err);
    process.exit(1);
  });
}

module.exports = { parseRow };
