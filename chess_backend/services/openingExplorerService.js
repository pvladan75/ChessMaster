// openingExplorerService.js — the opening book, asked once and remembered.
//
// Why the server asks rather than the app: the Lichess Explorer wants a token,
// and until now that token had to be the user's own. Every trainer and every
// child was sent to lichess.org to create one and paste it into Settings before
// the panel would show anything at all, and most of them will simply not do it —
// the panel then quietly became ChessDB and the feature was, in practice, off.
// One token lives here instead, in .env, belonging to the account that runs this
// server. Nobody else ever sees it, and nothing has to be pasted anywhere.
//
// That trade has a price: Lichess counts requests per token, so everyone now
// shares one allowance. The cache is what pays it. Openings are the most
// repetitive positions in chess — twenty children walking into the Italian ask
// the same twenty questions — so one entry answers all of them, and the traffic
// that leaves this server is closer to the number of distinct positions than to
// the number of lookups.
//
// The same shape as tablebaseService, deliberately: bounded cache, one in-flight
// request per key, and retries only where a retry can help. Nothing here
// guesses. A token that is missing, refused or throttled is reported as such,
// each with its own reason, because the app falls back to ChessDB either way and
// the log is the only place the difference can still be seen. A refused token
// that reads as "this opening has no games" is exactly the silent failure this
// codebase keeps meeting.

const {
  createPacer, MIN_REQUEST_GAP_MS, RATE_LIMIT_COOLDOWN_MS,
} = require('./lichessPacing');
const { withStandardUci } = require('./openingMoveNotation');

const DEFAULT_URL = process.env.LICHESS_EXPLORER_URL
  || 'https://explorer.lichess.ovh/lichess';

/// The rating buckets the Explorer knows. A request carries the list of buckets
/// it wants, not a floor, so "1600 and up" has to be spelled out as every bucket
/// from 1600 on. Sending the single bucket instead is the quieter mistake: the
/// panel says "1600+" and shows only games between 1600 and 1799.
const RATING_BUCKETS = [0, 1000, 1200, 1400, 1600, 1800, 2000, 2200, 2500];

const MAX_MOVES = 30;

class OpeningExplorerUnavailable extends Error {
  /// `reason` is what the log and the client key off: 'not-configured' (no
  /// token in .env), 'unauthorized' (Lichess refused it), 'rate-limited' (spent
  /// the allowance) or 'network'. They are four different jobs for whoever
  /// reads the log, so they never collapse into one message.
  constructor(message, { reason = 'network', status = 503, cause } = {}) {
    super(message);
    this.name = 'OpeningExplorerUnavailable';
    this.reason = reason;
    this.status = status;
    this.cause = cause;
  }
}

/// Every bucket at or above `minRating`, or null for "all ratings".
///
/// Throws on a value that is not a bucket rather than rounding to the nearest
/// one: a filter that appears to work and quietly answers a different question
/// is worse than a refusal.
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

/**
 * Build an Explorer client.
 *
 * `fetchImpl` is injected so tests never touch the network, `token` so a test
 * does not need one, and `cacheLimit` bounds what a long-running server keeps.
 */
