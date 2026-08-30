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

/// A local Syzygy sidecar, when one is running. Unset means there is none and
/// every position goes to Lichess, which is the shape this service had for its
/// whole life and still works.
const DEFAULT_SIDECAR_URL = process.env.SYZYGY_SIDECAR_URL || null;

const logger = require('./logger');

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
      `Tablica nije dala ishod za poziciju (kategorija: ${category ?? 'nema'}).`
    );
  }
  return WDL[category];
}

/// The move a tablebase-perfect player makes in this position.
///
/// In the drill this is the opponent's reply, but the rule is not about sides:
/// the categories on `moves` describe the player to move *after* each move, so
/// the mover's own result is their negation. Among moves that reach the same
/// result the choice is not arbitrary. A losing side must take the longest
/// road, or the drill ends early and teaches the child nothing; a winning side
/// must take the shortest, or "you are not making progress" becomes a lie told
/// by the opponent rather than by the child's play.
function bestReply(moves) {
  if (!Array.isArray(moves) || moves.length === 0) return null;

  const scored = moves.map((m) => ({
    move: m,
    value: -wdlOf(m.category),
    distance: Math.abs(m.dtz ?? 0),
  }));

  const best = Math.max(...scored.map((s) => s.value));
  const tied = scored.filter((s) => s.value === best);
  // Sorted by uci first so the pick is the same on every run; without it two
  // equally good moves would alternate between requests and the same drill
  // would play out differently each time.
  tied.sort((a, b) => a.move.uci.localeCompare(b.move.uci));

  if (best > 0) {
    // Converting, and this is where the obvious rule is wrong. "Smallest DTZ"
    // compares distances measured from different starting points, because a
    // capture or a pawn move resets the counter: at DTZ 1 the winning move is
    // precisely the zeroing one, and its distance afterwards is whatever the
    // new ending happens to be - often larger. Played out, that rule had the
    // winner shuffle a rook back and forth forever, holding the win and never
    // finishing it, which is not a drill anyone can complete.
    //
    // So a zeroing move that keeps the win comes first: it is progress by
    // definition, it restarts the fifty move count, and it is what guarantees
    // the drill ends. Among the rest, the shortest road.
    tied.sort((a, b) => {
      if (a.move.zeroing !== b.move.zeroing) return a.move.zeroing ? -1 : 1;
      return a.distance - b.distance;
    });
  } else if (best < 0) {
    // Lost, so the longest road: ending early would teach the child nothing
    // about converting.
    tied.sort((a, b) => b.distance - a.distance);
  }
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
  sidecarUrl = DEFAULT_SIDECAR_URL,
  // Short on purpose. A local read that takes longer than this is not a local
  // read, and waiting on it costs more than asking Lichess would.
  sidecarTimeoutMs = 2000,
} = {}) {
  const cache = new Map();
  // Two children on the same position, or one child whose client retried, must
  // not become two requests to a donated service.
  const inFlight = new Map();
  // And the ones that do go out are spaced, and stop entirely for a minute
  // after a 429. The endgame audit is what made this necessary: it walks every
  // archived game that reached seven men, which on one real archive is 471
  // games and thousands of positions, anonymously, as fast as the round trips
  // allow. That is a scan of a donated service, and it was written without a
  // gap for the same reason every bug in this codebase gets written — the fast
  // version works, right up until it does not.
  const pacer = createPacer({ minGapMs, cooldownMs, now, sleep });
  let requests = 0;
  // Where the answers came from. Reported rather than inferred: "the sidecar is
  // running" and "the sidecar is answering" are different claims, and only the
  // second one is worth anything.
  let local = 0;
  let declined = 0;
  let unreachable = 0;
  let sidecarWarned = false;

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
        `Lichess privremeno ne prima upite za tablice. Probajte za ${
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
          'Lichess je odbio upit zbog učestalosti; provera staje umesto da navaljuje.',
          null, { reason: 'rate-limited', retryable: false },
        );
      }
      if (!res.ok) {
        throw new TablebaseUnavailable(`Tablica je odgovorila ${res.status}.`);
      }
      requests += 1;
      return await res.json();
    } finally {
      clearTimeout(timer);
    }
  }

  /// The local tables, when there are any. Null means "ask Lichess".
  ///
  /// Not paced, not retried, and deliberately so: this is a memory-mapped file
  /// on the same machine, and pacing it would be pacing a disk read. Everything
  /// the pacer protects — the shared address, the donated service — is on the
  /// other branch.
  ///
  /// A 404 is the sidecar declining, which is a real answer and the reason it
  /// can be trusted at all: it refuses castling, positions past its largest
  /// table, tables missing from disk, and any verdict the fifty-move rule could
  /// overturn. Those fall through to Lichess.
  async function fromSidecar(fen) {
    if (!sidecarUrl) return null;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), sidecarTimeoutMs);
    try {
      const res = await fetchImpl(`${sidecarUrl}?fen=${encodeURIComponent(fen)}`, {
        signal: controller.signal,
      });
      if (res.status === 404) {
        declined += 1;
        return null;
      }
      if (!res.ok) throw new Error(`sidecar answered ${res.status}`);
      local += 1;
      return await res.json();
    } catch (err) {
      // Configured and unreachable is not the same as not configured, and it
      // must not read the same. Falling back silently would leave every probe
      // going to Lichess at one a second while the logs said nothing — the
      // exact shape of every bug in this codebase. Said once, not per probe,
      // because an audit would otherwise print it thousands of times.
      if (!sidecarWarned) {
        sidecarWarned = true;
        logger.warn(
          `[TABLICE] Lokalni sidecar (${sidecarUrl}) ne odgovara (${err.message}); `
          + 'sve pozicije idu na Lichess, sporije. Ovo se prijavljuje jednom.',
        );
      }
      unreachable += 1;
      return null;
    } finally {
      clearTimeout(timer);
    }
  }

  async function load(fen) {
    const localAnswer = await fromSidecar(fen);
    if (localAnswer) return localAnswer;

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
      'Tablica trenutno nije dostupna, pa se pozicija ne može presuditi.', last
    );
  }

  /**
   * Everything known about one position: its outcome for the side to move, the
   * distance to the next zeroing move, and every legal move with the same.
   */
  async function probe(fen) {
    if (cache.has(fen)) return cache.get(fen);
    if (inFlight.has(fen)) return inFlight.get(fen);

    const pending = load(fen).then((data) => {
      const value = {
        category: data.category,
        dtz: data.dtz ?? null,
        checkmate: Boolean(data.checkmate),
        stalemate: Boolean(data.stalemate),
        insufficientMaterial: Boolean(data.insufficient_material),
        moves: (data.moves || []).map((m) => ({
          uci: m.uci,
          san: m.san,
          category: m.category,
          dtz: m.dtz ?? null,
          zeroing: Boolean(m.zeroing),
        })),
      };
      remember(fen, value);
      return value;
    }).finally(() => inFlight.delete(fen));

    inFlight.set(fen, pending);
    return pending;
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
    stats: () => ({
      cached: cache.size,
      requests,
      local,
      declined,
      unreachable,
      sidecar: sidecarUrl,
    }),
    clear: () => {
      cache.clear();
      requests = 0;
      local = 0;
      declined = 0;
      unreachable = 0;
    },
  };
}

module.exports = {
  createTablebase,
  TABLEBASE_GAP_MS,
  bestReply,
  wdlOf,
  TablebaseUnavailable,
  WDL,
  tablebase: createTablebase(),
};
