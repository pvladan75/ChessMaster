// tablebaseService.js — the one place that asks a tablebase what a position is.
//
// Why the server asks rather than the app: the play-it-out drill judges every
// move a child makes, and a verdict that arrives from the client is a verdict
// the server cannot tell apart from any other POST. That matters less for
// cheating than for the ordinary case — an old APK still installed, a retry
// after a dropped connection — where the server would have no way to know which
// answer it is looking at. Judging here costs nothing extra, because the server
// has to ask the tables anyway to tell the child whether the move held.
//
// Why over the network: Node has no Syzygy reader, and the tables are read by
// memory mapping, so the 940 MB three-to-five set on a 960 MB droplet would
// fight everything else running there. Lichess serves the same Syzygy data and
// reaches to seven pieces, which is further than any set we could hold.
//
// A local sidecar was tried on 31.8.2026 and removed the same week, with the
// scan it was built for: two halves answering one question is a system with
// two ways to be down, and that one was slow and fell over.
//
// **Five men or fewer come back from our own tables since 25.9.2026**
// (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1t — the owner's decision of
// 24.9.2026, reversing the above on purpose). The whole-game review asks about
// every position with seven men or fewer, and Lichess throttles after about 90
// requests; the common endings of club play are mostly five men or fewer. What
// is different from 31.8: the prober is Lichess's own server
// (`lila-tablebase`, the same API over the 3-4-5 set, measured 71 of 71
// positions answering alike), the split is by the number of men and nothing
// else, and **a local server that does not answer is never silent** — the
// question goes to Lichess, paced as always, and the log says so. Unset
// `LOCAL_TABLEBASE_URL` and everything goes to Lichess, as before.
//
// One request answers a whole position — the response carries a category for
// every legal move — so a drill costs one request per move played, and repeated
// positions cost none. That is the small, targeted use this service is for, not
// a scan of it: bulk work belongs in puzzles/rejudge_endgames.py, which primes
// per position for the same reason.
//
// Nothing here falls back to an engine. A tablebase that cannot be reached is
// reported as unavailable and the drill says so; a guess dressed as an exact
// answer is the one outcome worse than no answer, because the whole promise of
// this mode is that "you lost the win" is a fact and not an opinion.

const DEFAULT_URL = process.env.LICHESS_TABLEBASE_URL
  || 'https://tablebase.lichess.ovh/standard';

const logger = require('./logger');

/// Our own `lila-tablebase` over the 3-4-5 set, or null for Lichess only.
const LOCAL_URL = process.env.LOCAL_TABLEBASE_URL || null;

/// The most men our own tables answer for: the 3-4-5 set, the one the
/// droplet can hold (940 MB; the 6-man set is 150 GB), so the owner's machine
/// and the droplet judge a game alike.
const LOCAL_MAX_MEN = 5;

/// Men on the board — kings included — from a FEN's placement field.
function pieceCount(fen) {
  return (String(fen).split(' ')[0].match(/[a-zA-Z]/g) || []).length;
}

/// Lichess's five words for an outcome, from the point of view of the side to
/// move. Anything outside this map is a position the service will not commit
/// to ('unknown', 'maybe-win', 'maybe-loss') and must not be turned into one.
const WDL = {
  win: 2,
  'cursed-win': 1,
  draw: 0,
  'blessed-loss': -1,
  loss: -2,
};

const { createPacer, RATE_LIMIT_COOLDOWN_MS } = require('./lichessPacing');

/// How long to leave between two requests to the tablebase.
///
/// **Measured, not borrowed.** This was 150 ms for one day — the Explorer's
/// documented gap, taken because it was the only number we had, with a comment
/// admitting the borrowing. Three real runs of the endgame audit on 30.8.2026
/// died at 84, 98 and 96 probes with a 429, about 4.8 requests a second. So the
/// tablebase allows a short burst and then throttles, and the Explorer's number
/// does not transfer.
///
/// One second is what `lichessPacing`'s header says an anonymous caller gets,
/// and it is now the number that has actually been tested against this
/// endpoint. It makes a first full audit slow — hours over a large archive —
/// which is affordable only because `tablebase_cache` is permanent and shared,
/// so every run after the first is nearly free.
const TABLEBASE_GAP_MS = 1000;

