// parent_consent.test.js
// The parent's half of a teaching relationship.
//
// The rule: **a minor's relationship with a trainer does not begin when the two
// of them agree, it begins when the parent says so.** Both sides agreeing moves
// the row to `awaiting_parent` — the state the status column has allowed since
// it was written and nothing filled until now — and only a parent opening a
// link moves it on to `accepted`.
//
// What is pinned hardest here is that no half of the record can exist on its
// own: an `accepted` row with an empty `parent_consent_at`, a friendship
// created before the parent answered, or a request marked answered while the
// relationship never moved. Each of those is a step that skipped quietly and
// reported success one layer up, which is the failure this codebase has paid
// for five times.

// Set before the service is required: it reads both of these once, at load.
process.env.PUBLIC_BASE_URL = 'https://primer.test';
process.env.PARENT_CONSENT_VERSION = 'rs-2026-08-25';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const {
  DEFAULT_TEXT_VERSION,
  parseTextVersion,
  parseBaseUrl,
  parseParentEmail,
  consentLink,
  openRequest,
  findRequest,
  recordAnswer,
} = require('../services/parentConsentService');
const { respondToRequest } = require('../services/relationshipService');

const squash = (text) => String(text).replace(/\s+/g, ' ').trim();

/// A pool whose answers are chosen by looking at the SQL, and which records
/// every statement in order.
///
/// Order matters in these tests more than usual: the whole point of several of
/// them is that two writes happen inside one transaction, so what is asserted
/// is often the sequence rather than any single call.
function stubPool(answer = () => null) {
  const calls = [];
  const run = async (text, params) => {
    const sql = squash(text);
    calls.push({ sql, params });
    const rows = answer(sql, params);
    return { rows: rows ?? [], rowCount: (rows ?? []).length };
  };
  const client = { query: run, release() {} };
  return {
    calls,
    query: run,
    async connect() { return client; },
    sqls: () => calls.map((c) => c.sql),
    find: (fragment) => calls.find((c) => c.sql.includes(fragment)),
  };
}

test('the text version is configuration, and a broken one is not a version', () => {
  // It is written into a legal record and read back years later, so a stray
  // space or a sentence that the VARCHAR(40) column would truncate is a record
  // that quietly says something else.
  assert.equal(parseTextVersion(undefined), DEFAULT_TEXT_VERSION);
  assert.equal(parseTextVersion(''), DEFAULT_TEXT_VERSION);
  assert.equal(parseTextVersion(' rs-2026-08-25 '), 'rs-2026-08-25');
  for (const bad of ['rs 2026', 'a'.repeat(41), 'rs/2026', 'rs;drop']) {
    assert.throws(() => parseTextVersion(bad), RangeError, `primljeno: ${bad}`);
  }
});

test('the country is part of the version, not just the date', () => {
  // The wording was confirmed for Serbia only, and the same product will need
  // different text elsewhere. A record saying "2026-08-25" could not say which
  // of them a parent read.
  assert.match(DEFAULT_TEXT_VERSION, /^rs-/);
});

test('an unset base URL is no link, and a broken one stops the server', () => {
  // Null is a real state: every development machine runs without one. What must
  // never happen is half a value, because a link that goes nowhere is found
  // only by a parent who has already decided the app does not work.
  assert.equal(parseBaseUrl(undefined), null);
  assert.equal(parseBaseUrl(''), null);
  assert.equal(parseBaseUrl('https://primer.test/'), 'https://primer.test');
  assert.equal(parseBaseUrl('https://primer.test///'), 'https://primer.test');
  for (const bad of ['primer.test', 'ftp://primer.test', '/consent', 'javascript:1']) {
    assert.throws(() => parseBaseUrl(bad), RangeError, `primljeno: ${bad}`);
  }
});

test('the link carries the token and nothing about the child', () => {
  const link = consentLink('abc123');
  assert.equal(link, 'https://primer.test/consent/abc123');
});

test('a parent email is checked for what is actually typed wrong', () => {
  assert.equal(parseParentEmail(' Roditelj@Primer.RS ').email, 'roditelj@primer.rs');
  for (const bad of ['', '   ', 'roditelj', 'roditelj@', '@primer.rs',
    'roditelj@primer', 'dva @primer.rs', null, undefined]) {
    assert.equal(parseParentEmail(bad).email, null, `primljeno: ${bad}`);
  }
});

