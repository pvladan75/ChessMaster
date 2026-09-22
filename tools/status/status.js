// status.js — what the app's paid services have left, and what the app is doing.
//
//   node tools/status/status.js
//
// Read-only. It reads chess_backend/.env, asks each provider that *has* an API
// for a balance, and reads the database for what this app itself counted.
//
// Only some providers can answer "how much is left" through an API:
//
//   DeepSeek      yes — GET /user/balance, free to call.
//   DigitalOcean  yes, with a read-only API token in DIGITALOCEAN_TOKEN
//                 (month-to-date usage and balance). Not needed by the app.
//   Azure Speech  no — the subscription key proves the key works and nothing
//                 more; usage lives in Azure Monitor behind an Azure AD login.
//   Agora         no — the App ID and certificate mint tokens; usage needs the
//                 console's Customer ID/Secret.
//   Gemini        no — Google exposes no remaining-quota call. Not probed at
//                 all: the key is on the free tier, and every call counts.
//
// For the last three the answer is the app's own meter (`usage_counters`),
// set against the provider's free allowance. Those allowances are written
// below as they stood when this was written — check the console before relying
// on one.
//
// Lives in tools/ rather than chess_backend/ on purpose: nodemon watches every
// .js under chess_backend, and editing this file must not restart the server.

const path = require('path');
const { createRequire } = require('module');

const BACKEND = path.resolve(__dirname, '..', '..', 'chess_backend');
const backendRequire = createRequire(path.join(BACKEND, 'package.json'));
backendRequire('dotenv').config({ path: path.join(BACKEND, '.env') });

const { Pool } = backendRequire('pg');
const { buildSslConfig } = backendRequire('./db.js');
const { METRIC, UNIT_COSTS, ENTITLING_STATUSES } = backendRequire('./services/entitlementService.js');

const TIMEOUT_MS = 10000;

// Free allowances per calendar month, as published by each provider.
const FREE = {
  agoraMinutes: 10000, // Agora: 10,000 free minutes a month
  azureNeuralChars: 500000, // Azure Speech F0: 0.5M neural characters a month
};

// ---------------------------------------------------------------- printing

const lines = [];
const section = (title) => lines.push('', title, '-'.repeat(title.length));
const row = (label, value) => lines.push(`  ${label.padEnd(28)} ${value}`);
const fmt = (n) => Number(n).toLocaleString('en-US');
const pct = (used, of) => `${((100 * used) / of).toFixed(1)}%`;

async function getJson(url, headers = {}) {
  const res = await fetch(url, { headers, signal: AbortSignal.timeout(TIMEOUT_MS) });
  const body = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status} ${body.slice(0, 120)}`);
  return JSON.parse(body);
}

// ---------------------------------------------------------------- providers

async function deepseek() {
  const key = process.env.DEEPSEEK_API_KEY;
  if (!key) return row('DeepSeek', 'no DEEPSEEK_API_KEY');
  const base = (process.env.DEEPSEEK_URL || 'https://api.deepseek.com').replace(/\/+$/, '');
  const data = await getJson(`${base}/user/balance`, { Authorization: `Bearer ${key}` });
  for (const b of data.balance_infos || []) {
    row(
      'DeepSeek balance',
      `${b.total_balance} ${b.currency}  (topped up ${b.topped_up_balance}, granted ${b.granted_balance})`
    );
  }
  if (!data.is_available) row('DeepSeek', 'NOT AVAILABLE — balance too low to serve calls');
}

async function digitalocean() {
  const token = process.env.DIGITALOCEAN_TOKEN;
  if (!token) {
    return row('DigitalOcean', 'skipped — set DIGITALOCEAN_TOKEN (read-only scope) in chess_backend/.env');
  }
  const b = await getJson('https://api.digitalocean.com/v2/customers/my/balance', {
    Authorization: `Bearer ${token}`,
  });
  row('DigitalOcean this month', `$${b.month_to_date_usage} used`);
  // A balance here is what is owed, not what is left: DigitalOcean bills after use.
  row('DigitalOcean owed', `$${b.month_to_date_balance} this month, $${b.account_balance} carried over`);
}

async function azureSpeech() {
  const key = process.env.AZURE_SPEECH_KEY;
  const region = process.env.AZURE_SPEECH_REGION;
  if (!key || !region) return row('Azure Speech', 'not configured');
  const voices = await getJson(
    `https://${region}.tts.speech.microsoft.com/cognitiveservices/voices/list`,
    { 'Ocp-Apim-Subscription-Key': key }
  );
  row('Azure Speech key', `works (${voices.length} voices in ${region}); usage: Azure portal only`);
}

function configured(label, envName, note) {
  row(label, process.env[envName] ? `key set — ${note}` : `no ${envName}`);
}

// ---------------------------------------------------------------- database

