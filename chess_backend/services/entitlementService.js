// entitlementService.js
// Provider-agnostic access rights.
//
// Nothing in here knows about Google Play, Paddle, or any other payment
// provider. A provider's only job is to write a row into `subscriptions`;
// everything downstream asks this service what a user is allowed to do. That
// keeps a second provider (Paddle for the web build) an additive change rather
// than a rewrite.

const logger = require('./logger');

/// Tiers, weakest first. A user's effective tier is the strongest of their
/// active subscription and the manual grant on users.account_type, so a comped
/// account is never downgraded by an expiring purchase and vice versa.
const TIERS = ['free', 'premium', 'pro', 'club'];

const ENT = {
  MP4_EXPORT: 'mp4_export',
  UNLIMITED_LESSONS: 'unlimited_lessons',
  UNLIMITED_SESSIONS: 'unlimited_sessions',
  AI_COMMENTS: 'ai_comments',
  ASSIGNMENTS: 'assignments',
};

/// Everything counted per user per month.
///
/// Some of these gate access (ai_comments has a quota); the rest exist purely so
/// the cost of serving one active trainer is a number we can look up instead of
/// guess. Voice, rendering and AI are all paid per use by the provider, and a
/// subscription priced without knowing that number is priced blind.
const METRIC = {
  AI_COMMENTS: 'ai_comments',
  AGORA_SECONDS: 'agora_seconds',
  MP4_RENDERS: 'mp4_renders',
  MP4_RENDER_SECONDS: 'mp4_render_seconds',
  // Pages put through the position scanner. Costs nothing to a provider — it is
  // our own CPU — but on a one-vCPU host that is the number that decides when a
  // bigger droplet is due, and it is invisible unless counted.
  SCANNED_PAGES: 'scanned_pages',
};

/// Metered features. -1 means unmetered.
///
/// Assignments are metered rather than locked on the free tier deliberately: a
/// trainer has to feel the feature work with a real student before a
/// subscription is worth anything to them, and a locked button demonstrates
/// nothing.
const QUOTAS = {
  free: { [ENT.AI_COMMENTS]: 10, [ENT.ASSIGNMENTS]: 5 },
  premium: { [ENT.AI_COMMENTS]: 500, [ENT.ASSIGNMENTS]: -1 },
  pro: { [ENT.AI_COMMENTS]: 2000, [ENT.ASSIGNMENTS]: -1 },
  club: { [ENT.AI_COMMENTS]: -1, [ENT.ASSIGNMENTS]: -1 },
};

const PAID_ENTITLEMENTS = [
  ENT.AI_COMMENTS,
  ENT.ASSIGNMENTS,
  ENT.MP4_EXPORT,
  ENT.UNLIMITED_LESSONS,
  ENT.UNLIMITED_SESSIONS,
];

const TIER_ENTITLEMENTS = {
  free: [ENT.AI_COMMENTS, ENT.ASSIGNMENTS],
  premium: PAID_ENTITLEMENTS,
  pro: PAID_ENTITLEMENTS,
  club: PAID_ENTITLEMENTS,
};

/// Subscription states that still grant access. A cancelled subscription keeps
/// its entitlements until the period the user already paid for runs out — the
/// alternative silently takes away access someone is still owed.
const ENTITLING_STATUSES = new Set(['active', 'grace', 'canceled']);

function tierRank(tier) {
  const idx = TIERS.indexOf(tier);
  return idx === -1 ? 0 : idx;
}

function highestTier(...tiers) {
  return tiers.reduce(
    (best, candidate) => (tierRank(candidate) > tierRank(best) ? candidate : best),
    'free'
  );
}

/// True when a subscription row currently grants its tier.
/// Pure: takes `now` so the boundary is testable without waiting for a clock.
function isSubscriptionEntitling(sub, now = new Date()) {
  if (!sub || !ENTITLING_STATUSES.has(sub.status)) return false;
  if (!sub.current_period_end) return sub.status === 'active';
  return new Date(sub.current_period_end).getTime() > now.getTime();
}

function entitlementsForTier(tier) {
  return TIER_ENTITLEMENTS[tier] || TIER_ENTITLEMENTS.free;
}

function quotaFor(tier, metric) {
  const tierQuotas = QUOTAS[tier] || QUOTAS.free;
  return tierQuotas[metric] === undefined ? 0 : tierQuotas[metric];
}

/// The first day of the month a timestamp falls in, in UTC — the period key
/// every usage counter is bucketed by.
function periodStart(now = new Date()) {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
}

