// routes/exercises.js
//
// The exercises a trainer makes by hand (docs/PLAN-EXERCISE.md, phase 2a):
// a position plus a task, judged by the server. Making one costs no quota, as
// writing a homework does not; sending is what is charged.
//
// Every route is the owner's own. `exerciseAuthoring` scopes each query by
// `owner_id` and answers 404 for „no such exercise" and „not yours" alike.
// The list is not here: an exercise is a Library entry, and the Library
// already lists this table (`services/positionLibrary.js`).

const express = require('express');

const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const authoring = require('../services/exerciseAuthoring');
const solo = require('../services/exerciseSolo');

const router = express.Router();

function answer(res, result, okStatus = 200) {
  if (!result.ok) return res.status(result.status).json({ error: result.error });
  return res.status(okStatus).json({ exercise: result.exercise });
}

// POST /exercises — a new one.
router.post('/', authenticateToken, async (req, res) => {
  try {
    answer(res, await authoring.createExercise(pool, { ownerId: req.user.id, payload: req.body }), 201);
  } catch (err) {
    logger.error('Error creating exercise:', err);
    res.status(500).json({ error: 'Error saving the exercise.' });
  }
});

// GET /exercises/queue — the owner's own find exercises to solve: never tried,
// and failed last time (docs/PLAN-MATERIJAL.md, phase 1). Before `/:id`, or
// Express would read „queue" as an id.
router.get('/queue', authenticateToken, async (req, res) => {
  try {
    res.json(await solo.queueOf(pool, req.user.id));
  } catch (err) {
    logger.error('Error reading the exercise queue:', err);
    res.status(500).json({ error: 'Error loading your exercises.' });
  }
});

// POST /exercises/:id/attempt — the owner answers their own exercise, judged
// here as homework is, and logged as an `own` attempt.
router.post('/:id/attempt', authenticateToken, async (req, res) => {
  try {
    const { moveSan, msTaken } = req.body || {};
    const out = await solo.attemptOwn(pool, {
      ownerId: req.user.id, puzzleId: req.params.id, moveSan, msTaken,
    });
    if (!out.ok) return res.status(out.status).json({ error: out.error });
    res.json(out.result);
  } catch (err) {
    logger.error('Error judging an own attempt:', err);
    res.status(500).json({ error: 'Error checking answer.' });
  }
});

// GET /exercises/:id — one, with its solution, for its owner's editor.
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    answer(res, await authoring.readExercise(pool, { ownerId: req.user.id, puzzleId: req.params.id }));
  } catch (err) {
    logger.error('Error reading exercise:', err);
    res.status(500).json({ error: 'Error loading the exercise.' });
  }
});

// PUT /exercises/:id — its name, words, labels, task and solution. Never its
// position.
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    answer(res, await authoring.updateExercise(pool, {
      ownerId: req.user.id, puzzleId: req.params.id, payload: req.body,
    }));
  } catch (err) {
    logger.error('Error updating exercise:', err);
    res.status(500).json({ error: 'Error saving the exercise.' });
  }
});

module.exports = router;
