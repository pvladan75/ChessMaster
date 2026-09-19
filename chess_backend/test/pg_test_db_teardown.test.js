// The teardown of a throwaway database must leave no socket behind.
//
// Written 19.9.2026 after three database test files hung in CI: every test in
// them passed, the suite closed, and then the child process never exited.
// `node --test` waits for the child, so the run froze — for six hours, until
// `--test-timeout` was added, and for sixty seconds after that.
//
// The handle was a TCP socket to the server, still open and undestroyed after
// `pool.end()` had resolved and the pool reported `total=0 ended=true`. `end()`
// sends `Terminate` and waits for the *server* to hang up; on this workstation
// the server does so a moment later, which is why five weeks of local runs saw
// nothing. This test does not wait for that moment — it asserts that when
// `drop()` returns, the helper is holding nothing at all.
const { describe, test } = require('node:test');
const assert = require('node:assert/strict');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

describe('tearing a throwaway database down', { skip: skip ? skip.skip : false }, () => {
  test('drop() leaves no socket open, however many clients were used', async () => {
    const db = await freshDatabase();

    // Fill the pool: four clients at once, so `end()` has more than one socket
    // to close and the test cannot pass by there being only ever one.
    await Promise.all([1, 2, 3, 4].map(() => db.pool.query('SELECT pg_sleep(0.05)')));
    assert.ok(db.stillOpen() >= 2, `the pool must actually be open: ${db.stillOpen()}`);

    await db.drop();
    assert.equal(db.stillOpen(), 0, 'a socket outlived the database it talked to');
  });

  test('a database torn down after its backends were killed leaves nothing either', async () => {
    const db = await freshDatabase();
    await db.pool.query('SELECT 1');

    // What `DROP DATABASE ... WITH (FORCE)` does to every connection, done
    // early so the sockets are already broken when `end()` asks politely.
    await db.pool.query(
      `SELECT pg_terminate_backend(pid) FROM pg_stat_activity
        WHERE datname = current_database() AND pid <> pg_backend_pid()`
    );

    await db.drop();
    assert.equal(db.stillOpen(), 0, 'a broken socket outlived the database');
  });
});
