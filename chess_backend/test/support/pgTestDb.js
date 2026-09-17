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

/// A fresh database with the application's schema on it. Call `drop()` when
/// done; the name carries the pid and a counter, so parallel test files never
/// share one.
let counter = 0;
async function freshDatabase() {
  const name = `mislisha_test_${process.pid}_${Date.now()}_${counter++}`;
  const admin = new Pool({ connectionString: url, max: 1 });
  await admin.query(`CREATE DATABASE ${name}`);

  const target = new URL(url);
  target.pathname = `/${name}`;
  const pool = new Pool({ connectionString: target.toString(), max: 4 });

  // Required late: db.js builds its own pool from the environment at import,
  // and that pool is never connected by these tests.
  const { initDB } = require('../../db');
  await initDB(pool);

  return {
    pool,
    async drop() {
      await pool.end();
      await admin.query(`DROP DATABASE IF EXISTS ${name} WITH (FORCE)`);
      await admin.end();
    },
  };
}

module.exports = { skipUnlessDatabase, freshDatabase };
