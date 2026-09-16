// destructive_script_guard.test.js
// A script that deletes data refuses a database it was not told by name.
// See `services/destructiveScriptGuard.js` for the audit finding behind it.
//
// The rule is tested twice: as a function, and by **running the real scripts**
// against a host that is not local. The second half is the one that matters —
// a correct guard that a script forgot to call guards nothing, and reading the
// script's source for the call would be the text-matching check this project
// has already been fooled by.

const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { destructiveTargetVerdict } = require('../services/destructiveScriptGuard');

test('a local database needs no confirmation', () => {
  for (const host of ['localhost', '127.0.0.1', '::1', '', undefined, 'LOCALHOST']) {
    assert.equal(destructiveTargetVerdict({ DB_HOST: host }, []).allowed, true, String(host));
  }
});

test('a remote database is refused without a confirmation naming it', () => {
  const env = { DB_HOST: 'cluster.example.test' };
  const verdict = destructiveTargetVerdict(env, []);
  assert.equal(verdict.allowed, false);
  assert.match(verdict.reason, /cluster\.example\.test/);
  assert.equal(destructiveTargetVerdict(env, ['--yes']).allowed, false);
  assert.equal(destructiveTargetVerdict(env, ['--target=other.example.test']).allowed, false);
  assert.equal(destructiveTargetVerdict(env, ['--target=cluster.example']).allowed, false);
});

test('a remote database named on the command line is allowed', () => {
  const env = { DB_HOST: 'cluster.example.test' };
  assert.equal(destructiveTargetVerdict(env, ['--target=cluster.example.test']).allowed, true);
});

const SCRIPTS = ['clear_users.js', 'import_new_puzzles.js'];

for (const script of SCRIPTS) {
  test(`${script} stops before connecting when pointed at a remote database`, () => {
    // An empty working directory, so `dotenv` finds no `.env` and the only
    // database the script can see is the one given here. The host is reserved
    // (`.invalid`) and a port nothing listens on, so a missing guard fails to
    // connect rather than reaching anything.
    const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'guard-'));
    const env = {
      PATH: process.env.PATH,
      SystemRoot: process.env.SystemRoot,
      DB_HOST: 'cluster.invalid',
      DB_PORT: '9',
      DB_USER: 'nobody',
      DB_PASSWORD: 'nothing',
      DB_DATABASE: 'none',
    };
    const run = spawnSync(process.execPath, [path.join(__dirname, '..', script)], {
      cwd,
      env,
      encoding: 'utf8',
      timeout: 30000,
    });
    assert.notEqual(run.status, 0, `${script} must exit non-zero; stdout: ${run.stdout}`);
    assert.match(
      run.stderr,
      /Refusing to run: this script deletes data, and DB_HOST is cluster\.invalid/,
      `${script} must refuse before touching the database; stderr: ${run.stderr}`,
    );
  });
}
