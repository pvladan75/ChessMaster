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
// **Whose allowance is spent.** The Explorer counts requests per token, and the
// server's own token is a single throat for every child in the app. Judging
// asks up to four upstream questions per move, so it is deliberately not on
// that token: the caller must send their own, and someone without one is told
// so rather than quietly served from the shared allowance. The token arrives in
// a header, is used, and is never stored or logged.
//
// **What the cache holds.** Positions, not people. An evaluation of a position
// is the same fact whoever asked for it, so a line walked by one child is
// nearly free for the next — and the "after" position of one move is the
// "before" of the next, which is most of what walking a variation costs.

const { Chess } = require('chess.js');
const {
  createPacer, MIN_REQUEST_GAP_MS, RATE_LIMIT_COOLDOWN_MS,
} = require('./lichessPacing');
const { withStandardUci } = require('./openingMoveNotation');

const DEFAULT_MASTERS_URL = process.env.LICHESS_MASTERS_URL
  || 'https://explorer.lichess.ovh/masters';
const DEFAULT_LICHESS_URL = process.env.LICHESS_EXPLORER_URL
  || 'https://explorer.lichess.ovh/lichess';
const DEFAULT_CLOUD_EVAL_URL = process.env.LICHESS_CLOUD_EVAL_URL
  || 'https://lichess.org/api/cloud-eval';

/// The same buckets the Explorer knows, and the same reason they are spelled
/// out: a request carries the list of buckets it wants, not a floor.
const RATING_BUCKETS = [0, 1000, 1200, 1400, 1600, 1800, 2000, 2200, 2500];

/// How many master games make a move "theory" rather than "someone once tried
/// it". Ten is low on purpose: a sideline played ten times by masters is a real
/// line a child may meet, and the panel prints the count beside the verdict so
/// the reader can weigh it themselves.
const MIN_MASTER_GAMES = 10;

/// How many games in the chosen rating band make a move worth calling common in
/// practice. Only a label - the verdict itself comes from the evaluation.
const MIN_BAND_GAMES = 5;

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
  /// `reason` is what the log and the app key off: 'no-token' (the caller has
  /// no Lichess token of their own), 'unauthorized' (Lichess refused it),
  /// 'rate-limited', or 'network'. Four different jobs for whoever reads the
  /// log, so they never collapse into one message.
  constructor(message, { reason = 'network', status = 503, cause } = {}) {
    super(message);
    this.name = 'OpeningJudgeUnavailable';
    this.reason = reason;
    this.status = status;
    this.cause = cause;
  }
}

