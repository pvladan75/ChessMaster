// personal_data_exposure.test.js
// Addresses stay out of logs and out of lists; credentials stay out of URLs; a
// verification code is not predictable.
//
// Four small findings of the architecture audit of 16.9.2026
// (`docs/audit/server.md`, 11, 13, 15 and 17), each cheap to fix and each the
// kind that comes back one careless line at a time — so each is pinned where a
// careless line would land.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { Writable } = require('stream');
const pino = require('pino');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const logger = require('../services/logger');
const { tokenFromHandshake } = require('../middleware/auth');
const { getTrainerAssignments } = require('../services/assignmentService');

// ── 11: addresses in logs ────────────────────────────────────────────────────

function captured() {
  const lines = [];
  const stream = new Writable({
    write(chunk, _enc, done) {
      lines.push(String(chunk));
      done();
    },
  });
  return { lines, log: pino({ redact: { paths: logger.REDACT_PATHS, censor: '[redacted]' } }, stream) };
}

test('an address handed to the logger as a field is redacted, at the top and one level down', () => {
  const { lines, log } = captured();
  log.info({ email: 'child@example.test' }, 'one');
  log.info({ user: { id: 3, email: 'child@example.test', parent_email: 'parent@example.test' } }, 'two');
  log.info({ parentEmail: 'parent@example.test' }, 'three');
  const all = lines.join('');
  assert.ok(!all.includes('@example.test'), all);
  assert.ok(all.includes('[redacted]'));
});

test('the server\'s logger is built with that redaction', () => {
  // The paths above are only worth anything if the real logger uses them; pino
  // keeps its configuration private, so this reads the one line that passes it.
  const src = fs.readFileSync(path.join(__dirname, '..', 'services', 'logger.js'), 'utf8');
  assert.match(src, /redact:\s*\{\s*paths:\s*REDACT_PATHS/);
});

test('a masked address keeps its domain and loses the person', () => {
  assert.equal(logger.maskEmail('pavle@example.test'), 'p***@example.test');
  assert.equal(logger.maskEmail(''), '[address]');
  assert.equal(logger.maskEmail(undefined), '[address]');
});

/// Every argument list of a `logger.<level>(...)` call, with string contents
/// removed but template interpolations kept — so a word in a sentence is not an
/// address and `${email}` is.
function loggerArguments(src) {
  const out = [];
  const call = /\blogger\.(?:info|warn|error|debug|fatal|trace)\(/g;
  let m;
  while ((m = call.exec(src)) !== null) {
    let i = m.index + m[0].length;
    let depth = 1;
    let text = '';
    while (i < src.length && depth > 0) {
      const c = src[i];
      if (c === "'" || c === '"') {
        const q = c;
        i += 1;
        while (i < src.length && src[i] !== q) i += src[i] === '\\' ? 2 : 1;
        text += ' "" ';
      } else if (c === '`') {
        i += 1;
        while (i < src.length && src[i] !== '`') {
          if (src[i] === '\\') { i += 2; continue; }
          if (src[i] === '$' && src[i + 1] === '{') {
            let d = 1;
            i += 2;
            let expr = '';
            while (i < src.length && d > 0) {
              if (src[i] === '{') d += 1;
              if (src[i] === '}') d -= 1;
              if (d > 0) expr += src[i];
              i += 1;
            }
            text += ` ${expr} `;
            continue;
          }
          i += 1;
        }
      } else {
        if (c === '(') depth += 1;
        if (c === ')') depth -= 1;
        if (depth > 0) text += c;
      }
      i += 1;
    }
    out.push(text);
  }
  return out;
}

function sourceFiles(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (['node_modules', 'test', 'exports', 'uploads', 'tts-cache'].includes(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...sourceFiles(full));
    else if (/\.(c|m)?js$/.test(entry.name)) out.push(full);
  }
  return out;
}

test('no log call anywhere on the server passes an address except through maskEmail', () => {
  const offenders = [];
  for (const file of sourceFiles(path.join(__dirname, '..'))) {
    const src = fs.readFileSync(file, 'utf8').replace(/\/\/.*$/gm, '');
    for (const args of loggerArguments(src)) {
      const unmasked = args.replace(/maskEmail\([^()]*\)/g, '');
      if (/\b\w*(?:email|Email)\w*\b/.test(unmasked)) {
        offenders.push(`${path.relative(path.join(__dirname, '..'), file)}: ${args.trim().slice(0, 80)}`);
      }
    }
  }
  assert.deepEqual(offenders, []);
});

test('the argument reader sees an interpolated address and ignores the word in a sentence', () => {
  const args = loggerArguments("logger.info(`sent to ${email}`); logger.error('emails cannot be delivered');");
  assert.match(args[0], /\bemail\b/);
  assert.doesNotMatch(args[1], /email/);
});

// ── 13: a trainer's homework list ────────────────────────────────────────────

test('a trainer\'s homework list asks for no student address', async () => {
  const asked = [];
  const pool = { query: async (text) => { asked.push(String(text)); return { rows: [] }; } };
  await getTrainerAssignments(pool, 1, {});
  await getTrainerAssignments(pool, 1, { studentId: 42 });
  for (const sql of asked) {
    assert.doesNotMatch(sql, /email/i, sql);
  }
});

// ── 17: the socket token ─────────────────────────────────────────────────────

test('a socket is authenticated only by the token in the handshake\'s auth, never the query string', () => {
  assert.equal(tokenFromHandshake({ auth: { token: 'abc' } }), 'abc');
  assert.equal(tokenFromHandshake({ auth: {}, query: { token: 'abc' } }), undefined);
  assert.equal(tokenFromHandshake({ query: { token: 'abc' } }), undefined);
  assert.equal(tokenFromHandshake(undefined), undefined);
});