/// How many Lichess requests may already be waiting before a question about
/// the distance to mate stops joining them and takes our own tables' answer.
/// Three is about three seconds at TABLEBASE_GAP_MS: well inside the app's
/// ten-second wait for the server, and short enough for the drill's reply.
const MATE_QUEUE_LIMIT = 3;

class TablebaseUnavailable extends Error {
  /// `retryable` is the half of this class that matters most.
  ///
  /// `load` used to retry every failure twice, immediately, with no gap — so a
  /// 429 became three 429s, and `lichessPacing`'s header says exactly what that
  /// does: it turns one lost minute into a lost hour, for everybody at once.
  /// A refusal that says "wait" must never be retried; a timeout still should.
  constructor(message, cause, { reason = 'error', retryable = true } = {}) {
    super(message);
    this.name = 'TablebaseUnavailable';
    this.cause = cause;
    this.reason = reason;
    this.retryable = retryable;
  }
}

/// The outcome for the side to move, or a throw. Never a guess.
function wdlOf(category) {
  if (!(category in WDL)) {
    throw new TablebaseUnavailable(
      `Tablebase gave no outcome for position (category: ${category ?? 'none'}).`
    );
  }
  return WDL[category];
}

/// Two optional numbers in Rust's `Option` order: none before any, then by
/// value.
function optionOrder(a, b) {
  const noA = a === null || a === undefined;
  const noB = b === null || b === undefined;
  if (noA && noB) return 0;
  if (noA) return -1;
  if (noB) return 1;
  return a - b;
}

/// Distance to mate, ordered as lila-tablebase orders it
/// (`tightening_metric_sort_key` in its `src/metric.rs`). A move's `dtm` is
/// the opponent's after it, in plies: negative when the opponent is being
/// mated, so the nearest mate comes first; positive when the mover is, so the
/// farthest comes first. A move whose distance is not known sorts after the
/// known ones for a winner and before them for a loser — Lichess's own quirk,
/// kept so our pick and its list agree.
function byMateDistance(a, b) {
  const neg = (m) => (typeof m.dtm === 'number' && m.dtm < 0 ? m.dtm : null);
  const pos = (m) => (typeof m.dtm === 'number' && m.dtm > 0 ? m.dtm : null);
  const nearer = optionOrder(neg(b), neg(a));
  if (nearer !== 0) return nearer;
  const pa = pos(a);
  const pb = pos(b);
  if (pa === null && pb === null) return 0;
  if (pa === null) return -1;
  if (pb === null) return 1;
  return pb - pa;
}