async function database() {
  const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_DATABASE,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
    ssl: buildSslConfig(),
    connectionTimeoutMillis: TIMEOUT_MS,
    max: 1,
  });
  const one = async (sql) => (await pool.query(sql)).rows[0];

  try {
    // --- the app's own meter, this calendar month
    section('Metered this month (usage_counters)');
    const metered = await pool.query(
      `SELECT metric, SUM(used)::bigint AS used, COUNT(DISTINCT user_id)::int AS users
         FROM usage_counters
        WHERE period_start = date_trunc('month', CURRENT_DATE)::date
        GROUP BY metric ORDER BY metric`
    );
    const used = Object.fromEntries(metered.rows.map((r) => [r.metric, Number(r.used)]));
    if (metered.rows.length === 0) row('(nothing recorded yet this month)', '');
    let cost = 0;
    for (const r of metered.rows) {
      cost += Number(r.used) * (UNIT_COSTS[r.metric] || 0);
      row(r.metric, `${fmt(r.used)}  by ${r.users} user(s)`);
    }
    const priced = Object.values(UNIT_COSTS).some((c) => c > 0);
    row('estimated cost', priced ? `${cost.toFixed(2)} (USAGE_UNIT_COSTS)` : 'unknown — USAGE_UNIT_COSTS not set in .env');

    section('Against free allowances');
    const agoraMin = Math.ceil((used[METRIC.AGORA_SECONDS] || 0) / 60);
    row(
      'Agora voice',
      `${fmt(agoraMin)} / ${fmt(FREE.agoraMinutes)} min  (${pct(agoraMin, FREE.agoraMinutes)}), ` +
        `${fmt(FREE.agoraMinutes - agoraMin)} left`
    );
    row('Gemini AI comments', `${fmt(used[METRIC.AI_COMMENTS] || 0)} this month (free key: ~20 requests/day)`);
    row(
      'DeepSeek tutorials',
      `${fmt(used[METRIC.AI_TUTORIALS] || 0)} tutorials, ${fmt(used[METRIC.AI_TUTORIAL_TOKENS] || 0)} tokens`
    );
    row('Azure Speech', `not metered by the app — F0 allows ${fmt(FREE.azureNeuralChars)} chars/month`);

    // --- what the app is doing
    section('Accounts');
    const accounts = await pool.query(
      `SELECT COALESCE(account_type, 'free') AS t, COUNT(*)::int AS n,
              COUNT(*) FILTER (WHERE is_verified)::int AS verified
         FROM users GROUP BY 1 ORDER BY 2 DESC`
    );
    for (const r of accounts.rows) row(`${r.t}`, `${r.n}  (${r.verified} verified)`);
    const rel = await one(
      `SELECT COUNT(*) FILTER (WHERE status = 'accepted')::int AS accepted,
              COUNT(*) FILTER (WHERE status <> 'accepted')::int AS pending
         FROM trainer_students`
    );
    row('trainer–student links', `${rel.accepted} accepted, ${rel.pending} not yet`);
    const subs = (
      await pool.query(`SELECT COUNT(*)::int AS n FROM subscriptions WHERE status = ANY($1)`, [
        [...ENTITLING_STATUSES],
      ])
    ).rows[0];
    row('paying subscriptions', `${subs.n}`);

    section('Last 7 days');
    const puzzles = await one(
      `SELECT COUNT(*)::int AS attempts, COUNT(DISTINCT user_id)::int AS users
         FROM user_puzzle_attempts WHERE created_at > NOW() - INTERVAL '7 days'`
    );
    row('puzzle attempts', `${fmt(puzzles.attempts)} by ${puzzles.users} user(s)`);
    const rooms = await one(
      `SELECT COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days')::int AS started,
              COUNT(*) FILTER (WHERE status = 'active' AND ended_at IS NULL)::int AS live
         FROM rooms`
    );
    row('sessions started', `${rooms.started}  (live now: ${rooms.live})`);
    const hw = await one(
      `SELECT COUNT(*)::int AS n FROM homeworks WHERE updated_at > NOW() - INTERVAL '7 days'`
    );
    row('homeworks touched', `${hw.n}`);
  } finally {
    await pool.end();
  }
}

// ---------------------------------------------------------------- main

async function step(fn) {
  try {
    await fn();
  } catch (err) {
    // Loud, and the next step still runs: one provider being down must not
    // hide the others.
    row(`!! ${fn.name} failed`, err.message);
    process.exitCode = 1;
  }
}

(async () => {
  lines.push(`Status  ${new Date().toISOString().replace('T', ' ').slice(0, 16)} UTC`);

  section('Provider balances (live)');
  await step(deepseek);
  await step(digitalocean);
  await step(azureSpeech);
  configured('Gemini', 'GEMINI_API_KEY', 'no quota API, not probed');
  configured('Agora', 'AGORA_APP_ID', 'no usage API with these credentials');

  await step(database);

  console.log(lines.join('\n'));
})();
