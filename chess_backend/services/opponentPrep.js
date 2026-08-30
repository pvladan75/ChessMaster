// opponentPrep.js — pulling an opponent's public archive, and the policy in front of it.
//
// Section 7 of docs/PLAN-MOJE-PARTIJE.md. Mechanically this is section 1
// pointed somewhere else: Lichess serves any account's games to an
// unauthenticated caller, the importer already takes an arbitrary username, and
// the leak report already aggregates by subject. Almost nothing new is needed
// to make it work.
//
// Which is the problem. **This is the one feature here that reads about a
// person who never opened the app**, and most of the accounts in this product
// belong to children. Preparing for a club match against a named ten-year-old
// is the same HTTP request as preparing for a titled player, and the code
// cannot tell them apart.
//
// So the mechanism is built and the switch is off. `OPPONENT_PREP_ENABLED`
// defaults to false and this refuses loudly until somebody decides — the same
// shape as `AGE_OF_CONSENT`, and for the same reason: the decision is a product
// and legal one, not a default to arrive at by leaving a parameter unused.
//
// Three limits exist for when it is turned on, and they are the ones that can
// actually be enforced. Note what is *not* here: "refuse if this handle belongs
// to a child using this app" cannot be written, because nothing links a Lichess
// handle to an account. A rating floor is a proxy for it and an imperfect one.
//
//   - a rating floor, checked **before** anything is stored, because a check
//     afterwards would mean already holding the archive it was meant to refuse;
//   - a cap on how many different people one account may pull in a day, so this
//     cannot become a scraper;
//   - a retention window, because an opponent archive is reproducible in one
//     request and there is no reason to keep it. Exposure falls by holding
//     less.

const { createPacer, MIN_REQUEST_GAP_MS, RATE_LIMIT_COOLDOWN_MS } = require('./lichessPacing');
const logger = require('./logger');

const DEFAULT_USER_URL = process.env.LICHESS_USER_URL || 'https://lichess.org/api/user';

/// Lichess answers an unrecognised User-Agent with a fake 404, so this is not
/// decoration. Same string the archive importer sends.
const USER_AGENT = 'chess-coach opponent preparation';

class OpponentPrepUnavailable extends Error {
  constructor(message, { reason, status = 400 } = {}) {
    super(message);
    this.name = 'OpponentPrepUnavailable';
    this.reason = reason;
    this.status = status;
  }
}

/// The policy, read from the environment every time rather than captured once.
///
/// Read at call time so turning it on does not need a deploy, and so a test can
/// set it without reloading the module. Every value is deliberately
/// conservative: absent configuration means the feature is off, not open.
function policyFrom(env = process.env) {
  const number = (raw, fallback) => {
    const value = Number(raw);
    return Number.isFinite(value) && value >= 0 ? value : fallback;
  };
  return {
    enabled: String(env.OPPONENT_PREP_ENABLED || '').toLowerCase() === 'true',
    minRating: number(env.OPPONENT_PREP_MIN_RATING, 0),
    maxSubjectsPerDay: number(env.OPPONENT_PREP_MAX_SUBJECTS_PER_DAY, 3),
    retentionDays: number(env.OPPONENT_PREP_RETENTION_DAYS, 30),
  };
}

/// The rating this account actually plays at, or null when Lichess will not say.
///
/// `null` is not "allowed". A floor that cannot be checked is a floor that is
/// not enforced, so the caller below refuses rather than waving it through —
/// the alternative is a guard that opens itself whenever the network is down.
async function lookupRating(handle, { fetchImpl, baseUrl, pacer, perfTypes }) {
  let res;
  try {
    res = await pacer.spaced(() => fetchImpl(
      `${baseUrl}/${encodeURIComponent(handle)}`,
      { headers: { Accept: 'application/json', 'User-Agent': USER_AGENT } },
    ));
  } catch (err) {
    throw new OpponentPrepUnavailable('Nema veze sa Lichess-om.', {
      reason: 'network', status: 502,
    });
  }
  if (res.status === 404) {
    throw new OpponentPrepUnavailable(`Lichess ne zna za nalog "${handle}".`, {
      reason: 'not-found', status: 404,
    });
  }
  if (res.status === 429) {
    pacer.block();
    throw new OpponentPrepUnavailable('Lichess je odbio zahtev zbog ograničenja.', {
      reason: 'rate-limited', status: 503,
    });
  }
  if (!res.ok) {
    throw new OpponentPrepUnavailable(`Lichess je odgovorio ${res.status}.`, {
      reason: 'network', status: 502,
    });
  }

  const body = await res.json();
  const perfs = body?.perfs || {};
  const wanted = perfTypes && perfTypes.length > 0 ? perfTypes : Object.keys(perfs);

  // The highest rating among the formats being prepared for. The highest and
  // not the average, because the floor is asking "is this a serious player",
  // and one strong format answers yes.
  let best = null;
  for (const perf of wanted) {
    const rating = perfs[perf]?.rating;
    // A provisional rating is a guess Lichess itself will not stand behind, and
    // it is exactly what a new account has — which is what the floor is for.
    if (!Number.isFinite(rating) || perfs[perf]?.prov) continue;
    if (best === null || rating > best) best = rating;
  }
  return best;
}

