// recording_consent.test.js
// Who may put a voice into `uploads/`, and why almost nobody may.
//
// The rule this file guards changed on 26.8.2026, and it got smaller rather
// than more careful. It used to be "a lesson may be recorded once the parent
// has agreed", enforced against `parent_allows_recording`. It is now: **audio
// is recorded only by an adult who is alone in the room.** A trainer records
// teaching material for themselves; the interaction between a trainer and a
// student is not recorded at all, by anybody, under any consent.
//
// What that buys is written down in `services/recordingConsent.js`. What it
// costs is nothing the replay needs: a recording is a `timeline_json` and
// `audio_url` was always nullable, so the lesson is still replayed — silently.
//
// Three of the tests below are the places this could quietly stop meaning
// anything: a guest who counts for nothing because they have no account, an
// unstated age read as an adult, and the roster losing the very people it now
// exists to notice.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  ADULT_AGE,
  blockedForRecording,
  mayRecordRoom,
  othersInRoom,
} = require('../services/recordingConsent');
const realtime = require('../services/realtime');

const thisYear = new Date().getFullYear();
const ADULT_YEAR = thisYear - 40;
const CHILD_YEAR = thisYear - 10;
// `statedAge` takes the younger reading, so this is seventeen all year.
const ALMOST_ADULT_YEAR = thisYear - ADULT_AGE;

const OWNER = 1;

/// A pool that answers by the shape of the query rather than by call order, so
/// a test does not break when the service asks its questions in a different
/// sequence.
function stubPool({ owner = OWNER, names = {}, years = {} } = {}) {
  return {
    async query(text, params) {
      const sql = String(text).replace(/\s+/g, ' ').trim();
      if (sql.startsWith('SELECT creator_id FROM rooms')) {
        return owner === null
          ? { rows: [], rowCount: 0 }
          : { rows: [{ creator_id: owner }], rowCount: 1 };
      }
      if (sql.startsWith('SELECT id, name FROM users')) {
        const rows = (params[0] ?? [])
          .filter((id) => names[id] !== undefined)
          .map((id) => ({ id, name: names[id] }));
        return { rows, rowCount: rows.length };
      }
      if (sql.startsWith('SELECT birth_year FROM users')) {
        const year = years[params[0]];
        return year === undefined
          ? { rows: [], rowCount: 0 }
          : { rows: [{ birth_year: year }], rowCount: 1 };
      }
      throw new Error('neočekivan upit: ' + sql);
    },
  };
}

test('an adult alone in the room may record', async () => {
  const pool = stubPool({ years: { [OWNER]: ADULT_YEAR } });
  const verdict = await mayRecordRoom(pool, { roomCode: 'r', userIds: [OWNER] });
  assert.equal(verdict.allowed, true);
  assert.deepEqual(verdict.blocked, []);
});

test('the owner never blocks themselves', async () => {
  // They are the one recording, and they arrive in their own roster.
  const pool = stubPool({ years: { [OWNER]: ADULT_YEAR } });
  assert.deepEqual(
    await blockedForRecording(pool, { ownerId: OWNER, userIds: [OWNER, OWNER] }),
    [],
  );
});

test('anybody else in the room blocks it, and is named', async () => {
  const pool = stubPool({ names: { 2: 'Mila' }, years: { [OWNER]: ADULT_YEAR } });
  const verdict = await mayRecordRoom(pool, { roomCode: 'r', userIds: [OWNER, 2] });

  assert.equal(verdict.allowed, false);
  assert.deepEqual(verdict.blocked.map((b) => b.id), [2]);
  assert.match(verdict.reason, /Mila/,
    'odbijanje mora da imenuje onoga zbog koga se ne snima');
  assert.match(verdict.reason, /sami u sobi/,
    'odbijanje mora da kaže pravilo, ne samo činjenicu');
});

