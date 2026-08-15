// playBillingService.js
// Google Play Billing adapter — the first provider behind entitlementService.
//
// Serbia is a merchant-supported location on Google Play, and Play Billing is
// mandatory for digital goods in an Android app anyway, so this is the rail the
// app monetizes through. Google is the merchant of record: it collects the
// money, handles VAT, and pays out. We only ever verify and record.
//
// Deliberately dependency-free: the service-account OAuth exchange is done with
// `jsonwebtoken` (already a dependency) and native fetch, rather than pulling in
// the whole `googleapis` client for two REST calls.

const jwt = require('jsonwebtoken');
const logger = require('./logger');

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || '';
const SA_EMAIL = process.env.GOOGLE_PLAY_SA_EMAIL || '';
// Private keys carry literal newlines that .env files cannot hold, so the
// conventional \n escaping is expanded here.
const SA_PRIVATE_KEY = (process.env.GOOGLE_PLAY_SA_PRIVATE_KEY || '').replace(/\\n/g, '\n');

/// Maps a Play product id to the tier it grants. Configured as JSON so adding a
/// price point never needs a code change.
function loadProductTierMap() {
  const raw = process.env.PLAY_PRODUCT_TIERS;
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (err) {
    logger.error('PLAY_PRODUCT_TIERS is not valid JSON — no Play product will map to a tier.');
    return {};
  }
}

const PRODUCT_TIERS = loadProductTierMap();

function isConfigured() {
  return Boolean(PACKAGE_NAME && SA_EMAIL && SA_PRIVATE_KEY);
}

/// Play's subscription states, mapped onto the vocabulary entitlementService
/// understands. Anything unrecognised is treated as not entitling.
const STATE_MAP = {
  SUBSCRIPTION_STATE_ACTIVE: 'active',
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'grace',
  SUBSCRIPTION_STATE_CANCELED: 'canceled',
  SUBSCRIPTION_STATE_ON_HOLD: 'on_hold',
  SUBSCRIPTION_STATE_PAUSED: 'paused',
  SUBSCRIPTION_STATE_EXPIRED: 'expired',
  SUBSCRIPTION_STATE_PENDING: 'pending',
  SUBSCRIPTION_STATE_UNSPECIFIED: 'unknown',
};

let cachedToken = null; // { value, expiresAt }

async function getAccessToken() {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }

  const now = Math.floor(Date.now() / 1000);
  const assertion = jwt.sign(
    { iss: SA_EMAIL, scope: SCOPE, aud: TOKEN_URL, iat: now, exp: now + 3600 },
    SA_PRIVATE_KEY,
    { algorithm: 'RS256' }
  );

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Google OAuth token exchange failed (${response.status}): ${detail.slice(0, 200)}`);
  }

  const data = await response.json();
  cachedToken = {
    value: data.access_token,
    expiresAt: Date.now() + (data.expires_in || 3600) * 1000,
  };
  return cachedToken.value;
}

async function callApi(path, { method = 'GET', body } = {}) {
  const token = await getAccessToken();
  const response = await fetch(`${API_BASE}/${encodeURIComponent(PACKAGE_NAME)}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return response;
}

/// Translates a subscriptionsv2 response into the shape upsertSubscription wants.
/// Exported separately from the network call so the mapping is unit-testable.
function normalizePurchase(purchase, productTiers = PRODUCT_TIERS) {
  const lineItem = (purchase.lineItems || [])[0] || {};
  const productId = lineItem.productId || '';
  const tier = productTiers[productId] || null;

  return {
    productId,
    tier,
    status: STATE_MAP[purchase.subscriptionState] || 'unknown',
    currentPeriodEnd: lineItem.expiryTime ? new Date(lineItem.expiryTime) : null,
    autoRenewing: Boolean(lineItem.autoRenewingPlan?.autoRenewEnabled),
    acknowledged: purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
    // Set when the buyer supplied it at purchase time; lets a renewal find its
    // account even if the row was somehow never written.
    obfuscatedAccountId: purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId || null,
  };
}

/// Asks Google what a purchase token is actually worth.
/// This is the only source of truth — a client claiming to have paid is not
/// evidence of payment, and neither is an RTDN message, which is why both paths
/// funnel through here.
async function getSubscription(purchaseToken) {
  if (!isConfigured()) {
    throw new Error('Google Play billing nije konfigurisan na serveru.');
  }

  const response = await callApi(
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`
  );

  if (response.status === 404 || response.status === 410) {
    return null;
  }
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Play API verification failed (${response.status}): ${detail.slice(0, 200)}`);
  }

  return normalizePurchase(await response.json());
}

/// Confirms delivery to Google.
///
/// This is not optional bookkeeping: Play automatically refunds and revokes any
/// purchase left unacknowledged for three days, so skipping it means customers
/// silently lose what they paid for.
async function acknowledge(purchaseToken, productId) {
  if (!isConfigured()) return false;

  const response = await callApi(
    `/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
    { method: 'POST', body: {} }
  );

  if (!response.ok) {
    const detail = await response.text();
    logger.error(`Play acknowledge failed (${response.status}): ${detail.slice(0, 200)}`);
    return false;
  }
  return true;
}

/// Unwraps a Pub/Sub push envelope into the developer notification inside it.
/// Pure, so the envelope handling is testable without a live subscription.
function decodeRtdnEnvelope(body) {
  const encoded = body?.message?.data;
  if (!encoded) return null;
  try {
    return JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
  } catch (err) {
    return null;
  }
}

module.exports = {
  isConfigured,
  getSubscription,
  acknowledge,
  normalizePurchase,
  decodeRtdnEnvelope,
  STATE_MAP,
  PRODUCT_TIERS,
  PACKAGE_NAME,
};
