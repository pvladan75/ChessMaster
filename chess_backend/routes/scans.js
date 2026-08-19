// scans.js — turning a trainer's own book into positions they can assign.
//
// The uploaded document is **never kept**. It is written to a temp file because
// the PDF reader needs a path, scanned inside the request, and deleted in a
// `finally` whatever happens. Two reasons, and both matter:
//
//   * a scanned book is someone else's copyrighted work, and a server that
//     stores none of it cannot leak any of it;
//   * `uploads/` is the only copy of children's voices, and nothing else may
//     ever be written there.
//
// Nothing on this route saves a position by itself. A scan returns candidates,
// the trainer confirms them, and only then does a row appear — including the
// ones the scanner is unsure about, which are saved flagged rather than dropped.
const path = require('path');
const fs = require('fs');
const os = require('os');
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');

const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { METRIC, recordUsage } = require('../services/entitlementService');
const { prepareRows, MAX_POSITIONS_PER_CONFIRM } = require('../services/scanIntake');

const router = express.Router();

const SCAN_TMP_DIR = path.join(os.tmpdir(), 'chess-scans');
const MAX_DOCUMENT_BYTES = 25 * 1024 * 1024;

const upload = multer({
  storage: multer.diskStorage({
    destination(req, file, cb) {
      fs.mkdirSync(SCAN_TMP_DIR, { recursive: true });
      cb(null, SCAN_TMP_DIR);
    },
    filename(req, file, cb) {
      cb(null, `scan_${Date.now()}_${crypto.randomBytes(6).toString('hex')}.pdf`);
    },
  }),
  limits: { fileSize: MAX_DOCUMENT_BYTES },
  fileFilter(req, file, cb) {
    const looksPdf =
      file.mimetype === 'application/pdf' || path.extname(file.originalname).toLowerCase() === '.pdf';
    cb(looksPdf ? null : new Error('Podržan je samo PDF.'), looksPdf);
  },
});

// The scanner is ESM (pdfjs ships no CommonJS build), so it is imported lazily.
// Cached, because parsing it on every request would be pure waste.
let scannerPromise = null;
function loadScanner() {
  if (!scannerPromise) scannerPromise = import('../services/positionScanner/index.mjs');
  return scannerPromise;
}

function removeQuietly(filePath) {
  if (!filePath) return;
  fs.promises.unlink(filePath).catch((err) => {
    // Worth a line in the log: a temp file that survives is a copy of a book we
    // promised not to keep.
    logger.warn(`[SCAN] Nije obrisan privremeni fajl ${filePath}: ${err.message}`);
  });
}

/// Deletes uploads orphaned by a process that died mid-scan.
///
/// The `finally` above cannot run if the process is killed while a scan is in
/// flight — nodemon restarting on a file save is enough to do it, and that is
/// exactly how this was found: a 5 MB copy of a book left sitting in the temp
/// directory. At startup nothing is in flight by definition, so everything
/// still here is orphaned and goes.
function sweepLeftovers(dir = SCAN_TMP_DIR) {
  if (!fs.existsSync(dir)) return 0;
  let removed = 0;
  for (const name of fs.readdirSync(dir)) {
    if (!name.startsWith('scan_')) continue;
    try {
      fs.unlinkSync(path.join(dir, name));
      removed += 1;
    } catch (err) {
      logger.warn(`[SCAN] Zaostali fajl ${name} nije obrisan: ${err.message}`);
    }
  }
  if (removed > 0) {
    logger.warn(`[SCAN] Obrisano ${removed} zaostalih dokumenata iz prekinutih skeniranja.`);
  }
  return removed;
}

sweepLeftovers();

// POST /scans — scan a page range of an uploaded PDF and return candidates.
router.post('/', authenticateToken, upload.single('document'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Nije poslat dokument.' });
  }

  const { fromPage, toPage, solutionsFrom, solutionsTo } = req.body;

  try {
    const { scanDocument, ScanError } = await loadScanner();
    let result;
    try {
      result = await scanDocument({
        filePath: req.file.path,
        fromPage: Number(fromPage) || 1,
        toPage: Number(toPage) || Number(fromPage) || 1,
        solutionsFrom: solutionsFrom ? Number(solutionsFrom) : null,
        solutionsTo: solutionsTo ? Number(solutionsTo) : null,
      });
    } catch (err) {
      if (err instanceof ScanError) {
        return res.status(422).json({ error: err.message, code: err.code, details: err.details });
      }
      throw err;
    }

    await recordUsage(pool, req.user.id, METRIC.SCANNED_PAGES, result.scannedTo - result.scannedFrom + 1);

    logger.info(
      `[SCAN] user=${req.user.id} strane=${result.scannedFrom}-${result.scannedTo} ` +
        `font=${result.font} pozicija=${result.positions.length} spornih=${result.positions.filter((p) => p.problem).length}`
    );

    res.json({
      documentName: req.file.originalname,
      pageCount: result.pageCount,
      scannedFrom: result.scannedFrom,
      scannedTo: result.scannedTo,
      font: result.font,
      positions: result.positions,
      anomalies: result.anomalies.length,
      glyphErrors: result.glyphErrors,
    });
  } catch (err) {
    logger.error(`[SCAN] Neuspešno skeniranje: ${err.stack || err.message}`);
    res.status(500).json({ error: 'Greška pri čitanju dokumenta.' });
  } finally {
    removeQuietly(req.file.path);
  }
});

