const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { mayJoinRoom, REFUSED } = require('../services/roomAccess');

/// The rule this file pins, and why it had to be written at all:
///
/// `joinGame` used to take a room code and join, asking nothing — not a
/// relationship, not an invitation, not even whether the caller was signed in.
/// `audio_join` was the same, so whoever guessed a six-digit code was in a live
/// voice conversation with a child, and in the recording if one was running.
///
/// A room is a place with a guest list. The code names the room; it does not
/// authorise anybody.
function stubPool(results) {
  const calls = [];
  let index = 0;
  return {
    calls,
    async query(text, params) {
      calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
      const rows = results[Math.min(index, results.length - 1)] ?? [];
      index += 1;
      return { rows, rowCount: rows.length };
    },
  };
}

const room = (creatorId, allowGuests = false) => [
  { creator_id: creatorId, allow_guests: allowGuests },
];

test('the creator is let in, as the host', async () => {
  const pool = stubPool([room(7)]);

  const seat = await mayJoinRoom(pool, { roomCode: '123456', userId: 7 });

  assert.deepEqual(seat, { allowed: true, reason: null, role: 'trener' });
});

const yes = [{ '?column?': 1 }];
const no = [];

test('an accepted student of the creator is let in', async () => {
  // room, the relationship, "is there a guest list" — none here, so the
  // relationship alone answers.
  const pool = stubPool([room(7), yes, no]);

  const seat = await mayJoinRoom(pool, { roomCode: '123456', userId: 9 });

  assert.equal(seat.allowed, true);
  assert.equal(seat.role, 'ucenik');
  // Read through the shared check, which is the only place that remembers
  // `status = 'accepted'` — three hand-written copies of it did not.
  assert.match(pool.calls[1].text, /status = 'accepted'/);
});

test('a stranger with the right code is refused', async () => {
  // The whole point. Before this existed, this call was the one that let
  // somebody into a voice room with a child.
  const pool = stubPool([room(7), no, no, no]);

  const seat = await mayJoinRoom(pool, { roomCode: '123456', userId: 999 });

  assert.deepEqual(seat, {
    allowed: false,
    reason: REFUSED.notInvited,
    role: null,
  });
});

test('somebody invited to a session on this room code is let in', async () => {
  // The invitation is the consent, and it is already recorded.
  const pool = stubPool([room(7), no, no, yes]);

  const seat = await mayJoinRoom(pool, { roomCode: '123456', userId: 12 });

  assert.equal(seat.allowed, true);
  assert.match(pool.calls[3].text, /scheduled_session_invites/);
  assert.match(pool.calls[3].text, /status <> 'declined'/);
});

test('a guest list narrows the room to the people on it', async () => {
  // What "invite this group" has to mean: those eight, and nobody else. The
  // trainer asked for it because going down a list of forty every Tuesday is
  // the thing groups exist to stop.
  const onIt = stubPool([room(7), yes, yes, yes]);
  const seat = await mayJoinRoom(onIt, { roomCode: '123456', userId: 9 });
  assert.equal(seat.allowed, true);
  assert.equal(seat.role, 'ucenik');
  // The list is read once for "is there one" and once for "are you on it".
  assert.match(onIt.calls[2].text, /FROM room_guests/);
  assert.match(onIt.calls[3].text, /student_group_members/);

  // Another student of the same trainer, not on the list: turned away. Before
  // groups this person could walk in, which is precisely what was asked to end.
  const notOnIt = stubPool([room(7), yes, yes, no]);
  const refused = await mayJoinRoom(notOnIt, { roomCode: '123456', userId: 11 });
  assert.deepEqual(refused, {
    allowed: false,
    reason: REFUSED.notInvited,
    role: null,
  });
});

test('the list holds single students as well as groups', async () => {
  // Asked for in the same breath as groups: sometimes it is one person.
  const pool = stubPool([room(7), yes, yes, yes]);

  await mayJoinRoom(pool, { roomCode: '123456', userId: 9 });

  const onList = pool.calls[3].text;
  assert.match(onList, /rg\.user_id/);
  assert.match(onList, /m\.student_id/);
});

test('a group row left behind is not a key', async () => {
  // On the list, but the relationship is gone — somebody who stopped being a
  // student. Membership is a convenience; the accepted edge is the right.
  const pool = stubPool([room(7), no, yes, yes]);

  const seat = await mayJoinRoom(pool, { roomCode: '123456', userId: 9 });

  assert.equal(seat.allowed, false);
  assert.equal(seat.reason, REFUSED.notInvited);
});

test('a guest is refused unless the room says otherwise', async () => {
  const closed = stubPool([room(7, false)]);
  assert.deepEqual(await mayJoinRoom(closed, { roomCode: '123456' }), {
    allowed: false,
    reason: REFUSED.guestNotAllowed,
    role: null,
  });

  // Off by default, because the default decides what happens in the room
  // nobody thought about.
  const open = stubPool([room(7, true)]);
  const seat = await mayJoinRoom(open, { roomCode: '123456', userId: null });
  assert.equal(seat.allowed, true);
  assert.equal(seat.role, 'gost');
});

test('a room that does not exist is not a room to be let into', async () => {
  const pool = stubPool([[]]);
  const seat = await mayJoinRoom(pool, { roomCode: '000000', userId: 7 });
  assert.equal(seat.reason, REFUSED.noRoom);

  const empty = stubPool([[]]);
  assert.equal(
    (await mayJoinRoom(empty, { roomCode: '', userId: 7 })).reason,
    REFUSED.noRoom,
  );
  assert.equal(empty.calls.length, 0, 'bez koda se baza i ne pita');
});

test('the room socket handlers ask before they admit anybody', () => {
  // Asserted on the source, because the failure it guards against is invisible
  // in behaviour: the room works perfectly for everyone who belongs in it, and
  // the only difference is that it also works for everyone who does not.
  const server = fs.readFileSync(
    path.join(__dirname, '..', 'server.js'), 'utf8');

  for (const handler of ['joinGame', 'audio_join']) {
    const start = server.indexOf(`socket.on('${handler}'`);
    assert.ok(start > 0, `${handler} nije nađen u server.js`);
    const body = server.slice(start, start + 1200);
    assert.match(body, /mayJoinRoom/,
      `${handler} pušta unutra bez provere spiska zvanica`);
  }
});

test('the room code comes from a real random source', () => {
  // Not the lock any more — the guest list is — but a lock that is not one
  // should not look like one either.
  const rooms = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'rooms.js'), 'utf8');
  // Comments stripped first: the comment above the generator names the thing it
  // replaced, so a test that reads prose finds what the code no longer does.
  const code = rooms.replace(/^\s*\/\/.*$/gm, '');

  assert.doesNotMatch(code, /Math\.random\(\)/,
    'kod sobe se i dalje pravi iz Math.random()');
  assert.match(code, /crypto\.randomInt/);
});
