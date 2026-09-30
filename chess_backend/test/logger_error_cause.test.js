// logger_error_cause.test.js
// An error handed to the logger reaches the log.
//
// pino reads `logger.error('message:', err)` as a message and a value for a
// `%s` in it. With no placeholder in the message the value is dropped without
// a word — so for as long as the server wrote its error lines in that shape,
// 156 calls on 30.9.2026 and most of its error logging, every one of them
// printed the sentence and lost the error. The owner saw it as an AUTH line
// with no cause while the managed database briefly did not answer. The shape
// pino reads is `logger.error({ err }, 'message:')`.
//
// The first half reads every server source by its tokens (`support/jsTokens.js`,
// never by text: a comment, a string or a comma inside `${…}` would fool a
// regex) and fails when a call in the old shape comes back. The second half
// drives the path the owner saw and reads what the logger actually wrote.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const pino = require('pino');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const { tokenize, lineOf } = require('./support/jsTokens');

const ROOT = path.join(__dirname, '..');
const LEVELS = new Set(['fatal', 'error', 'warn', 'info', 'debug', 'trace']);

/// Every token list in [tokens], the ones inside each template's `${…}`
/// included — a call can stand there too.
function* tokenLists(tokens) {
  yield tokens;
  for (const token of tokens) {
    for (const inner of token.inner ?? []) yield* tokenLists(inner);
  }
}

/// The names under which a file holds the server's logger: `logger` itself,
/// and whatever is bound to it — `log = logger` (a default parameter, as in
/// `tablebaseService.js`), `x = logger.child(…)`, or a require or import of
/// `…/logger`.
function receiversIn(tokens) {
  const names = new Set(['logger']);
  for (const list of tokenLists(tokens)) {
    for (let k = 0; k < list.length; k += 1) {
      const [name, eq, value, after, next] = list.slice(k, k + 5);
      if (name?.type !== 'ident') continue;
      if (eq?.value === '=' && eq.type === 'punct' && value?.type === 'ident') {
        const bare = value.value === 'logger'
          && !(after?.type === 'punct' && ['.', '(', '[', '?'].includes(after.value));
        const child = value.value === 'logger' && after?.value === '.' && next?.value === 'child';
        const required = value.value === 'require' && after?.value === '('
          && next?.type === 'string' && /(^|\/)logger(\.js)?$/.test(next.value);
        if (bare || child || required) names.add(name.value);
      }
      if (list[k - 1]?.value === 'import' && eq?.value === 'from'
        && value?.type === 'string' && /(^|\/)logger(\.js)?$/.test(value.value)) {
        names.add(name.value);
      }
    }
  }
  return names;
}

/// Every `<logger>.<level>(…)` call in [tokens], with its arguments split at
/// the commas that separate them — never at one inside brackets or a template.
function loggerCalls(tokens) {
  const receivers = receiversIn(tokens);
  const calls = [];
  for (const list of tokenLists(tokens)) {
    for (let k = 0; k < list.length; k += 1) {
      if (list[k].type !== 'ident' || !receivers.has(list[k].value)) continue;
      let j = k + 1;
      if (list[j]?.value === '?') j += 1;
      if (list[j]?.value !== '.' || list[j]?.type !== 'punct') continue;
      j += 1;
      if (list[j]?.type !== 'ident' || !LEVELS.has(list[j].value)) continue;
      j += 1;
      if (list[j]?.value !== '(' || list[j]?.type !== 'punct') continue;
      j += 1;
      const args = [[]];
      let depth = 0;
      for (; j < list.length; j += 1) {
        const token = list[j];
        if (token.type === 'punct' && '([{'.includes(token.value)) depth += 1;
        if (token.type === 'punct' && ')]}'.includes(token.value)) {
          if (depth === 0) break;
          depth -= 1;
        }
        if (token.type === 'punct' && token.value === ',' && depth === 0) {
          args.push([]);
          continue;
        }
        args[args.length - 1].push(token);
      }
      if (args[args.length - 1].length === 0) args.pop(); // a trailing comma
      calls.push({ receiver: list[k].value, start: list[k].start, end: list[j].end, args });
    }
  }
  return calls;
}

