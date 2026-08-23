const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { requireQuota, refundQuota } = require('../middleware/entitlements');
const { ENT } = require('../services/entitlementService');
const puzzleSelection = require('../services/puzzleSelectionService');
const {
  buildCatalog, ELO_BANDS, ELO_BAND_SQL,
} = require('../services/endgameCatalog');
const endgameDrill = require('../services/endgameDrill');
const { tablebase, TablebaseUnavailable } = require('../services/tablebaseService');
const assignmentService = require('../services/assignmentService');
const geminiService = require('../geminiService');

const isProduction = process.env.NODE_ENV === 'production';

// /puzzles/log is reachable without a session and the client also uses it as a
// connectivity check, so it is capped per-IP.
const debugLogLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, status: 'REJECTED', reason: 'Previše zahteva. Sačekajte trenutak.' },
});

// The Gemini call costs money per request, so it gets a tighter budget still.
const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše AI zahteva. Sačekajte trenutak.' },
});

// Every uncached position in a drill is a request to a tablebase someone else
// pays to run, so the endpoint carries a cap even though a child playing an
// ending moves once every few seconds. This is not there to stop them; it is
// there to stop a loop in a client from becoming a scan of a donated service.
const drillLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše poteza u minuti. Sačekajte trenutak.' },
});

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

    logger.info('\n=================== ♟️ [TRAINING LOG - BACKEND TERMINAL] ===================');
    logger.info(`[1] MOD: ${puzzle.type === 'mate_puzzle' ? `Zagonetke: Mat u ${puzzle.mate_depth || 1} poteza` : 'Pronađite dobitni put'}`);
    logger.info(`[2] UČITANI FEN: ${puzzle.fen}`);
    logger.info(`[ID ZAGONETKE]: ${puzzle.puzzle_id} | Evaluacija: ${puzzle.eval}`);
    logger.info(`[OČEKIVANI POTEZ (JSON)]: ${puzzle.winning_move_uci} (${puzzle.winning_move_san || ''})`);
    logger.info('============================================================================\n');
    res.json(responsePayload);
  } catch (err) {
    logger.error('Error fetching next puzzle:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zagonetke.' });
  }
});

// GET /api/puzzles/endgame/catalog - what there is to practise.
//
// The collection holds 128 distinct endings and grows with every mining run, so
// the picker is built from the data rather than from a list someone maintains:
// families and their endings, each with how many positions stand behind it.
// A trainer who asks for rook endings gets the thirteen shapes they come in,
// with the numbers, instead of having to know that 'KRPvKR' is one of them.
//
// Counted per mode, because converting and holding are separate exercises and
// their distributions are not the same.
router.get('/puzzles/endgame/catalog', authenticateToken, async (req, res) => {
  const { mode } = req.query;
  const where = ["material IS NOT NULL", "cardinality(winning_moves) > 0"];
  const params = [];
  if (mode && mode !== 'all') {
    params.push(mode);
    where.push(`mode = $${params.length}`);
  }

  try {
    const result = await pool.query(
      `SELECT material, ${ELO_BAND_SQL} AS band, COUNT(*)::int AS n,
              COUNT(*) FILTER (WHERE opposite_bishops)::int AS opposite
         FROM endgame_puzzles
        WHERE ${where.join(' AND ')}
        GROUP BY material, band`,
      params
    );
    const opposite = result.rows.reduce((sum, row) => sum + row.opposite, 0);
    res.json({
      families: buildCatalog(result.rows),
      bands: ELO_BANDS,
      oppositeBishops: opposite,
    });
  } catch (err) {
    logger.error('Error building endgame catalog:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju spiska završnica.' });
  }
});