test('opening a request and stopping the relationship are one transaction', async () => {
  const pool = stubPool();
  const result = await openRequest(pool, {
    relationshipId: 5,
    studentId: 2,
    trainerId: 1,
    parentEmail: 'roditelj@primer.rs',
  });

  const sqls = pool.sqls();
  assert.equal(sqls[0], 'BEGIN');
  assert.equal(sqls[sqls.length - 1], 'COMMIT');
  // A live request with no relationship behind it, or a relationship waiting on
  // a parent with nothing to answer, are both halves of a record.
  assert.ok(pool.find('INSERT INTO parent_consent_requests'));
  assert.ok(pool.find("SET status = 'awaiting_parent'"));

  // The token goes out; only its hash is kept.
  assert.match(result.token, /^[0-9a-f]{64}$/);
  assert.equal(result.link, `https://primer.test/consent/${result.token}`);
  const stored = pool.find('INSERT INTO parent_consent_requests').params;
  assert.ok(!stored.includes(result.token), 'token je upisan u čitljivom obliku');
  assert.equal(stored[5], 'rs-2026-08-25', 'verzija teksta se prepisuje na zahtev');
});

test('a second request replaces the first rather than joining it', async () => {
  // Two live links for one question means the record cannot say which one the
  // parent answered.
  const pool = stubPool();
  await openRequest(pool, {
    relationshipId: 5, studentId: 2, trainerId: 1, parentEmail: 'r@primer.rs',
  });
  const removal = pool.find('DELETE FROM parent_consent_requests');
  assert.ok(removal, 'stari zahtev ostaje u igri');
  assert.match(removal.sql, /answered_at IS NULL/,
    'briše se i odgovoren zahtev, čime nestaje zapis da je roditelj odgovorio');
});

const liveRequest = (over = {}) => [{
  id: 9,
  relationship_id: 5,
  student_id: 2,
  trainer_id: 1,
  parent_email: 'roditelj@primer.rs',
  text_version: 'rs-2026-08-25',
  expires_at: new Date(Date.now() + 86400000),
  answered_at: null,
  granted: null,
  student_name: 'Dete',
  trainer_name: 'Trener',
  ...over,
}];

test('a link that is unknown, expired or spent says which of the three', async () => {
  // Different sentences, because they need different answers from the reader:
  // ask for a new one, ask for a new one for a different reason, or do nothing
  // because the answer was already recorded. Collapsing them into "link nije
  // ispravan" would make a parent who already consented think it had failed.
  assert.equal((await findRequest(stubPool(), 'nepostojeci')).reason, 'not-found');

  const expired = stubPool(() => liveRequest({
    expires_at: new Date(Date.now() - 1000),
  }));
  assert.equal((await findRequest(expired, 't')).reason, 'expired');

  const answered = stubPool(() => liveRequest({
    answered_at: new Date(), granted: true,
  }));
  assert.equal((await findRequest(answered, 't')).reason, 'answered');

  const live = stubPool(() => liveRequest());
  assert.equal((await findRequest(live, 't')).reason, null);
});

test('the token is never compared in the clear', async () => {
  const pool = stubPool(() => liveRequest());
  await findRequest(pool, 'tajna');
  const lookup = pool.calls[0];
  assert.match(lookup.sql, /token_hash = \$1/);
  assert.ok(!lookup.params.includes('tajna'));
});

test('consent fills the relationship, the account and the friendship at once', async () => {
  const pool = stubPool((sql) => {
    if (sql.includes('FROM parent_consent_requests r')) return liveRequest();
    if (sql.includes('UPDATE parent_consent_requests')) return [{ id: 9 }];
    return null;
  });

  const result = await recordAnswer(pool, {
    token: 't', ip: '198.51.100.7', granted: true,
  });

  assert.equal(result.ok, true);
  const relationship = pool.find("SET status = 'accepted'");
  assert.ok(relationship, 'veza nije prešla u accepted');
  // An accepted row with an empty consent column is the state somebody would
  // later point at and ask what it means.
  assert.match(relationship.sql, /parent_consent_at = CURRENT_TIMESTAMP/);
  assert.ok(relationship.params.includes('198.51.100.7'));
  assert.ok(relationship.params.includes('rs-2026-08-25'));

  assert.ok(pool.find('INSERT INTO friends'), 'prijateljstvo prati prihvatanje');
  assert.ok(pool.find('UPDATE users'), 'saglasnost na nalogu');
  assert.equal(pool.sqls()[pool.calls.length - 1], 'COMMIT');
});

