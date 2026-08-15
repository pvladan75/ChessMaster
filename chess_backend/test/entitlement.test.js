// entitlement.test.js
// Covers the pure decision logic behind paid access — the part where a mistake
// either gives a feature away or takes away something someone paid for.
//
// Run with: npm test   (node:test, no test framework dependency)

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  ENT,
  tierRank,
  highestTier,
  isSubscriptionEntitling,
  entitlementsForTier,
  quotaFor,
  periodStart,
} = require('../services/entitlementService');

const { normalizePurchase, decodeRtdnEnvelope } = require('../services/playBillingService');

test('tier ordering places every paid tier above free', () => {
  assert.ok(tierRank('premium') > tierRank('free'));
  assert.ok(tierRank('pro') > tierRank('premium'));
  assert.ok(tierRank('club') > tierRank('pro'));
  assert.equal(tierRank('nonsense'), 0);
});

test('highestTier keeps a manual grant when the subscription is weaker', () => {
  // An admin comping someone to club must not be downgraded by their own
  // premium purchase.
  assert.equal(highestTier('club', 'premium'), 'club');
  assert.equal(highestTier('free', 'premium'), 'premium');
  assert.equal(highestTier('free', 'free'), 'free');
  assert.equal(highestTier(), 'free');
});

test('an active subscription with a future period end is entitling', () => {
  const now = new Date('2026-08-15T12:00:00Z');
  assert.equal(
    isSubscriptionEntitling(
      { status: 'active', current_period_end: '2026-09-15T12:00:00Z' },
      now
    ),
    true
  );
});

test('a cancelled subscription keeps access until the paid period runs out', () => {
  const now = new Date('2026-08-15T12:00:00Z');
  // Cancelled but still inside the period the user paid for.
  assert.equal(
    isSubscriptionEntitling(
      { status: 'canceled', current_period_end: '2026-08-20T00:00:00Z' },
      now
    ),
    true
  );
  // Same subscription, after the period ended.
  assert.equal(
    isSubscriptionEntitling(
      { status: 'canceled', current_period_end: '2026-08-10T00:00:00Z' },
      now
    ),
    false
  );
});

test('expired, on-hold and paused subscriptions grant nothing', () => {
  const now = new Date('2026-08-15T12:00:00Z');
  const future = '2026-12-01T00:00:00Z';
  for (const status of ['expired', 'on_hold', 'paused', 'pending', 'unknown']) {
    assert.equal(
      isSubscriptionEntitling({ status, current_period_end: future }, now),
      false,
      `status '${status}' must not entitle`
    );
  }
});

test('an active subscription without an expiry is entitling, a cancelled one is not', () => {
  assert.equal(isSubscriptionEntitling({ status: 'active', current_period_end: null }), true);
  assert.equal(isSubscriptionEntitling({ status: 'canceled', current_period_end: null }), false);
  assert.equal(isSubscriptionEntitling(null), false);
});

test('free accounts do not carry the paid entitlements', () => {
  const free = entitlementsForTier('free');
  assert.ok(!free.includes(ENT.MP4_EXPORT));
  assert.ok(!free.includes(ENT.UNLIMITED_SESSIONS));
  assert.ok(free.includes(ENT.AI_COMMENTS)); // metered, not absent

  for (const tier of ['premium', 'pro', 'club']) {
    assert.ok(entitlementsForTier(tier).includes(ENT.MP4_EXPORT), `${tier} must include MP4 export`);
  }
});

test('an unknown tier falls back to free rather than granting everything', () => {
  assert.deepEqual(entitlementsForTier('enterprise_ultra'), entitlementsForTier('free'));
  assert.equal(quotaFor('enterprise_ultra', ENT.AI_COMMENTS), quotaFor('free', ENT.AI_COMMENTS));
});

test('quota grows with tier and -1 marks unmetered', () => {
  assert.equal(quotaFor('free', ENT.AI_COMMENTS), 10);
  assert.equal(quotaFor('premium', ENT.AI_COMMENTS), 500);
  assert.equal(quotaFor('club', ENT.AI_COMMENTS), -1);
  // An unknown metric must default to zero, never to unlimited.
  assert.equal(quotaFor('premium', 'teleportation'), 0);
});

test('usage periods bucket by UTC month', () => {
  assert.equal(periodStart(new Date('2026-08-31T23:59:59Z')).toISOString(), '2026-08-01T00:00:00.000Z');
  assert.equal(periodStart(new Date('2026-09-01T00:00:00Z')).toISOString(), '2026-09-01T00:00:00.000Z');
});

test('a Play purchase maps onto our subscription shape', () => {
  const purchase = normalizePurchase(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      lineItems: [
        {
          productId: 'coach_pro_monthly',
          expiryTime: '2026-09-15T10:00:00Z',
          autoRenewingPlan: { autoRenewEnabled: true },
        },
      ],
    },
    { coach_pro_monthly: 'premium' }
  );

  assert.equal(purchase.tier, 'premium');
  assert.equal(purchase.status, 'active');
  assert.equal(purchase.autoRenewing, true);
  assert.equal(purchase.acknowledged, false);
  assert.equal(purchase.currentPeriodEnd.toISOString(), '2026-09-15T10:00:00.000Z');
});

test('an unmapped Play product yields no tier instead of a default one', () => {
  // Guards the case where a new price point ships before PLAY_PRODUCT_TIERS is
  // updated: it must fail closed, not hand out premium.
  const purchase = normalizePurchase(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ productId: 'some_new_sku', expiryTime: '2026-09-15T10:00:00Z' }],
    },
    { coach_pro_monthly: 'premium' }
  );
  assert.equal(purchase.tier, null);
});

test('Play grace period is treated as still-paid, on hold is not', () => {
  const base = { lineItems: [{ productId: 'p', expiryTime: '2026-09-15T10:00:00Z' }] };
  const tiers = { p: 'premium' };

  const grace = normalizePurchase({ ...base, subscriptionState: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' }, tiers);
  assert.equal(grace.status, 'grace');
  assert.equal(isSubscriptionEntitling({ status: grace.status, current_period_end: grace.currentPeriodEnd }, new Date('2026-08-15T00:00:00Z')), true);

  const onHold = normalizePurchase({ ...base, subscriptionState: 'SUBSCRIPTION_STATE_ON_HOLD' }, tiers);
  assert.equal(onHold.status, 'on_hold');
  assert.equal(isSubscriptionEntitling({ status: onHold.status, current_period_end: onHold.currentPeriodEnd }, new Date('2026-08-15T00:00:00Z')), false);
});

test('RTDN envelopes decode, and malformed ones return null instead of throwing', () => {
  const notification = {
    version: '1.0',
    packageName: 'com.example.chess',
    subscriptionNotification: { notificationType: 2, purchaseToken: 'tok_123', subscriptionId: 'coach_pro_monthly' },
  };
  const envelope = {
    message: { data: Buffer.from(JSON.stringify(notification)).toString('base64') },
  };

  assert.deepEqual(decodeRtdnEnvelope(envelope), notification);
  assert.equal(decodeRtdnEnvelope({ message: { data: 'not-base64-json' } }), null);
  assert.equal(decodeRtdnEnvelope({}), null);
  assert.equal(decodeRtdnEnvelope(null), null);
});
