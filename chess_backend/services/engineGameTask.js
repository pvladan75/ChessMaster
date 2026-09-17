// engineGameTask.js
//
// „Play it out": the one task in a homework where the student plays a position
// against the engine until the game ends (docs/PLAN-DOMACI-ZADATAK.md §3,
// phase 2). This file holds its shape and its verdict.
//
// **The server judges.** The app plays the game offline and decides on its own
// board when it is over — it has to, to stop the game and say what happened —
// but the recorded result is judged again here from the moves. Nothing else in
// this app lets the client mark its own work (`customPuzzleJudge`, the lesson
// step routes), and a goal a student's device reports as met would be exactly
// that. The two ends are held to one another by a shared fixture,
// `docs/gates/engine_game_cases.json`, which both suites read.

const { Chess } = require('chess.js');

const GOALS = ['win', 'hold', 'survive'];

/// Every way an assigned game can be over. The first five are the board's, and
/// mirror `GameEnding` in the app (`lib/core/models/drill_outcome.dart`); the
/// last three cannot be read off a board: the trainer's move limit, the number
/// of moves a „survive" goal asked for, and giving up.
const ENDINGS = [
  'checkmate',
  'stalemate',
  'insufficientMaterial',
  'threefoldRepetition',
  'fiftyMoves',
  'moveLimit',
  'moveTarget',
  'resignation',
];

const DEFAULT_PLY_CAP = 200;
const MAX_PLY_CAP = 600;
const MAX_SURVIVE_MOVES = 200;

/// Reads a task as the trainer set it, or says why it is not one.
///
/// Refused rather than defaulted, everywhere it matters: a position that does
/// not load, a goal nobody defined, or „survive" with no number to survive are
/// all a homework that cannot be answered, and a default would hide which.
/// `level` and `thinkSeconds` are the engine's strength, and they travel **on
/// the task** — the student does not choose the opponent the trainer chose.
function parseEngineGameTask(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ok: false, error: 'A game task must be an object.' };
  }
  const { fen, side, goal } = raw;
  if (typeof fen !== 'string' || !fen.trim()) {
    return { ok: false, error: 'A game task needs a position.' };
  }
  let board;
  try {
    board = new Chess(fen);
  } catch (err) {
    return { ok: false, error: `That position is not valid: ${err.message}` };
  }
  if (side !== 'w' && side !== 'b') {
    return { ok: false, error: "The student's side must be 'w' or 'b'." };
  }
  if (!GOALS.includes(goal)) {
    return { ok: false, error: `The goal must be one of ${GOALS.join(', ')}.` };
  }

  let surviveMoves = null;
  if (goal === 'survive') {
    surviveMoves = Number.parseInt(raw.surviveMoves, 10);
    if (!Number.isInteger(surviveMoves) || surviveMoves < 1 || surviveMoves > MAX_SURVIVE_MOVES) {
      return { ok: false, error: 'Surviving needs a number of moves, from 1.' };
    }
  }

  // The engine's strength: the three levels the app already plays at. Left to
  // the app's own default when the trainer did not say.
  const level = raw.level === undefined || raw.level === null ? null : String(raw.level);
  if (level !== null && !['lako', 'srednje', 'tesko'].includes(level)) {
    return { ok: false, error: 'The engine level must be lako, srednje or tesko.' };
  }
  let thinkSeconds = null;
  if (raw.thinkSeconds !== undefined && raw.thinkSeconds !== null) {
    thinkSeconds = Number.parseInt(raw.thinkSeconds, 10);
    if (!Number.isInteger(thinkSeconds) || thinkSeconds < 1 || thinkSeconds > 60) {
      return { ok: false, error: 'The think time must be 1 to 60 seconds.' };
    }
  }

  // A cap so a student cannot be held on one board for ever, and so a game
  // that neither side can finish still ends and still counts.
  let plyCap = DEFAULT_PLY_CAP;
  if (raw.plyCap !== undefined && raw.plyCap !== null) {
    plyCap = Number.parseInt(raw.plyCap, 10);
    if (!Number.isInteger(plyCap) || plyCap < 1 || plyCap > MAX_PLY_CAP) {
      return { ok: false, error: `The move limit must be 1 to ${MAX_PLY_CAP} half-moves.` };
    }
  }

  return {
    ok: true,
    task: {
      fen: board.fen(),
      side,
      goal,
      surviveMoves,
      level,
      thinkSeconds,
      plyCap,
    },
  };
}

