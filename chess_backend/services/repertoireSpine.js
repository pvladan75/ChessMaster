// repertoireSpine.js — a trunk to walk along, not a repertoire.
//
// The build loop asks one position at a time from the root. For anything ten
// moves deep that is thirty questions before it looks like an opening, and the
// owner's first sitting with it ended in "ovako je konfuzno". This gives him a
// trunk in one action: the most played move for both sides, N moves deep.
//
// **Everything it writes is a draft.** `source = 'auto'`, which the drill never
// asks about and the map counts apart. That column exists because of this
// function: the archive seed wrote moves nobody had chosen into the same graph
// as decisions, they became indistinguishable, and the drill asked the student
// to recall them and marked them correct. A spine writes moves the student did
// not choose too — better moves, identical hole — so the difference is stored
// and confirming is an act.
//
// **It never overwrites a decision.** Where a position already holds a move,
// the spine follows it instead of asking the book. That is what makes it safe
// to re-run, and what makes "continue from here" the same operation as "start
// here".
//
// **It stops when the line runs thin, and says so.** Top-1 at ply twenty is
// sometimes forty games; a spine that ran to the requested depth regardless
// would hand back authoritative-looking noise. The floor is a parameter and the
// answer names where it stopped and why — which is the difference between this
// and every silent truncation this codebase has had to fix. Running off the end
// of the book file is a reason of its own, `beyond-book`: the line may be as
// thick as ever there, and "too thin" would send the student looking for a
// sideline that is not the problem.

const { Chess } = require('chess.js');
const { fenKey, addMove, nodeMoves } = require('./repertoireService');
const { rememberReplies } = require('./repertoireDrillService');
const { openingJudge: defaultJudge } = require('./openingJudgeService');

/// How many of the student's own moves a spine may write in one go.
///
/// Two book lookups per move, from a file on this server, so twelve is no
/// waiting at all — the cap is about how much a student is handed unasked, not
/// about cost.
const MAX_SPINE_DEPTH = 12;

/// How many games a move needs before the spine will follow it.
///
/// Not the judge's `MIN_MASTER_GAMES` of 10. That number answers "is this move
/// theory at all"; this one answers "is this still the main line", and a main
/// line with eighty games in it is not one worth writing down unasked.
///
/// **Re-read against the local book on 15.9.2026.** Against the Lichess rating
/// bands, whose counts run to millions, a hundred games never bound, so a spine
/// always ran to its depth. Against 2.57 million master games it does: walking
/// the most played move from nine common roots, the first move under a hundred
/// games came 14 to 32 plies in (Caro-Kann soonest, the start position latest),
/// and four of the nine ran the full 24 plies of `MAX_SPINE_DEPTH`. That is the
/// number doing what it says — stopping where the main line thins — and the
/// answer names where, so it stays.
const MIN_SPINE_GAMES = 100;

/// Advances a position by one UCI move, or answers null if it will not go.
function step(fen, uci) {
  try {
    const board = new Chess(fen);
    const played = board.move({
      from: uci.slice(0, 2),
      to: uci.slice(2, 4),
      promotion: uci.length > 4 ? uci[4] : undefined,
    });
    if (!played) return null;
    return { fen: board.fen(), san: played.san };
  } catch {
    return null;
  }
}

/// Builds the trunk and reports what it did.
///
/// `depth` counts the student's moves, so the line it walks is twice that in
/// plies. Every book it opens is stored in `opening_replies` on the way past —
/// it had to be fetched anyway, and storing it is what makes the drill and the
/// derived queue free afterwards.
async function buildSpine(pool, userId, {
  color, rootFen, depth = 8, minGames = MIN_SPINE_GAMES, judge = defaultJudge,
} = {}) {
  if (color !== 'w' && color !== 'b') {
    throw new RangeError(`Color must be "w" or "b", not "${color}".`);
  }
  fenKey(rootFen);
  const moves = Math.min(Math.max(Number(depth) || 0, 1), MAX_SPINE_DEPTH);
  // `0` means "as low as you allow", not "use the default". `|| default` would
  // have turned an explicit zero into 100 without saying so, which is the
  // silent substitution this codebase keeps having to undo.
  const wanted = Number(minGames);
  const floor = Number.isFinite(wanted)
    ? Math.min(Math.max(wanted, 5), 100000)
    : MIN_SPINE_GAMES;

  let fen = rootFen;
  const path = [];
  let written = 0;
  let followed = 0;
  let stopped = { reason: 'depth', ply: moves * 2 };

  /// The book for one position, stored on the way past: its most played move,
  /// or why there is none to follow.
  const bookAt = async (at) => {
    const answer = await judge.replies(at);
    // A failure to store is not a failure to answer, the same rule the replies
    // route keeps: the caller asked what the book says, and it says it whether
    // or not we managed to write it down.
    try {
      await rememberReplies(pool, { fen: at, moves: answer.all ?? [] });
    } catch {
      // Deliberately swallowed. The spine is still right without the cache.
    }
    return { top: (answer.all ?? [])[0] ?? null, beyondBook: answer.beyondBook === true };
  };

  /// Why a book answer cannot be followed, or null when it can.
  const refusal = (book) => {
    if (book.beyondBook) return { reason: 'beyond-book', ply: path.length };
    if (book.top === null || Number(book.top.games) < floor) {
      return {
        reason: 'thin', ply: path.length, games: book.top ? Number(book.top.games) : 0,
      };
    }
    return null;
  };

  for (let i = 0; i < moves; i += 1) {
    // --- the student's move
    const already = await nodeMoves(pool, userId, { color, fen });
    let mine = already[0] ?? null;
    if (mine === null) {
      const book = await bookAt(fen);
      const refused = refusal(book);
      if (refused !== null) {
        stopped = refused;
        break;
      }
      mine = await addMove(pool, userId, {
        color, fen, uci: book.top.uci, san: book.top.san, source: 'auto',
      });
      written += 1;
    } else {
      // A decision, or a draft from an earlier run. Either way it is already
      // an answer to this position and the spine does not get a second one.
      followed += 1;
    }

    const afterMine = step(fen, mine.uci);
    if (afterMine === null) {
      stopped = { reason: 'illegal', ply: path.length };
      break;
    }
    path.push(afterMine.san);

    // --- the opponent's answer
    const book = await bookAt(afterMine.fen);
    const refused = refusal(book);
    if (refused !== null) {
      stopped = refused;
      break;
    }
    const landed = step(afterMine.fen, book.top.uci);
    if (landed === null) {
      stopped = { reason: 'illegal', ply: path.length };
      break;
    }
    path.push(landed.san);
    fen = landed.fen;
  }

  return {
    written,
    followed,
    path,
    plies: path.length,
    // Where it stopped and why, always — `depth` when it ran the whole way.
    // A spine that quietly came back short would be the oldest bug here.
    stopped,
    minGames: floor,
  };
}

module.exports = {
  buildSpine,
  MAX_SPINE_DEPTH,
  MIN_SPINE_GAMES,
};