// GET /api/puzzles/endgame/next - one endgame position to solve.
//
// The filters exist because the callers want genuinely different things from
// the same table, and each has its own reason:
//   type      - a themed lesson ("today we do rook and pawn")
//   mode      - win is converting an advantage, draw is holding one; two skills
//   maxPieces - the play-it-out drill needs <= 5, which is how far the
//               tablebases reach, so this is a hard limit and not a preference
//   minPawns  - a pawn-ending lesson wants pawns on the board; there the
//               structure is the subject, so few pieces is the wrong measure
//
// No silent fallback to "any position at all" when a filter matches nothing.
// The old handler did that, and a screen asking for a drawn rook ending would
// be handed a won pawn ending without a word.
router.get('/puzzles/endgame/next', authenticateToken, async (req, res) => {
  const {
    type, mode, difficulty, maxPieces, minPawns, excludeId, material,
    minElo, maxElo, oppositeBishops,
  } = req.query;

  const where = [];
  const params = [];
  // replaceAll, not replace: the exclude clause uses the same parameter twice
  // and replacing only the first occurrence leaves a literal $? in the SQL.
  const add = (clause, value) => {
    params.push(value);
    where.push(clause.replaceAll('$?', `$${params.length}`));
  };

  // The table still holds 510 rows from the old generator: a position and a
  // one-word evaluation, no solution and no type. Serving one would put a board
  // in front of a child with nothing to find and no way to be right, so only
  // rows that carry a solution are eligible.
  where.push("winning_moves <> '{}'");

  add('($? = \'\' OR puzzle_id IS DISTINCT FROM $?)', excludeId || '');
  if (type && type !== 'all') add('endgame_type = $?', type);
  // The Syzygy table name, which is a far finer grouping than the seven mined
  // categories: 'KRPvKR' picks out one ending rather than a family of them.
  // A list, because the picker offers a family and the trainer unticks the
  // shapes they do not want - so "rook endings except R+B vs R" is one request.
  if (material && material !== 'all') {
    add('material = ANY($?)', String(material).split(',').filter(Boolean));
  }
  // The rating of the player who got it wrong, which is the honest measure of
  // how hard a position is. Only blunder positions carry one, so a band asks
  // for those and leaves the mined ones out - deliberately, since a lesson
  // pitched at a level means the level somebody actually failed at.
  if (minElo) add('blunder_elo >= $?', parseInt(minElo, 10));
  if (maxElo) add('blunder_elo <= $?', parseInt(maxElo, 10));
  if (oppositeBishops === 'true') where.push('opposite_bishops IS TRUE');
  if (mode && mode !== 'all') add('mode = $?', mode);
  if (difficulty && difficulty !== 'all') add('difficulty = $?', difficulty);
  if (maxPieces) add('piece_count <= $?', parseInt(maxPieces, 10));
  if (minPawns) add('pawn_count >= $?', parseInt(minPawns, 10));

  try {
    const result = await pool.query(
      `SELECT * FROM endgame_puzzles
        WHERE ${where.join(' AND ')}
        ORDER BY RANDOM() LIMIT 1`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Nema završnice koja odgovara traženim uslovima.' });
    }

    const item = result.rows[0];
    res.json({
      endgame: {
        puzzle_id: item.puzzle_id,
        fen: item.fen,
        type: item.endgame_type,
        mode: item.mode,
        side_to_move: item.side_to_move,
        // Every move that holds the result. The client must accept any of them:
        // in 68% of mined positions there is more than one.
        winning_moves: item.winning_moves,
        solution: item.solution,
        solution_san: item.solution_san,
        difficulty: item.difficulty,
        difficulty_score: item.difficulty_score,
        piece_count: item.piece_count,
        pawn_count: item.pawn_count,
        // Exact where it came from a tablebase, an engine estimate otherwise.
        source: item.source,
        // Where the position came from, when it came from a real mistake:
        // the table it belongs to, how strong the player who erred was, and
        // what they played instead.
        material: item.material,
        blunder_elo: item.blunder_elo,
        played_move: item.played_move,
        evaluation: item.evaluation,
        wdl: item.wdl,
        dtz: item.dtz,
        game: item.game_white
          ? { white: item.game_white, black: item.game_black, date: item.game_date }
          : null,
      },
    });
  } catch (err) {
    logger.error('Error fetching endgame puzzle:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju završnice.' });
  }
});

