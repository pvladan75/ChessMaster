// library.js — "my positions" as one place, over three tables that stay apart.
//
// The tables are not merged and are not going to be: see the comment at the top
// of `services/positionLibrary.js` for why. This route only reads.

const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const logger = require('../services/logger');
const { listLibrary, isKind, KINDS } = require('../services/positionLibrary');

// GET /library/positions?kind=scan|position|analysis&search=
router.get('/positions', authenticateToken, async (req, res) => {
  const { kind, search } = req.query;

  // An unknown kind is refused rather than ignored. A filter that appears to
  // work and quietly returns everything is the exact failure this codebase
  // keeps meeting.
  if (kind !== undefined && !isKind(kind)) {
    return res.status(400).json({
      error: `Nepoznata vrsta „${kind}". Dozvoljene su: ${KINDS.join(', ')}.`,
    });
  }

  try {
    const items = await listLibrary(pool, req.user.id, {
      kind: kind || null,
      search: typeof search === 'string' ? search : null,
    });
    res.json({ items });
  } catch (err) {
    logger.error(`[LIBRARY] Lista pozicija nije učitana: ${err.message}`);
    res.status(500).json({ error: 'Greška pri učitavanju biblioteke pozicija.' });
  }
});

module.exports = router;