function createOpeningExplorer({
  fetchImpl = globalThis.fetch,
  baseUrl = DEFAULT_URL,
  token = process.env.LICHESS_API_TOKEN || '',
  cacheLimit = 4000,
  timeoutMs = 8000,
  retries = 1,
  minGapMs = MIN_REQUEST_GAP_MS,
  cooldownMs = RATE_LIMIT_COOLDOWN_MS,
  // Injected so a test can spend Lichess's minute without waiting one.
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  const cache = new Map();
  // Two children in the same opening, or one client that retried, must not
  // become two requests against a single shared allowance.
  const inFlight = new Map();
  // And the ones that do go out are spaced, and stop entirely for a minute
  // after a 429. This matters more here than in the judge: the token spent
  // here is the server's, so a block earned by one child closes the opening
  // book for all of them.
  const pacer = createPacer({ minGapMs, cooldownMs, now, sleep });
  let requests = 0;
  let hits = 0;

  function remember(key, value) {
    cache.set(key, value);
    while (cache.size > cacheLimit) {
      cache.delete(cache.keys().next().value);
    }
  }

  async function fetchOnce(fen, moves, buckets) {
    const params = new URLSearchParams({
      fen,
      moves: String(moves),
      // The panel draws neither, and together they are most of the response —
      // dropping them keeps both the wire and this cache small.
      topGames: '0',
      recentGames: '0',
    });
    if (buckets) params.set('ratings', buckets.join(','));

    // Serving Lichess's block here rather than knocking through it: they hold
    // an address for a minute, and for up to an hour if the knocking goes on.
    const blockedFor = pacer.blockedForMs();
    if (blockedFor > 0) {
      throw new OpeningExplorerUnavailable(
        `Lichess privremeno ne prima upite. Probajte za ${
          Math.ceil(blockedFor / 1000)} s.`,
        { reason: 'rate-limited', status: 503 }
      );
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await pacer.spaced(() => fetchImpl(`${baseUrl}?${params}`, {
        signal: controller.signal,
        headers: {
          Authorization: `Bearer ${token}`,
          'User-Agent': 'chess-coach opening explorer',
        },
      }));
      if (res.status === 401 || res.status === 403) {
        throw new OpeningExplorerUnavailable(
          'Lichess je odbio token servera za bazu otvaranja.',
          { reason: 'unauthorized', status: 502 }
        );
      }
      if (res.status === 429) {
        pacer.block();
        throw new OpeningExplorerUnavailable(
          'Potrošen je dozvoljeni broj upita ka Lichess bazi otvaranja.',
          { reason: 'rate-limited', status: 503 }
        );
      }
      if (!res.ok) {
        throw new OpeningExplorerUnavailable(
          `Baza otvaranja je odgovorila ${res.status}.`, { reason: 'network' }
        );
      }
      requests += 1;
      return await res.json();
    } finally {
      clearTimeout(timer);
    }
  }

  async function load(fen, moves, buckets) {
    let last;
    for (let attempt = 0; attempt <= retries; attempt += 1) {
      try {
        return await fetchOnce(fen, moves, buckets);
      } catch (err) {
        // A refused token is refused on the second try too, and a spent
        // allowance is only made worse by asking again. A retry is for a
        // connection that dropped, and for nothing else.
        if (err instanceof OpeningExplorerUnavailable && err.reason !== 'network') {
          throw err;
        }
        last = err;
      }
    }
    throw new OpeningExplorerUnavailable(
      'Baza otvaranja trenutno nije dostupna.', { reason: 'network', cause: last }
    );
  }

  /**
   * What real games did from this position: the outcome split, the opening's
   * name, and the same for every move played from here.
   *
   * `minRating` is a bucket floor, not a free number — see ratingBucketsFrom.
   */
  async function probe(fen, { moves = 12, minRating = null } = {}) {
    if (typeof fen !== 'string' || fen.trim() === '') {
      throw new RangeError('Pozicija (FEN) nije prosleđena.');
    }

    // What the caller sent is judged before what this server has, so a
    // malformed request is told so whether or not a token is configured. The
    // other order hides a broken client behind a server-side excuse.
    const limit = Math.min(Math.max(Number(moves) || 12, 1), MAX_MOVES);
    const buckets = ratingBucketsFrom(minRating);

    if (!token) {
      throw new OpeningExplorerUnavailable(
        'Baza otvaranja nije podešena na serveru (LICHESS_API_TOKEN).',
        { reason: 'not-configured', status: 503 }
      );
    }

    const key = `${fen}|${limit}|${buckets ? buckets[0] : 'all'}`;

    if (cache.has(key)) {
      hits += 1;
      return cache.get(key);
    }
    if (inFlight.has(key)) return inFlight.get(key);

    const pending = load(fen, limit, buckets).then((data) => {
      const value = {
        fen,
        white: data.white ?? 0,
        draws: data.draws ?? 0,
        black: data.black ?? 0,
        opening: data.opening
          ? { eco: data.opening.eco ?? '', name: data.opening.name ?? '' }
          : null,
        // Castling is rewritten into this app's notation on the way out:
        // Lichess sends `e1h1`, our board plays `e1g1`, and the panel's
        // "click a move to play it" did nothing at all for castling.
        moves: withStandardUci(fen, (data.moves || []).map((m) => ({
          uci: m.uci,
          san: m.san,
          white: m.white ?? 0,
          draws: m.draws ?? 0,
          black: m.black ?? 0,
          // Lichess calls it averageRating here and averageOpponentRating in
          // its other explorers; the app reads the second name, so both arrive
          // under it rather than the field staying null forever.
          averageOpponentRating: m.averageRating ?? m.averageOpponentRating ?? null,
        }))),
      };
      remember(key, value);
      return value;
    }).finally(() => inFlight.delete(key));

    inFlight.set(key, pending);
    return pending;
  }

  return {
    probe,
    isConfigured: () => Boolean(token),
    stats: () => ({
      cached: cache.size,
      requests,
      hits,
      // Seconds left of a Lichess block, so a panel gone quiet has somewhere to
      // be explained from.
      blockedForMs: pacer.blockedForMs(),
    }),
    clear: () => { cache.clear(); requests = 0; hits = 0; pacer.reset(); },
  };
}

module.exports = {
  createOpeningExplorer,
  ratingBucketsFrom,
  OpeningExplorerUnavailable,
  RATING_BUCKETS,
  MAX_MOVES,
  openingExplorer: createOpeningExplorer(),
};