// POST /api/puzzles/endgame/play - judge one move of a play-it-out drill.
//
// The verdict is made here rather than in the app, and not out of distrust: a
// result posted by a client is one the server cannot tell apart from any other
// POST, and the ordinary case is an old build still installed or a retry after
// a dropped connection rather than a child cheating. It also costs nothing,
// because the tables have to be asked anyway to answer the child at all.
//
// 503 when the tablebase cannot be reached, never a verdict from an engine
// standing in for it. This mode's promise is that "that move let the win go" is
// a fact; an estimate wearing the same sentence would be worse than silence.
router.post('/puzzles/endgame/play', authenticateToken, drillLimiter, async (req, res) => {
  const { fen, move } = req.body || {};

  try {
    const result = await endgameDrill.judgeMove({ fen, move, tablebase });
    res.json(result);
  } catch (err) {
    if (err instanceof endgameDrill.DrillError) {
      return res.status(err.status).json({ error: err.message });
    }
    if (err instanceof TablebaseUnavailable) {
      logger.warn(`[ZAVRSNICE] tablica nedostupna: ${err.message}`);
      return res.status(503).json({ error: err.message });
    }
    logger.error('Error judging endgame move:', err);
    res.status(500).json({ error: 'Greška pri suđenju poteza.' });
  }
});

// GET /api/puzzles/endgame/game/next - one game to walk through.
//
// A different exercise from a single position, and it needs the whole thing:
// the board where it first went wrong, the moves as they were actually played,
// and every mistake in between. The walk stops at each one and asks for the
// move that held, then plays on the way the game really went.
//
// The filters are the ones a trainer would ask for out loud. blunders is how
// long the session runs - one mistake is a puzzle with context, six is an
// ending played badly from start to finish. elo is the level the game was
// played at, and material picks a shape: a game that passes through KRPvKR at
// any point.
//
// Same rule as the position route: nothing is served when the filters match
// nothing, because a game handed over silently instead of the one asked for
// teaches the caller to distrust the filters.
router.get('/puzzles/endgame/game/next', authenticateToken, async (req, res) => {
  const { minBlunders, maxBlunders, minElo, maxElo, material, excludeId } =
    req.query;

  const where = [];
  const params = [];
  const add = (clause, value) => {
    params.push(value);
    where.push(clause.replaceAll('$?', `$${params.length}`));
  };

  add('($? = \'\' OR game_id IS DISTINCT FROM $?)', excludeId || '');
  if (minBlunders) add('blunder_count >= $?', parseInt(minBlunders, 10));
  if (maxBlunders) add('blunder_count <= $?', parseInt(maxBlunders, 10));
  // min_elo is the weaker player, so a range on it is a statement about the
  // game rather than about whoever happened to be stronger.
  if (minElo) add('min_elo >= $?', parseInt(minElo, 10));
  if (maxElo) add('min_elo <= $?', parseInt(maxElo, 10));
  if (material && material !== 'all') add('materials @> ARRAY[$?]::varchar[]', material);

  try {
    const result = await pool.query(
      `SELECT * FROM blunder_games
        WHERE ${where.join(' AND ')}
        ORDER BY RANDOM() LIMIT 1`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Nema partije koja odgovara traženim uslovima.' });
    }

    const row = result.rows[0];
    res.json({
      game: {
        game_id: row.game_id,
        white: row.white,
        black: row.black,
        white_elo: row.white_elo,
        black_elo: row.black_elo,
        date: row.played_on,
        event: row.event,
        result: row.result,
        database: row.source_db,
        // The board where the walk starts, and the game from there on. Not
        // from move one: the opening is not the subject and carrying it would
        // multiply every record for nothing.
        start_fen: row.start_fen,
        moves: row.moves,
        blunders: row.blunders,
        materials: row.materials,
      },
    });
  } catch (err) {
    logger.error('Error fetching blunder game:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju partije.' });
  }
});

