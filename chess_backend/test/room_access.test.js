const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const {
  mayJoinRoom,
  maySpeakInRoom,
  ownsRoom,
  guestAccess,
  setGuestAccess,
  REFUSED,
} = require('../services/roomAccess');

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
  // Whose invitation it is decides whether it is consent at all. Scheduling a
  // session takes a room code and a list of people, and nothing stopped anybody
  // from scheduling one on **somebody else's** code and inviting themselves —
  // an invitation issued to yourself, walking past the guest list.
  assert.match(pool.calls[3].text, /s\.host_id = \$3/);
  assert.deepEqual(pool.calls[3].params, ['123456', 12, 7],
    'soba, pozvani, i tvorac sobe kao domaćin');
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

test('a signed-in stranger is a guest too, where the room takes guests', async () => {
  // The switch used to be asked only of somebody who was *not* signed in, which
  // had it backwards: a stranger who logged out could watch a room that took
  // guests while a parent with an account was turned away. `allow_guests` means
  // one thing now — whoever knows the code may watch — and it is the last door
  // tried, after every other claim has failed.
  const open = stubPool([room(7, true), no, no, no]);
  const seat = await mayJoinRoom(open, { roomCode: '123456', userId: 999 });
  assert.deepEqual(seat, { allowed: true, reason: null, role: 'gost' });

  // Closed, which is the default, and the stranger is where they were.
  const shut = stubPool([room(7, false), no, no, no]);
  assert.equal(
    (await mayJoinRoom(shut, { roomCode: '123456', userId: 999 })).reason,
    REFUSED.notInvited,
  );
});

test('a guest list narrows who is a student, not whether guests may watch',
  async () => {
    // Both controls on at once. The list says who is here as a *student*; the
    // switch says whether anybody may watch at all. They are deliberately
    // independent, and the dialog that offers them says so — a switch that
    // silently stops working because another screen was used would be the
    // surprise this codebase keeps trying not to build.
    const pool = stubPool([room(7, true), yes, yes, no]);

    const seat = await mayJoinRoom(pool, { roomCode: '123456', userId: 11 });

    assert.deepEqual(seat, { allowed: true, reason: null, role: 'gost' });
  });

test('the guest switch belongs to whoever the room belongs to',
  async () => {
    const notMine = stubPool([no]);
    assert.equal(
      await guestAccess(notMine, { roomCode: '123456', userId: 9 }), null);
    assert.equal(notMine.calls.length, 1, 'tuđa soba se ne čita dalje od vlasnika');

    const mine = stubPool([yes, [{ allow_guests: true }]]);
    assert.equal(await guestAccess(mine, { roomCode: '123456', userId: 7 }), true);

    const refused = stubPool([no]);
    assert.equal(
      await setGuestAccess(refused,
        { roomCode: '123456', userId: 9, allowGuests: true }),
      null,
      'tuđa soba se ne otvara',
    );
    assert.equal(refused.calls.length, 1, 'i ne dira se UPDATE-om');
  });

test('the switch reports what the row says, not what the request asked for',
  async () => {
    // The failure this codebase keeps meeting, one layer up: a control that
    // echoes the value it was handed looks right in the app and is wrong in the
    // database. The answer is read back from `RETURNING`.
    const pool = stubPool([yes, [{ allow_guests: false }]]);

    const answer = await setGuestAccess(pool,
      { roomCode: '123456', userId: 7, allowGuests: true });

    assert.equal(answer, false);
    assert.match(pool.calls[1].text, /UPDATE rooms SET allow_guests/);
    assert.match(pool.calls[1].text, /RETURNING allow_guests/);
  });

test('without a code or a user, there is nothing to own', async () => {
  const pool = stubPool([yes]);
  assert.equal(await ownsRoom(pool, { roomCode: '', userId: 7 }), false);
  assert.equal(await ownsRoom(pool, { roomCode: '123456', userId: null }), false);
  assert.equal(pool.calls.length, 0, 'bez koda ili bez korisnika se baza ne pita');
});

test('whoever the room belongs to is always the one who may be heard', async () => {
  const pool = stubPool([room(7)]);

  const seat = await maySpeakInRoom(pool, { roomCode: '123456', userId: 7 });

  assert.deepEqual(seat,
    { allowed: true, maySpeak: true, reason: null, role: 'trener' });
});

test('a student is heard only where the relationship says so', async () => {
  // The rule the whole level model rests on: a child listens, answers on the
  // board and with the ready answers, and their voice is never published — so
  // it is never in the recording either.
  const listens = stubPool([room(7), yes, no, [{ voice_level: 'listen' }]]);
  const quiet = await maySpeakInRoom(listens, { roomCode: '123456', userId: 9 });
  assert.equal(quiet.allowed, true, 'i dalje sme u sobu');
  assert.equal(quiet.maySpeak, false);
  assert.equal(quiet.role, 'ucenik');

  const talks = stubPool([room(7), yes, no, [{ voice_level: 'talk' }]]);
  const heard = await maySpeakInRoom(talks, { roomCode: '123456', userId: 9 });
  assert.equal(heard.maySpeak, true);
  // Read through the accepted edge, in either direction, like everything else
  // that is a right in this file.
  assert.match(talks.calls[3].text, /status = 'accepted'/);
});

