// sources_compile.test.js
// Every server file is at least **loadable**.
//
// Written the day `server.js` did not parse at all. Two `const seat`
// declarations landed in one block in `audio_join`, which is a SyntaxError
// before a single line runs — the backend could not start, and the state was
// committed. Nothing caught it: `npm test` never loads `server.js`, and the two
// tests that do look at it read it as **text** and search for the name of a
// function. Both passed, on a file that could not be parsed.
//
// That is this codebase's recurring bug in its purest form: a check that skips
// the thing it appears to verify and reports success one layer up.
//
// Compiled rather than required: requiring `server.js` would open a database
// pool and bind a port, and requiring a route file would run the fail-fast
// checks that call `process.exit`. Compiling answers the only question asked
// here — is this a file Node can load at all — and answers it for every file
// rather than for the ones some other test happens to touch.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const Module = require('module');

const root = path.join(__dirname, '..');

/// Every .js file that is part of the server, excluding what is not ours.
function sourceFiles() {
  const found = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (['uploads', 'coverage', 'logs'].includes(entry.name)) continue;
        walk(full);
      } else if (entry.name.endsWith('.js')) {
        found.push(full);
      }
    }
  };
  walk(root);
  return found;
}

test('every server source parses', () => {
  const files = sourceFiles();
  assert.ok(files.length > 20, `nađeno samo ${files.length} fajlova — obilazak ne radi`);

  const broken = [];
  for (const file of files) {
    try {
      // Wrapped the way Node wraps a CommonJS module, so `require`, `module` and
      // the rest are legal names rather than parse errors.
      new vm.Script(Module.wrap(fs.readFileSync(file, 'utf8')), { filename: file });
    } catch (err) {
      broken.push(`${path.relative(root, file)}: ${err.message}`);
    }
  }

  assert.deepEqual(broken, [], 'fajlovi koji se ne mogu ni pročitati kao kod');
});

test('the file this test was written for is among the ones checked', () => {
  // A guard on the guard, and it earned its place: the first attempt to prove
  // this test works put the old bug back in the *wrong* function, watched the
  // test pass, and nearly concluded the check was useless. A walk that quietly
  // stops finding `server.js` — renamed, moved, excluded — would fail in exactly
  // that way, and go on passing.
  const files = sourceFiles()
    .map((f) => path.relative(root, f).split(path.sep).join('/'));

  for (const expected of ['server.js', 'db.js', 'routes/rooms.js', 'services/roomAccess.js']) {
    assert.ok(files.includes(expected), `${expected} nije u obilasku`);
  }
});