// GET /api/puzzles/adaptive - Next Lichess puzzle chosen for this user.
//
// Unlike /puzzles/next, which serves a random row from a fixed category, this
// targets the motif the user is measurably weakest at, at a rating just below
// their own. Themes and ratings here are the dataset's real ones.
router.get('/puzzles/adaptive', authenticateToken, async (req, res) => {
  const { theme, phase, excludeId } = req.query;

  try {
    const result = await puzzleSelection.selectAdaptivePuzzle(pool, req.user.id, {
      theme: theme || null,
      phase: phase || null,
      excludeId: excludeId || null,
    });

    if (!result) {
      return res.status(404).json({
        error: 'Nema dostupnih zagonetki. Da li je baza uvezena (import_lichess_puzzles.js)?',
      });
    }

    res.json({
      puzzle: puzzleSelection.toClientPuzzle(result.puzzle),
      selection: {
        targetTheme: result.targetTheme,
        targetRating: result.targetRating,
        band: result.band,
      },
    });
  } catch (err) {
    logger.error('Error selecting adaptive puzzle:', err);
    res.status(500).json({ error: 'Greška pri izboru zagonetke.' });
  }
});

// GET /api/puzzles/themes - the user's rating per motif, weakest first.
// Also the data a trainer's progress view will read.
router.get('/puzzles/themes', authenticateToken, async (req, res) => {
  try {
    const profile = await puzzleSelection.getUserRatingProfile(pool, req.user.id);

    const themes = puzzleSelection.TRAINABLE_THEMES.map((theme) => ({
      theme,
      rating: profile.themeRatings[theme] ?? null,
      attempts: profile.themeAttempts[theme] || 0,
      measured: (profile.themeAttempts[theme] || 0) >= puzzleSelection.MIN_ATTEMPTS_FOR_WEAKNESS,
    }));

    // Unmeasured themes sort last: they are unknowns, not weaknesses.
    themes.sort((a, b) => {
      if (a.measured !== b.measured) return a.measured ? -1 : 1;
      return (a.rating ?? Infinity) - (b.rating ?? Infinity);
    });

    res.json({ overallRating: profile.overallRating, themes });
  } catch (err) {
    logger.error('Error reading theme ratings:', err);
    res.status(500).json({ error: 'Greška pri čitanju rejtinga po temama.' });
  }
});

