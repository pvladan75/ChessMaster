const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const geminiService = require('../geminiService');

// GET /api/puzzles/next - Fetch next puzzle from clean puzzles_23 and winning_chess dataset
router.get('/puzzles/next', authenticateToken, async (req, res) => {
  const { type, mate_depth, excludeId } = req.query;
  const currentExclude = excludeId || '';
  const puzzleType = (type === 'winning' || type === 'winning_position') ? 'winning_position' : 'mate_puzzle';

  try {
    let puzzleRes;
    if (puzzleType === 'mate_puzzle' && mate_depth && mate_depth !== 'all') {
      const depthNum = parseInt(mate_depth, 10);
      puzzleRes = await pool.query(
        `SELECT * FROM puzzles
         WHERE type = $1 AND mate_depth = $2 
           AND solutions != '{}'::jsonb AND solutions IS NOT NULL
           AND ($3 = '' OR puzzle_id != $3)
         ORDER BY RANDOM() LIMIT 1`,
        ['mate_puzzle', depthNum, currentExclude]
      );
    } else if (puzzleType === 'mate_puzzle') {
      puzzleRes = await pool.query(
        `SELECT * FROM puzzles
         WHERE type = $1 
           AND solutions != '{}'::jsonb AND solutions IS NOT NULL
           AND ($2 = '' OR puzzle_id != $2)
         ORDER BY RANDOM() LIMIT 1`,
        ['mate_puzzle', currentExclude]
      );
    } else {
      puzzleRes = await pool.query(
        `SELECT * FROM puzzles
         WHERE type = $1 AND ($2 = '' OR puzzle_id != $2)
         ORDER BY RANDOM() LIMIT 1`,
        [puzzleType, currentExclude]
      );
    }

    if (puzzleRes.rows.length === 0) {
      puzzleRes = await pool.query(
        `SELECT * FROM puzzles WHERE type = $1 AND solutions != '{}'::jsonb AND solutions IS NOT NULL ORDER BY RANDOM() LIMIT 1`,
        [puzzleType]
      );
    }

    if (puzzleRes.rows.length === 0) {
      return res.status(404).json({ error: 'Nema dostupnih zagonetki u bazi.' });
    }

    const puzzle = puzzleRes.rows[0];
    const responsePayload = {
      puzzle: {
        puzzle_id: puzzle.puzzle_id,
        source: puzzle.source,
        fen: puzzle.fen,
        side_to_move: puzzle.side_to_move,
        eval: puzzle.eval,
        eval_value: puzzle.eval_value,
        type: puzzle.type,
        mate_depth: puzzle.mate_depth,
        winning_move_uci: puzzle.winning_move_uci,
        winning_move_san: puzzle.winning_move_san,
        solutions: puzzle.solutions || {},
        moves: [puzzle.winning_move_uci],
        rating: 1500,
        themes: [puzzle.type]
      }
    };

    console.log('\n=================== ♟️ [TRAINING LOG - BACKEND TERMINAL] ===================');
    console.log(`[1] MOD: ${puzzle.type === 'mate_puzzle' ? `Zagonetke: Mat u ${puzzle.mate_depth || 1} poteza` : 'Pronađite dobitni put'}`);
    console.log(`[2] UČITANI FEN: ${puzzle.fen}`);
    console.log(`[ID ZAGONETKE]: ${puzzle.puzzle_id} | Evaluacija: ${puzzle.eval}`);
    console.log(`[OČEKIVANI POTEZ (JSON)]: ${puzzle.winning_move_uci} (${puzzle.winning_move_san || ''})`);
    console.log('============================================================================\n');
    res.json(responsePayload);
  } catch (err) {
    console.error('Error fetching next puzzle:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zagonetke.' });
  }
});

