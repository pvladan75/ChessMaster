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

test('the door opens for the creator’s students, not for the creator’s trainer', async () => {
  // The owner's decision of 21.9.2026: whoever starts a session is teaching in
  // it. The relationship used to be read in either direction, so a trainer could
  // enter a student's room and be seated as a student. A sequential stub cannot
  // see a direction, so this one answers the question it is actually asked:
  // 7 teaches 9, and nothing else is true.
  const teaches = (trainerId, studentId) => trainerId === 7 && studentId === 9;
  const poolFor = (creatorId) => ({
    async query(text, params) {
      const sql = text.replace(/\s+/g, ' ');
      if (/FROM rooms WHERE room_code/.test(sql)) {
        return { rows: [{ creator_id: creatorId, allow_guests: false }], rowCount: 1 };
      }
      if (/FROM trainer_students/.test(sql)) {
        const [a, b] = params.map(Number);
        const eitherWay = /trainer_id = \$2/.test(sql);
        const hit = teaches(a, b) || (eitherWay && teaches(b, a));
        return hit ? { rows: [{ ok: 1 }], rowCount: 1 } : { rows: [], rowCount: 0 };
      }
      return { rows: [], rowCount: 0 };
    },
  });

  const student = await mayJoinRoom(poolFor(7), { roomCode: '123456', userId: 9 });
  assert.equal(student.allowed, true);
  assert.equal(student.role, 'ucenik');

  const trainer = await mayJoinRoom(poolFor(9), { roomCode: '123456', userId: 7 });
  assert.equal(trainer.allowed, false, 'a trainer walked into a student’s room');
  assert.equal(trainer.reason, REFUSED.notInvited);
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

test('an invitation to a scheduled session is no longer a door', async () => {
  // Supersedes „somebody invited to a session on this room code is let in".
  // Scheduled sessions were removed on 21.9.2026 on the owner's word
  // (`docs/PLAN-SESIJA.md`, §5.4): nothing in the app could write one, and the
  // door they opened was one more way into a room. The stub would still answer
  // „yes" to a fourth question — the point is that nobody asks it.
  const pool = stubPool([room(7), no, no, yes]);

  const seat = await mayJoinRoom(pool, { roomCode: '123456', userId: 12 });

  assert.equal(seat.allowed, false);
  assert.equal(seat.reason, REFUSED.notInvited);
  assert.ok(!pool.calls.some((call) => /scheduled_session/.test(call.text)),
    'mayJoinRoom still reads scheduled sessions');
});

const archived = (creatorId) => [
  { creator_id: creatorId, allow_guests: false, status: 'archived' },
];

test('an ended session admits nobody, its creator included', async () => {
  const owner = await mayJoinRoom(stubPool([archived(7)]), { roomCode: '123456', userId: 7 });
  assert.deepEqual(owner, { allowed: false, reason: REFUSED.ended, role: null });

  const student = await mayJoinRoom(stubPool([archived(7), yes, no]),
    { roomCode: '123456', userId: 9 });
  assert.deepEqual(student, { allowed: false, reason: REFUSED.ended, role: null });
});

test('a stranger is not told that a room has ended', async () => {
  // „Ended" confirms that the code once named a room. Somebody with no seat in
  // it hears what a stranger always heard.
  const seat = await mayJoinRoom(stubPool([archived(7), no, no]),
    { roomCode: '123456', userId: 99 });

  assert.equal(seat.allowed, false);
  assert.equal(seat.reason, REFUSED.notInvited);
});

test('an ended session has no voice either', async () => {
  // `/agora/token` and `audio_join` ask `maySpeakInRoom`, which asks
  // `mayJoinRoom` — so the channel closes with the room, by construction.
  const seat = await maySpeakInRoom(stubPool([archived(7)]), { roomCode: '123456', userId: 7 });

  assert.equal(seat.allowed, false);
  assert.equal(seat.maySpeak, false);
  assert.equal(seat.reason, REFUSED.ended);
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

test('a seat with no voice decision behind it listens', async () => {
  // Seated as a student, and the relationship row that would hold the decision
  // about their microphone is not found. A missing answer must not read as yes.
  const pool = stubPool([room(7), yes, no, []]);

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
  //
  // Comments stripped and each handler read by itself: the file's comment says
  // „a plain 403 for anybody else", so matching `/403/` over the file passed
  // with both refusals turned into `res.json({ allowGuests: false })` — the
  // exact failure the message names. Audit of 16.9.2026,
  // `docs/audit/tests.md`, 7.
  const rooms = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'rooms.js'), 'utf8')
    .replace(/^\s*\/\/.*$/gm, '');

  assert.match(rooms, /setGuestAccess/);
  for (const method of ['get', 'patch']) {
    const start = rooms.indexOf(`router.${method}('/:roomCode/guest-access'`);
    assert.ok(start >= 0, `nema rute ${method.toUpperCase()} za prekidač koji soba prima goste`);
    const open = rooms.indexOf('{', rooms.indexOf('=>', start));
    let depth = 0;
    let end = open;
    for (; end < rooms.length; end += 1) {
      if (rooms[end] === '{') depth += 1;
      if (rooms[end] === '}') depth -= 1;
      if (depth === 0) break;
    }
    const body = rooms.slice(open, end + 1);
    assert.match(body, /res\.status\(403\)/,
      `${method.toUpperCase()} guest-access: tuđa soba mora da bude odbijena, a ne prećutana`);
  }
});

test('an invitation asks who is inviting, and into which room', () => {
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
  // `trainerOwnsStudent` since 21.9.2026: whoever starts a session invites
  // their own students, so the check names the direction as well as the status.
  assert.match(invitations, /trainerOwnsStudent/,
    'poziv se šalje bilo kom id-u, bez veze sa pošiljaocem');

  // And only into the sender's own live session: the route used to take any
  // room code at all.
  assert.match(invitations, /mayJoinRoom/,
    'poziv može da imenuje tuđu ili završenu sobu');

  assert.ok(!social.includes("'/sessions/schedule'"),
    'zakazane sesije su uklonjene 21.9.2026 i ne vraćaju se kao druga vrata u sobu');
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