// POST /scans/confirm — save the positions the trainer accepted.
router.post('/confirm', authenticateToken, async (req, res) => {
  const { sourceTitle, positions } = req.body || {};

  if (!Array.isArray(positions) || positions.length === 0) {
    return res.status(400).json({ error: 'Nije poslata nijedna pozicija.' });
  }
  if (positions.length > MAX_POSITIONS_PER_CONFIRM) {
    return res.status(400).json({ error: `Najviše ${MAX_POSITIONS_PER_CONFIRM} pozicija odjednom.` });
  }

  // Every FEN is re-validated in scanIntake before it can become a row; the
  // client is not the authority on whether what it sent is a position.
  const { rows, rejected } = prepareRows(positions);

  if (rows.length === 0) {
    return res.status(400).json({ error: 'Nijedna pozicija nije ispravna.', rejected });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const saved = [];
    for (const row of rows) {
      const result = await client.query(
        `INSERT INTO custom_puzzles
           (puzzle_id, owner_id, fen, side_to_move, solution_san, themes, source_title, source_page, source_label, needs_review)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING puzzle_id, fen, needs_review`,
        [
          row.puzzleId,
          req.user.id,
          row.fen,
          row.side,
          row.solutionSan,
          row.themes,
          typeof sourceTitle === 'string' ? sourceTitle.slice(0, 255) : null,
          row.page,
          row.label,
          row.needsReview,
        ]
      );
      saved.push(result.rows[0]);
    }
    await client.query('COMMIT');

    logger.info(`[SCAN] user=${req.user.id} sačuvano ${saved.length} pozicija, odbijeno ${rejected.length}`);
    res.status(201).json({ saved: saved.length, rejected, puzzles: saved });
  } catch (err) {
    await client.query('ROLLBACK');
    logger.error(`[SCAN] Čuvanje nije uspelo: ${err.message}`);
    res.status(500).json({ error: 'Greška pri čuvanju pozicija.' });
  } finally {
    client.release();
  }
});

// DELETE /scans/puzzles/:puzzleId — throw one away.
//
// Scoped by owner in the WHERE clause rather than checked first and deleted
// after: one statement cannot be raced, and a request for someone else's
// position simply matches nothing.
router.delete('/puzzles/:puzzleId', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM custom_puzzles WHERE puzzle_id = $1 AND owner_id = $2 RETURNING puzzle_id',
      [req.params.puzzleId, req.user.id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Pozicija nije nađena.' });
    }
    res.json({ deleted: result.rows[0].puzzle_id });
  } catch (err) {
    logger.error(`[SCAN] Brisanje pozicije nije uspelo: ${err.message}`);
    res.status(500).json({ error: 'Greška pri brisanju pozicije.' });
  }
});

// GET /scans/puzzles — the caller's own scanned positions.
router.get('/puzzles', authenticateToken, async (req, res) => {
  try {
    // Ordered the way the book is, not the way the rows were written.
    //
    // The scanner walks a page by position — down and then across — but a book
    // numbers its diagrams down one column and then down the next, so insertion
    // order comes out as 97, 100, 98, 101. Everything from one scan also shares
    // a `created_at` to the microsecond, so sorting by time is really no sort at
    // all. The printed number is what a trainer is looking for, and it is text,
    // so it has to be compared as a number or 100 lands before 97.
    const result = await pool.query(
      `SELECT puzzle_id, fen, side_to_move, solution_san, themes,
              source_title, source_page, source_label, needs_review, created_at
         FROM custom_puzzles
        WHERE owner_id = $1
        ORDER BY source_title NULLS LAST,
                 source_page NULLS LAST,
                 CASE WHEN source_label ~ '^[0-9]+$' THEN source_label::int END NULLS LAST,
                 id
        LIMIT 500`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    logger.error(`[SCAN] Lista pozicija nije učitana: ${err.message}`);
    res.status(500).json({ error: 'Greška pri učitavanju pozicija.' });
  }
});

module.exports = router;
module.exports.sweepLeftovers = sweepLeftovers;