/// The move a tablebase-perfect player makes in this position.
///
/// In the drill this is the opponent's reply, but the rule is not about sides:
/// the categories on `moves` describe the player to move *after* each move, so
/// the mover's own result is their negation.
///
/// **Among moves that reach the same result, the order is Lichess's**
/// (`MoveInfo::sort_key` in lila-tablebase's `src/response.rs`, the server
/// behind `tablebase.lichess.ovh` and behind our own tables): a mate first,
/// then the distance to mate, then a conversion, then a zeroing move, then
/// DTZ. `test/fixtures/tablebase_best.json` holds real answers to it, and the
/// app's reader keeps the same order by never re-sorting what arrives.
///
/// Until 30.9.2026 this looked at DTZ alone, and a defence by DTZ is not a
/// defence. DTZ counts to the next capture or pawn move, so the loser who
/// maximises it keeps the winner from zeroing and nothing else: in the owner's
/// rook ending it walked away from a free pawn (Kh3 where Rxh4 holds eight
/// plies longer) and offered the rook trade that cut the mate from 35 plies to
/// 15. Distance to mate is what "the longest resistance" means. Our own
/// tables (five men or fewer) have no DTM, and there the order falls back to
/// the DTZ half of the same key — see `probe`'s `mateDistance`.
///
/// A draw is left alone: every drawing move is equally good, Lichess's order
/// among them puts a stalemate or a trade into bare kings first — which would
/// end the draw drill on its first reply — so the pick among them is by uci,
/// the same on every run. Without a stable tie-break the same drill would play
/// out differently each time.
function bestReply(moves) {
  if (!Array.isArray(moves) || moves.length === 0) return null;

  const scored = moves.map((m) => ({
    move: m,
    value: -wdlOf(m.category),
    distance: Math.abs(m.dtz ?? 0),
  }));

  const best = Math.max(...scored.map((s) => s.value));
  const tied = scored.filter((s) => s.value === best);
  tied.sort((a, b) => a.move.uci.localeCompare(b.move.uci));
  if (best === 0) return tied[0].move;

  const winning = best > 0;
  // A mover who is winning wants the conversion and the zeroing move first;
  // one who is losing wants them last: they restart the counter for the
  // winner. The same xor lila writes as `zeroing ^ !is_positive`.
  const later = (flag) => (winning ? !flag : Boolean(flag));
  tied.sort((a, b) => {
    if (Boolean(a.move.checkmate) !== Boolean(b.move.checkmate)) {
      return a.move.checkmate ? -1 : 1;
    }
    const mate = byMateDistance(a.move, b.move);
    if (mate !== 0) return mate;
    if (later(a.move.conversion) !== later(b.move.conversion)) {
      return later(a.move.conversion) ? 1 : -1;
    }
    // Converting, and this is where the obvious rule is wrong. "Smallest DTZ"
    // compares distances measured from different starting points, because a
    // capture or a pawn move resets the counter: at DTZ 1 the winning move is
    // precisely the zeroing one, and its distance afterwards is whatever the
    // new ending happens to be - often larger. Played out, that rule had the
    // winner shuffle a rook back and forth forever. So a zeroing move that
    // keeps the win comes first: it is progress by definition.
    if (later(a.move.zeroing) !== later(b.move.zeroing)) {
      return later(a.move.zeroing) ? 1 : -1;
    }
    // The shortest road for the winner, the longest for the loser.
    return winning ? a.distance - b.distance : b.distance - a.distance;
  });
  return tied[0].move;
}

/**
 * Build a tablebase client.
 *
 * `fetchImpl` is injected so tests never touch the network, and `cacheLimit`
 * bounds what a long-running server accumulates.
 */
