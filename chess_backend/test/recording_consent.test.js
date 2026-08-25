// recording_consent.test.js
// Whether a lesson may be recorded, and who says no.
//
// This exists because of a hole rather than a feature. `parent_allows_recording`
// was filled honestly by the parent's page from the day it was written, and
// **nothing read it**: the column was touched by exactly two places, the
// migration that created it and the write that set it. A rule that is recorded
// and never enforced is the failure this codebase has paid for five times, and
// `docs/saglasnost-roditelja.md` names it outright — the enforcement is the half
// that turns the promise into something the system actually does.
//
// The last test in this file is the guard against it coming back.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const {
  blockedForRecording,
  mayRecordRoom,
  refusalSentence,
} = require('../services/recordingConsent');

const thisYear = new Date().getFullYear();
const CHILD_YEAR = thisYear - 10; // eleven at most, minor under any threshold
const ADULT_YEAR = thisYear - 40;

function stubPool(answer = () => null) {
  const calls = [];
  return {
    calls,
    async query(text, params) {
      const sql = String(text).replace(/\s+/g, ' ').trim();
      calls.push({ sql, params });
      const rows = answer(sql, params);
      return { rows: rows ?? [], rowCount: (rows ?? []).length };
    },
  };
}

const person = (over) => ({
  id: 2,
  name: 'Dete',
  birth_year: CHILD_YEAR,
  parent_allows_recording: null,
  ...over,
});

test('an age nobody has stated blocks nothing', async () => {
  // The same grandfathering `status` and `voice_level` got. Refusing on an empty
  // column would have switched recording off for every lesson in the app on the
  // strength of a field that was empty an hour ago — and every account in the
  // app is this one until the age gate has been round.
  const pool = stubPool(() => [person({ birth_year: null })]);
  assert.deepEqual(
    await blockedForRecording(pool, { ownerId: 1, userIds: [2] }),
    [],
  );
});

test('an adult student blocks nothing, whatever the column says', async () => {
  for (const value of [null, false, true]) {
    const pool = stubPool(() => [
      person({ birth_year: ADULT_YEAR, parent_allows_recording: value }),
    ]);
    assert.deepEqual(
      await blockedForRecording(pool, { ownerId: 1, userIds: [2] }),
      [],
      `parent_allows_recording=${value}`,
    );
  }
});

test('a child whose parent agreed is recordable', async () => {
  const pool = stubPool(() => [person({ parent_allows_recording: true })]);
  assert.deepEqual(
    await blockedForRecording(pool, { ownerId: 1, userIds: [2] }),
    [],
  );
});

test('a refusal and a question never asked both block, and are told apart',
  async () => {
    // The same answer to "may I record" and different answers to "what do I do
    // about it": one is a decision to respect, the other a letter to send.
    const refused = stubPool(() => [person({ parent_allows_recording: false })]);
    assert.deepEqual(
      await blockedForRecording(refused, { ownerId: 1, userIds: [2] }),
      [{ id: 2, name: 'Dete', reason: 'refused' }],
    );

    const unasked = stubPool(() => [person({ parent_allows_recording: null })]);
    assert.deepEqual(
      await blockedForRecording(unasked, { ownerId: 1, userIds: [2] }),
      [{ id: 2, name: 'Dete', reason: 'not-asked' }],
    );
  });

test('a stated child with no relationship at all is the least consented case',
  async () => {
    // The LEFT JOIN is why this is even asked: somebody in the room with no row
    // to this trainer still has an age, and nobody has agreed to anything.
    const pool = stubPool((sql) => {
      assert.match(sql, /LEFT JOIN trainer_students/);
      return [person({ parent_allows_recording: null })];
    });
    const blocked = await blockedForRecording(pool, { ownerId: 1, userIds: [2] });
    assert.equal(blocked.length, 1);
    assert.equal(blocked[0].reason, 'not-asked');
  });

test('the room owner is never blocked by their own room', async () => {
  const pool = stubPool(() => {
    throw new Error('nije trebalo ništa da se pita');
  });
  assert.deepEqual(
    await blockedForRecording(pool, { ownerId: 1, userIds: [1, 1] }),
    [],
  );
});

test('guests are not asked about, because they have no account', async () => {
  // A guest joins under a socket id rather than a user id. Whether they may be
  // in the room at all is the guest switch's question, not this one.
  const pool = stubPool(() => {
    throw new Error('nije trebalo ništa da se pita');
  });
  assert.deepEqual(
    await blockedForRecording(pool, { ownerId: 1, userIds: ['abc123socket'] }),
    [],
  );
});

test('a room that does not exist is not a room that may be recorded', async () => {
  const pool = stubPool(() => []);
  const verdict = await mayRecordRoom(pool, { roomCode: '000000', userIds: [2] });
  assert.equal(verdict.allowed, false);
  assert.deepEqual(verdict.blocked, []);
});

test('a refusal names the children, because a trainer cannot act on "no"',
  async () => {
    const pool = stubPool((sql) => {
      if (sql.includes('FROM rooms')) return [{ creator_id: 1 }];
      return [
        person({ id: 2, name: 'Mila', parent_allows_recording: false }),
        person({ id: 3, name: 'Petar', parent_allows_recording: null }),
      ];
    });

    const verdict = await mayRecordRoom(pool, {
      roomCode: '123456', userIds: [2, 3],
    });

    assert.equal(verdict.allowed, false);
    assert.equal(verdict.blocked.length, 2);
    // The two halves are separated in the sentence as well, for the same reason
    // they are separated in the data.
    assert.match(verdict.reason, /nije dozvolio snimanje za: Mila/);
    assert.match(verdict.reason, /još nije data za: Petar/);
  });

test('the sentence stays readable when only one half applies', () => {
  const only = refusalSentence([{ id: 2, name: 'Mila', reason: 'refused' }]);
  assert.match(only, /Mila/);
  assert.doesNotMatch(only, /još nije data/);
});

test('the recording consent column is read, not only written', () => {
  // The regression this whole file exists for. `parent_allows_recording` spent
  // its first hours being written by the parent's page and read by nobody, so a
  // parent could refuse a recording and the recording would run.
  //
  // Asserted on the source because the failure is invisible in behaviour:
  // everything keeps working, and the only difference is that the answer does
  // not matter. Same shape as the test that pins `INSERT INTO friends`.
  const root = path.join(__dirname, '..');
  const readers = [];

  for (const dir of ['routes', 'services']) {
    for (const name of fs.readdirSync(path.join(root, dir))) {
      if (!name.endsWith('.js')) continue;
      const source = fs.readFileSync(path.join(root, dir, name), 'utf8')
        // Comments first: several of them name the column while explaining it.
        .replace(/^\s*\/\/.*$/gm, '');
      if (!/parent_allows_recording/.test(source)) continue;
      // A file that only ever writes it is not a file that reads it.
      const writesOnly = /parent_allows_recording\s*=\s*\$/.test(source)
        && !/row\.parent_allows_recording|\.parent_allows_recording\s*===/.test(source);
      readers.push(`${dir}/${name}${writesOnly ? ' (samo upis)' : ''}`);
    }
  }

  assert.ok(
    readers.includes('services/recordingConsent.js'),
    'saglasnost za snimanje se nigde ne čita — kolona je opet samo zapis',
  );
});
