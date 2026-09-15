// openingJudgeService.js — one move in the opening, judged: theory, playable,
// or a mistake.
//
// This is the piece the repertoire trainer is built on, and it is useful on its
// own long before there is a repertoire: the analysis board can ask it about
// any move a child just played.
//
// **The verdict is computed here and not in the app.** Not for tidiness — for
// reproducibility. An engine running on a phone answers from whatever depth it
// reached before the user moved on, so the same move could be "playable" today
// and "a mistake" tomorrow on a slower device. That is the failure this
// codebase keeps meeting: a result that looks computed and is really a guess.
// Lichess's cloud evaluation is one fixed number per position, the same for
// everyone, cached upstream and here.
//
// **Two questions, and only one of them leaves this server.** What masters
// played comes from the local opening book (`services/openingBook.js`), and
// what the position is worth from Lichess's cloud evaluation, which answers
// without a token (probed 15.9.2026: 200, depth 60). Until
// `docs/PLAN-OTVARANJA-LOKALNO.md` both books were Lichess explorers, and the
// caller had to bring a Lichess token of their own for all four questions —
// which in practice meant nobody could build a repertoire. There is no token
// anywhere now, and no rating band: one book, 2200+, because a student learns
// the sound move whatever their own rating.
//
// **What the cache holds.** Positions, not people. An evaluation of a position
// is the same fact whoever asked for it, so a line walked by one child is
// nearly free for the next — and the "after" position of one move is the
// "before" of the next, which is most of what walking a variation costs.

const { Chess } = require('chess.js');
const {
  createPacer, MIN_REQUEST_GAP_MS, RATE_LIMIT_COOLDOWN_MS,
} = require('./lichessPacing');
const { sharedOpeningBook } = require('./openingBook');

const DEFAULT_CLOUD_EVAL_URL = process.env.LICHESS_CLOUD_EVAL_URL
  || 'https://lichess.org/api/cloud-eval';

/// How many master games make a move "theory" rather than "someone once tried
/// it". Ten is low on purpose: a sideline played ten times by masters is a real
/// line a child may meet, and the panel prints the count beside the verdict so
/// the reader can weigh it themselves.
///
/// **Re-read against the local book on 15.9.2026 rather than carried over.**
/// It was set against Lichess's masters explorer. Every move of the thirteen
/// harness games that Lichess's cached answers name was counted in the 2200+
/// file as well: the median ratio per move is 0.99 and per position 1.00, and
/// at ten the local book keeps 783 of the 795 moves Lichess called theory and
/// adds 23 of 376 it did not — every one of them within a few games of the
/// line (7–9 against 10–18). Fifteen would drop 65 of Lichess's. The same
/// number means the same thing, so it stays.
const MIN_MASTER_GAMES = 10;

/// How much the move may cost, in centipawns, and still be playable.
///
/// Loss and not absolute evaluation, which is the one change from the original
/// sketch: a gambit line standing at -0.3 before the move is not a mistake, and
/// judging by absolute score would call every gambit one. What is being asked
/// is "did this move throw something away", and that is a difference.
const MAX_LOSS_CP = 40;

/// ...and a floor under it, because a move that loses nothing in a position
/// that is already lost is not playable in any useful sense. Both conditions
/// have to hold.
const MIN_EVAL_CP = -100;

/// How much of what the student will actually meet has to be covered before a
/// position counts as done, and how many replies that may take.
///
/// "The main replies" is not a number, and without one the work has no end:
/// branching is three to eight moves a level, so every level multiplies. The
/// share is what makes coverage measurable later - a repertoire is not "deep",
/// it answers 84% of what this opponent plays - and the cap is what keeps one
/// position from becoming an afternoon. What falls outside is not thrown away:
/// it is counted and named, because an unmet reply is the thing the drill will
/// one day spring on the student.
const COVERAGE_SHARE = 0.8;
const MAX_REPLIES = 4;
const MIN_REPLIES = 1;

/// How many replies are kept for later, past the ones the student prepares.
/// Twelve is well past the tail of any real opening position and still small
/// enough that a position's whole book is one short row set.
const KEEP_REPLIES = 12;