/// Whether [text] holds a placeholder pino fills from the next argument.
/// `%%` is a percent sign and consumes nothing.
function hasPlaceholder(text) {
  for (let i = 0; i < text.length - 1; i += 1) {
    if (text[i] !== '%') continue;
    if (text[i + 1] === '%') { i += 1; continue; }
    if ('sdifjoO'.includes(text[i + 1])) return true;
  }
  return false;
}

/// The calls in [src] that hand pino a message and then a value it will drop.
function droppedValues(src, name = '<snippet>') {
  return loggerCalls(tokenize(src, name))
    .filter(({ args }) => args.length >= 2)
    .filter(({ args }) => ['string', 'template'].includes(args[0][0]?.type))
    .filter(({ args }) => !hasPlaceholder(
      args[0].filter((t) => t.type === 'string' || t.type === 'template').map((t) => t.value).join('')))
    .map((call) => `${name}:${lineOf(src, call.start)}  ${src.slice(call.start, call.end).replace(/\s+/g, ' ')}`);
}

/// Every server source: `.js`, `.mjs` and `.cjs` outside the tests, the
/// dependencies and the directories that hold data.
function serverSources() {
  const found = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      if (['node_modules', 'test', 'uploads', 'exports', 'coverage', 'logs', 'tts-cache'].includes(entry.name)) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (/\.(c|m)?js$/.test(entry.name)) found.push(path.relative(ROOT, full).split(path.sep).join('/'));
    }
  };
  walk(ROOT);
  return found;
}

// ── the reader ───────────────────────────────────────────────────────────────

test('the tokenizer skips what a text match would take for a call', () => {
  const src = [
    '// logger.error(\'in a comment\', err);',
    '/* logger.error(\'in a block\', err); */',
    'const s = "logger.error(\'in a string\', err)";',
    'const t = `logger.error(\'in a template\', err)`;',
    'const r = /logger\\.error\\(\'[^\']*\', err\\)/;',
  ].join('\n');
  assert.deepEqual(loggerCalls(tokenize(src)), []);
});

test('the tokenizer tells a regex from a division and keeps its brackets matched', () => {
  const src = [
    'const quote = /[\'"`(]/.test(s);',
    'const half = total / 2 / (count || 1);',
    'if (x) return /}/.exec(y);',
    'logger.info(`${f(a, b)} and ${`${c}`}`);',
  ].join('\n');
  const calls = loggerCalls(tokenize(src));
  assert.equal(calls.length, 1);
  assert.equal(calls[0].args.length, 1, 'a comma inside `${…}` is not a comma between arguments');
});

test('the tokenizer is loud when it loses its place', () => {
  assert.throws(() => tokenize('logger.info((\'x\');', 'a.js'), /a\.js:1: `\(` is never closed/);
  assert.throws(() => tokenize('const x = [1, 2);\n', 'b.js'), /b\.js:1: `\)` closes `\[`/);
  assert.throws(() => tokenize('const s = \'open\nlogger.info(1);', 'c.js'), /c\.js:1: a string runs past/);
});

test('the rule, on the shapes it has to tell apart', () => {
  const dropped = (src) => droppedValues(src).length;

  // What pino drops.
  assert.equal(dropped('logger.error(\'Save failed:\', err);'), 1);
  assert.equal(dropped('logger.error(\n  \'Save failed:\',\n  err,\n);'), 1);
  assert.equal(dropped('logger.warn(`[ROOM] ${code} ended:`, err);'), 1);
  assert.equal(dropped('logger.error(\'a \' + b, err);'), 1);
  assert.equal(dropped('logger?.error(\'x\', e);'), 1);
  // The letter after `%%` is where reading `%%` wrong shows: a percent sign
  // with a space after it is no placeholder whichever way it is read.
  assert.equal(dropped('logger.info(\'grew 5%%s\', value);'), 1, '%%s is a percent sign and an s');
  assert.equal(dropped('logger.error(\'x\', { err });'), 1, 'an object after the message is dropped too');
  assert.equal(dropped('p.catch((err) => logger.error(\'x:\', err));'), 1);

  // Under another name.
  assert.equal(dropped('function f({ log = logger } = {}) { log.warn(\'x\', err); }'), 1);
  assert.equal(dropped('const log = require(\'../services/logger\');\nlog.error(\'x\', e);'), 1);
  assert.equal(dropped('import log from \'./logger.js\';\nlog.info(\'x\', y);'), 1);
  assert.equal(dropped('const roomLog = logger.child({ room: 1 });\nroomLog.error(\'x\', e);'), 1);

  // What pino reads.
  assert.equal(dropped('logger.error({ err }, \'Save failed:\');'), 0);
  assert.equal(dropped('logger.error(err, \'Save failed:\');'), 0);
  assert.equal(dropped('logger.info(\'%s of %d\', done, total);'), 0);
  assert.equal(dropped('logger.error(\'only a sentence\');'), 0);
  assert.equal(dropped('logger.error(`only a ${sentence}`);'), 0);
  assert.equal(dropped('logger.info(\'Totals: \' + [a, b].join(\', \') + f(c, d));'), 0,
    'a comma inside brackets is not a comma between arguments');

  // Not the logger.
  assert.equal(dropped('console.error(\'x\', err);'), 0);
  assert.equal(dropped('io.log.push(\'x\', err); other.error(\'x\', err);'), 0);
  assert.equal(dropped('if (level === logger) log.error(\'x\', err);'), 0);
});