test('the account-level consent is written once and not overwritten', async () => {
  // "May this child be here at all" is answered once by one parent; "may it be
  // this trainer" is asked again for every trainer. A second consent must not
  // restamp the first with today's date and a different IP.
  const pool = stubPool((sql) => {
    if (sql.includes('FROM parent_consent_requests r')) return liveRequest();
    if (sql.includes('UPDATE parent_consent_requests')) return [{ id: 9 }];
    return null;
  });
  await recordAnswer(pool, { token: 't', ip: '203.0.113.9', granted: true });

  const account = pool.find('UPDATE users');
  assert.match(account.sql, /parent_consent_at = COALESCE\(parent_consent_at/);
  assert.match(account.sql, /parent_email = COALESCE\(parent_email/);
});

test('a refusal is recorded, and it accepts nothing', async () => {
  // `granted = false` with a time on it is the answer. A refused request that
  // erased itself would look exactly like one that was never sent.
  const pool = stubPool((sql) => {
    if (sql.includes('FROM parent_consent_requests r')) return liveRequest();
    if (sql.includes('UPDATE parent_consent_requests')) return [{ id: 9 }];
    return null;
  });

  const result = await recordAnswer(pool, { token: 't', ip: '::1', granted: false });

  assert.equal(result.ok, true);
  assert.equal(result.granted, false);
  assert.equal(pool.find("SET status = 'accepted'"), undefined);
  assert.equal(pool.find('INSERT INTO friends'), undefined);
  assert.equal(pool.find('UPDATE users'), undefined);
  const claim = pool.find('UPDATE parent_consent_requests');
  assert.ok(claim.params.includes(false), 'odbijanje se ne upisuje');
});

test('the parent is not asked about recording, and cannot be recorded as having agreed', async () => {
  // The third item of the form is gone. Since 26.8.2026 a lesson is not
  // recorded at all — audio belongs to somebody alone in a room — so there is
  // no question left for a parent to answer about it.
  //
  // This test is the guard against it drifting back in the quiet way: a caller
  // that still passes `allowsRecording` must change nothing, and the write must
  // not name the column. A parameter that is accepted and ignored, or a column
  // written and never read, is the exact failure this area has already had once.
  const pool = stubPool((sql) => {
    if (sql.includes('FROM parent_consent_requests r')) return liveRequest();
    if (sql.includes('UPDATE parent_consent_requests')) return [{ id: 9 }];
    return null;
  });

  await recordAnswer(pool, {
    token: 't', ip: '::1', granted: true, allowsRecording: true,
  });

  const relationship = pool.find("SET status = 'accepted'");
  assert.ok(relationship, 'veza nije prešla u accepted');
  assert.doesNotMatch(relationship.sql, /parent_allows_recording/,
    'upis i dalje pominje kolonu o snimanju, koja više nema šta da znači');
  assert.equal(relationship.params.includes(true), false,
    'saglasnost za snimanje je stigla u upis iako se više ne pita');

  // And the page itself no longer carries the question.
  const consentRoute = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'consent.js'), 'utf8',
  );
  assert.doesNotMatch(consentRoute, /name="recording"/,
    'obrazac za roditelja i dalje nudi polje o snimanju');
});

test('two clicks on the same link count once', async () => {
  // The check above passes for both of them half a second apart. What decides
  // is the write: claiming the row is the single-use lock, not reading it.
  const pool = stubPool((sql) => {
    if (sql.includes('FROM parent_consent_requests r')) return liveRequest();
    if (sql.includes('UPDATE parent_consent_requests')) return null; // already claimed
    return null;
  });

  const result = await recordAnswer(pool, { token: 't', ip: '::1', granted: true });

  assert.deepEqual(result, { ok: false, reason: 'answered' });
  assert.equal(pool.find("SET status = 'accepted'"), undefined);
  assert.equal(pool.sqls()[pool.calls.length - 1], 'ROLLBACK');
});