test('an adult student blocks it just as a child does', async () => {
  // The age of the other person is not asked any more. This is the shape of the
  // change: it is not a stricter consent check, it is a different question.
  const pool = stubPool({
    names: { 2: 'Petar' },
    years: { [OWNER]: ADULT_YEAR, 2: ADULT_YEAR },
  });
  const verdict = await mayRecordRoom(pool, { roomCode: 'r', userIds: [OWNER, 2] });
  assert.equal(verdict.allowed, false);
});

test('a guest blocks it, though they have no account', async () => {
  // The hole the old rule had by design. A guest joins with a socket id, has no
  // account, no stated age and no relationship, so every question the old check
  // asked came back empty and they were skipped. Under this rule they need no
  // account to matter: they are somebody else in the room.
  const pool = stubPool({ years: { [OWNER]: ADULT_YEAR } });
  const verdict = await mayRecordRoom(pool, {
    roomCode: 'r',
    userIds: [OWNER, 'socket-Ab3xY'],
  });

  assert.equal(verdict.allowed, false);
  assert.equal(verdict.blocked.length, 1);
  assert.match(verdict.reason, /Gost/,
    'gost mora da bude imenovan kao gost, jer drugo ime nema');
});

test('an age nobody has stated is a refusal, not a pass', async () => {
  // The one place in this codebase where an unstated age is *not* grandfathered,
  // and deliberately so: everywhere else refusing on an empty column would
  // switch off a working feature for accounts nobody has asked yet. Here the
  // permission is to create the one artefact that cannot be taken back, so
  // "we never asked" must not read as "yes".
  const pool = stubPool({ years: {} });
  const verdict = await mayRecordRoom(pool, { roomCode: 'r', userIds: [OWNER] });

  assert.equal(verdict.allowed, false);
  assert.deepEqual(verdict.blocked, [], 'nema koga da imenuje — pitanje je o vlasniku');
  assert.match(verdict.reason, /godinu rođenja/,
    'odbijanje mora da kaže šta korisnik treba da uradi');
});

test('a minor alone in the room may not record either', async () => {
  const pool = stubPool({ years: { [OWNER]: CHILD_YEAR } });
  const verdict = await mayRecordRoom(pool, { roomCode: 'r', userIds: [OWNER] });
  assert.equal(verdict.allowed, false);
  assert.match(verdict.reason, /punoletn/);
});

test('seventeen is not eighteen', async () => {
  // The threshold is majority rather than `AGE_OF_CONSENT`, which runs 13–18 by
  // country and answers a different question. A year is read at its younger
  // end, so this account is seventeen for the whole year.
  const pool = stubPool({ years: { [OWNER]: ALMOST_ADULT_YEAR } });
  const verdict = await mayRecordRoom(pool, { roomCode: 'r', userIds: [OWNER] });
  assert.equal(verdict.allowed, false);
});

test('a room that does not exist records nothing', async () => {
  const pool = stubPool({ owner: null });
  const verdict = await mayRecordRoom(pool, { roomCode: 'nema', userIds: [OWNER] });
  assert.equal(verdict.allowed, false);
});

test('ids of different types are one person', async () => {
  // The owner arrives as a number from the database and as a string from the
  // roster. Compared loosely they are one person; compared strictly the trainer
  // blocks their own recording and the reason names them.
  assert.deepEqual(othersInRoom(['1', 1, ''], 1), []);
  assert.deepEqual(othersInRoom([1, '2'], 1), ['2']);
});

test('the roster keeps guests, which is the whole point of it now', async () => {
  // The specific hole that would reopen silently. `noteRecordedParticipant`
  // used to drop anybody without a numeric id — correct while the question was
  // "has this child's parent agreed", and fatal now that it is "are you alone".
  const room = 'test-room-guests';
  realtime.clearRecordedRoster(room);
  realtime.beginRecordingRoster(room, [OWNER]);

  assert.equal(realtime.noteRecordedParticipant(room, 'socket-Zz9'), true,
    'gost mora da uđe u spisak učesnika');
  assert.deepEqual(realtime.recordedRoster(room).sort(), ['1', 'socket-Zz9']);

  realtime.clearRecordedRoster(room);
});