// POST /api/puzzles/attempt - Records a Lichess puzzle attempt and updates ratings.
//
// The puzzle's own rating is read from the database rather than taken from the
// request: a client that reported its own difficulty could inflate a rating at
// will. Every trainable theme on the puzzle moves, so a fork-and-pin puzzle
// informs both.
router.post('/puzzles/attempt', authenticateToken, async (req, res) => {
  const { puzzleId, solved, msTaken, playedSan } = req.body;
  const userId = req.user.id;

  if (!puzzleId || typeof solved !== 'boolean') {
    return res.status(400).json({ error: 'puzzleId i solved su obavezni.' });
  }

  try {
    const puzzleRes = await pool.query(
      'SELECT rating, themes FROM lichess_puzzles WHERE puzzle_id = $1',
      [puzzleId]
    );
    if (puzzleRes.rows.length === 0) {
      return res.status(404).json({ error: 'Zagonetka nije pronađena.' });
    }

    const puzzleRating = puzzleRes.rows[0].rating;
    const themes = puzzleSelection.trainableThemes(puzzleRes.rows[0].themes);

    const userRes = await pool.query(
      'SELECT overall_rating, theme_ratings, puzzles_solved, puzzles_failed FROM user_puzzle_ratings WHERE user_id = $1',
      [userId]
    );

    const currentRating = userRes.rows[0]?.overall_rating || 1500;
    const themeRatings = { ...(userRes.rows[0]?.theme_ratings || {}) };
    let solvedCount = userRes.rows[0]?.puzzles_solved || 0;
    let failedCount = userRes.rows[0]?.puzzles_failed || 0;

    const K = 32;
    const actual = solved ? 1 : 0;
    const elo = (rating) => {
      const expected = 1 / (1 + Math.pow(10, (puzzleRating - rating) / 400));
      return Math.max(600, rating + Math.round(K * (actual - expected)));
    };

    const newRating = elo(currentRating);
    for (const theme of themes) {
      themeRatings[theme] = elo(themeRatings[theme] ?? currentRating);
    }

    if (solved) solvedCount++;
    else failedCount++;

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

    // Written even for a repeat, so the selector's "already seen" check and the
    // future progress view both stay honest.
    await pool.query(
      `INSERT INTO user_puzzle_attempts
         (user_id, puzzle_id, source, solved, puzzle_rating, rating_before, rating_after, themes, ms_taken)
       VALUES ($1, $2, 'lichess', $3, $4, $5, $6, $7, $8)`,
      [userId, puzzleId, solved, puzzleRating, currentRating, newRating, themes, Number.isInteger(msTaken) ? msTaken : null]
    );

    // Homework is marked from the same attempt rather than from a separate
    // action: the student solves an assigned puzzle exactly like any other, and
    // asking them to remember which were set would leave most of it unmarked.
    const markedItems = await assignmentService.recordPuzzleResult(pool, {
      studentId: userId,
      puzzleId,
      solved,
      msTaken,
      // The first move they tried that was not the one the puzzle wanted. A
      // puzzle is not one shot, so there is no single move played here — this
      // is the idea they had before they found it, or instead of finding it.
      playedSan,
    });

    res.json({
      success: true,
      newRating,
      ratingChange: newRating - currentRating,
      puzzleRating,
      themes,
      themeRatings,
      puzzlesSolved: solvedCount,
      puzzlesFailed: failedCount,
      assignmentItemsMarked: markedItems,
    });
  } catch (err) {
    logger.error('Error recording puzzle attempt:', err);
    res.status(500).json({ error: 'Greška pri čuvanju rezultata.' });
  }
});

// GET /api/puzzles/by-id/:puzzleId - one specific Lichess puzzle.
//
// Needed because an assignment names its puzzles: the student must get exactly
// what the trainer set, not whatever the adaptive selector would have chosen.
router.get('/puzzles/by-id/:puzzleId', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM lichess_puzzles WHERE puzzle_id = $1',
      [req.params.puzzleId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Zagonetka nije pronađena.' });
    }
    res.json({ puzzle: puzzleSelection.toClientPuzzle(result.rows[0]) });
  } catch (err) {
    logger.error('Error fetching puzzle by id:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zagonetke.' });
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
    logger.error('Error submitting puzzle result:', err);
    res.status(500).json({ error: 'Greška pri čuvanju rezultata.' });
  }
});

/// Strips control characters and caps length on every string in the debug log payload,
/// so a client cannot forge log lines or flood the log with a single request.
function sanitizeLogDetails(details) {
  if (!details || typeof details !== 'object') return null;

  const clean = {};
  for (const [key, value] of Object.entries(details)) {
    if (typeof value === 'string') {
      clean[key] = Array.from(value)
        .filter((ch) => ch.codePointAt(0) >= 32 && ch.codePointAt(0) !== 127)
        .join('')
        .slice(0, 300);
    } else if (typeof value === 'number' || typeof value === 'boolean') {
      clean[key] = value;
    }
  }
  return clean;
}