function ratingBucketsFrom(minRating) {
  if (minRating === null || minRating === undefined || minRating === '') return null;
  const min = Number(minRating);
  if (!RATING_BUCKETS.includes(min)) {
    throw new RangeError(
      `Nepoznat prag rejtinga „${minRating}". Dozvoljeni su: ${RATING_BUCKETS.join(', ')}.`
    );
  }
  return RATING_BUCKETS.filter((b) => b >= min);
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
  for (const uci of uciMoves.slice(0, limit)) {
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
 * `fetchImpl` is injected so tests never touch the network; the three URLs so a
 * test can tell the two Explorers apart by what was asked.
 */
function createOpeningJudge({
  fetchImpl = globalThis.fetch,
  mastersUrl = DEFAULT_MASTERS_URL,
  lichessUrl = DEFAULT_LICHESS_URL,
  cloudEvalUrl = DEFAULT_CLOUD_EVAL_URL,
  cacheLimit = 4000,
  timeoutMs = 8000,
  minGapMs = MIN_REQUEST_GAP_MS,
  cooldownMs = RATE_LIMIT_COOLDOWN_MS,
  // Injected so the tests can spend a minute without waiting one.
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  // Three caches rather than one, because they are three different facts with
  // three different keys: a verdict is about a move, an evaluation and an
  // Explorer answer are about a position.
  const verdicts = new Map();
  const evals = new Map();
  const books = new Map();
  const inFlight = new Map();
  let requests = 0;
  let hits = 0;

  // Judging one move is four requests, so without a queue it is four at once -
  // and the rule about how fast this server may ask lives in one place, shared
  // with the opening book.
  const pacer = createPacer({ minGapMs, cooldownMs, now, sleep });

  function remember(cache, key, value) {
    cache.set(key, value);
    while (cache.size > cacheLimit) {
      cache.delete(cache.keys().next().value);
    }
  }

  async function getJson(url, { token, allowMissing = false } = {}) {
    // Serving the block ourselves. Asking during it is what lengthens it.
    const blockedFor = pacer.blockedForMs();
    if (blockedFor > 0) {
      const left = Math.ceil(blockedFor / 1000);
      throw new OpeningJudgeUnavailable(
        `Lichess privremeno ne prima upite. Probajte za ${left} s.`,
        { reason: 'rate-limited', status: 503 }
      );
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const headers = { 'User-Agent': 'chess-coach opening judge' };
      if (token) headers.Authorization = `Bearer ${token}`;
      const res = await pacer.spaced(
        () => fetchImpl(url, { signal: controller.signal, headers })
      );

      if (res.status === 401 || res.status === 403) {
        throw new OpeningJudgeUnavailable(
          'Lichess je odbio vaš token.', { reason: 'unauthorized', status: 502 }
        );
      }
      if (res.status === 429) {
        pacer.block();
        throw new OpeningJudgeUnavailable(
          'Potrošen je dozvoljeni broj upita ka Lichessu. Probajte za minut.',
          { reason: 'rate-limited', status: 503 }
        );
      }
      // A position the cloud has never evaluated answers 404, and that is an
      // answer rather than a fault: it means "not known here", and the judge
      // says so instead of inventing a verdict.
      if (res.status === 404 && allowMissing) return null;
      if (!res.ok) {
        throw new OpeningJudgeUnavailable(
          `Lichess je odgovorio ${res.status}.`, { reason: 'network' }
        );
      }
      requests += 1;
      return await res.json();
    } catch (err) {
      if (err instanceof OpeningJudgeUnavailable) throw err;
      throw new OpeningJudgeUnavailable(
        'Lichess trenutno nije dostupan.', { reason: 'network', cause: err }
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

  /// What the given book says about this position, as a map from UCI to the
  /// game counts. Only what the verdict needs; the panel already has the full
  /// Explorer through its own route.
  function bookAt(fen, { source, buckets, token }) {
    const key = `${source}|${fen}|${buckets ? buckets[0] : 'all'}`;
    return once(key, books, async () => {
      const params = new URLSearchParams({
        fen, moves: '30', topGames: '0', recentGames: '0',
      });
      if (buckets) params.set('ratings', buckets.join(','));
      const base = source === 'masters' ? mastersUrl : lichessUrl;
      const data = await getJson(`${base}?${params}`, { token });

      // Rewritten into our own notation first. Lichess castles "king takes
      // rook" (`e1h1`), this app's board does not, and a castling move left in
      // their notation is one nothing downstream can play — silently.
      const raw = (data?.moves || []).map((m) => {
        const white = m.white ?? 0;
        const draws = m.draws ?? 0;
        const black = m.black ?? 0;
        return {
          uci: m.uci,
          san: m.san,
          games: white + draws + black,
          // The outcome split travels with the count, because "how often" and
          // "how well" are different questions and the second is the one a
          // student is really asking when they compare two candidate moves.
          white,
          draws,
          black,
        };
      });

      const moves = new Map();
      let total = 0;
      for (const m of withStandardUci(fen, raw)) {
        moves.set(m.uci, m);
        total += m.games;
      }
      return { total, moves };
    });
  }

  /// Lichess's evaluation of one position, White-relative, or null when the
  /// cloud has never seen it.
  function evalAt(fen, { token }) {
    return once(`eval|${fen}`, evals, async () => {
      const params = new URLSearchParams({ fen, multiPv: '1' });
      const data = await getJson(`${cloudEvalUrl}?${params}`, { token, allowMissing: true });
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
   * the app has one and the books are keyed by the other.
   */
  async function judge(fen, move, { token = '', minRating = null } = {}) {
    if (typeof fen !== 'string' || fen.trim() === '') {
      throw new RangeError('Pozicija (FEN) nije prosleđena.');
    }
    if (typeof move !== 'string' || move.trim() === '') {
      throw new RangeError('Potez nije prosleđen.');
    }

    // The caller's own mistakes are answered before this server's state, so a
    // malformed request is told so whether or not a token came with it.
    const buckets = ratingBucketsFrom(minRating);

    let board;
    try {
      board = new Chess(fen);
    } catch {
      throw new RangeError('Pozicija (FEN) nije ispravna.');
    }

    let played;
    try {
      played = board.move(move.trim(), { strict: false });
    } catch {
      played = null;
    }
    if (!played) {
      throw new RangeError(`Potez „${move}" nije moguć u toj poziciji.`);
    }

    const uci = `${played.from}${played.to}${played.promotion ?? ''}`;
    const moverIsWhite = played.color === 'w';
    const fenAfter = board.fen();

    if (!token) {
      throw new OpeningJudgeUnavailable(
        'Za suđenje poteza potreban je vaš Lichess token.',
        { reason: 'no-token', status: 403 }
      );
    }

    const key = `${fen}|${uci}|${buckets ? buckets[0] : 'all'}`;
    if (verdicts.has(key)) {
      hits += 1;
      return verdicts.get(key);
    }

    const base = {
      fen, fenAfter, uci, san: played.san, moverIsWhite,
      minRating: buckets ? buckets[0] : null,
    };

    const masters = await bookAt(fen, { source: 'masters', buckets: null, token });
    const inMasters = masters.moves.get(uci);
    const mastersStat = {
      games: inMasters?.games ?? 0,
      total: masters.total,
    };

    if (mastersStat.games >= MIN_MASTER_GAMES) {
      // The books outrank the engine here on purpose. A move masters keep
      // playing is theory even when the cloud has it a tenth of a pawn worse
      // than the top choice, and telling a child otherwise teaches them to
      // distrust the opening they were given.
      const value = {
        ...base, verdict: 'theory', masters: mastersStat, band: null, eval: null,
      };
      remember(verdicts, key, value);
      return value;
    }

    const band = await bookAt(fen, { source: 'lichess', buckets, token });
    const inBand = band.moves.get(uci);
    const bandStat = { games: inBand?.games ?? 0, total: band.total };

    const [before, after] = await Promise.all([
      evalAt(fen, { token }),
      evalAt(fenAfter, { token }),
    ]);

    if (!before || !after) {
      // Loud, and its own verdict. Calling an unjudged move a mistake is the
      // exact shape of failure this project keeps paying for.
      const value = {
        ...base,
        verdict: 'unknown',
        reason: 'no-eval',
        masters: mastersStat,
        band: bandStat,
        eval: null,
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
      band: bandStat,
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
   * Lives here rather than in the repertoire service because everything it
   * needs is already here: the same book cache, the same queue, and the same
   * rule about whose token is spent. A second place asking Lichess would be a
   * second place to get the pacing and the token gate wrong.
   */
  async function replies(fen, { token = '', minRating = null } = {}) {
    if (typeof fen !== 'string' || fen.trim() === '') {
      throw new RangeError('Pozicija (FEN) nije prosleđena.');
    }
    const buckets = ratingBucketsFrom(minRating);
    if (!token) {
      throw new OpeningJudgeUnavailable(
        'Za gradnju repertoara potreban je vaš Lichess token.',
        { reason: 'no-token', status: 403 }
      );
    }

    const band = await bookAt(fen, { source: 'lichess', buckets, token });
    const all = [...band.moves.values()].sort((a, b) => b.games - a.games);
    const total = band.total;

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
        white: move.white ?? 0,
        draws: move.draws ?? 0,
        black: move.black ?? 0,
      });
      running += move.games;
    }

    const tailMoves = all.length - covered.length;
    const tailGames = total - running;
    const isCovered = new Set(covered.map((m) => m.uci));
    return {
      fen,
      minRating: buckets ? buckets[0] : null,
      total,
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
        white: move.white ?? 0,
        draws: move.draws ?? 0,
        black: move.black ?? 0,
        covered: isCovered.has(move.uci),
      })),
      coveredShare: total > 0 ? running / total : 0,
      // Named and counted rather than dropped: this is exactly the set of moves
      // the drill will one day play and the student will not have an answer to.
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
      books: books.size,
      requests,
      hits,
      // Seconds left of a Lichess block, so the log can say why the panel has
      // gone quiet instead of leaving it to be guessed.
      blockedForMs: pacer.blockedForMs(),
    }),
    clear: () => {
      verdicts.clear(); evals.clear(); books.clear();
      requests = 0; hits = 0; pacer.reset();
    },
  };
}

module.exports = {
  createOpeningJudge,
  sanLine,
  ratingBucketsFrom,
  whiteRelativeCp,
  OpeningJudgeUnavailable,
  RATING_BUCKETS,
  MIN_MASTER_GAMES,
  MIN_BAND_GAMES,
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
