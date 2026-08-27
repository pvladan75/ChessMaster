// trainerPanel.js — one read that answers "what is my job right now".
//
// Deliberately a single endpoint rather than four. The four sections are drawn
// as one screen and go stale together; four calls would let the trainer read a
// panel whose halves disagree, and would cost four round trips on a phone
// opened thirty seconds before a lesson.
//
// Nothing here is a right: every section is already scoped to the caller as
// trainer, and the sections that name a student go through the accepted-edge
// fragment. There is nothing to authorise beyond being signed in.

const express = require('express');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { trainerPanel } = require('../services/trainerPanelService');

// GET /trainer/panel — today's lessons, deadlines, handed-in work, quiet students.
//
// Answered for everybody, including somebody who teaches nobody: the empty
// panel is what the client uses to decide not to draw the section at all, and
// a 403 would make "you have no students" indistinguishable from "something
// went wrong".
router.get('/trainer/panel', authenticateToken, async (req, res) => {
  try {
    res.json(await trainerPanel(pool, req.user.id));
  } catch (err) {
    logger.error('Error building trainer panel:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju panela.' });
  }
});

module.exports = router;
