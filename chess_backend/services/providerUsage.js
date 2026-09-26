// providerUsage.js
// How hard this server leans on a service that is free to it but not to its
// owner: Lichess's tablebase and cloud evaluation, and our own tablebase.
//
// `usage_counters` answers "what does one account cost a month" and is keyed
// by the account; that is the pricing question. This table answers a different
// one — "how many requests did the whole server send a donated service today"
// — which nobody can answer from per-account rows, because a homework judged
// on the server, a review asked from a phone and a room's endgame drill all
// reach the same service, and only some of those calls know which account
// caused them. So the key is the provider and the day, nothing else.
//
// Recording must never be able to fail the request it counts (CLAUDE.md, „do
// the thing, then say it"): every write here logs and swallows its error, and
// the hooks handed to the services are fire-and-forget.

const logger = require('./logger');

/// The names a day's row can carry. A provider missing from here is a typo
/// waiting to become a column nobody reads.
const PROVIDER = Object.freeze({
  LICHESS_TABLEBASE: 'lichess_tablebase',
  LOCAL_TABLEBASE: 'local_tablebase',
  LICHESS_CLOUD_EVAL: 'lichess_cloud_eval',
  LICHESS_GAMES: 'lichess_games',
  LICHESS_USER: 'lichess_user',
});

const KNOWN = new Set(Object.values(PROVIDER));

/// The UTC calendar day a moment falls in, as the DATE the row is keyed by.
/// UTC on purpose: `usage_counters` buckets by UTC month, and two clocks in
/// one report is one clock too many.
function dayOf(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

/// Adds `amount` requests to today's row for `provider`. Resolves either way.
async function recordProviderRequest(pool, provider, amount = 1, now = new Date()) {
  if (!KNOWN.has(provider)) {
    logger.error({ provider }, 'Refusing to count requests for an unknown provider');
    return;
  }
  if (!Number.isFinite(amount) || amount <= 0) return;
  try {
    await pool.query(
      `INSERT INTO provider_requests (provider, day, requests)
       VALUES ($1, $2, $3)
       ON CONFLICT (provider, day) DO UPDATE
         SET requests = provider_requests.requests + EXCLUDED.requests,
             updated_at = CURRENT_TIMESTAMP`,
      [provider, dayOf(now), Math.round(amount)],
    );
  } catch (err) {
    logger.error({ provider, amount }, `Failed to count a provider request: ${err.message}`);
  }
}

/// Hands each service the hook it calls once per request it sends, with the
/// pool bound in. The services themselves take no pool and no hook by default,
/// so a test that builds one never touches a database — only the server, once
/// at startup, wires these.
function wireProviderMeters({ pool, tablebase = null, openingJudge = null }) {
  if (tablebase) {
    tablebase.setOnRequest((kind) => {
      recordProviderRequest(
        pool,
        kind === 'local' ? PROVIDER.LOCAL_TABLEBASE : PROVIDER.LICHESS_TABLEBASE,
      );
    });
  }
  if (openingJudge) {
    openingJudge.setOnRequest(() => {
      recordProviderRequest(pool, PROVIDER.LICHESS_CLOUD_EVAL);
    });
  }
}

/// A hook for a service built where the pool is already known (the archive
/// importer, the opponent lookup): one call, one request counted.
function providerHook(pool, provider) {
  return () => { recordProviderRequest(pool, provider); };
}

module.exports = {
  PROVIDER,
  dayOf,
  recordProviderRequest,
  wireProviderMeters,
  providerHook,
};