test('accepting a minor stops at the parent instead of at accepted', async () => {
  // Both sides agreed and the relationship still does not exist. Nothing an
  // accepted edge unlocks — homework, reports, the room, the microphone — is
  // reachable from `awaiting_parent`.
  const pool = stubPool((sql, params) => {
    if (sql.includes("status = 'pending'") && sql.startsWith('SELECT')) {
      return [{ trainer_id: 1, student_id: 2 }];
    }
    // Asked twice and answered differently: 1 is the adult teaching, 2 is the
    // child. A stub that made both minors would be testing the other rule.
    if (sql.includes('SELECT birth_year')) {
      return [{ birth_year: params[0] === 2 ? 2014 : 1990 }];
    }
    if (sql.startsWith('UPDATE trainer_students SET status = $3')) {
      return [{ trainer_id: 1, student_id: 2 }];
    }
    if (sql.includes('s.parent_email')) {
      return [{
        parent_email: 'roditelj@primer.rs',
        student_name: 'Dete',
        trainer_name: 'Trener',
      }];
    }
    return null;
  });

  const result = await respondToRequest(pool, {
    requestId: 5, userId: 1, accept: true,
  });

  assert.equal(result.ok, true);
  assert.equal(result.awaitingParent, true);
  assert.equal(result.missingParentEmail, false);
  assert.match(result.consentLink, /^https:\/\/primer\.test\/consent\//);

  const statusWrite = pool.find('UPDATE trainer_students SET status = $3');
  assert.equal(statusWrite.params[2], 'awaiting_parent',
    'red je makar na trenutak rekao accepted');
  assert.equal(pool.find('INSERT INTO friends'), undefined,
    'prijateljstvo pre nego što je roditelj odgovorio');
});

test('a minor with no parent on file is said out loud, not left waiting', async () => {
  // Silence here looks exactly like an email that got lost, and the two need
  // different answers from whoever is reading.
  const pool = stubPool((sql, params) => {
    if (sql.includes("status = 'pending'") && sql.startsWith('SELECT')) {
      return [{ trainer_id: 1, student_id: 2 }];
    }
    // Asked twice and answered differently: 1 is the adult teaching, 2 is the
    // child. A stub that made both minors would be testing the other rule.
    if (sql.includes('SELECT birth_year')) {
      return [{ birth_year: params[0] === 2 ? 2014 : 1990 }];
    }
    if (sql.startsWith('UPDATE trainer_students SET status = $3')) {
      return [{ trainer_id: 1, student_id: 2 }];
    }
    if (sql.includes('s.parent_email')) {
      return [{ parent_email: null, student_name: 'Dete', trainer_name: 'Trener' }];
    }
    return null;
  });

  const result = await respondToRequest(pool, {
    requestId: 5, userId: 1, accept: true,
  });

  assert.equal(result.awaitingParent, true);
  assert.equal(result.missingParentEmail, true);
  assert.equal(pool.find('INSERT INTO parent_consent_requests'), undefined);
});

test('an adult accepting is unchanged, and still becomes a friendship', async () => {
  // The flow above must not have cost everybody else a step. Every relationship
  // in the app today is this one.
  const pool = stubPool((sql, params) => {
    if (sql.includes("status = 'pending'") && sql.startsWith('SELECT')) {
      return [{ trainer_id: 1, student_id: 2 }];
    }
    // Both adults, which is every relationship in the app today.
    if (sql.includes('SELECT birth_year')) return [{ birth_year: 1990 }];
    if (sql.startsWith('UPDATE trainer_students SET status = $3')) {
      return [{ trainer_id: 1, student_id: 2 }];
    }
    return null;
  });

  const result = await respondToRequest(pool, {
    requestId: 5, userId: 1, accept: true,
  });

  assert.equal(result.ok, true);
  assert.equal(result.awaitingParent, false);
  assert.equal(pool.find('UPDATE trainer_students SET status = $3').params[2],
    'accepted');
  assert.ok(pool.find('INSERT INTO friends'));
});