// GET /api/puzzles/endgame/next - Fetch random endgame position from modul2 dataset
router.get('/puzzles/endgame/next', authenticateToken, async (req, res) => {
  const { difficulty, excludeId } = req.query;
  const currentExclude = excludeId || '';

  try {
    let result;
    if (difficulty && difficulty !== 'all') {
      result = await pool.query(
        `SELECT * FROM endgame_puzzles
         WHERE difficulty = $1 AND ($2 = '' OR puzzle_id != $2)
         ORDER BY RANDOM() LIMIT 1`,
        [difficulty, currentExclude]
      );
    } else {
      result = await pool.query(
        `SELECT * FROM endgame_puzzles
         WHERE ($1 = '' OR puzzle_id != $1)
         ORDER BY RANDOM() LIMIT 1`,
        [currentExclude]
      );
    }

    if (result.rows.length === 0) {
      result = await pool.query('SELECT * FROM endgame_puzzles ORDER BY RANDOM() LIMIT 1');
    }

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Nema dostupnih završnica u bazi.' });
    }

    const item = result.rows[0];
    res.json({
      endgame: {
        puzzle_id: item.puzzle_id,
        fen: item.fen,
        evaluation: item.evaluation,
        difficulty: item.difficulty,
        piece_tags: item.piece_tags
      }
    });
  } catch (err) {
    console.error('Error fetching endgame puzzle:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju završnice.' });
  }
});

// POST /api/puzzles/submit - Submit puzzle result & update Elo rating
router.post('/puzzles/submit', authenticateToken, async (req, res) => {
  const { puzzleId, solved, theme } = req.body;
  const userId = req.user.id;

  try {
    const puzzleRes = await pool.query('SELECT eval_value FROM puzzles WHERE puzzle_id = $1', [puzzleId]);
    const puzzleEval = parseFloat(puzzleRes.rows[0]?.eval_value || 1.5);
    const puzzleRating = Math.round(1500 + (puzzleEval * 50));

    const userRes = await pool.query(
      'SELECT overall_rating, theme_ratings, puzzles_solved, puzzles_failed FROM user_puzzle_ratings WHERE user_id = $1',
      [userId]
    );

    let currentRating = userRes.rows[0]?.overall_rating || 1500;
    let themeRatings = userRes.rows[0]?.theme_ratings || {};
    let solvedCount = userRes.rows[0]?.puzzles_solved || 0;
    let failedCount = userRes.rows[0]?.puzzles_failed || 0;

    const K = 32;
    const expected = 1 / (1 + Math.pow(10, (puzzleRating - currentRating) / 400));
    const actual = solved ? 1 : 0;
    const ratingChange = Math.round(K * (actual - expected));
    const newRating = Math.max(800, currentRating + ratingChange);

    if (solved) {
      solvedCount++;
    } else {
      failedCount++;
    }

    if (theme) {
      const currentThemeRating = themeRatings[theme] || currentRating;
      const themeExpected = 1 / (1 + Math.pow(10, (puzzleRating - currentThemeRating) / 400));
      const themeChange = Math.round(K * (actual - themeExpected));
      themeRatings[theme] = Math.max(800, currentThemeRating + themeChange);
    }

    await pool.query(
      `INSERT INTO user_puzzle_ratings (user_id, overall_rating, theme_ratings, puzzles_solved, puzzles_failed, updated_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
       ON CONFLICT (user_id) DO UPDATE SET
         overall_rating = EXCLUDED.overall_rating,
         theme_ratings = EXCLUDED.theme_ratings,
         puzzles_solved = EXCLUDED.puzzles_solved,
         puzzles_failed = EXCLUDED.puzzles_failed,
         updated_at = CURRENT_TIMESTAMP`,
      [userId, newRating, JSON.stringify(themeRatings), solvedCount, failedCount]
    );

    res.json({
      success: true,
      newRating,
      ratingChange,
      puzzlesSolved: solvedCount,
      puzzlesFailed: failedCount
    });
  } catch (err) {
    console.error('Error submitting puzzle result:', err);
    res.status(500).json({ error: 'Greška pri čuvanju rezultata.' });
  }
});

// Worker Queue lock to ensure single atomic Stockfish requests
let isStockfishBusy = false;
const stockfishQueue = [];

function processStockfishQueue() {
  if (isStockfishBusy || stockfishQueue.length === 0) return;
  const task = stockfishQueue.shift();
  isStockfishBusy = true;
  task().finally(() => {
    isStockfishBusy = false;
    processStockfishQueue();
  });
}

function runAtomicStockfishTask(taskFn) {
  return new Promise((resolve, reject) => {
    stockfishQueue.push(() => taskFn().then(resolve).catch(reject));
    processStockfishQueue();
  });
}