// ── the server ───────────────────────────────────────────────────────────────

test('the walk reaches the server and finds its logger calls', () => {
  // A guard over an empty list passes whatever is written.
  const files = serverSources();
  for (const expected of [
    'server.js', 'db.js', 'middleware/auth.js', 'routes/rooms.js',
    'services/tablebaseService.js', 'services/positionScanner/index.mjs',
  ]) {
    assert.ok(files.includes(expected), `${expected} is not walked`);
  }

  let calls = 0;
  for (const rel of files) calls += loggerCalls(tokenize(fs.readFileSync(path.join(ROOT, rel), 'utf8'), rel)).length;
  // 459 on 30.9.2026. The floor is there to see a walk that stopped finding
  // them, not to count them.
  assert.ok(calls >= 400, `found only ${calls} logger calls`);

  const tablebase = tokenize(fs.readFileSync(path.join(ROOT, 'services/tablebaseService.js'), 'utf8'));
  assert.ok(receiversIn(tablebase).has('log'), 'tablebaseService.js logs through `log = logger`');
  assert.ok(loggerCalls(tablebase).some((call) => call.receiver === 'log'));
});

test('no logger call on the server hands pino a value it drops', () => {
  const offenders = [];
  for (const rel of serverSources()) {
    offenders.push(...droppedValues(fs.readFileSync(path.join(ROOT, rel), 'utf8'), rel));
  }
  assert.deepEqual(offenders, [],
    'pino drops an argument after the message unless the message has a placeholder for it — '
    + 'write logger.<level>({ err }, \'message\')');
});

// ── what the log says ────────────────────────────────────────────────────────

test('an AUTH line says why the account could not be checked', async (t) => {
  const jwt = require('jsonwebtoken');
  const logger = require('../services/logger');
  const { pool } = require('../db');
  const { authenticateToken } = require('../middleware/auth');

  const cause = new Error('Connection terminated due to connection timeout');
  t.mock.method(pool, 'query', async () => { throw cause; });

  // The logger's own stream, swapped for one this test reads: what is checked
  // is the line pino wrote, serializers and all, not the arguments it was given.
  const lines = [];
  const stream = logger[pino.symbols.streamSym];
  logger[pino.symbols.streamSym] = { write: (line) => { lines.push(line); } };
  t.after(() => { logger[pino.symbols.streamSym] = stream; });

  const res = {
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
  let passed = false;
  const token = jwt.sign({ id: 7 }, process.env.JWT_SECRET);
  await authenticateToken({ headers: { authorization: `Bearer ${token}` } }, res, () => { passed = true; });

  assert.equal(passed, false);
  assert.equal(res.statusCode, 503);
  const written = lines.map((line) => JSON.parse(line))
    .filter((entry) => entry.msg === '[AUTH] Nalog nije mogao da se proveri:');
  assert.equal(written.length, 1, lines.join(''));
  assert.equal(written[0].err?.message, cause.message);
  assert.match(written[0].err?.stack ?? '', /^Error: Connection terminated/);
});