/// A mate score as centipawns, so one comparison covers both kinds of answer.
/// The distance is subtracted so mate in 2 outranks mate in 9, and the real
/// mate figure is passed on untouched for the panel to print.
const MATE_CP = 100000;

class OpeningJudgeUnavailable extends Error {
  /// `reason` is what the log and the app key off: 'rate-limited' (Lichess
  /// asked this server to wait) or 'network' (it did not answer, or answered
  /// with something that is not an evaluation). The book's own failures are
  /// `OpeningBookUnavailable`, which the routes pass on with their reason.
  constructor(message, { reason = 'network', status = 503, cause } = {}) {
    super(message);
    this.name = 'OpeningJudgeUnavailable';
    this.reason = reason;
    this.status = status;
    this.cause = cause;
  }
}

/// Lichess reports cloud evaluations from White's point of view - `mate: -8`
/// with Black to move means White is being mated in 8, not Black. Verified
/// against the live API rather than assumed, because the sign is the one thing
/// here that cannot be caught by reading: every verdict would simply be the
/// wrong one, consistently, and only for one colour.
function whiteRelativeCp(pv) {
  if (pv == null) return null;
  if (typeof pv.cp === 'number') return pv.cp;
  if (typeof pv.mate === 'number') {
    if (pv.mate === 0) return 0;
    const distance = Math.abs(pv.mate);
    const magnitude = MATE_CP - distance;
    return pv.mate > 0 ? magnitude : -magnitude;
  }
  return null;
}

/// Lichess writes castling as "king takes rook" — `e1h1`, `e8a8` — the Chess960
/// convention, and its cloud evaluation's lines are written that way
/// (verified live on 25.8.2026: `d2d3 d7d6 e1h1 a7a5 f1e1 e8h8 …`). This app's
/// board, like chess.js, writes `e1g1`. Read literally, the castling move does
/// not play, and a line stops at it without a word: "better was O-O" became
/// "better was nothing", and a punishment stopped one move short.
const KING_TAKES_ROOK = {
  e1h1: 'e1g1', e1a1: 'e1c1', e8h8: 'e8g8', e8a8: 'e8c8',
};

/// The first `limit` moves of a UCI line, in the notation a child reads.
///
/// Silence on anything it cannot replay: a line that does not fit the position
/// means the two came from different places, and half a line printed under a
/// verdict would be read as advice.
function sanLine(fen, uciMoves, limit) {
  if (!Array.isArray(uciMoves) || uciMoves.length === 0) return [];
  let board;
  try {
    board = new Chess(fen);
  } catch {
    return [];
  }
  const line = [];
  for (const written of uciMoves.slice(0, limit)) {
    // Only where a king stands on the square it castles from: `e1h1` is also
    // a rook or queen sliding along the first rank.
    const castles = KING_TAKES_ROOK[written]
      && board.get(written.slice(0, 2))?.type === 'k';
    const uci = castles ? KING_TAKES_ROOK[written] : written;
    let played;
    try {
      played = board.move({
        from: uci.slice(0, 2),
        to: uci.slice(2, 4),
        promotion: uci.length > 4 ? uci[4] : undefined,
      });
    } catch {
      return line;
    }
    if (!played) return line;
    line.push(played.san);
  }
  return line;
}

/**
 * Build a judge.
 *
 * `book` is injected so tests hand over a table instead of a file, and
 * `fetchImpl` so they never touch the network.
 */
