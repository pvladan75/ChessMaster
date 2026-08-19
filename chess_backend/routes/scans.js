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
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');

const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { METRIC, recordUsage } = require('../services/entitlementService');
const {
  SCAN_TMP_DIR,
  sweepLeftovers,
  removeQuietly,
} = require('../services/scanTempFiles');
const {
  prepareRows,
  mergePlan,
  withSideToMove,
  solutionPlaysIn,
  deriveInstruction,
  MAX_POSITIONS_PER_CONFIRM,
} = require('../services/scanIntake');

const router = express.Router();

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

  const title = typeof sourceTitle === 'string' ? sourceTitle.slice(0, 255) : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const saved = [];
    let filled = 0;
    let unchanged = 0;
    const conflicts = [];

    for (const row of rows) {
      // A diagram is identified by its printed number within one book. Books
      // that number nothing fall back to the page plus the board itself, which
      // is the only other thing that stays the same across two scans.
      const existing = row.label
        ? await client.query(
            `SELECT puzzle_id, fen, solution_san, themes, instruction FROM custom_puzzles
              WHERE owner_id = $1 AND source_title IS NOT DISTINCT FROM $2 AND source_label = $3
              LIMIT 1`,
            [req.user.id, title, row.label]
          )
        : await client.query(
            `SELECT puzzle_id, fen, solution_san, themes, instruction FROM custom_puzzles
              WHERE owner_id = $1 AND source_title IS NOT DISTINCT FROM $2
                AND source_page IS NOT DISTINCT FROM $3 AND fen = $4
              LIMIT 1`,
            [req.user.id, title, row.page, row.fen]
          );

      if (existing.rowCount > 0) {
        const plan = mergePlan(existing.rows[0], row);
        if (plan.action === 'conflict') {
          // A disagreement that leaves no mark on the row is a disagreement
          // nobody will ever see again: the count goes into a response that is
          // gone as soon as the message is dismissed, and the position sits
          // there looking merely unfinished. Flagging it is the only way back
          // to it.
          await client.query(
            'UPDATE custom_puzzles SET needs_review = TRUE WHERE puzzle_id = $1',
            [existing.rows[0].puzzle_id]
          );
          conflicts.push({
            label: row.label,
            page: row.page,
            reason: plan.reason,
            sideLikelyWrong: Boolean(plan.sideLikelyWrong),
          });
        } else if (plan.action === 'fill') {
          const sets = Object.keys(plan.fields).map((key, i) => `${key} = $${i + 2}`);
          await client.query(
            `UPDATE custom_puzzles SET ${sets.join(', ')} WHERE puzzle_id = $1`,
            [existing.rows[0].puzzle_id, ...Object.values(plan.fields)]
          );
          filled += 1;
        } else {
          unchanged += 1;
        }
        continue;
      }

      const result = await client.query(
        `INSERT INTO custom_puzzles
           (puzzle_id, owner_id, fen, side_to_move, solution_san, instruction, themes, source_title, source_page, source_label, needs_review)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         RETURNING puzzle_id, fen, needs_review`,
        [
          row.puzzleId,
          req.user.id,
          row.fen,
          row.side,
          row.solutionSan,
          row.instruction,
          row.themes,
          title,
          row.page,
          row.label,
          row.needsReview,
        ]
      );
      saved.push(result.rows[0]);
    }
    await client.query('COMMIT');

    logger.info(
      `[SCAN] user=${req.user.id} novo ${saved.length}, dopunjeno ${filled}, nepromenjeno ${unchanged}, ` +
        `neslaganja ${conflicts.length}, odbijeno ${rejected.length}`
    );
    res.status(201).json({
      saved: saved.length,
      filled,
      unchanged,
      conflicts,
      rejected,
      puzzles: saved,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    logger.error(`[SCAN] Čuvanje nije uspelo: ${err.message}`);
    res.status(500).json({ error: 'Greška pri čuvanju pozicija.' });
  } finally {
    client.release();
  }
});

// PATCH /scans/puzzles/:puzzleId — settle whose move it is.
//
// The only edit this route allows, and the one that matters most. A diagram
// does not print the side to move and many books never say it in words, so the
// position is stored with white and flagged. Until someone answers, every
// screen downstream — the analysis board, the engine, the arrow it draws — is
// answering a different question than the one being asked.
router.patch('/puzzles/:puzzleId', authenticateToken, async (req, res) => {
  const { sideToMove, instruction } = req.body || {};

  try {
    const existing = await pool.query(
      'SELECT fen, solution_san, instruction FROM custom_puzzles WHERE puzzle_id = $1 AND owner_id = $2',
      [req.params.puzzleId, req.user.id]
    );
    if (existing.rowCount === 0) {
      return res.status(404).json({ error: 'Pozicija nije nađena.' });
    }

    // Editing only the task text. Teaching words are the trainer's, so they are
    // taken as written — trimmed and capped, never rewritten or generated over.
    if (typeof instruction === 'string' && sideToMove === undefined) {
      const text = instruction.trim().slice(0, 500);
      const updated = await pool.query(
        `UPDATE custom_puzzles SET instruction = $1
          WHERE puzzle_id = $2 AND owner_id = $3
          RETURNING puzzle_id, fen, side_to_move, solution_san, instruction, needs_review`,
        [text || null, req.params.puzzleId, req.user.id]
      );
      return res.json(updated.rows[0]);
    }

    let fen;
    try {
      fen = withSideToMove(existing.rows[0].fen, sideToMove);
    } catch (err) {
      // Worth its own status: this is not a broken request but a real answer —
      // that side cannot be the one to move in this position.
      return res.status(422).json({ error: `Ta strana ne može biti na potezu: ${err.message}` });
    }

    // Answering the side question settles that doubt — but only that one. If a
    // solution is stored, changing whose move it is can make it unplayable, and
    // clearing the flag then would hide a position whose move and board no
    // longer agree. Re-check rather than assume the edit was harmless.
    const solutionStillPlays = solutionPlaysIn(fen, existing.rows[0].solution_san);

    // Settling the side can make the position able to state its own task, so a
    // still-empty instruction is filled from what has now been verified.
    const instructionNow =
      existing.rows[0].instruction ?? deriveInstruction(fen, existing.rows[0].solution_san);

    const updated = await pool.query(
      `UPDATE custom_puzzles
          SET fen = $1, side_to_move = $2, needs_review = $3, instruction = $4
        WHERE puzzle_id = $5 AND owner_id = $6
        RETURNING puzzle_id, fen, side_to_move, solution_san, instruction, needs_review`,
      [fen, sideToMove, !solutionStillPlays, instructionNow, req.params.puzzleId, req.user.id]
    );
    res.json(updated.rows[0]);
  } catch (err) {
    logger.error(`[SCAN] Izmena strane na potezu nije uspela: ${err.message}`);
    res.status(500).json({ error: 'Greška pri izmeni pozicije.' });
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
      `SELECT puzzle_id, fen, side_to_move, solution_san, instruction, themes,
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
