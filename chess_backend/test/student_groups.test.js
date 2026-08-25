const test = require('node:test');
const assert = require('node:assert/strict');

const {
  NotYours,
  createGroup,
  deleteGroup,
  listGroups,
  listMembers,
  addMember,
  removeMember,
  inviteToRoom,
  uninviteFromRoom,
  roomGuests,
} = require('../services/studentGroups');

/// Groups exist for one plain reason a trainer gave: with forty students,
/// inviting the same eight every Tuesday means going down a list and finding
/// them each time. What is pinned here is that the convenience never becomes a
/// right — a name in a group is not consent, and the accepted relationship is
/// checked every time.
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
    ran: (fragment) => calls.filter((c) => c.text.includes(fragment)).length,
  };
}

const yes = [{ '?column?': 1 }];
const no = [];

test('a group needs a name', async () => {
  const pool = stubPool([[]]);
  await assert.rejects(() => createGroup(pool, 7, { name: '  ' }), RangeError);
  assert.equal(pool.calls.length, 0, 'ništa se ne šalje bazi dok ime ne stoji');
});

test('somebody else\'s group is refused, not answered emptily', async () => {
  // An empty answer would hide the bug that asked the question.
  const pool = stubPool([no]);
  await assert.rejects(() => listMembers(pool, 7, 3), NotYours);

  const gone = stubPool([no]);
  await assert.rejects(() => deleteGroup(gone, 7, 3), NotYours);
});

test('only an accepted student can be put in a group', async () => {
  // The group must not become a second way to attach yourself to somebody who
  // never agreed to it — the same rule the relationship itself lives by.
  const pool = stubPool([yes, no]);

  await assert.rejects(() => addMember(pool, 7, 3, 99), RangeError);

  assert.match(pool.calls[1].text, /status = 'accepted'/);
  assert.equal(pool.ran('INSERT INTO student_group_members'), 0);
});

test('an accepted student is added once, however often it is asked', async () => {
  const pool = stubPool([yes, yes, []]);

  await addMember(pool, 7, 3, 9);

  assert.match(pool.calls[2].text, /INSERT INTO student_group_members/);
  assert.match(pool.calls[2].text, /ON CONFLICT DO NOTHING/);
});

test('members come back as names, without addresses', async () => {
  // Most of the people in these lists are children, and an address that
  // travels through a list ends up on a screen it was never meant for.
  const pool = stubPool([yes, [{ id: 9, name: 'Mika' }]]);

  const members = await listMembers(pool, 7, 3);

  assert.deepEqual(members, [{ id: 9, name: 'Mika' }]);
  assert.doesNotMatch(pool.calls[1].text, /email/);
});

test('groups are listed with how many people are in each', async () => {
  const pool = stubPool([[
    { id: 3, name: 'Utorak 18h', members: 8, created_at: 'x' },
  ]]);

  const groups = await listGroups(pool, 7);

  assert.deepEqual(groups[0],
    { id: 3, name: 'Utorak 18h', members: 8, createdAt: 'x' });
});

test('a whole group is invited to a room in one go', async () => {
  const pool = stubPool([yes, yes, []]);

  const result = await inviteToRoom(pool, 7, '123456', { groupIds: [3] });

  assert.deepEqual(result, { groups: 1, students: 0 });
  assert.match(pool.calls[2].text, /INSERT INTO room_guests \(room_code, group_id\)/);
});

test('one person can be invited too, and consent is still checked', async () => {
  // Asked for in the same breath as groups: sometimes it is one student.
  const pool = stubPool([yes, no]);

  await assert.rejects(
    () => inviteToRoom(pool, 7, '123456', { userIds: [99] }),
    RangeError,
  );
  assert.equal(pool.ran('INSERT INTO room_guests'), 0);

  const ok = stubPool([yes, yes, []]);
  await inviteToRoom(ok, 7, '123456', { userIds: [9] });
  assert.match(ok.calls[2].text, /INSERT INTO room_guests \(room_code, user_id\)/);
});

test('a room that is not yours cannot be given a guest list', async () => {
  const pool = stubPool([no]);
  await assert.rejects(
    () => inviteToRoom(pool, 7, '123456', { groupIds: [3] }),
    NotYours,
  );
});

test('removing a guest takes one target, not two', async () => {
  const both = stubPool([yes]);
  await assert.rejects(
    () => uninviteFromRoom(both, 7, '123456', { groupId: 3, userId: 9 }),
    RangeError,
  );

  const neither = stubPool([yes]);
  await assert.rejects(
    () => uninviteFromRoom(neither, 7, '123456', {}),
    RangeError,
  );

  const one = stubPool([yes, [{}]]);
  assert.deepEqual(
    await uninviteFromRoom(one, 7, '123456', { groupId: 3 }),
    { removed: true },
  );
});

test('the guest list reads back as groups and people, by name', async () => {
  const pool = stubPool([yes, [
    { group_id: 3, user_id: null, group_name: 'Utorak 18h', user_name: null },
    { group_id: null, user_id: 9, group_name: null, user_name: 'Mika' },
  ]]);

  const guests = await roomGuests(pool, 7, '123456');

  assert.deepEqual(guests, [
    { kind: 'group', id: 3, name: 'Utorak 18h' },
    { kind: 'student', id: 9, name: 'Mika' },
  ]);
});

test('taking somebody out of a group says whether it did anything', async () => {
  const pool = stubPool([yes, []]);
  assert.deepEqual(await removeMember(pool, 7, 3, 9), { removed: false });
});
