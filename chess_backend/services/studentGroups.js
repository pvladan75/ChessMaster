// studentGroups.js — named lists of students, and the guest list of a room.
//
// Asked for by a trainer with the plain reason: with forty students, inviting
// the same eight every Tuesday means going down a list and finding them each
// time. A group is that list, named once.
//
// Two rules hold the whole file together:
//
//   **A group is a convenience, never a right.** Being in "Utorak 18h" does not
//   make somebody your student; the accepted relationship does, and that is
//   checked every time a name is added and again every time the door opens. So
//   a relationship that ends closes the door even if the row in the group is
//   still there.
//
//   **A guest list narrows, it never widens.** An empty list means what the
//   room always meant — every accepted student of the creator may come. One row
//   and the room is those people only, which is exactly what "invite the group"
//   is supposed to mean. Individuals and groups sit on the same list, because
//   the trainer asked for both and there is no reason for two mechanisms.

const { acceptedEdgeBetween } = require('./relationshipService');

/// Loud rather than convenient: a caller that asks about somebody else's group
/// has a bug, and answering "no members" would hide it.
class NotYours extends Error {
  constructor(message = 'Ta grupa nije vaša.') {
    super(message);
    this.name = 'NotYours';
  }
}

async function ownsGroup(pool, trainerId, groupId) {
  const result = await pool.query(
    'SELECT 1 FROM student_groups WHERE id = $1 AND trainer_id = $2',
    [groupId, trainerId],
  );
  return result.rowCount > 0;
}

async function createGroup(pool, trainerId, { name }) {
  const clean = typeof name === 'string' ? name.trim() : '';
  if (clean === '') throw new RangeError('Grupa mora imati ime.');

  const result = await pool.query(
    `INSERT INTO student_groups (trainer_id, name)
     VALUES ($1, $2)
     RETURNING id, name, created_at`,
    [trainerId, clean],
  );
  return result.rows[0];
}

async function renameGroup(pool, trainerId, groupId, { name }) {
  const clean = typeof name === 'string' ? name.trim() : '';
  if (clean === '') throw new RangeError('Grupa mora imati ime.');

  const result = await pool.query(
    `UPDATE student_groups SET name = $1
      WHERE id = $2 AND trainer_id = $3
      RETURNING id, name`,
    [clean, groupId, trainerId],
  );
  if (result.rowCount === 0) throw new NotYours();
  return result.rows[0];
}

async function deleteGroup(pool, trainerId, groupId) {
  const result = await pool.query(
    'DELETE FROM student_groups WHERE id = $1 AND trainer_id = $2',
    [groupId, trainerId],
  );
  if (result.rowCount === 0) throw new NotYours();
  return { deleted: true };
}

/// The trainer's groups, with how many people are in each.
async function listGroups(pool, trainerId) {
  const result = await pool.query(
    `SELECT g.id, g.name, g.created_at,
            (SELECT COUNT(*)::int FROM student_group_members m
              WHERE m.group_id = g.id) AS members
       FROM student_groups g
      WHERE g.trainer_id = $1
      ORDER BY g.name ASC`,
    [trainerId],
  );
  return result.rows.map((row) => ({
    id: row.id,
    name: row.name,
    members: row.members,
    createdAt: row.created_at,
  }));
}

/// Who is in the group — names only.
///
/// No email. A trainer already knows how to reach their student, and an address
/// that travels through a list is an address that ends up on a screen it was
/// never meant for. Most of the people in these lists are children.
async function listMembers(pool, trainerId, groupId) {
  if (!(await ownsGroup(pool, trainerId, groupId))) throw new NotYours();

  const result = await pool.query(
    `SELECT u.id, u.name
       FROM student_group_members m
       JOIN users u ON u.id = m.student_id
      WHERE m.group_id = $1
      ORDER BY u.name ASC`,
    [groupId],
  );
  return result.rows;
}

