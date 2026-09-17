// routes/homeworks.js
//
// The homework a trainer writes and keeps (docs/PLAN-DOMACI-ZADATAK.md §5,
// phase 3). Writing one costs no quota: sending it does, one unit per student
// per homework (owner, 17.9.2026), and sending is phase 4.
//
// Every route is the trainer's own: `homeworkTemplate` scopes each query by
// `trainer_id` and answers 404 for „no such homework" and „not yours" alike,
// so a guessed id tells nobody which homeworks exist.

const express = require('express');

const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const template = require('../services/homeworkTemplate');
const { sendHomework } = require('../services/homeworkSend');
const { requireQuota, refundQuota } = require('../middleware/entitlements');
const { ENT } = require('../services/entitlementService');
const { notify } = require('../services/notifications');

const router = express.Router();

// GET /homeworks — the trainer's own, newest edit first.
router.get('/', authenticateToken, async (req, res) => {
  try {
    res.json({ homeworks: await template.listHomeworks(pool, req.user.id) });
  } catch (err) {
    logger.error('Error listing homeworks:', err);
    res.status(500).json({ error: 'Error loading homeworks.' });
  }
});

// POST /homeworks — a new one, with its items in the order they were written.
router.post('/', authenticateToken, async (req, res) => {
  try {
    const result = await template.saveHomework(pool, {
      trainerId: req.user.id,
      payload: req.body,
    });
    if (!result.ok) return res.status(result.status).json({ error: result.error });
    res.status(201).json(result.homework);
  } catch (err) {
    logger.error('Error creating a homework:', err);
    res.status(500).json({ error: 'Error saving the homework.' });
  }
});

// GET /homeworks/:id — one homework, its items in order, and where it has
// already been sent.
router.get('/:id', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'Invalid homework ID.' });

  try {
    const homework = await template.loadHomework(pool, id, req.user.id);
    if (!homework) return res.status(404).json({ error: 'Homework not found.' });
    res.json(homework);
  } catch (err) {
    logger.error('Error loading a homework:', err);
    res.status(500).json({ error: 'Error loading the homework.' });
  }
});

// PUT /homeworks/:id — the whole homework as the editor now shows it.
//
// The items are a list, not a patch: an item that comes back with a key it
// really has keeps that key and everything a sent copy points at; an item with
// no key is new; an item the editor did not send is gone. Reordering therefore
// rewrites positions and no keys.
router.put('/:id', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'Invalid homework ID.' });

  try {
    const result = await template.saveHomework(pool, {
      trainerId: req.user.id,
      homeworkId: id,
      payload: req.body,
    });
    if (!result.ok) return res.status(result.status).json({ error: result.error });
    res.json(result.homework);
  } catch (err) {
    logger.error('Error saving a homework:', err);
    res.status(500).json({ error: 'Error saving the homework.' });
  }
});

// POST /homeworks/:id/send — one homework to one student.
//
// One student per request, and therefore **one quota unit per student per
// homework** whatever it holds (owner, 17.9.2026). A dialog that was given
// three students sends three requests and pays three units; the five items
// inside cost nothing extra, which is what „the homework is the unit" means.
//
// The unit goes back on every refusal, because a refusal writes nothing:
// `sendHomework` plans every item before it opens its transaction.
router.post('/:id/send', authenticateToken, requireQuota(ENT.ASSIGNMENTS), async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  const studentId = Number.parseInt(req.body?.studentId, 10);
  if (!Number.isInteger(id) || !Number.isInteger(studentId)) {
    await refundQuota(req);
    return res.status(400).json({ error: 'A homework and a student are required.' });
  }

  try {
    const result = await sendHomework(pool, {
      trainerId: req.user.id,
      studentId,
      homeworkId: id,
      dueAt: req.body?.dueAt || null,
      note: typeof req.body?.note === 'string' && req.body.note.trim()
        ? req.body.note.trim()
        : null,
    });
    if (!result.ok) {
      await refundQuota(req);
      return res.status(result.status).json({ error: result.error });
    }

    // Do the thing, then say it: the homework is already in the student's list,
    // and the notice only reports it. One notice for the homework, none for its
    // items — five notices for one homework is noise a trainer learns to skip.
    await notify(pool, {
      recipientId: studentId,
      senderId: req.user.id,
      title: 'New homework',
      message: `${req.user.name || 'Trainer'} sent you: ${result.assignment.title}`,
      kind: 'assignment_new',
      refId: result.assignment.id,
    });
    res.status(201).json(result.assignment);
  } catch (err) {
    await refundQuota(req);
    logger.error('Error sending a homework:', err);
    res.status(500).json({ error: 'Error sending the homework.' });
  }
});

// DELETE /homeworks/:id — what was sent from it stays sent.
router.delete('/:id', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'Invalid homework ID.' });

  try {
    const gone = await template.deleteHomework(pool, id, req.user.id);
    if (!gone) return res.status(404).json({ error: 'Homework not found.' });
    res.json({ success: true });
  } catch (err) {
    logger.error('Error deleting a homework:', err);
    res.status(500).json({ error: 'Error deleting the homework.' });
  }
});

module.exports = router;