// POST /api/puzzles/verify - Atomic Stockfish Move Verification with 2000ms Hard Timeout
router.post('/puzzles/verify', async (req, res) => {
  const { fen, userMove, mode, remainingNeeded, orientation } = req.body;

  try {
    const result = await runAtomicStockfishTask(async () => {
      const verifyPromise = (async () => {
        try {
          const cloudUrl = `https://lichess.org/api/cloud-eval?fen=${encodeURIComponent(fen)}`;
          const response = await fetch(cloudUrl);
          if (response.ok) {
            const data = await response.json();
            if (data.pvs && data.pvs.length > 0) {
              const pv = data.pvs[0];
              const isBlackToMove = fen.includes(' b ');
              let mateVal = null;
              if (pv.mate !== undefined && pv.mate !== null) {
                mateVal = pv.mate;
                if (isBlackToMove) mateVal = -mateVal;
              }

              const isWhite = (orientation === 'white');
              let isMateForUser = false;
              if (mateVal !== null) {
                if (isWhite && mateVal > 0 && mateVal <= (remainingNeeded || 3)) isMateForUser = true;
                if (!isWhite && mateVal < 0 && Math.abs(mateVal) <= (remainingNeeded || 3)) isMateForUser = true;
              }

              if (isMateForUser) {
                return { success: true, status: 'ACCEPTED', mateVal: Math.abs(mateVal), depth: data.depth || 25 };
              }
            }
          }
        } catch (_) {}

        try {
          const sfUrl = `https://stockfish.online/api/s/v2.php?fen=${encodeURIComponent(fen)}&depth=12`;
          const sfRes = await fetch(sfUrl);
          if (sfRes.ok) {
            const sfData = await sfRes.json();
            if (sfData.success) {
              const isBlackToMove = fen.includes(' b ');
              let mateVal = sfData.mate;
              if (mateVal !== null && mateVal !== undefined) {
                if (isBlackToMove) mateVal = -mateVal;
                const isWhite = (orientation === 'white');
                if (isWhite && mateVal > 0 && mateVal <= (remainingNeeded || 3)) {
                  return { success: true, status: 'ACCEPTED', mateVal: Math.abs(mateVal), depth: 12 };
                }
                if (!isWhite && mateVal < 0 && Math.abs(mateVal) <= (remainingNeeded || 3)) {
                  return { success: true, status: 'ACCEPTED', mateVal: Math.abs(mateVal), depth: 12 };
                }
              }
            }
          }
        } catch (_) {}

        return { success: false, status: 'REJECTED', reason: 'Netačan potez (Nije pronađen mat u zadatom broju poteza).' };
      })();

      const timeoutPromise = new Promise((resolve) => {
        setTimeout(() => {
          resolve({ success: false, status: 'TIMEOUT_REJECTED', reason: 'Evaluacija je istekla (Timeout 2000ms).' });
        }, 2000);
      });

      return Promise.race([verifyPromise, timeoutPromise]);
    });

    console.log(`[VERIFY ENDPOINT] FEN: ${fen} | Move: ${userMove} | Result: ${result.status} (${result.reason || 'OK'})`);
    return res.json(result);
  } catch (err) {
    console.error('Error in /api/puzzles/verify:', err);
    return res.json({ success: false, status: 'REJECTED', reason: 'Greška na serveru pri verifikaciji.' });
  }
});