/// Adds a student, and only a student.
///
/// The accepted relationship is checked here rather than assumed from the fact
/// that the trainer typed the name: a group must not become a second way to
/// attach yourself to somebody who never agreed to it.
async function addMember(pool, trainerId, groupId, studentId) {
  if (!(await ownsGroup(pool, trainerId, groupId))) throw new NotYours();
  if (!(await acceptedEdgeBetween(pool, trainerId, studentId))) {
    throw new RangeError('Taj učenik nije prihvatio vezu sa vama.');
  }

  await pool.query(
    `INSERT INTO student_group_members (group_id, student_id)
     VALUES ($1, $2)
     ON CONFLICT DO NOTHING`,
    [groupId, studentId],
  );
  return { added: true };
}

async function removeMember(pool, trainerId, groupId, studentId) {
  if (!(await ownsGroup(pool, trainerId, groupId))) throw new NotYours();
  const result = await pool.query(
    'DELETE FROM student_group_members WHERE group_id = $1 AND student_id = $2',
    [groupId, studentId],
  );
  return { removed: result.rowCount > 0 };
}

async function ownsRoom(pool, trainerId, roomCode) {
  const result = await pool.query(
    'SELECT 1 FROM rooms WHERE room_code = $1 AND creator_id = $2',
    [roomCode, trainerId],
  );
  return result.rowCount > 0;
}

/// Puts people on a room's guest list: whole groups, single students, or both.
///
/// The first row narrows the room. That is the behaviour the trainer asked for
/// — "invite the group" has to mean *only* the group — and it is why an empty
/// list is left meaning "all my students" rather than "nobody".
async function inviteToRoom(pool, trainerId, roomCode, { groupIds = [], userIds = [] } = {}) {
  if (!(await ownsRoom(pool, trainerId, roomCode))) {
    throw new NotYours('Ta soba nije vaša.');
  }

  for (const groupId of groupIds) {
    if (!(await ownsGroup(pool, trainerId, groupId))) throw new NotYours();
    await pool.query(
      `INSERT INTO room_guests (room_code, group_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [roomCode, groupId],
    );
  }

  for (const userId of userIds) {
    // Same check as for a group member, for the same reason: an invitation is
    // not a way around consent.
    if (!(await acceptedEdgeBetween(pool, trainerId, userId))) {
      throw new RangeError('Taj učenik nije prihvatio vezu sa vama.');
    }
    await pool.query(
      `INSERT INTO room_guests (room_code, user_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [roomCode, userId],
    );
  }

  return { groups: groupIds.length, students: userIds.length };
}

async function uninviteFromRoom(pool, trainerId, roomCode, { groupId = null, userId = null } = {}) {
  if (!(await ownsRoom(pool, trainerId, roomCode))) {
    throw new NotYours('Ta soba nije vaša.');
  }
  if ((groupId === null) === (userId === null)) {
    throw new RangeError('Uklonite ili grupu ili pojedinca, ne oboje.');
  }

  const result = groupId !== null
    ? await pool.query(
      'DELETE FROM room_guests WHERE room_code = $1 AND group_id = $2',
      [roomCode, groupId])
    : await pool.query(
      'DELETE FROM room_guests WHERE room_code = $1 AND user_id = $2',
      [roomCode, userId]);
  return { removed: result.rowCount > 0 };
}

/// What the room's guest list holds, for the screen that manages it. Names, not
/// addresses.
async function roomGuests(pool, trainerId, roomCode) {
  if (!(await ownsRoom(pool, trainerId, roomCode))) {
    throw new NotYours('Ta soba nije vaša.');
  }
  const result = await pool.query(
    `SELECT rg.group_id, rg.user_id, g.name AS group_name, u.name AS user_name
       FROM room_guests rg
       LEFT JOIN student_groups g ON g.id = rg.group_id
       LEFT JOIN users u ON u.id = rg.user_id
      WHERE rg.room_code = $1
      ORDER BY g.name ASC, u.name ASC`,
    [roomCode],
  );
  return result.rows.map((row) => row.group_id !== null
    ? { kind: 'group', id: row.group_id, name: row.group_name }
    : { kind: 'student', id: row.user_id, name: row.user_name });
}

module.exports = {
  NotYours,
  createGroup,
  renameGroup,
  deleteGroup,
  listGroups,
  listMembers,
  addMember,
  removeMember,
  inviteToRoom,
  uninviteFromRoom,
  roomGuests,
};