test('a guest watches, and is not heard', async () => {
  // Nothing about a guest says anybody agreed to hear them — and if the trainer
  // is recording, a guest's voice would land in uploads/ beside the children's.
  const pool = stubPool([room(7, true)]);

  const seat = await maySpeakInRoom(pool, { roomCode: '123456', userId: null });

  assert.equal(seat.allowed, true);
  assert.equal(seat.maySpeak, false);
  assert.equal(seat.role, 'gost');
});

test('somebody with no relationship behind them listens', async () => {
  // In on an invitation to a scheduled session: there is no row to hold a
  // decision about their microphone, and a missing answer must not read as yes.
  const pool = stubPool([room(7), no, no, yes, []]);

  const seat = await maySpeakInRoom(pool, { roomCode: '123456', userId: 12 });

  assert.equal(seat.allowed, true);
  assert.equal(seat.maySpeak, false);
});

test('somebody refused the room is refused the microphone before it is asked',
  async () => {
    const pool = stubPool([room(7), no, no, no]);

    const seat = await maySpeakInRoom(pool, { roomCode: '123456', userId: 999 });

    assert.deepEqual(seat, {
      allowed: false,
      maySpeak: false,
      reason: REFUSED.notInvited,
      role: null,
    });
    assert.ok(!pool.calls.some((c) => /voice_level/.test(c.text)),
      'ne pita se za glas onaj ko uopšte ne sme unutra');
  });

test('the voice token is not a key to any room', () => {
  // The channel name **is** the room code, and this route used to hand a
  // PUBLISHER token to any signed-in caller who asked for any channel. The guest
  // list guarded the socket while the voice walked around it: take a token, join
  // the Agora channel, be heard in a lesson, never appear on the roster.
  const agora = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'agora.js'), 'utf8')
    .replace(/^\s*\/\/.*$/gm, '');

  assert.match(agora, /maySpeakInRoom/,
    'token se izdaje bez pitanja ko sme u tu sobu');
  assert.match(agora, /RtcRole\.SUBSCRIBER/,
    'svi i dalje dobijaju pravo da objavljuju zvuk');
  assert.match(agora, /403/, 'odbijanje mora da bude izgovoreno');
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

  // `audio_join` asks the wider question — `maySpeakInRoom` decides the seat
  // *and* the microphone, and returns the same answer the voice token is minted
  // from, so the roster and the token cannot disagree.
  const asks = { joinGame: /mayJoinRoom/, audio_join: /maySpeakInRoom/ };

  for (const [handler, expected] of Object.entries(asks)) {
    const start = server.indexOf(`socket.on('${handler}'`);
    assert.ok(start > 0, `${handler} nije nađen u server.js`);
    const body = server.slice(start, start + 1200);
    assert.match(body, expected,
      `${handler} pušta unutra bez provere spiska zvanica`);
  }
});

test('the guest switch is exposed, and refuses a room that is not yours', () => {
  // The column existed for a day with no way to touch it: a rule nobody can
  // see is a rule nobody can rely on. The route reads and writes it, and it
  // refuses a room that is not yours rather than answering `false`.
  const rooms = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'rooms.js'), 'utf8');

  assert.match(rooms, /guest-access/, 'nema rute za prekidač koji soba prima goste');
  assert.match(rooms, /setGuestAccess/);
  assert.match(rooms, /403/, 'tuđa soba mora da bude odbijena, a ne prećutana');
});

test('the two ways to be invited both ask who is inviting', () => {
  // Asserted on the source for the same reason as the socket handlers: the
  // failure is invisible in behaviour. Both routes keep working perfectly for
  // the trainer who uses them, and the only difference is that they also work
  // for somebody typing user ids and a room code they do not own.
  const social = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'social.js'), 'utf8');

  const handler = (route) => {
    const start = social.indexOf(`router.post('${route}'`);
    assert.ok(start > 0, `${route} nije nađen`);
    return social.slice(start, start + 2500).replace(/^\s*\/\/.*$/gm, '');
  };

  const invitations = handler('/invitations/send');
  assert.match(invitations, /acceptedEdgeBetween/,
    'poziv se šalje bilo kom id-u, bez veze sa pošiljaocem');

  const schedule = handler('/sessions/schedule');
  assert.match(schedule, /ownsRoom/,
    'čas se zakazuje u tuđoj sobi, što je ključ za tu sobu');
  assert.match(schedule, /acceptedEdgeBetween/,
    'na čas se poziva neko ko nije prihvatio vezu');
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