function createOpponentPrep({
  pool,
  importer,
  fetchImpl = (...args) => fetch(...args),
  baseUrl = DEFAULT_USER_URL,
  env = process.env,
  minGapMs = MIN_REQUEST_GAP_MS,
  cooldownMs = RATE_LIMIT_COOLDOWN_MS,
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  ratingOf = null,
} = {}) {
  if (!pool) throw new TypeError('createOpponentPrep requires a pool');
  if (!importer) throw new TypeError('createOpponentPrep requires an importer');

  const pacer = createPacer({ minGapMs, cooldownMs, now, sleep });
  const rating = ratingOf
    || ((handle, perfTypes) => lookupRating(handle, {
      fetchImpl, baseUrl, pacer, perfTypes,
    }));

  /// How many different people this account has already pulled today.
  ///
  /// Counted over the imports table rather than a counter of its own, because a
  /// separate counter is a second thing that can disagree with what happened.
  async function subjectsPulledToday(userId) {
    const { rows } = await pool.query(
      `SELECT COUNT(DISTINCT i.subject)::int AS subjects
         FROM user_game_imports i
        WHERE i.user_id = $1
          AND i.started_at > NOW() - INTERVAL '1 day'
          AND EXISTS (
            SELECT 1 FROM user_games g
             WHERE g.user_id = i.user_id AND g.subject = i.subject
               AND g.subject_is_owner = FALSE
          )`,
      [userId],
    );
    return rows[0]?.subjects ?? 0;
  }

  /// Everything that must be true before a single game is fetched.
  async function assertAllowed(userId, handle, { perfTypes = [] } = {}) {
    const policy = policyFrom(env);

    if (!policy.enabled) {
      // Loud, and by name. A feature that is off should say so rather than
      // return an empty report that reads like an opponent with no weaknesses.
      throw new OpponentPrepUnavailable(
        'Priprema za protivnika nije uključena na ovom serveru.',
        { reason: 'disabled', status: 403 },
      );
    }

    if (policy.maxSubjectsPerDay > 0) {
      const already = await subjectsPulledToday(userId);
      if (already >= policy.maxSubjectsPerDay) {
        throw new OpponentPrepUnavailable(
          `Danas je moguće pripremiti najviše ${policy.maxSubjectsPerDay} protivnika.`,
          { reason: 'too-many-subjects', status: 429 },
        );
      }
    }

    if (policy.minRating > 0) {
      const found = await rating(handle, perfTypes);
      if (found === null) {
        throw new OpponentPrepUnavailable(
          `Lichess ne daje rejting za "${handle}", pa priprema nije moguća.`,
          { reason: 'no-rating', status: 403 },
        );
      }
      if (found < policy.minRating) {
        // The message says the floor and not the rating. Reporting a named
        // person's rating back to whoever asked about them is the smaller half
        // of the same problem this floor exists for.
        throw new OpponentPrepUnavailable(
          `Priprema je moguća samo za igrače sa rejtingom ${policy.minRating} i više.`,
          { reason: 'below-rating-floor', status: 403 },
        );
      }
    }

    return policy;
  }

  /// Pulls an opponent's public archive, after the policy has said yes.
  async function prepare({ userId, subject, filters = {} }) {
    if (!Number.isInteger(userId)) throw new TypeError('userId is required');
    const handle = String(subject || '').trim();
    if (!handle) {
      throw new OpponentPrepUnavailable('Nedostaje korisničko ime protivnika.', {
        reason: 'bad-request', status: 400,
      });
    }

    const perfTypes = String(filters.perfType || '')
      .split(',').map((p) => p.trim()).filter(Boolean);
    await assertAllowed(userId, handle, { perfTypes });

    logger.info({ userId, subject: handle }, 'Opponent preparation started');

    // `subjectIsOwner: false` is the whole difference, and it is what every
    // read in `archiveScope.js` keys off. `incremental: false` because a
    // preparation pull is a fresh question with its own filters, not a resume
    // of whatever was fetched about this person last time.
    return importer.start({
      userId,
      subject: handle,
      source: 'lichess',
      subjectIsOwner: false,
      incremental: false,
      filters,
    });
  }

  /// Drops opponent archives past the retention window.
  ///
  /// Only `subject_is_owner = FALSE` rows, ever. The player's own archive is
  /// the one thing here that cannot be re-fetched — they uploaded a file — and
  /// this must never be the code that deletes it.
  async function forgetOldOpponents({ days = null } = {}) {
    const policy = policyFrom(env);
    const window = days === null ? policy.retentionDays : days;
    if (!Number.isFinite(window) || window <= 0) return { deleted: 0 };

    const { rowCount } = await pool.query(
      `DELETE FROM user_games
        WHERE subject_is_owner = FALSE
          AND imported_at < NOW() - ($1 || ' days')::interval`,
      [String(window)],
    );
    if (rowCount > 0) {
      logger.info(`[PRIPREMA] Obrisano ${rowCount} protivničkih partija starijih od ${window} dana.`);
    }
    return { deleted: rowCount };
  }

  return { prepare, assertAllowed, forgetOldOpponents, subjectsPulledToday };
}

module.exports = {
  createOpponentPrep,
  OpponentPrepUnavailable,
  policyFrom,
  lookupRating,
};