/// Replays [moves] from the task's position and says how the game ended and
/// whether the goal was met.
///
/// The order is the same as the app's `verdictFor`: the board first, in a fixed
/// order, then the things a board cannot know — resignation, then the trainer's
/// limit, then the number of moves a „survive" goal asked for. A move the
/// position cannot play is refused, not skipped: `MoveTree.parsePgn` skipping a
/// move in silence is the bug this codebase has paid for most often.
function judgeEngineGame({ task: rawTask, moves, resigned = false }) {
  const parsed = parseEngineGameTask(rawTask);
  if (!parsed.ok) return parsed;
  const task = parsed.task;

  const list = Array.isArray(moves)
    ? moves
    : typeof moves === 'string'
      ? moves.trim().split(/\s+/).filter(Boolean)
      : null;
  if (list === null) return { ok: false, error: 'The moves must be a list.' };
  if (list.length > task.plyCap + 1) {
    return { ok: false, error: 'More moves than the limit allows.' };
  }

  const board = new Chess(task.fen);
  let ownMoves = 0;
  for (const [index, san] of list.entries()) {
    if (typeof san !== 'string') {
      return { ok: false, error: `Move ${index + 1} is not a move.` };
    }
    const mine = board.turn() === task.side;
    try {
      board.move(san);
    } catch (err) {
      return { ok: false, error: `Move ${index + 1} (${san}) cannot be played here.` };
    }
    if (mine) ownMoves++;
  }

  let ending = null;
  if (board.isCheckmate()) ending = 'checkmate';
  else if (board.isStalemate()) ending = 'stalemate';
  else if (board.isInsufficientMaterial()) ending = 'insufficientMaterial';
  else if (board.isThreefoldRepetition()) ending = 'threefoldRepetition';
  else if (board.isDraw()) ending = 'fiftyMoves';
  else if (resigned === true) ending = 'resignation';
  else if (list.length >= task.plyCap) ending = 'moveLimit';
  else if (task.goal === 'survive' && ownMoves >= task.surviveMoves) ending = 'moveTarget';

  let outcome = 'undecided';
  if (ending === 'checkmate') {
    // After a mate the side to move is the mated one — that is what mate is.
    outcome = board.turn() === task.side ? 'lost' : 'won';
  } else if (ending === 'resignation') {
    outcome = 'lost';
  } else if (['stalemate', 'insufficientMaterial', 'threefoldRepetition', 'fiftyMoves', 'moveLimit'].includes(ending)) {
    outcome = 'drawn';
  }

  // „win" is a win; „hold" is anything that is not a loss, once the game is
  // over; „survive" is not losing, either to the end of the game or for as
  // many of the student's own moves as the trainer asked.
  let goalMet = false;
  if (ending !== null) {
    if (task.goal === 'win') goalMet = outcome === 'won';
    else if (task.goal === 'hold') goalMet = outcome !== 'lost';
    else if (task.goal === 'survive') goalMet = outcome !== 'lost';
  }

  return {
    ok: true,
    task,
    ending,
    outcome,
    goalMet,
    ownMoves,
    plies: list.length,
    fen: board.fen(),
    moves: list,
  };
}

module.exports = {
  GOALS,
  ENDINGS,
  DEFAULT_PLY_CAP,
  MAX_PLY_CAP,
  parseEngineGameTask,
  judgeEngineGame,
};