/// Resolves the tier a user is actually on right now.
async function resolveTier(pool, userId, now = new Date()) {
  const [userRes, subsRes] = await Promise.all([
    pool.query('SELECT account_type FROM users WHERE id = $1', [userId]),
    pool.query(
      `SELECT tier, status, current_period_end FROM subscriptions
       WHERE user_id = $1 AND status = ANY($2::varchar[])`,
      [userId, [...ENTITLING_STATUSES]]
    ),
  ]);

  const manualTier = userRes.rows[0]?.account_type || 'free';
  const activeSubTiers = subsRes.rows
    .filter((sub) => isSubscriptionEntitling(sub, now))
    .map((sub) => sub.tier);

  return highestTier(manualTier, ...activeSubTiers);
}

/// Everything the client needs to render tier state in one round trip.
async function getEntitlementState(pool, userId, now = new Date()) {
  const tier = await resolveTier(pool, userId, now);
  const usageRes = await pool.query(
    'SELECT metric, used FROM usage_counters WHERE user_id = $1 AND period_start = $2',
    [userId, periodStart(now)]
  );

  const usage = {};
  for (const row of usageRes.rows) {
    usage[row.metric] = row.used;
  }

  const quotas = {};
  for (const metric of Object.keys(QUOTAS[tier] || QUOTAS.free)) {
    quotas[metric] = { limit: quotaFor(tier, metric), used: usage[metric] || 0 };
  }

  return {
    tier,
    entitlements: entitlementsForTier(tier),
    quotas,
    periodStart: periodStart(now).toISOString(),
  };
}

/// Reserves one unit of a metered feature, atomically.
///
/// The increment and the limit check are a single statement: a WHERE clause that
/// refuses the UPDATE once the quota is spent. Reading the count and then
/// writing it would let two concurrent requests both pass the check.
async function consumeQuota(pool, userId, metric, now = new Date()) {
  const tier = await resolveTier(pool, userId, now);
  const limit = quotaFor(tier, metric);

  if (limit === -1) return { allowed: true, tier, limit, used: null };
  if (limit === 0) return { allowed: false, tier, limit, used: 0 };

  const period = periodStart(now);
  const result = await pool.query(
    `INSERT INTO usage_counters (user_id, metric, period_start, used)
     VALUES ($1, $2, $3, 1)
     ON CONFLICT (user_id, metric, period_start) DO UPDATE
       SET used = usage_counters.used + 1, updated_at = CURRENT_TIMESTAMP
       WHERE usage_counters.used < $4
     RETURNING used`,
    [userId, metric, period, limit]
  );

  if (result.rows.length === 0) {
    return { allowed: false, tier, limit, used: limit };
  }
  return { allowed: true, tier, limit, used: result.rows[0].used };
}

/// Unit costs used to turn raw usage into an estimated bill, configured as JSON
/// so a provider's price change is an env edit rather than a deploy.
/// Values are in whatever currency the operator thinks in — the report only ever
/// multiplies, it never assumes a currency.
function loadUnitCosts() {
  const defaults = {
    [METRIC.AGORA_SECONDS]: 0,
    [METRIC.MP4_RENDER_SECONDS]: 0,
    [METRIC.AI_COMMENTS]: 0,
    [METRIC.MP4_RENDERS]: 0,
  };
  const raw = process.env.USAGE_UNIT_COSTS;
  if (!raw) return defaults;
  try {
    return { ...defaults, ...JSON.parse(raw) };
  } catch (err) {
    logger.error('USAGE_UNIT_COSTS is not valid JSON — cost estimates will read as zero.');
    return defaults;
  }
}

const UNIT_COSTS = loadUnitCosts();

/// Adds to a usage counter without enforcing anything.
///
/// Separate from consumeQuota on purpose: that one may refuse, this one only
/// records. Measuring must never be able to fail a user's request, so errors are
/// logged and swallowed rather than propagated.
async function recordUsage(pool, userId, metric, amount = 1, now = new Date()) {
  if (!userId || !Number.isFinite(amount) || amount <= 0) return;

  try {
    await pool.query(
      `INSERT INTO usage_counters (user_id, metric, period_start, used)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, metric, period_start) DO UPDATE
         SET used = usage_counters.used + EXCLUDED.used, updated_at = CURRENT_TIMESTAMP`,
      [userId, metric, periodStart(now), Math.round(amount)]
    );
  } catch (err) {
    logger.error({ userId, metric, amount }, `Failed to record usage: ${err.message}`);
  }
}

