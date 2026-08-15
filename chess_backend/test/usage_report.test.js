// usage_report.test.js
// Covers the cost report's aggregation against a stubbed pool, so the shape and
// the arithmetic are pinned without needing a database.

const test = require('node:test');
const assert = require('node:assert/strict');

const { METRIC, getUsageReport, recordUsage, periodStart } = require('../services/entitlementService');

/// Minimal pg-pool stand-in: records queries and replays canned rows.
function stubPool(rows = []) {
  const calls = [];
  return {
    calls,
    async query(text, params) {
      calls.push({ text, params });
      return { rows };
    },
  };
}

test('the report groups a user\'s metrics and converts voice seconds to minutes', async () => {
  const pool = stubPool([
    { user_id: 7, email: 't@example.com', name: 'Trener', account_type: 'premium', metric: METRIC.AGORA_SECONDS, used: 3700 },
    { user_id: 7, email: 't@example.com', name: 'Trener', account_type: 'premium', metric: METRIC.AI_COMMENTS, used: 12 },
  ]);

  const report = await getUsageReport(pool, { month: '2026-08' });

  assert.equal(report.userCount, 1);
  assert.equal(report.periodStart, '2026-08-01T00:00:00.000Z');

  const user = report.users[0];
  assert.equal(user.email, 't@example.com');
  assert.equal(user.metrics[METRIC.AI_COMMENTS], 12);
  // Providers bill whole minutes, so a partial minute rounds up.
  assert.equal(user.agoraMinutes, 62);
});

test('users are ranked by estimated cost, most expensive first', async () => {
  process.env.USAGE_UNIT_COSTS = JSON.stringify({ [METRIC.AI_COMMENTS]: 1 });
  // Re-require so the module re-reads the env it captured at load time.
  delete require.cache[require.resolve('../services/entitlementService')];
  const svc = require('../services/entitlementService');

  const pool = stubPool([
    { user_id: 1, email: 'a@x', name: 'A', account_type: 'free', metric: svc.METRIC.AI_COMMENTS, used: 3 },
    { user_id: 2, email: 'b@x', name: 'B', account_type: 'premium', metric: svc.METRIC.AI_COMMENTS, used: 40 },
  ]);

  const report = await svc.getUsageReport(pool, {});

  assert.equal(report.users[0].userId, 2, 'the costliest user must sort first');
  assert.equal(report.users[0].estimatedCost, 40);
  assert.equal(report.totalEstimatedCost, 43);

  delete process.env.USAGE_UNIT_COSTS;
  delete require.cache[require.resolve('../services/entitlementService')];
});

test('an empty month reports zero rather than failing', async () => {
  const report = await getUsageReport(stubPool([]), { month: '2026-01' });
  assert.equal(report.userCount, 0);
  assert.equal(report.totalEstimatedCost, 0);
  assert.deepEqual(report.users, []);
});

test('recordUsage writes an additive increment for the current period', async () => {
  const pool = stubPool([]);
  await recordUsage(pool, 42, METRIC.AGORA_SECONDS, 125, new Date('2026-08-15T10:00:00Z'));

  assert.equal(pool.calls.length, 1);
  const { text, params } = pool.calls[0];
  assert.match(text, /usage_counters\.used \+ EXCLUDED\.used/, 'must add to the existing count, not replace it');
  assert.deepEqual(params.slice(0, 2), [42, METRIC.AGORA_SECONDS]);
  assert.equal(params[3], 125);
  assert.equal(params[2].toISOString(), periodStart(new Date('2026-08-15T10:00:00Z')).toISOString());
});

test('recordUsage ignores meaningless amounts instead of writing noise', async () => {
  const pool = stubPool([]);
  await recordUsage(pool, 42, METRIC.AGORA_SECONDS, 0);
  await recordUsage(pool, 42, METRIC.AGORA_SECONDS, -5);
  await recordUsage(pool, 42, METRIC.AGORA_SECONDS, NaN);
  await recordUsage(pool, null, METRIC.AGORA_SECONDS, 60); // guest, billed to nobody

  assert.equal(pool.calls.length, 0);
});

test('a failing database never propagates out of recordUsage', async () => {
  // Measuring must not be able to break the request it is measuring.
  const brokenPool = {
    async query() {
      throw new Error('connection reset');
    },
  };

  await assert.doesNotReject(() => recordUsage(brokenPool, 1, METRIC.MP4_RENDERS, 1));
});
