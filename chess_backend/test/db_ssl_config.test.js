// db_ssl_config.test.js
// Pins how the database connection decides to secure itself.
//
// This is one .env line away from silently becoming an unverified connection:
// drop DB_CA_PATH and everything still works, still encrypts, and no longer
// proves who is on the other end. Nothing in normal use would show it, so the
// three states are asserted here instead.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { buildSslConfig } = require('../db');

test('a CA path means the certificate and hostname are verified', () => {
  const file = path.join(os.tmpdir(), `ca-test-${Date.now()}.crt`);
  fs.writeFileSync(file, '-----BEGIN CERTIFICATE-----\nnot a real one\n');

  try {
    const ssl = buildSslConfig({ DB_CA_PATH: file, DB_SSL: 'true' });
    assert.equal(ssl.rejectUnauthorized, true);
    assert.match(ssl.ca, /BEGIN CERTIFICATE/);
  } finally {
    fs.unlinkSync(file);
  }
});

test('the CA path wins over DB_SSL rather than being overridden by it', () => {
  const file = path.join(os.tmpdir(), `ca-test-${Date.now()}-2.crt`);
  fs.writeFileSync(file, 'cert');

  try {
    // DB_SSL unset must not demote a configured CA to the unverified path.
    const ssl = buildSslConfig({ DB_CA_PATH: file });
    assert.equal(ssl.rejectUnauthorized, true);
  } finally {
    fs.unlinkSync(file);
  }
});

test('an unreadable CA path stops the process instead of downgrading', () => {
  assert.throws(
    () => buildSslConfig({ DB_CA_PATH: path.join(os.tmpdir(), 'nema-ovog-fajla.crt') }),
    /ENOENT/
  );
});

test('DB_SSL alone is the old unverified behaviour', () => {
  assert.deepEqual(buildSslConfig({ DB_SSL: 'true' }), { rejectUnauthorized: false });
});

test('neither set means no TLS, for a local PostgreSQL', () => {
  assert.equal(buildSslConfig({}), false);
  assert.equal(buildSslConfig({ DB_SSL: 'false' }), false);
});
