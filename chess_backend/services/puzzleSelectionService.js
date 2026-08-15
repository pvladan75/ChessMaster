// puzzleSelectionService.js
// Picks the next puzzle for a user, and decodes what a Lichess puzzle means.
//
// The selection logic is pure and exported separately from the queries, because
// "which theme is this student weakest at" is the part worth testing and the
// part most likely to be wrong in a way nobody notices.

const logger = require('./logger');

/// Themes that describe a tactical idea, and are therefore worth tracking a
/// separate rating for. Lichess also tags outcome ("crushing", "advantage"),
/// length ("short", "veryLong") and provenance ("master", "superGM"); none of
/// those describe a skill, so training against them would produce a rating that
/// measures nothing.
const MOTIF_THEMES = [
  'advancedPawn', 'anastasiaMate', 'arabianMate', 'attackingF2F7', 'attraction',
  'backRankMate', 'bishopEndgame', 'bodenMate', 'capturingDefender', 'clearance',
  'defensiveMove', 'deflection', 'discoveredAttack', 'doubleBishopMate', 'doubleCheck',
  'dovetailMate', 'enPassant', 'exposedKing', 'fork', 'hangingPiece',
  'hookMate', 'interference', 'intermezzo', 'kingsideAttack', 'knightEndgame',
  'pin', 'promotion', 'queensideAttack', 'quietMove', 'sacrifice',
  'skewer', 'smotheredMate', 'trappedPiece', 'underPromotion', 'xRayAttack',
  'zugzwang',
];

/// Game-phase tags — useful as a filter ("only endgames"), not as a skill.
const PHASE_THEMES = ['opening', 'middlegame', 'endgame', 'rookEndgame', 'pawnEndgame', 'queenEndgame'];

/// Forced-mate tags, kept apart because they form their own difficulty ladder.
const MATE_THEMES = ['mateIn1', 'mateIn2', 'mateIn3', 'mateIn4', 'mateIn5'];

const TRAINABLE_THEMES = [...MOTIF_THEMES, ...MATE_THEMES];
const TRAINABLE_SET = new Set(TRAINABLE_THEMES);

/// How many attempts a theme needs before its rating is treated as a measurement
/// rather than noise. Below this, one unlucky puzzle would brand a theme as the
/// user's weakness for a long time.
const MIN_ATTEMPTS_FOR_WEAKNESS = 4;

/// How often to serve a theme the user has never tried instead of their known
/// weakest. Without this the selector locks onto the first theme that goes badly
/// and never discovers the others.
const EXPLORATION_RATE = 0.25;

/// Splits a Lichess move line into the parts a client needs.
///
/// The stored FEN is the position *before* the opponent's mistake. `moves[0]` is
/// that mistake — playing it produces the position the user is asked to solve.
/// From there the user plays the even indices of the remainder and the opponent
/// answers with the odd ones.
function splitSolution(movesText) {
  const moves = (movesText || '').trim().split(/\s+/).filter(Boolean);
  if (moves.length < 2) {
    return { setupMove: null, solution: [], userMoves: [], opponentMoves: [] };
  }

  const [setupMove, ...solution] = moves;
  return {
    setupMove,
    solution,
    userMoves: solution.filter((_, i) => i % 2 === 0),
    opponentMoves: solution.filter((_, i) => i % 2 === 1),
  };
}

/// Keeps only the themes worth showing or rating.
function trainableThemes(themes) {
  return (themes || []).filter((theme) => TRAINABLE_SET.has(theme));
}

/// Chooses which theme to train next.
///
/// Prefers the lowest-rated theme the user has attempted enough times to have a
/// real measurement; otherwise explores something untried. Returns null when
/// there is nothing to go on, which the caller reads as "just use the overall
/// rating and any theme".
function pickTargetTheme(themeRatings = {}, themeAttempts = {}, { random = Math.random } = {}) {
  const measured = TRAINABLE_THEMES.filter(
    (theme) => (themeAttempts[theme] || 0) >= MIN_ATTEMPTS_FOR_WEAKNESS && themeRatings[theme] !== undefined
  );

  const untried = TRAINABLE_THEMES.filter((theme) => !(themeAttempts[theme] > 0));

  // Explore when there is nothing measured yet, or on a deliberate fraction of
  // requests so the picture keeps filling in.
  const shouldExplore = measured.length === 0 || (untried.length > 0 && random() < EXPLORATION_RATE);
  if (shouldExplore && untried.length > 0) {
    return untried[Math.floor(random() * untried.length)];
  }
  if (measured.length === 0) return null;

  return measured.reduce((weakest, theme) =>
    themeRatings[theme] < themeRatings[weakest] ? theme : weakest
  );
}

