// import_endgame_puzzles.js - Import generated endgame puzzles into PostgreSQL
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool, initDB } = require('./db');

const MODUL2_DIR = 'D:\\generator\\BlindfoldChessCouch\\modul2';

async function importEndgamePuzzles() {
  console.log('--- Starting Import of Endgame Puzzles into PostgreSQL ---');
  await initDB();
  const client = await pool.connect();

  try {
    if (!fs.existsSync(MODUL2_DIR)) {
      console.error(`Folder not found: ${MODUL2_DIR}`);
      return;
    }

    const files = fs.readdirSync(MODUL2_DIR).filter(f => f.endsWith('.json'));
    console.log(`Found ${files.length} JSON files in ${MODUL2_DIR}`);

    let totalImported = 0;

    for (const filename of files) {
      const filePath = path.join(MODUL2_DIR, filename);
      let difficulty = 'medium';

      if (filename.includes('easy')) difficulty = 'easy';
      else if (filename.includes('hard')) difficulty = 'hard';

      // Extract piece tags from filename if available (e.g. W_Q_B_N)
      let pieceTags = '';
      const tagMatch = filename.match(/W_[A-Z_]+_B_[A-Z_]*/i);
      if (tagMatch) pieceTags = tagMatch[0];

      try {
        const rawContent = fs.readFileSync(filePath, 'utf-8');
        const items = JSON.parse(rawContent);
        if (!Array.isArray(items)) continue;

        let importedCount = 0;
        for (const item of items) {
          if (!item.fen) continue;

          const puzzleId = item.id ? `${filename}_${item.id}` : `endgame_${Date.now()}_${Math.random()}`;

          await client.query(
            `INSERT INTO endgame_puzzles (puzzle_id, fen, evaluation, difficulty, piece_tags)
             VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT DO NOTHING`,
            [puzzleId, item.fen, item.evaluation || 'Winning', difficulty, pieceTags]
          );
          importedCount++;
        }
        totalImported += importedCount;
        console.log(`Imported ${importedCount} positions from ${filename} (${difficulty})`);
      } catch (err) {
        console.error(`Error reading ${filename}:`, err);
      }
    }

    console.log(`\nSuccessfully imported ${totalImported} total endgame positions into 'endgame_puzzles' table!`);
  } catch (err) {
    console.error('Error during endgame import:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

importEndgamePuzzles();
