require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./db');
const { Chess } = require('chess.js');

const puzzles23Path = path.join(__dirname, '../puzzles/puzzles_23.json');
const winningPath = path.join(__dirname, '../puzzles/winning_chess.json');

async function runImport() {
  console.log('Starting dataset import for puzzles_23.json & winning_chess.json...');

  const data23 = JSON.parse(fs.readFileSync(puzzles23Path, 'utf8')).positions || [];
  const dataWinning = JSON.parse(fs.readFileSync(winningPath, 'utf8')).positions || [];

  console.log(`Loaded ${data23.length} raw positions from 23.json`);
  console.log(`Loaded ${dataWinning.length} raw positions from winning_chess.json`);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Drop & Create table & clear old Lichess entries
    await client.query(`
      DROP TABLE IF EXISTS puzzles CASCADE;
      CREATE TABLE puzzles (
        id SERIAL PRIMARY KEY,
        puzzle_id VARCHAR(100) UNIQUE NOT NULL,
        source VARCHAR(100) NOT NULL,
        fen VARCHAR(255) NOT NULL,
        side_to_move VARCHAR(10) NOT NULL,
        eval VARCHAR(20) NOT NULL,
        eval_value NUMERIC(6, 2) DEFAULT 0,
        type VARCHAR(50) NOT NULL,
        mate_depth INTEGER DEFAULT NULL,
        winning_move_uci VARCHAR(10) NOT NULL,
        winning_move_san VARCHAR(20) NOT NULL,
        solutions JSONB DEFAULT '{}'::jsonb
      );
      CREATE INDEX idx_puzzles_type_depth ON puzzles(type, mate_depth);
    `);

    let importedMate = 0;
    let importedWinning = 0;
    let rejectedCount = 0;

    const mateDbPath = path.join(__dirname, '../puzzles/mate_puzzles_db.json');
    if (fs.existsSync(mateDbPath)) {
      const mateDbData = JSON.parse(fs.readFileSync(mateDbPath, 'utf8'));
      console.log(`Loaded ${mateDbData.length} clean mate positions from mate_puzzles_db.json`);
      for (const item of mateDbData) {
        const fen = (item.fen || '').trim();
        if (!fen) continue;
        const puzzleId = item.id || `mate_db_${item.diagramNumber}`;
        const targetMoves = item.targetMoves || 1;
        const solutionsJson = item.solutions || {};
        let winUci = '';
        if (solutionsJson && typeof solutionsJson === 'object') {
          const keys = Object.keys(solutionsJson);
          if (keys.length > 0) winUci = keys[0];
        }
        const side = fen.split(' ')[1] === 'b' ? 'black' : 'white';

        await client.query(
          `INSERT INTO puzzles (puzzle_id, source, fen, side_to_move, eval, eval_value, type, mate_depth, winning_move_uci, winning_move_san, solutions)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
           ON CONFLICT (puzzle_id) DO UPDATE SET solutions = EXCLUDED.solutions, mate_depth = EXCLUDED.mate_depth`,
          [puzzleId, 'mate_db', fen, side, `+M${targetMoves}`, 100.0, 'mate_puzzle', targetMoves, winUci, winUci, JSON.stringify(solutionsJson)]
        );
        importedMate++;
      }
    }

    function processItem(item, sourceTag) {
      const fen = (item.fen || '').trim();
      if (!fen) {
        rejectedCount++;
        return;
      }

      // Validate FEN with chess.js
      let chessInstance;
      try {
        chessInstance = new Chess(fen);
        if (!chessInstance) {
          rejectedCount++;
          return;
        }
      } catch (e) {
        rejectedCount++;
        return;
      }

      const side = (item.side_to_move || 'white').toLowerCase();
      const evStr = String(item.eval || '').trim();
      const evVal = Number(item.eval_value || 0);
      const winUci = (item.winning_move_uci || '').trim();
      const winSan = (item.winning_move_san || '').trim();

      if (!winUci) {
        rejectedCount++;
        return;
      }

      // Legal move check
      try {
        const fromStr = winUci.substring(0, 2);
        const toStr = winUci.substring(2, 4);
        const promo = winUci.length > 4 ? winUci[4] : undefined;
        const validMove = chessInstance.move({ from: fromStr, to: toStr, promotion: promo });
        if (!validMove) {
          rejectedCount++;
          return;
        }
      } catch (e) {
        rejectedCount++;
        return;
      }

      // Perspective-aware positivity check:
      // White to move: eval must be +M... or eval_value >= 1.5
      // Black to move: eval must be -M... or eval_value <= -1.5
      const isMate = evStr.includes('M');
      let isWinningEval = false;
      let mateDepth = null;

      if (side === 'white') {
        if (isMate && evStr.startsWith('+M')) {
          isWinningEval = true;
          mateDepth = parseInt(evStr.replace('+M', ''), 10);
        } else if (!isMate && evVal >= 1.5) {
          isWinningEval = true;
        }
      } else { // Black to move
        if (isMate && evStr.startsWith('-M')) {
          isWinningEval = true;
          mateDepth = parseInt(evStr.replace('-M', ''), 10);
        } else if (!isMate && evVal <= -1.5) {
          isWinningEval = true;
        }
      }

      if (!isWinningEval) {
        rejectedCount++;
        return;
      }

      const rawId = item.diagram_id || item.id || Math.random().toString(36).substring(2, 7);
      const puzzleId = `${sourceTag}_${rawId}`;

      if (isMate && mateDepth && [1, 2, 3].includes(mateDepth)) {
        client.query(
          `INSERT INTO puzzles (puzzle_id, source, fen, side_to_move, eval, eval_value, type, mate_depth, winning_move_uci, winning_move_san)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (puzzle_id) DO NOTHING`,
          [puzzleId, sourceTag, fen, side, evStr, Math.abs(evVal), 'mate_puzzle', mateDepth, winUci, winSan]
        );
        importedMate++;
      } else {
        client.query(
          `INSERT INTO puzzles (puzzle_id, source, fen, side_to_move, eval, eval_value, type, mate_depth, winning_move_uci, winning_move_san)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (puzzle_id) DO NOTHING`,
          [puzzleId, sourceTag, fen, side, evStr, Math.abs(evVal), 'winning_position', mateDepth || null, winUci, winSan]
        );
        importedWinning++;
      }
    }

    // Process winning chess positions
    for (const p of dataWinning) {
      processItem(p, 'winning_chess');
    }

    await client.query('COMMIT');

    console.log('--- Dataset Import Successful ---');
    console.log(`Successfully imported Verified Mate Puzzles (M1, M2, M3): ${importedMate}`);
    console.log(`Successfully imported Dobitne Pozicije (Winning): ${importedWinning}`);
    console.log(`Total valid imported: ${importedMate + importedWinning}`);
    console.log(`Total invalid/rejected: ${rejectedCount}`);
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('Import error:', e);
  } finally {
    client.release();
    pool.end();
  }
}

runImport();