/// Per-user usage for one month, with an estimated cost per user.
/// Answers the question a subscription price depends on: what does one active
/// trainer actually cost to serve?
async function getUsageReport(pool, { month = null, userId = null } = {}) {
  const period = month ? new Date(`${month}-01T00:00:00Z`) : periodStart();

  const conditions = ['uc.period_start = $1'];
  const params = [period];
  if (userId) {
    params.push(userId);
    conditions.push(`uc.user_id = $${params.length}`);
  }

  const result = await pool.query(
    `SELECT uc.user_id, u.email, u.name, u.account_type, uc.metric, uc.used
     FROM usage_counters uc
     LEFT JOIN users u ON u.id = uc.user_id
     WHERE ${conditions.join(' AND ')}
     ORDER BY uc.user_id`,
    params
  );

  const byUser = new Map();
  for (const row of result.rows) {
    if (!byUser.has(row.user_id)) {
      byUser.set(row.user_id, {
        userId: row.user_id,
        email: row.email,
        name: row.name,
        accountType: row.account_type,
        metrics: {},
        estimatedCost: 0,
      });
    }
    const entry = byUser.get(row.user_id);
    entry.metrics[row.metric] = row.used;
    entry.estimatedCost += row.used * (UNIT_COSTS[row.metric] || 0);
  }

  const users = [...byUser.values()].map((entry) => ({
    ...entry,
    // Voice is recorded in seconds for accuracy; minutes are what a provider bills.
    agoraMinutes: Math.ceil((entry.metrics[METRIC.AGORA_SECONDS] || 0) / 60),
    estimatedCost: Number(entry.estimatedCost.toFixed(4)),
  }));

  users.sort((a, b) => b.estimatedCost - a.estimatedCost);

  return {
    periodStart: period.toISOString(),
    unitCosts: UNIT_COSTS,
    totalEstimatedCost: Number(users.reduce((sum, u) => sum + u.estimatedCost, 0).toFixed(4)),
    userCount: users.length,
    users,
  };
}

/// Writes a provider's view of a subscription into our own shape.
/// Keyed on (provider, provider_ref) so replaying the same notification — which
/// Google's Pub/Sub push does on any non-200 — updates instead of duplicating.
async function upsertSubscription(pool, { userId, provider, providerRef, productId, tier, status, currentPeriodEnd, autoRenewing, rawPayload }) {
  const result = await pool.query(
    `INSERT INTO subscriptions
       (user_id, provider, provider_ref, product_id, tier, status, current_period_end, auto_renewing, raw_payload)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     ON CONFLICT (provider, provider_ref) DO UPDATE SET
       user_id = COALESCE(subscriptions.user_id, EXCLUDED.user_id),
       product_id = EXCLUDED.product_id,
       tier = EXCLUDED.tier,
       status = EXCLUDED.status,
       current_period_end = EXCLUDED.current_period_end,
       auto_renewing = EXCLUDED.auto_renewing,
       raw_payload = EXCLUDED.raw_payload,
       updated_at = CURRENT_TIMESTAMP
     RETURNING *`,
    [
      userId, provider, providerRef, productId, tier, status,
      currentPeriodEnd, autoRenewing !== false, rawPayload ? JSON.stringify(rawPayload) : null,
    ]
  );

  const row = result.rows[0];
  logger.info(
    { userId: row.user_id, provider, productId, tier, status, periodEnd: currentPeriodEnd },
    'Subscription state written'
  );
  return row;
}

/// Finds the account a purchase token already belongs to, so a renewal
/// notification that arrives without a logged-in user still lands on the right
/// account.
async function findSubscriptionByRef(pool, provider, providerRef) {
  const result = await pool.query(
    'SELECT * FROM subscriptions WHERE provider = $1 AND provider_ref = $2',
    [provider, providerRef]
  );
  return result.rows[0] || null;
}

module.exports = {
  TIERS,
  ENT,
  METRIC,
  UNIT_COSTS,
  QUOTAS,
  TIER_ENTITLEMENTS,
  ENTITLING_STATUSES,
  tierRank,
  highestTier,
  isSubscriptionEntitling,
  entitlementsForTier,
  quotaFor,
  periodStart,
  resolveTier,
  getEntitlementState,
  consumeQuota,
  recordUsage,
  getUsageReport,
  upsertSubscription,
  findSubscriptionByRef,
};
