// A real, throwaway PostgreSQL database for the tests that must prove SQL.
//
// The rest of the suite fakes the pool with canned rows, which is right for
// arithmetic and wrong for a CHECK constraint, a partial index or a WHERE
// clause: a stub returns what it was told whatever the query says. This builds
// a fresh database, runs the real `initDB` on it, and drops it afterwards.
//
// `TEST_DATABASE_URL` names a server and a maintenance database the tests may
// create databases through, e.g. `postgres://postgres@localhost:54329/postgres`.
// CI provides one as a service container. **In CI a missing URL fails the
// test** — a check that quietly skips wherever it is not configured is a
// check that cannot fail. On a workstation without one the tests are skipped,
// and say so.

const { Pool } = require('pg');

const url = process.env.TEST_DATABASE_URL;

/// The options `node:test` takes to skip a whole file's tests when there is no
/// server, or null when they should run. Throws in CI rather than skipping.
function skipUnlessDatabase() {
  if (url) return null;
  if (process.env.CI) {
    throw new Error(
      'TEST_DATABASE_URL is not set in CI: the database tests would skip, and a ' +
        'skipped gate is not a gate. See .github/workflows/ci_cd.yml.'
    );
  }
  return { skip: 'TEST_DATABASE_URL not set — no throwaway PostgreSQL to run on' };
}

/// Nothing here may wait for ever. `pg` defaults `connectionTimeoutMillis` to
/// 0, which means a pool that cannot reach the server blocks its `before` hook
/// with no error and no end — and `node --test` has no timeout of its own, so
/// one stalled connection freezes the whole suite. That is not theory: between
/// 18.9.2026 and 19.9.2026 four CI runs out of seven sat in `npm test` until
/// the six-hour job limit killed them, every one of them after this file's
/// tests started running, and there was nothing in the log to say where.
/// A loud failure beats a silent wait (CLAUDE.md, "Rules that bite").
const TIMEOUTS = { connectionTimeoutMillis: 15000, query_timeout: 60000 };

/// A pool that cannot kill the process it is being tested in.
///
/// `pg` emits `error` on the **pool** when a client that is sitting idle loses
/// its connection, and an `EventEmitter` with no `error` listener throws: the
/// exception belongs to no test, so `node --test` reports it as an
/// `uncaughtException`, the child exits 1, and the file fails as a whole with
/// no assertion to point at. That is exactly what CI reported on 19.9.2026 —
/// „generated asynchronous activity after the test ended … terminating
/// connection due to administrator command", the message PostgreSQL sends to
/// every backend when `DROP DATABASE … WITH (FORCE)` runs. Tearing a throwaway
/// database down is allowed to disturb an idle connection; it is not allowed
/// to take the test process with it.
///
/// The error is printed rather than swallowed. A quiet `catch` here would hide
/// a pool that is losing connections mid-test, which is a real fault and looks
/// nothing like teardown noise.
/// It also watches the pool's sockets, because `end()` is a *request* to close
/// and not a close. `pg` sends `Terminate` and waits for the server to hang up;
/// measured here on 19.9.2026, a socket to the server is still open, undestroyed
/// and readable after `pool.end()` has resolved and the pool reports
/// `total=0 ended=true`. On this workstation it goes a moment later and the
/// process exits. In CI it does not always, and an open `TCPSocketWrap` is a
/// handle: `node --test` waits for the child to exit, and the child is waiting
/// for a socket that nobody is going to close. Three database files hung on
/// exactly this and were cut down by `--test-timeout` after 60 s; before that
/// ceiling existed, the same wait ran to the six-hour job limit.
function unkillable(pool, what) {
  const open = new Set();
  pool.on('connect', (client) => {
    const socket = client.connection && client.connection.stream;
    if (!socket) return;
    open.add(socket);
    socket.once('close', () => open.delete(socket));
  });
  pool.on('error', (err) => {
    process.stderr.write(`[pgTestDb] idle client on the ${what} pool: ${err.message}\n`);
  });
  return { pool, open };
}

/// Closes for real what `end()` only asked to close. The database is already
/// gone by the time this runs, so there is nothing left to say politely.
/// Waits for each socket's own 'close' rather than for a fixed number of turns
/// — that is the event the sets are keyed on, and guessing at a tick count is
/// how a teardown check starts passing for the wrong reason. Bounded, because
/// a socket that will not close is the fault being looked for and must show up
/// as a failed assertion, not as another hang.
async function destroyStragglers(...sets) {
  const left = sets.flatMap((s) => [...s]);
  const closed = left.map((socket) => {
    if (socket.closed) return Promise.resolve();
    const done = new Promise((resolve) => socket.once('close', resolve));
    socket.destroy();
    return done;
  });
  let timer;
  await Promise.race([
    Promise.all(closed),
    new Promise((resolve) => { timer = setTimeout(resolve, 5000); }),
  ]);
  clearTimeout(timer);
  return left.length;
}

/// A fresh database with the application's schema on it. Call `drop()` when
/// done; the name carries the pid and a counter, so parallel test files never
/// share one.
let counter = 0;
async function freshDatabase() {
  const name = `mislisha_test_${process.pid}_${Date.now()}_${counter++}`;
  const { pool: admin, open: adminOpen } =
    unkillable(new Pool({ connectionString: url, max: 1, ...TIMEOUTS }), 'admin');
  await admin.query(`CREATE DATABASE ${name}`);

  const target = new URL(url);
  target.pathname = `/${name}`;
  const { pool, open: poolOpen } = unkillable(
    new Pool({ connectionString: target.toString(), max: 4, ...TIMEOUTS }),
    'test'
  );

  // Required late: db.js builds its own pool from the environment at import,
  // and that pool is never connected by these tests.
  const { initDB } = require('../../db');
  await initDB(pool);

  return {
    pool,
    /// How many sockets this helper still holds open. Zero once `drop()` has
    /// run — that is what `pg_test_db_teardown.test.js` asserts, and what the
    /// hung CI runs did not have.
    stillOpen: () => adminOpen.size + poolOpen.size,
    async drop() {
      await pool.end();
      await admin.query(`DROP DATABASE IF EXISTS ${name} WITH (FORCE)`);
      await admin.end();
      return destroyStragglers(poolOpen, adminOpen);
    },
  };
}

module.exports = { skipUnlessDatabase, freshDatabase };