// POST /api/puzzles/log - Stream live position state & user actions directly to backend console
// Development instrumentation only. It echoes client-supplied strings into the server
// log, so in production it accepts and discards the payload rather than writing it.
router.post('/puzzles/log', debugLogLimiter, (req, res) => {
  if (isProduction) {
    return res.json({ success: true, logged: false });
  }
  try {
    const details = sanitizeLogDetails(req.body.details);
    if (details) {
      if (details.type === 'engineStream') {
        logger.info(`[ENGINE STREAM] Received eval for FEN: ${details.fen} | Depth: ${details.depth} | Best Move: ${details.bestMove}`);
        return res.json({ success: true });
      }
      if (details.type === 'uiRender') {
        logger.info(`[UI RENDER] Attempting to draw arrows for FEN: ${details.fen} | Current Board FEN: ${details.currentFen}`);
        return res.json({ success: true });
      }
      if (details.type === 'stateReset') {
        logger.info(`[STATE RESET] Cleared arrows and stopped analysis for FEN: ${details.oldFen} (Token: ${details.token || 1})`);
        return res.json({ success: true });
      }
      if (details.type === 'ignoredEvent') {
        logger.info(`[IGNORED EVENT] Discarding stale evaluation from old FEN: ${details.oldFen} (Current Board FEN: ${details.currentFen})`);
        return res.json({ success: true });
      }

      if (details.type === 'buttonClick') {
        logger.info('\n🔘 [KLIK NA DUGME - BACKEND TERMINAL] ==============================');
        logger.info(`[DUGME]: ${details.button}`);
        if (details.puzzleId) logger.info(`[ID ZAGONETKE]: ${details.puzzleId}`);
        if (details.fen) logger.info(`[FEN POZICIJE]: ${details.fen}`);
        if (details.category) logger.info(`[KATEGORIJA]: ${details.category}`);
        logger.info('============================================================================\n');
        return res.json({ success: true });
      }

      if (details.type === 'branchReset') {
        logger.info('\n🔄 [VARIATION BRANCH RESET - BACKEND TERMINAL] =====================');
        logger.info(`[1] MOD: ${details.mode}`);
        logger.info(`[STATUS]: Prva linija resena! Vracanje na tacku razgranjenja.`);
        logger.info(`[NAREDNI ODGOVOR PROTIVNIKA]: ${details.nextOpponentMove}`);
        logger.info(`[PREOSTALO UNIKATNIH LINIJA]: ${details.remainingBranches}`);
        logger.info('============================================================================\n');
        return res.json({ success: true });
      }

      if (details.type === 'pgnChipClick') {
        logger.info('\n♟️ [KLIK NA PGN POTEZ - BACKEND TERMINAL] ===========================');
        logger.info(`[ODABRANI POTEZ U STABLU]: ${details.moveSan}`);
        logger.info(`[CILJNI FEN]: ${details.targetFen}`);
        logger.info('============================================================================\n');
        return res.json({ success: true });
      }

      if (details.status === 'REJECTED') {
        logger.info('\n[REJECTED] [REJECTED MOVE LOG - BACKEND TERMINAL] ===================');
        logger.info(`[1] MOD: ${details.mode}`);
        logger.info(`[2] FEN PRE POTEZA: ${details.initialFen || details.dynamicFen}`);
        logger.info(`[3] ODIGRANI POTEZ KORISNIKA: [REJECTED] ${details.userMove}`);
        logger.info(`[STATUS]: [REJECTED] ODBIJEN POTEZ (Nije u stablu rešenja)`);
        if (details.validTreeKeys) logger.info(`[DOZVOLJENI POTEZI U TRENUTNOM ČVORU]: ${details.validTreeKeys}`);
        if (details.reason) logger.info(`[RAZLOG]: ${details.reason}`);
        logger.info('============================================================================\n');
        return res.json({ success: true });
      }

      logger.info('\n=================== ♟️ [TRAINING LOG - BACKEND TERMINAL] ===================');
      if (details.mode) logger.info(`[1] MOD: ${details.mode}`);
      if (details.initialFen) logger.info(`[2] UČITANI FEN: ${details.initialFen}`);
      if (details.dynamicFen) logger.info(`[3] DINAMIČKI FEN: ${details.dynamicFen}`);
      if (details.userMove) logger.info(`[4] POTEZ KORISNIKA: ${details.userMove}`);
      if (details.status) logger.info(`[4] STATUS POTEZA: ${details.status === 'ACCEPTED' ? '✅ TAČAN (Prihvaćen u stablu)' : details.status}`);
      if (details.validTreeKeys) logger.info(`[4] DOZVOLJENI POTEZI U TRENUTNOM ČVORU]: ${details.validTreeKeys}`);
      if (details.subBranch) logger.info(`[4] STABLO NASTAVKA: ${details.subBranch}`);
      if (details.fastTrack !== undefined) logger.info(`[4] FAST-TRACK PROVERA: ${details.fastTrack ? '✅ DA (Potez u JSON-u)' : '⚡ NE (Šalje se na Stockfish)'}`);
      if (details.engineMove) logger.info(`[5] ODGOVOR PROTIVNIKA: ${details.engineMove}`);
      if (details.decisionBasis) logger.info(`[5] OSNOV ODABIRA: ${details.decisionBasis}`);
      if (details.depth) logger.info(`[5] DUBINA (DEPTH): ${details.depth}`);
      if (details.eval) logger.info(`[5] EVALUACIJA: ${details.eval}`);
      logger.info('============================================================================\n');
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Log failure' });
  }
});

// POST /api/ai/explain-position - AI Chess Coach powered by Gemini SDK (@google/genai)
// The rate limiter caps bursts per IP; the quota caps what an account may spend
// over a month. They solve different problems, so both apply.
router.post('/ai/explain-position', aiLimiter, authenticateToken, requireQuota(ENT.AI_COMMENTS), async (req, res) => {
  const { fen, evals, userLanguage } = req.body;
  if (!fen) {
    await refundQuota(req);
    return res.status(400).json({ error: 'FEN kod je obavezan parametar.' });
  }

  try {
    const explanation = await geminiService.explainPosition({
      fen,
      evals: evals || {},
      userLanguage: userLanguage || 'sr'
    });

    res.json({ ...explanation, quota: { limit: req.quota.limit, used: req.quota.used } });
  } catch (err) {
    // The user got nothing, so the reserved unit goes back.
    await refundQuota(req);
    logger.error('Error in AI position explanation route:', err);
    res.status(500).json({ error: 'Greška pri generisanju AI objašnjenja.' });
  }
});

// POST /api/ai/generate-move-comment - short move-annotation prose from a
// move's evaluation swing plus its tactical/positional finding diff.
router.post('/ai/generate-move-comment', aiLimiter, authenticateToken, requireQuota(ENT.AI_COMMENTS), async (req, res) => {
  const {
    moveSan, evalBefore, evalAfter, tacticalFindings, positionalFindings,
    previousMove, engineAlternative, nextMoveEval, siblingAlternatives,
    userLanguage
  } = req.body;
  if (!moveSan) {
    await refundQuota(req);
    return res.status(400).json({ error: 'moveSan je obavezan parametar.' });
  }

  try {
    const result = await geminiService.generateMoveComment({
      moveSan,
      evalBefore,
      evalAfter,
      tacticalFindings: tacticalFindings || [],
      positionalFindings: positionalFindings || [],
      previousMove: previousMove || null,
      engineAlternative: engineAlternative || null,
      nextMoveEval: nextMoveEval || null,
      siblingAlternatives: siblingAlternatives || [],
      userLanguage: userLanguage || 'sr'
    });

    res.json({ ...result, quota: { limit: req.quota.limit, used: req.quota.used } });
  } catch (err) {
    await refundQuota(req);
    logger.error('Error in AI move comment route:', err);
    res.status(500).json({ error: 'Greška pri generisanju AI komentara.' });
  }
});

module.exports = router;
