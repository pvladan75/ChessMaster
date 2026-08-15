// entitlements.js
// Route guards for paid features.
//
// These sit on the server on purpose. The client already hides locked features,
// but hiding a button is presentation, not enforcement — anyone can call the
// endpoint directly.

const logger = require('../services/logger');
const { pool } = require('../db');
const entitlements = require('../services/entitlementService');

/// Blocks a route unless the caller's tier includes `entitlement`.
function requireEntitlement(entitlement) {
  return async (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Prijava je obavezna.' });
    }

    try {
      const tier = await entitlements.resolveTier(pool, req.user.id);
      if (!entitlements.entitlementsForTier(tier).includes(entitlement)) {
        return res.status(403).json({
          error: 'Ova funkcija je dostupna uz Premium nalog.',
          upgradeRequired: true,
          entitlement,
          tier,
        });
      }
      req.tier = tier;
      next();
    } catch (err) {
      logger.error('Entitlement check failed:', err);
      res.status(500).json({ error: 'Greška pri proveri prava pristupa.' });
    }
  };
}

/// Blocks a route once the caller has spent their monthly allowance of `metric`,
/// and reserves one unit for the request that passes.
///
/// The unit is reserved before the handler runs, so a burst of parallel requests
/// cannot all slip past the limit. A handler that fails should hand the unit
/// back with `refundQuota`.
function requireQuota(metric) {
  return async (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Prijava je obavezna.' });
    }

    try {
      const result = await entitlements.consumeQuota(pool, req.user.id, metric);
      if (!result.allowed) {
        return res.status(403).json({
          error: `Potrošili ste mesečnu kvotu (${result.limit}). Pređite na Premium za veću.`,
          quotaExceeded: true,
          metric,
          limit: result.limit,
          tier: result.tier,
        });
      }
      req.quota = { metric, ...result };
      next();
    } catch (err) {
      logger.error('Quota check failed:', err);
      res.status(500).json({ error: 'Greška pri proveri kvote.' });
    }
  };
}

/// Returns a reserved unit after a handler failed, so a server-side error does
/// not cost the user part of their allowance.
async function refundQuota(req) {
  if (!req.quota || !req.user) return;
  try {
    await pool.query(
      `UPDATE usage_counters SET used = GREATEST(used - 1, 0), updated_at = CURRENT_TIMESTAMP
       WHERE user_id = $1 AND metric = $2 AND period_start = $3`,
      [req.user.id, req.quota.metric, entitlements.periodStart()]
    );
  } catch (err) {
    logger.error('Quota refund failed:', err);
  }
}

module.exports = { requireEntitlement, requireQuota, refundQuota };