// POST /api/puzzles/log - Stream live position state & user actions directly to backend console
router.post('/puzzles/log', (req, res) => {
  try {
    const { details } = req.body;
    if (details) {
      if (details.type === 'engineStream') {
        console.log(`[ENGINE STREAM] Received eval for FEN: ${details.fen} | Depth: ${details.depth} | Best Move: ${details.bestMove}`);
        return res.json({ success: true });
      }
      if (details.type === 'uiRender') {
        console.log(`[UI RENDER] Attempting to draw arrows for FEN: ${details.fen} | Current Board FEN: ${details.currentFen}`);
        return res.json({ success: true });
      }
      if (details.type === 'stateReset') {
        console.log(`[STATE RESET] Cleared arrows and stopped analysis for FEN: ${details.oldFen} (Token: ${details.token || 1})`);
        return res.json({ success: true });
      }
      if (details.type === 'ignoredEvent') {
        console.log(`[IGNORED EVENT] Discarding stale evaluation from old FEN: ${details.oldFen} (Current Board FEN: ${details.currentFen})`);
        return res.json({ success: true });
      }

      if (details.type === 'buttonClick') {
        console.log('\n🔘 [KLIK NA DUGME - BACKEND TERMINAL] ==============================');
        console.log(`[DUGME]: ${details.button}`);
        if (details.puzzleId) console.log(`[ID ZAGONETKE]: ${details.puzzleId}`);
        if (details.fen) console.log(`[FEN POZICIJE]: ${details.fen}`);
        if (details.category) console.log(`[KATEGORIJA]: ${details.category}`);
        console.log('============================================================================\n');
        return res.json({ success: true });
      }

      if (details.type === 'branchReset') {
        console.log('\n🔄 [VARIATION BRANCH RESET - BACKEND TERMINAL] =====================');
        console.log(`[1] MOD: ${details.mode}`);
        console.log(`[STATUS]: 🔁 Prva linija rešena! Vraćanje na tačku razgranjenja.`);
        console.log(`[NAREDNI ODGOVOR PROTIVNIKA]: ${details.nextOpponentMove}`);
        console.log(`[PREOSTALO UNIKATNIH LINIJA]: ${details.remainingBranches}`);
        console.log('============================================================================\n');
        return res.json({ success: true });
      }

      if (details.type === 'pgnChipClick') {
        console.log('\n♟️ [KLIK NA PGN POTEZ - BACKEND TERMINAL] ===========================');
        console.log(`[ODABRANI POTEZ U STABLU]: ${details.moveSan}`);
        console.log(`[CILJNI FEN]: ${details.targetFen}`);
        console.log('============================================================================\n');
        return res.json({ success: true });
      }

      if (details.status === 'REJECTED') {
        console.log('\n❌ [REJECTED MOVE LOG - BACKEND TERMINAL] ===================');
        console.log(`[1] MOD: ${details.mode}`);
        console.log(`[2] FEN PRE POTEZA: ${details.initialFen || details.dynamicFen}`);
        console.log(`[3] ODIGRANI POTEZ KORISNIKA: ❌ ${details.userMove}`);
        console.log(`[STATUS]: ❌ ODBIJEN POTEZ (Nije u stablu rešenja)`);
        if (details.validTreeKeys) console.log(`[DOZVOLJENI POTEZI U TRENUTNOM ČVORU]: ${details.validTreeKeys}`);
        if (details.reason) console.log(`[RAZLOG]: ${details.reason}`);
        console.log('============================================================================\n');
        return res.json({ success: true });
      }

      console.log('\n=================== ♟️ [TRAINING LOG - BACKEND TERMINAL] ===================');
      if (details.mode) console.log(`[1] MOD: ${details.mode}`);
      if (details.initialFen) console.log(`[2] UČITANI FEN: ${details.initialFen}`);
      if (details.dynamicFen) console.log(`[3] DINAMIČKI FEN: ${details.dynamicFen}`);
      if (details.userMove) console.log(`[4] POTEZ KORISNIKA: ${details.userMove}`);
      if (details.status) console.log(`[4] STATUS POTEZA: ${details.status === 'ACCEPTED' ? '✅ TAČAN (Prihvaćen u stablu)' : details.status}`);
      if (details.validTreeKeys) console.log(`[4] DOZVOLJENI POTEZI U TRENUTNOM ČVORU]: ${details.validTreeKeys}`);
      if (details.subBranch) console.log(`[4] STABLO NASTAVKA: ${details.subBranch}`);
      if (details.fastTrack !== undefined) console.log(`[4] FAST-TRACK PROVERA: ${details.fastTrack ? '✅ DA (Potez u JSON-u)' : '⚡ NE (Šalje se na Stockfish)'}`);
      if (details.engineMove) console.log(`[5] ODGOVOR PROTIVNIKA: ${details.engineMove}`);
      if (details.decisionBasis) console.log(`[5] OSNOV ODABIRA: ${details.decisionBasis}`);
      if (details.depth) console.log(`[5] DUBINA (DEPTH): ${details.depth}`);
      if (details.eval) console.log(`[5] EVALUACIJA: ${details.eval}`);
      console.log('============================================================================\n');
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Log failure' });
  }
});

// POST /api/ai/explain-position - AI Chess Coach powered by Gemini SDK (@google/genai)
router.post('/ai/explain-position', authenticateToken, async (req, res) => {
  const { fen, evals, userLanguage } = req.body;
  if (!fen) {
    return res.status(400).json({ error: 'FEN kod je obavezan parametar.' });
  }

  try {
    const explanation = await geminiService.explainPosition({
      fen,
      evals: evals || {},
      userLanguage: userLanguage || 'sr'
    });

    res.json(explanation);
  } catch (err) {
    console.error('Error in AI position explanation route:', err);
    res.status(500).json({ error: 'Greška pri generisanju AI objašnjenja.' });
  }
});

module.exports = router;