/// The rating window to search in.
///
/// Slightly below the user's rating rather than centred on it: a puzzle set is a
/// training tool, and a stream of failures teaches less than a stream that is
/// mostly solvable. Widens as attempts fail to find anything.
function ratingBand(targetRating, attempt = 0) {
  const width = 100 + attempt * 150;
  const centre = targetRating - 25;
  return { min: Math.max(400, centre - width), max: centre + width };
}

/// Reads the user's rating picture. Falls back to an unrated 1500 for a user who
/// has never solved anything.
async function getUserRatingProfile(pool, userId) {
  const [ratingRes, attemptRes] = await Promise.all([
    pool.query(
      'SELECT overall_rating, theme_ratings FROM user_puzzle_ratings WHERE user_id = $1',
      [userId]
    ),
    pool.query(
      `SELECT theme, COUNT(*)::int AS attempts
       FROM user_puzzle_attempts, UNNEST(themes) AS theme
       WHERE user_id = $1
       GROUP BY theme`,
      [userId]
    ),
  ]);

  const themeAttempts = {};
  for (const row of attemptRes.rows) {
    themeAttempts[row.theme] = row.attempts;
  }

  return {
    overallRating: ratingRes.rows[0]?.overall_rating || 1500,
    themeRatings: ratingRes.rows[0]?.theme_ratings || {},
    themeAttempts,
  };
}

/// Finds a puzzle matching the user's level, preferring an unseen one.
///
/// Widens the rating band rather than giving up, and only then drops the theme
/// constraint — a slightly-off-level puzzle on the right motif is more useful
/// than a perfectly-rated one on a motif the user is already good at.
async function selectAdaptivePuzzle(pool, userId, { theme = null, phase = null, excludeId = null } = {}) {
  const profile = await getUserRatingProfile(pool, userId);
  const targetTheme = theme || pickTargetTheme(profile.themeRatings, profile.themeAttempts);
  const targetRating = targetTheme
    ? profile.themeRatings[targetTheme] || profile.overallRating
    : profile.overallRating;

  for (let attempt = 0; attempt < 3; attempt++) {
    const band = ratingBand(targetRating, attempt);
    // The last pass drops the theme so the user always gets *something*.
    const useTheme = attempt < 2 ? targetTheme : null;

    const conditions = ['p.rating BETWEEN $1 AND $2'];
    const params = [band.min, band.max];

    if (useTheme) {
      params.push([useTheme]);
      conditions.push(`p.themes @> $${params.length}::varchar[]`);
    }
    if (phase) {
      params.push([phase]);
      conditions.push(`p.themes @> $${params.length}::varchar[]`);
    }
    if (excludeId) {
      params.push(excludeId);
      conditions.push(`p.puzzle_id <> $${params.length}`);
    }
    params.push(userId);
    const userParam = `$${params.length}`;

    const result = await pool.query(
      `SELECT p.* FROM lichess_puzzles p
       WHERE ${conditions.join(' AND ')}
         AND NOT EXISTS (
           SELECT 1 FROM user_puzzle_attempts a
           WHERE a.user_id = ${userParam} AND a.puzzle_id = p.puzzle_id
         )
       ORDER BY RANDOM()
       LIMIT 1`,
      params
    );

    if (result.rows.length > 0) {
      return { puzzle: result.rows[0], targetTheme: useTheme, targetRating, band };
    }
  }

  logger.warn(`No unseen puzzle found for user ${userId} around rating ${targetRating}.`);
  return null;
}

/// Shapes a database row into the payload the app consumes.
function toClientPuzzle(row) {
  const { setupMove, solution, userMoves } = splitSolution(row.moves);
  return {
    puzzle_id: row.puzzle_id,
    source: 'lichess',
    // Position before the opponent's mistake; the client plays setupMove to
    // reach the position being asked about.
    fen: row.fen,
    setup_move: setupMove,
    solution,
    user_moves: userMoves,
    rating: row.rating,
    popularity: row.popularity,
    nb_plays: row.nb_plays,
    themes: row.themes || [],
    trainable_themes: trainableThemes(row.themes),
    game_url: row.game_url,
    opening_tags: row.opening_tags || [],
  };
}

module.exports = {
  MOTIF_THEMES,
  PHASE_THEMES,
  MATE_THEMES,
  TRAINABLE_THEMES,
  MIN_ATTEMPTS_FOR_WEAKNESS,
  EXPLORATION_RATE,
  splitSolution,
  trainableThemes,
  pickTargetTheme,
  ratingBand,
  getUserRatingProfile,
  selectAdaptivePuzzle,
  toClientPuzzle,
};
