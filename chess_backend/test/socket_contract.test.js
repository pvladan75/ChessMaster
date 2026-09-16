// socket_contract.test.js
// Every socket event one end sends, the other end listens for — by name.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/contract.md`, 1–5
// and 14). Commit `6a6b0dd` (10.8.2026) renamed the server's room events while
// the app kept the old names: `moveMade` became `move`, `flip_board_forced`
// became `board_flipped`, `lesson_invite` became `lesson_invite_received`, and
// the handlers for sharing a position, muting a student, allowing speech and
// raising a hand were deleted. Fifteen app listeners had no sender and five app
// emits had no receiver. A student's board stopped following the trainer's
// moves, and for five weeks nobody saw it: every live check of the room was on
// one device, and the app's `pgn_loaded` kept the move tree looking right.
//
// Half the names on each side had no counterpart, so a missing one looked
// normal. This test makes the list whole in both directions: what the app sends
// the server handles, what the server sends the app handles — and the other way
// round, so a handler nothing calls is noticed too.
//
// It reads source, so it reads it by call shape with comments removed by a
// scanner that knows strings — never by a plain `contains`, which matches a
// comment explaining a rename. Proved by mutation before it was believed.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const BACKEND = path.join(__dirname, '..');
const APP_LIB = path.join(__dirname, '..', '..', 'chess_app', 'lib');

function walk(dir, ext, skip = new Set()) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (skip.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full, ext, skip));
    else if (entry.name.endsWith(ext)) out.push(full);
  }
  return out;
}

/// Replaces comments with spaces, leaving string literals intact. Handles
/// `//`, `/* */`, and single, double and backtick quotes with escapes — enough
/// for both Dart and JavaScript, whose comment and quote syntax agree here.
function stripComments(src) {
  let out = '';
  let i = 0;
  let quote = null;
  while (i < src.length) {
    const c = src[i];
    const next = src[i + 1];
    if (quote) {
      out += c;
      if (c === '\\') {
        out += next ?? '';
        i += 2;
        continue;
      }
      if (c === quote) quote = null;
      i += 1;
      continue;
    }
    if (c === '/' && next === '/') {
      while (i < src.length && src[i] !== '\n') i += 1;
      continue;
    }
    if (c === '/' && next === '*') {
      i += 2;
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i += 1;
      i += 2;
      continue;
    }
    if (c === "'" || c === '"' || c === '`') quote = c;
    out += c;
    i += 1;
  }
  return out;
}

function namesIn(files, patterns) {
  const found = new Map(); // name -> first file
  for (const file of files) {
    const src = stripComments(fs.readFileSync(file, 'utf8'));
    for (const pattern of patterns) {
      for (const match of src.matchAll(pattern)) {
        if (!found.has(match[1])) found.set(match[1], path.relative(path.join(BACKEND, '..'), file));
      }
    }
  }
  return found;
}

const serverFiles = walk(BACKEND, '.js', new Set(['node_modules', 'test', 'exports', 'uploads', 'tts-cache']));
const appFiles = walk(APP_LIB, '.dart');

const server = {
  listens: namesIn(serverFiles, [/\bsocket\.on\(\s*['"]([A-Za-z_]+)['"]/g]),
  emits: namesIn(serverFiles, [
    /\.emit\(\s*['"]([A-Za-z_]+)['"]/g,
    /\bemitToUser\(\s*[^,()]+(?:\([^()]*\))?\s*,\s*['"]([A-Za-z_]+)['"]/g,
  ]),
};
const app = {
  listens: namesIn(appFiles, [/\b_?socket\.on\(\s*['"]([A-Za-z_]+)['"]/g]),
  emits: namesIn(appFiles, [/\b_?socket\.emit\(\s*['"]([A-Za-z_]+)['"]/g]),
};

/// Events Socket.IO itself raises; nobody sends them.
const TRANSPORT = new Set(['connection', 'disconnect', 'connect', 'connect_error']);

function missing(from, to) {
  return [...from.keys()]
    .filter((name) => !TRANSPORT.has(name) && !to.has(name))
    .map((name) => `${name} (${from.get(name)})`)
    .sort();
}

test('the scan sees both ends', () => {
  // Without this, a path that moved would make every assertion below pass on
  // two empty sets.
  assert.ok(serverFiles.some((f) => f.endsWith('server.js')), 'server.js must be read');
  assert.ok(appFiles.some((f) => f.endsWith('chess_game_screen.dart')), 'the room screen must be read');
  assert.ok(server.listens.has('joinGame') && app.emits.has('joinGame'), 'joinGame must be found on both ends');
  assert.ok(server.emits.has('room_members_list') && app.listens.has('room_members_list'));
});

test('every event the app listens for is sent by the server', () => {
  assert.deepEqual(missing(app.listens, server.emits), []);
});

test('every event the app sends is handled by the server', () => {
  assert.deepEqual(missing(app.emits, server.listens), []);
});

test('every event the server sends is listened for by the app', () => {
  assert.deepEqual(missing(server.emits, app.listens), []);
});

test('every event the server handles is sent by the app', () => {
  assert.deepEqual(missing(server.listens, app.emits), []);
});

test('no event name is computed, so the scan above sees every one', () => {
  // A name chosen by a ternary or held in a variable is invisible to the pairing
  // above — the first version of the mute fix did exactly that and passed.
  // `realtime.emitToUser` is the one place that forwards a name it was given,
  // and its callers are read by the pattern for `emitToUser`.
  const computed = [];
  for (const file of serverFiles) {
    if (file.endsWith(path.join('services', 'realtime.js'))) continue;
    const src = stripComments(fs.readFileSync(file, 'utf8'));
    for (const m of src.matchAll(/(?:\bsocket|\bio|\.to\([^()]*\))\.emit\(\s*([^'"\s])/g)) {
      computed.push(`${path.basename(file)}: emit(${m[1]}…`);
    }
  }
  for (const file of appFiles) {
    const src = stripComments(fs.readFileSync(file, 'utf8'));
    for (const m of src.matchAll(/\b_?socket\.(?:emit|on)\(\s*([^'"\s])/g)) {
      computed.push(`${path.basename(file)}: (${m[1]}…`);
    }
  }
  assert.deepEqual(computed, []);
});

test('the comment scanner keeps strings and drops comments', () => {
  const src = "a('// not a comment'); // socket.on('ghost'\n/* socket.emit('ghost2') */ b(\"/*x*/\")";
  const stripped = stripComments(src);
  assert.ok(stripped.includes("'// not a comment'"));
  assert.ok(stripped.includes('"/*x*/"'));
  assert.ok(!stripped.includes('ghost'));
});
