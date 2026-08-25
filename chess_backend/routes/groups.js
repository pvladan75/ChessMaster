// groups.js — a trainer's named lists of students, and a room's guest list.
//
// Asked for plainly: with forty students, inviting the same eight every Tuesday
// means hunting down a list every time. A group is that list, named once — and
// because the same trainer also asked to invite one person now and then, both
// land on the same guest list rather than growing two mechanisms.
//
// Every route is scoped to `req.user.id` as the trainer. Somebody else's group
// is refused rather than answered emptily: an empty answer hides the bug that
// asked the question.

const express = require('express');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const {
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
} = require('../services/studentGroups');

/// One place where a caller's mistake becomes a 400 or a 403, and everything
/// else becomes a 500 with a line in the log.
function answer(res, work, whatFailed) {
  return work.then(
    (value) => res.json(value),
    (err) => {
      if (err instanceof NotYours) {
        return res.status(403).json({ error: err.message });
      }
      if (err instanceof RangeError) {
        return res.status(400).json({ error: err.message });
      }
      if (err && err.code === '23505') {
        return res.status(409).json({ error: 'To ime je već zauzeto.' });
      }
      logger.error(`[GRUPE] ${whatFailed}: ${err.message}`);
      return res.status(500).json({ error: whatFailed });
    },
  );
}

// GET /groups
router.get('/', authenticateToken, (req, res) => {
  answer(res, listGroups(pool, req.user.id).then((groups) => ({ groups })),
    'Spisak grupa nije mogao da se pročita.');
});

// POST /groups  { name }
router.post('/', authenticateToken, (req, res) => {
  answer(res, createGroup(pool, req.user.id, { name: req.body?.name }),
    'Grupa nije mogla da se napravi.');
});

// PATCH /groups/:id  { name }
router.patch('/:id', authenticateToken, (req, res) => {
  answer(
    res,
    renameGroup(pool, req.user.id, Number(req.params.id), { name: req.body?.name }),
    'Grupa nije mogla da se preimenuje.',
  );
});

// DELETE /groups/:id
router.delete('/:id', authenticateToken, (req, res) => {
  answer(res, deleteGroup(pool, req.user.id, Number(req.params.id)),
    'Grupa nije mogla da se obriše.');
});

// GET /groups/:id/members — names only; a list is not the place for addresses.
router.get('/:id/members', authenticateToken, (req, res) => {
  answer(
    res,
    listMembers(pool, req.user.id, Number(req.params.id))
      .then((members) => ({ members })),
    'Spisak članova nije mogao da se pročita.',
  );
});

// POST /groups/:id/members  { studentId }
router.post('/:id/members', authenticateToken, (req, res) => {
  answer(
    res,
    addMember(pool, req.user.id, Number(req.params.id),
      Number(req.body?.studentId)),
    'Učenik nije mogao da se doda u grupu.',
  );
});

// DELETE /groups/:id/members/:studentId
router.delete('/:id/members/:studentId', authenticateToken, (req, res) => {
  answer(
    res,
    removeMember(pool, req.user.id, Number(req.params.id),
      Number(req.params.studentId)),
    'Učenik nije mogao da se ukloni iz grupe.',
  );
});

// GET /groups/rooms/:roomCode/guests — who the room is open to.
router.get('/rooms/:roomCode/guests', authenticateToken, (req, res) => {
  answer(
    res,
    roomGuests(pool, req.user.id, req.params.roomCode)
      .then((guests) => ({ guests })),
    'Spisak zvanica nije mogao da se pročita.',
  );
});

// POST /groups/rooms/:roomCode/guests  { groupIds: [], userIds: [] }
//
// The first entry narrows the room to the guest list. Empty keeps the old
// meaning — every accepted student of the creator — so a trainer who never
// touches this screen loses nothing.
router.post('/rooms/:roomCode/guests', authenticateToken, (req, res) => {
  const groupIds = Array.isArray(req.body?.groupIds)
    ? req.body.groupIds.map(Number) : [];
  const userIds = Array.isArray(req.body?.userIds)
    ? req.body.userIds.map(Number) : [];
  answer(
    res,
    inviteToRoom(pool, req.user.id, req.params.roomCode, { groupIds, userIds }),
    'Zvanice nisu mogle da se dodaju.',
  );
});

// DELETE /groups/rooms/:roomCode/guests?groupId=  |  ?userId=
router.delete('/rooms/:roomCode/guests', authenticateToken, (req, res) => {
  const groupId = req.query.groupId ? Number(req.query.groupId) : null;
  const userId = req.query.userId ? Number(req.query.userId) : null;
  answer(
    res,
    uninviteFromRoom(pool, req.user.id, req.params.roomCode, { groupId, userId }),
    'Zvanica nije mogla da se ukloni.',
  );
});

module.exports = router;