function createTablebase({
  fetchImpl = globalThis.fetch,
  baseUrl = DEFAULT_URL,
  cacheLimit = 5000,
  timeoutMs = 8000,
  retries = 2,
  // `now` and `sleep` are injected for the same reason as in every other
  // consumer of the pacer: a test has to be able to spend a minute of cooldown
  // without waiting one.
  minGapMs = TABLEBASE_GAP_MS,
  cooldownMs = RATE_LIMIT_COOLDOWN_MS,
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  // Our own tables (phase 1t): asked first for LOCAL_MAX_MEN or fewer, never
  // paced — they are ours — and never the end of the road.
  localUrl = LOCAL_URL,
  localTimeoutMs = 3000,
  log = logger,
  // Called once per request that went out and was answered — `'lichess'` or
  // `'local'` — and never for a cache hit. Null by default so a test's client
  // reports to nobody; the server wires the counter (services/providerUsage.js)
  // through `setOnRequest` once at startup. It can neither fail nor delay a
  // probe: a throw is logged, and nothing awaits it.
  onRequest = null,
} = {}) {
  const cache = new Map();
  let reportRequest = onRequest;
  function report(kind) {
    if (typeof reportRequest !== 'function') return;
    try {
      reportRequest(kind);
    } catch (err) {
      log.warn(`[TABLEBASE] Brojač zahteva je pukao (${err.message}); nastavljam.`);
    }
  }
  // Two children on the same position, or one child whose client retried, must
  // not become two requests to a donated service.
  const inFlight = new Map();
  // And the ones that do go out are spaced, and stop entirely for a minute
  // after a 429. It was a scan of this donated service that made the pacing
  // necessary, and the scan has since been removed; the pacing stays, because
  // the drill can still ask for a position a second, and because a rule that
  // only holds while nothing stresses it is not a rule.
  const pacer = createPacer({ minGapMs, cooldownMs, now, sleep });
  let requests = 0;
  let localRequests = 0;
  let localMisses = 0;

  function remember(fen, value) {
    cache.set(fen, value);
    while (cache.size > cacheLimit) {
      cache.delete(cache.keys().next().value);
    }
  }

  async function fetchOnce(fen) {
    const url = `${baseUrl}?fen=${encodeURIComponent(fen)}`;

    // Serving Lichess's block here rather than knocking through it. They hold
    // an address for a minute, and for up to an hour if the knocking goes on,
    // so a request sent during a block is not a wasted request — it is what
    // extends the block.
    const blockedFor = pacer.blockedForMs();
    if (blockedFor > 0) {
      throw new TablebaseUnavailable(
        `Lichess is temporarily not accepting tablebase requests. Try again in ${
          Math.ceil(blockedFor / 1000)} s.`,
        null, { reason: 'rate-limited', retryable: false },
      );
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await pacer.spaced(() => fetchImpl(url, {
        signal: controller.signal,
        headers: { 'User-Agent': 'chess-coach endgame drill' },
      }));
      if (res.status === 429) {
        pacer.block();
        throw new TablebaseUnavailable(
          'Lichess rejected request due to rate limit; stopping checks instead of hammering.',
          null, { reason: 'rate-limited', retryable: false },
        );
      }
      if (!res.ok) {
        throw new TablebaseUnavailable(`Tablebase responded with ${res.status}.`);
      }
      requests += 1;
      report('lichess');
      return await res.json();
    } finally {
      clearTimeout(timer);
    }
  }

  /// Our own tables' answer, or null when they did not give one — which is
  /// logged, and then Lichess is asked.
  async function fetchLocal(fen) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), localTimeoutMs);
    try {
      const res = await fetchImpl(`${localUrl}?fen=${encodeURIComponent(fen)}`, {
        signal: controller.signal,
      });
      if (!res.ok) throw new Error(`status ${res.status}`);
      const data = await res.json();
      if (!data || typeof data.category !== 'string') throw new Error('no category');
      localRequests += 1;
      report('local');
      return data;
    } catch (err) {
      localMisses += 1;
      log.warn(`[TABLEBASE] Lokalne tabele nisu odgovorile (${err.message}); pitam Lichess: ${fen}`);
      return null;
    } finally {
      clearTimeout(timer);
    }
  }

  /// Whether our own tables are the first ones asked about this position.
  function localFirst(fen) {
    return Boolean(localUrl) && pieceCount(fen) <= LOCAL_MAX_MEN;
  }

  async function load(fen) {
    if (localFirst(fen)) {
      const local = await fetchLocal(fen);
      if (local) return { data: local, source: 'local' };
    }
    return { data: await loadLichess(fen), source: 'lichess' };
  }

  async function loadLichess(fen) {
    let last;
    for (let attempt = 0; attempt <= retries; attempt += 1) {
      try {
        return await fetchOnce(fen);
      } catch (err) {
        last = err;
        // A refusal that means "wait" is not retried. Retrying it is the whole
        // failure this pacing exists to prevent, and it is invisible when it
        // happens: three requests instead of one still looks like it works.
        if (err instanceof TablebaseUnavailable && err.retryable === false) throw err;
      }
    }
    throw new TablebaseUnavailable(
      'Tablebase is currently unavailable, so the position cannot be judged.', last
    );
  }

  /**
   * Everything known about one position: its outcome for the side to move, the
   * distance to the next zeroing move, and every legal move with the same.
   *
   * `mateDistance` asks for Lichess's answer where our own tables would be
   * asked first, because only Lichess knows the distance to mate — and a move
   * chosen as the best defence needs it (`bestReply`). Asked by the drill for
   * its reply alone: one request a move, never a walk. When Lichess does not
   * answer, our own tables' answer is used and the log says so — the result is
   * exact either way, only the choice among equally lost moves is coarser.
   */
  async function probe(fen, { mateDistance = false } = {}) {
    if (mateDistance && localFirst(fen)) return probeWithMate(fen);
    if (cache.has(fen)) return cache.get(fen);
    if (inFlight.has(fen)) return inFlight.get(fen);
    return tracked(fen, kept(fen, load(fen)));
  }

  function probeWithMate(fen) {
    const cached = cache.get(fen);
    if (cached && cached.source === 'lichess') return cached;
    // A line already waiting for Lichess is seconds of waiting for a person
    // who is reading the list, and the app gives up on the server after ten
    // and then asks Lichess itself — the same request twice. Our own tables
    // answer at once, exact in the result, coarser only in the order.
    if (localFirst(fen) && pacer.waiting() >= MATE_QUEUE_LIMIT) {
      log.warn(`[TABLEBASE] Lichess red je pun (${pacer.waiting()}); `
        + `udaljenost do mata se ne čeka, odgovor bira naša tabela: ${fen}`);
      return probe(fen);
    }
    const key = `${fen}|dtm`;
    if (inFlight.has(key)) return inFlight.get(key);
    const lichess = loadLichess(fen).then((data) => ({ data, source: 'lichess' }));
    return tracked(key, kept(fen, lichess).catch((err) => {
      if (!(err instanceof TablebaseUnavailable)) throw err;
      log.warn(`[TABLEBASE] Lichess nije dao udaljenost do mata (${err.message}); `
        + `odgovor bira naša tabela: ${fen}`);
      return probe(fen);
    }));
  }

  /// Held under `key` while it is on its way, so a second asker waits for the
  /// same answer — fallback included — instead of sending a second request.
  function tracked(key, pending) {
    const settled = pending.finally(() => inFlight.delete(key));
    inFlight.set(key, settled);
    return settled;
  }

  /// An answer in the service's own shape, cached under `fen`.
  function kept(fen, loading) {
    return loading.then(({ data, source }) => {
      const value = {
        source,
        category: data.category,
        dtz: data.dtz ?? null,
        // Distance to mate in plies, which Lichess has and our own tables do
        // not: null is "not known", never "no mate".
        dtm: data.dtm ?? null,
        checkmate: Boolean(data.checkmate),
        stalemate: Boolean(data.stalemate),
        insufficientMaterial: Boolean(data.insufficient_material),
        // The source's order is kept: it is lila-tablebase's best first,
        // which is what the app's reader shows and plays from.
        moves: (data.moves || []).map((m) => ({
          uci: m.uci,
          san: m.san,
          category: m.category,
          dtz: m.dtz ?? null,
          dtm: m.dtm ?? null,
          zeroing: Boolean(m.zeroing),
          conversion: Boolean(m.conversion),
          checkmate: Boolean(m.checkmate),
          stalemate: Boolean(m.stalemate),
        })),
      };
      remember(fen, value);
      return value;
    });
  }

  return {
    probe,
    /// Milliseconds left of a Lichess block, or 0.
    ///
    /// Exposed so a caller can decide what a block means for *it*. The two
    /// callers want opposite things: the live drill has a child waiting and
    /// must say "try again in 40 seconds", while the endgame audit is a
    /// background walk over hundreds of games and should simply wait. Deciding
    /// that here would force one answer on both.
    blockedForMs: () => pacer.blockedForMs(),
    /// Replaces the request hook. For the one shared instance, which is built
    /// when this module loads and cannot be handed a pool then.
    setOnRequest: (fn) => { reportRequest = typeof fn === 'function' ? fn : null; },
    stats: () => ({
      cached: cache.size,
      requests,
      localRequests,
      localMisses,
    }),
    clear: () => {
      cache.clear();
      requests = 0;
      localRequests = 0;
      localMisses = 0;
    },
  };
}

module.exports = {
  createTablebase,
  pieceCount,
  LOCAL_MAX_MEN,
  TABLEBASE_GAP_MS,
  MATE_QUEUE_LIMIT,
  bestReply,
  wdlOf,
  TablebaseUnavailable,
  WDL,
  tablebase: createTablebase(),
};