function createOpeningJudge({
  book = null,
  fetchImpl = globalThis.fetch,
  cloudEvalUrl = DEFAULT_CLOUD_EVAL_URL,
  cacheLimit = 4000,
  timeoutMs = 8000,
  minGapMs = MIN_REQUEST_GAP_MS,
  cooldownMs = RATE_LIMIT_COOLDOWN_MS,
  // Injected so the tests can spend a minute without waiting one.
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  // Asked for on the first question rather than at construction, so that
  // requiring this module never decides which file the server reads.
  const readBook = () => book ?? sharedOpeningBook();

  // Two caches rather than one: a verdict is about a move, an evaluation about
  // a position. The book is not cached here — it is a file on this disk, and a
  // copy of it in memory would be a second place for a number to go stale.
  const verdicts = new Map();
  const evals = new Map();
  const inFlight = new Map();
  let requests = 0;
  let hits = 0;

  // Judging one move is two evaluations, so without a queue it is two at once -
  // and the rule about how fast this server may ask Lichess lives in one place.
  const pacer = createPacer({ minGapMs, cooldownMs, now, sleep });

  function remember(cache, key, value) {
    cache.set(key, value);
    while (cache.size > cacheLimit) {
      cache.delete(cache.keys().next().value);
    }
  }

  async function getJson(url, { allowMissing = false } = {}) {
    // Serving the block ourselves. Asking during it is what lengthens it.
    const blockedFor = pacer.blockedForMs();
    if (blockedFor > 0) {
      const left = Math.ceil(blockedFor / 1000);
      throw new OpeningJudgeUnavailable(
        `Lichess is temporarily not accepting requests. Try again in ${left} s.`,
        { reason: 'rate-limited', status: 503 }
      );
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const headers = { 'User-Agent': 'chess-coach opening judge' };
      const res = await pacer.spaced(
        () => fetchImpl(url, { signal: controller.signal, headers })
      );

      if (res.status === 429) {
        pacer.block();
        throw new OpeningJudgeUnavailable(
          'Rate limit exceeded for Lichess requests. Try again in a minute.',
          { reason: 'rate-limited', status: 503 }
        );
      }
      // A position the cloud has never evaluated answers 404, and that is an
      // answer rather than a fault: it means "not known here", and the judge
      // says so instead of inventing a verdict.
      if (res.status === 404 && allowMissing) return null;
      if (!res.ok) {
        throw new OpeningJudgeUnavailable(
          `Lichess responded with ${res.status}.`, { reason: 'network' }
        );
      }
      requests += 1;
      return await res.json();
    } catch (err) {
      if (err instanceof OpeningJudgeUnavailable) throw err;
      throw new OpeningJudgeUnavailable(
        'Lichess is currently unavailable.', { reason: 'network', cause: err }
      );
    } finally {
      clearTimeout(timer);
    }
  }

  /// One question, asked once however many callers want it at the same moment.
  function once(key, cache, produce) {
    if (cache.has(key)) {
      hits += 1;
      return Promise.resolve(cache.get(key));
    }
    if (inFlight.has(key)) return inFlight.get(key);

    const pending = produce()
      .then((value) => {
        remember(cache, key, value);
        return value;
      })
      .finally(() => inFlight.delete(key));
    inFlight.set(key, pending);
    return pending;
  }

  /// What the book says about this position: every move it lists with its
  /// counts, the number of games that reached the position, and whether the
  /// position lies past the depth the file was built to.
  ///
  /// `total` is the position's own count, which in a pruned file is more than
  /// its listed moves add up to — the games in moves played only once. Shares
  /// are taken of that, so a reply list never claims to cover games it cannot
  /// see.
  ///
  /// Past the depth the file was built to, nothing is listed even where a row
  /// happens to exist — a count that arrived by transposition from a shallower
  /// ply is not the book speaking about this position, and a verdict or a
  /// reply list built on it would say more than the file can.
  function bookAt(fen) {
    const here = readBook().answer(fen);
    if (here.beyondBook === true) {
      return { total: 0, moves: new Map(), beyondBook: true };
    }
    const moves = new Map();
    for (const m of here.moves) {
      moves.set(m.uci, {
        uci: m.uci,
        san: m.san,
        games: m.white + m.draws + m.black,
        // The outcome split travels with the count, because "how often" and
        // "how well" are different questions and the second is the one a
        // student is really asking when they compare two candidate moves.
        white: m.white,
        draws: m.draws,
        black: m.black,
      });
    }
    return {
      total: here.white + here.draws + here.black,
      moves,
      beyondBook: false,
    };
  }

  /// Lichess's evaluation of one position, White-relative, or null when the
  /// cloud has never seen it.
  function evalAt(fen) {
    return once(`eval|${fen}`, evals, async () => {
      const params = new URLSearchParams({ fen, multiPv: '1' });
      const data = await getJson(`${cloudEvalUrl}?${params}`, { allowMissing: true });
      const pv = data?.pvs?.[0];
      const cp = whiteRelativeCp(pv);
      if (cp === null) return null;
      return {
        cp: typeof pv.cp === 'number' ? pv.cp : null,
        mate: typeof pv.mate === 'number' ? pv.mate : null,
        whiteCp: cp,
        depth: data.depth ?? null,
        // The line Lichess would play on. Kept because it is what turns a
        // verdict into a lesson: what to play instead, and how the move that
        // was played gets punished. It arrives with the evaluation, so neither
        // costs a request of its own.
        pvUci: typeof pv.moves === 'string' && pv.moves.trim() !== ''
          ? pv.moves.trim().split(/\s+/)
          : [],
      };
    });
  }

  /**
   * Judge one move played from `fen`.
   *
   * `move` may be SAN or UCI; whatever arrives, both forms come back, because
   * the app has one and the book is keyed by the other.
   */
  async function judge(fen, move) {
    if (typeof fen !== 'string' || fen.trim() === '') {
      throw new RangeError('Position (FEN) was not provided.');
    }
    if (typeof move !== 'string' || move.trim() === '') {
      throw new RangeError('Move was not provided.');
    }

    let board;
    try {
      board = new Chess(fen);
    } catch {
      throw new RangeError('Position (FEN) is invalid.');
    }

    let played;
    try {
      played = board.move(move.trim(), { strict: false });
    } catch {
      played = null;
    }
    if (!played) {
      throw new RangeError(`Move "${move}" is not possible in that position.`);
    }

    const uci = `${played.from}${played.to}${played.promotion ?? ''}`;
    const moverIsWhite = played.color === 'w';
    const fenAfter = board.fen();

    const key = `${fen}|${uci}`;
    if (verdicts.has(key)) {
      hits += 1;
      return verdicts.get(key);
    }

    const base = { fen, fenAfter, uci, san: played.san, moverIsWhite };

    const masters = bookAt(fen);
    const mastersStat = {
      games: masters.moves.get(uci)?.games ?? 0,
      total: masters.total,
      // Past the file's last ply the book has nothing to say — not "nobody
      // played this". The engine still judges; the panel can say which of the
      // two silences it is standing in.
      beyondBook: masters.beyondBook,
    };

    if (mastersStat.games >= MIN_MASTER_GAMES) {
      // The book outranks the engine here on purpose. A move masters keep
      // playing is theory even when the cloud has it a tenth of a pawn worse
      // than the top choice, and telling a child otherwise teaches them to
      // distrust the opening they were given.
      const value = { ...base, verdict: 'theory', masters: mastersStat, eval: null };
      remember(verdicts, key, value);
      return value;
    }

    const [before, after] = await Promise.all([evalAt(fen), evalAt(fenAfter)]);

    if (!before || !after) {
      // Loud, and its own verdict. Calling an unjudged move a mistake is the
      // exact shape of failure this project keeps paying for.
      const value = {
        ...base, verdict: 'unknown', reason: 'no-eval', masters: mastersStat, eval: null,
      };
      remember(verdicts, key, value);
      return value;
    }

    const sign = moverIsWhite ? 1 : -1;
    const beforeCp = before.whiteCp * sign;
    const afterCp = after.whiteCp * sign;
    const lossCp = Math.round(beforeCp - afterCp);

    const playable = lossCp <= MAX_LOSS_CP && afterCp >= MIN_EVAL_CP;

    // Only where it teaches something. Under a move that gave nothing away,
    // "better was..." is noise; under one that did, it is the whole point -
    // and so is seeing the punishment played rather than being told a number.
    const bestUci = before.pvUci?.[0];
    const better = !playable && bestUci && bestUci !== uci
      ? sanLine(fen, [bestUci], 1)[0] ?? null
      : null;
    const punishment = playable ? [] : sanLine(fenAfter, after.pvUci, 3);

    const value = {
      ...base,
      verdict: playable ? 'playable' : 'mistake',
      masters: mastersStat,
      eval: {
        // Mover-relative, because every sentence the panel writes is about the
        // person who played the move. White-relative numbers are kept out of
        // the payload entirely rather than travelling beside them, so nothing
        // downstream has to remember which is which.
        beforeCp: Math.round(beforeCp),
        afterCp: Math.round(afterCp),
        lossCp,
        mateBefore: before.mate === null ? null : before.mate * sign,
        mateAfter: after.mate === null ? null : after.mate * sign,
        depth: after.depth,
        better,
        punishment,
      },
    };
    remember(verdicts, key, value);
    return value;
  }

  /**
   * The opponent's replies worth answering in this position, and what is left
   * over.
   *
   * Lives here rather than in the repertoire service because it is the other
   * half of the same build loop and reads the same book the verdict does.
   */
  async function replies(fen) {
    if (typeof fen !== 'string' || fen.trim() === '') {
      throw new RangeError('Position (FEN) was not provided.');
    }

    const book = bookAt(fen);
    const all = [...book.moves.values()].sort((a, b) => b.games - a.games);
    const { total } = book;

    const covered = [];
    let running = 0;
    for (const move of all) {
      const enough = total > 0 && running / total >= COVERAGE_SHARE;
      if (covered.length >= MIN_REPLIES && (enough || covered.length >= MAX_REPLIES)) {
        break;
      }
      covered.push({
        uci: move.uci,
        san: move.san,
        games: move.games,
        share: total > 0 ? move.games / total : 0,
        white: move.white,
        draws: move.draws,
        black: move.black,
      });
      running += move.games;
    }

    const tailMoves = all.length - covered.length;
    const tailGames = total - running;
    const isCovered = new Set(covered.map((m) => m.uci));
    return {
      fen,
      total,
      // A position past the file's depth answers with no replies, and says it
      // is that rather than an opening nobody plays.
      beyondBook: book.beyondBook,
      replies: covered,
      // Everything the book returned, not only what was covered, so whoever
      // stores this can keep the moves the student is *not* prepared for. A
      // drill that only ever plays the four prepared answers rehearses a
      // repertoire that has never been surprised.
      all: all.slice(0, KEEP_REPLIES).map((move) => ({
        uci: move.uci,
        san: move.san,
        games: move.games,
        share: total > 0 ? move.games / total : 0,
        white: move.white,
        draws: move.draws,
        black: move.black,
        covered: isCovered.has(move.uci),
      })),
      coveredShare: total > 0 ? running / total : 0,
      // Named and counted rather than dropped: this is exactly the set of moves
      // the drill will one day play and the student will not have an answer to.
      // In a pruned book the games include the moves played only once, which
      // are counted here and listed nowhere.
      tail: {
        moves: tailMoves,
        games: tailGames,
        share: total > 0 ? tailGames / total : 0,
      },
    };
  }

  return {
    judge,
    replies,
    stats: () => ({
      verdicts: verdicts.size,
      evals: evals.size,
      requests,
      hits,
      // Seconds left of a Lichess block, so the log can say why the panel has
      // gone quiet instead of leaving it to be guessed.
      blockedForMs: pacer.blockedForMs(),
    }),
    clear: () => {
      verdicts.clear(); evals.clear();
      requests = 0; hits = 0; pacer.reset();
    },
  };
}

module.exports = {
  createOpeningJudge,
  sanLine,
  whiteRelativeCp,
  OpeningJudgeUnavailable,
  MIN_MASTER_GAMES,
  COVERAGE_SHARE,
  MAX_REPLIES,
  MIN_REPLIES,
  KEEP_REPLIES,
  MIN_REQUEST_GAP_MS,
  RATE_LIMIT_COOLDOWN_MS,
  MAX_LOSS_CP,
  MIN_EVAL_CP,
  openingJudge: createOpeningJudge(),
};
