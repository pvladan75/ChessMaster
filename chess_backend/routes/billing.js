// billing.js
// Purchase verification and subscription lifecycle.
//
// The rule this file is built around: a purchase is only real once Google says
// it is. Neither the app ("I paid") nor a webhook payload ("someone paid") is
// treated as evidence — both paths re-fetch the purchase from the Play
// Developer API and record what *it* returns.

const crypto = require('crypto');
const express = require('express');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken, requireRole } = require('../middleware/auth');
const entitlements = require('../services/entitlementService');
const play = require('../services/playBillingService');

const PROVIDER = 'google_play';
const RTDN_SECRET = process.env.PLAY_RTDN_SECRET || '';

/// Constant-time comparison so the shared secret cannot be recovered by timing
/// the endpoint's responses.
function secretMatches(supplied) {
  if (!RTDN_SECRET || typeof supplied !== 'string') return false;
  const a = Buffer.from(supplied);
  const b = Buffer.from(RTDN_SECRET);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

/// Fetches the purchase from Google and writes what it says.
/// Shared by the client-initiated path and the notification path so both can
/// never disagree about what a token means.
async function syncPurchase(purchaseToken, fallbackUserId = null) {
  const purchase = await play.getSubscription(purchaseToken);
  if (!purchase) {
    return { ok: false, reason: 'Kupovina nije pronađena kod Google-a.' };
  }
  if (!purchase.tier) {
    logger.warn(`Play product '${purchase.productId}' is not mapped in PLAY_PRODUCT_TIERS.`);
    return { ok: false, reason: 'Proizvod nije prepoznat na serveru.' };
  }

  const existing = await entitlements.findSubscriptionByRef(pool, PROVIDER, purchaseToken);
  const userId = existing?.user_id || fallbackUserId;
  if (!userId) {
    return { ok: false, reason: 'Kupovina nije povezana ni sa jednim nalogom.' };
  }

  const row = await entitlements.upsertSubscription(pool, {
    userId,
    provider: PROVIDER,
    providerRef: purchaseToken,
    productId: purchase.productId,
    tier: purchase.tier,
    status: purchase.status,
    currentPeriodEnd: purchase.currentPeriodEnd,
    autoRenewing: purchase.autoRenewing,
    rawPayload: purchase,
  });

  // Play revokes and refunds anything left unacknowledged for three days.
  if (!purchase.acknowledged && entitlements.ENTITLING_STATUSES.has(purchase.status)) {
    const acked = await play.acknowledge(purchaseToken, purchase.productId);
    if (!acked) {
      logger.error(`Purchase ${row.id} could not be acknowledged — Google will refund it in 3 days.`);
    }
  }

  return { ok: true, subscription: row };
}

// GET /billing/config — what the client needs to decide whether to offer a purchase.
router.get('/config', (req, res) => {
  res.json({
    playConfigured: play.isConfigured(),
    productIds: Object.keys(play.PRODUCT_TIERS),
  });
});

// GET /billing/entitlements — current tier, rights and quota usage.
router.get('/entitlements', authenticateToken, async (req, res) => {
  try {
    res.json(await entitlements.getEntitlementState(pool, req.user.id));
  } catch (err) {
    logger.error('Error reading entitlements:', err);
    res.status(500).json({ error: 'Greška pri čitanju prava pristupa.' });
  }
});

// GET /billing/usage?month=YYYY-MM — what serving each user actually costs.
//
// Admin-only: it lists every user's email alongside their consumption, which is
// operational data, not something a customer should be able to read.
router.get('/usage', authenticateToken, requireRole('admin'), async (req, res) => {
  const { month } = req.query;

  if (month !== undefined && !/^\d{4}-\d{2}$/.test(month)) {
    return res.status(400).json({ error: 'Parametar month mora biti u obliku YYYY-MM.' });
  }

  try {
    res.json(await entitlements.getUsageReport(pool, { month: month || null }));
  } catch (err) {
    logger.error('Error building usage report:', err);
    res.status(500).json({ error: 'Greška pri izradi izveštaja o potrošnji.' });
  }
});

// GET /billing/usage/me — the caller's own consumption, no other account's.
router.get('/usage/me', authenticateToken, async (req, res) => {
  try {
    const report = await entitlements.getUsageReport(pool, { userId: req.user.id });
    const own = report.users[0];
    // Deliberately without estimatedCost or unitCosts — what serving a customer
    // costs us is our business, not theirs.
    res.json({
      periodStart: report.periodStart,
      metrics: own?.metrics || {},
      agoraMinutes: own?.agoraMinutes || 0,
    });
  } catch (err) {
    logger.error('Error reading own usage:', err);
    res.status(500).json({ error: 'Greška pri čitanju potrošnje.' });
  }
});

// POST /billing/play/verify — called by the app right after a successful purchase.
//
// The app tells us *which* token to look at; it never tells us what the token is
// worth. Binding happens here, on the authenticated user.
router.post('/play/verify', authenticateToken, async (req, res) => {
  const { purchaseToken } = req.body;

  if (!purchaseToken || typeof purchaseToken !== 'string') {
    return res.status(400).json({ error: 'purchaseToken je obavezan.' });
  }
  if (!play.isConfigured()) {
    return res.status(503).json({ error: 'Naplata trenutno nije dostupna.' });
  }

  try {
    const existing = await entitlements.findSubscriptionByRef(pool, PROVIDER, purchaseToken);
    if (existing && existing.user_id !== req.user.id) {
      // One purchase, one account. Otherwise a token shared between friends
      // would upgrade all of them.
      logger.warn(
        { userId: req.user.id, ownerId: existing.user_id },
        'Rejected purchase token already bound to another account'
      );
      return res.status(409).json({ error: 'Ova kupovina je već vezana za drugi nalog.' });
    }

    const result = await syncPurchase(purchaseToken, req.user.id);
    if (!result.ok) {
      return res.status(400).json({ error: result.reason });
    }

    res.json({
      success: true,
      ...(await entitlements.getEntitlementState(pool, req.user.id)),
    });
  } catch (err) {
    logger.error('Play purchase verification failed:', err);
    res.status(502).json({ error: 'Google nije potvrdio kupovinu. Pokušajte ponovo.' });
  }
});

// POST /billing/play/rtdn?key=... — Google Pub/Sub push for renewals, cancellations,
// expiries and refunds.
//
// Unauthenticated by nature, so it is guarded two ways: a shared secret in the
// URL, and the fact that the payload is only ever used to learn *which* token to
// re-check. A forged notification can therefore not grant anything.
router.post('/play/rtdn', async (req, res) => {
  if (!secretMatches(req.query.key)) {
    logger.warn('Rejected RTDN push with a bad or missing key.');
    return res.status(403).json({ error: 'Forbidden' });
  }

  const notification = play.decodeRtdnEnvelope(req.body);
  if (!notification) {
    // Malformed and unfixable by retrying — acknowledge so Pub/Sub stops.
    logger.warn('Discarded an RTDN push with an undecodable envelope.');
    return res.status(200).json({ received: true, handled: false });
  }

  if (notification.testNotification) {
    logger.info('Received the Play RTDN test notification — endpoint is wired up.');
    return res.status(200).json({ received: true, test: true });
  }

  const purchaseToken = notification.subscriptionNotification?.purchaseToken;
  if (!purchaseToken) {
    // Voided-purchase and one-time-product notifications land here; nothing to do yet.
    return res.status(200).json({ received: true, handled: false });
  }

  try {
    const result = await syncPurchase(purchaseToken);
    if (!result.ok) {
      logger.warn(`RTDN for an unusable purchase token: ${result.reason}`);
      return res.status(200).json({ received: true, handled: false });
    }
    return res.status(200).json({ received: true, handled: true });
  } catch (err) {
    // A transient Google outage: fail loudly so Pub/Sub redelivers rather than
    // dropping a renewal on the floor.
    logger.error('RTDN processing failed, asking Pub/Sub to retry:', err);
    return res.status(500).json({ error: 'Retry' });
  }
});

module.exports = router;
