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
const positionDeletion = require('../services/positionDeletion');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { accountLimiter } = require('../middleware/accountLimiter');
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
  MAX_DOCUMENT_BYTES,
  uploadRejection,
} = require('../services/scanIntake');

const router = express.Router();

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
    cb(looksPdf ? null : new Error('Only PDF is supported.'), looksPdf);
  },
});

// The scanner is ESM (pdfjs ships no CommonJS build), so it is imported lazily.
// Cached, because parsing it on every request would be pure waste.
let scannerPromise = null;
function loadScanner() {
  if (!scannerPromise) scannerPromise = import('../services/positionScanner/index.mjs');
  return scannerPromise;
}

// The image path (phase 2 of docs/PLAN-SKENER-SLIKE.md): a book whose diagrams
// are pictures. ESM for the same reason, and cached the same way.
let imageReaderPromise = null;
function loadImageReader() {
  if (!imageReaderPromise) imageReaderPromise = import('../services/positionScanner/imageRead.mjs');
  return imageReaderPromise;
}
let imageFinderPromise = null;
function loadImageFinder() {
  if (!imageFinderPromise) imageFinderPromise = import('../services/positionScanner/imageDiagrams.mjs');
  return imageFinderPromise;
}

sweepLeftovers();

// Parsing up to 40 pages of a 100 MB book is seconds of CPU on the thread that
// also draws films and answers everybody else, and nothing stopped an account
// sending it in a loop. Counted per account, and checked before multer writes
// the file.
const scanLimiter = accountLimiter({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: 'Too many scans in a short time. Please wait a few minutes.',
});
router.scanLimiter = scanLimiter;

// POST /scans — scan a page range of an uploaded PDF and return candidates.
router.post('/', authenticateToken, scanLimiter, upload.single('document'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No document sent.' });
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
        // A book with no text, or no text shaped like a diagram, may still hold
        // its diagrams as pictures — and then this is a door, not a dead end.
        // Counted after the refusal is settled: a count that fails leaves the
        // refusal exactly as it was.
        let details = err.details;
        if (err.code === 'no_text' || err.code === 'no_diagram_text') {
          try {
            const { findImageDiagrams } = await loadImageFinder();
            const from = Number(fromPage) || 1;
            const found = await findImageDiagrams(req.file.path, {
              fromPage: from,
              toPage: Number(toPage) || from,
            });
            details = { ...(details || {}), imageDiagrams: found.diagrams.length };
          } catch (countErr) {
            logger.warn(`[SCAN] Brojanje slika-dijagrama nije uspelo: ${countErr.message}`);
          }
        }
        return res.status(422).json({ error: err.message, code: err.code, details });
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
    res.status(500).json({ error: 'Failed to read document.' });
  } finally {
    removeQuietly(req.file.path);
  }
});

// POST /scans/images — a book whose diagrams are pictures.
//
// Without a `calibration` field: the boards on those pages and a preview of
// each, which is how the trainer browses the book for calibration boards
// (phase 3e of docs/PLAN-SKENER-SLIKE.md). With one (JSON: [{ page, index, fen,
// ignore? }], the positions of a few of the book's own boards): every other
// board read against them, each with `source: 'image'` and its uncertain
// squares. The document is deleted in the `finally`, as above, and nothing is
// saved: POST /scans/confirm takes what the trainer confirms.
// Browsing a book for calibration boards (phase 3e) asks for twenty pages at a
// time, and a trainer turns many of them: counted by the scan limiter, a look
// through one book used up the account's twenty scans and the reading was then
// refused (the owner, 23.9.2026). Browsing gets its own route and a limiter
// sized for turning pages; reading keeps the scan limiter.
const browseLimiter = accountLimiter({
  windowMs: 15 * 60 * 1000,
  max: 150,
  message: 'Too many pages turned in a short time. Please wait a few minutes.',
});
router.browseLimiter = browseLimiter;

router.post('/images', authenticateToken, scanLimiter, upload.single('document'), (req, res) =>
  imagesRoute(req, res, { browse: false }));

// POST /scans/images/browse — the boards and previews of a page range, never
// a reading: a calibration field is not read here.
router.post('/images/browse', authenticateToken, browseLimiter, upload.single('document'), (req, res) =>
  imagesRoute(req, res, { browse: true }));

async function imagesRoute(req, res, { browse }) {
  if (!req.file) {
    return res.status(400).json({ error: 'No document sent.' });
  }
  const { fromPage, toPage } = req.body;
  const calibration = browse ? undefined : req.body.calibration;

  try {
    const { scanImages, parseCalibration } = await loadImageReader();
    const { ScanError } = await loadScanner();
    let result;
    try {
      const from = Number(fromPage) || 1;
      result = await scanImages({
        filePath: req.file.path,
        fromPage: from,
        toPage: Number(toPage) || from,
        calibration: parseCalibration(calibration),
      });
    } catch (err) {
      if (err instanceof ScanError) {
        return res.status(422).json({ error: err.message, code: err.code, details: err.details });
      }
      throw err;
    }

    // Browsing is not scanning: finding boards costs a fraction of a second a
    // page, and a trainer looking through a book for calibration boards would
    // otherwise be counted for every page he turned. The reading is counted.
    if (!result.needsCalibration) {
      await recordUsage(pool, req.user.id, METRIC.SCANNED_PAGES, result.scannedTo - result.scannedFrom + 1);
    }
    logger.info(
      `[SCAN] slike user=${req.user.id} strane=${result.scannedFrom}-${result.scannedTo} ` +
        (result.needsCalibration
          ? `tabli=${result.boards.length}, bez kalibracije`
          : `procitano=${result.positions.length} kalibracija=${result.calibration.length} ` +
            `oznaka po tabli=${result.marksPerBoard.toFixed(1)}`)
    );
    res.json({ documentName: req.file.originalname, ...result });
  } catch (err) {
    logger.error(`[SCAN] Citanje slika nije uspelo: ${err.stack || err.message}`);
    res.status(500).json({ error: 'Failed to read document.' });
  } finally {
    removeQuietly(req.file.path);
  }
}

// POST /scans/kind — whether a book's diagrams are set in a chess font or are
// pictures, from a sample spread over the whole book (phase 3f): asked the
// moment a book is chosen, so a picture book goes to its calibration before
// anyone asks for pages. Turning to a book is not scanning it: the browse
// limiter, and no pages counted.
let bookKindPromise = null;
function loadBookKind() {
  if (!bookKindPromise) bookKindPromise = import('../services/positionScanner/bookKind.mjs');
  return bookKindPromise;
}

router.post('/kind', authenticateToken, browseLimiter, upload.single('document'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No document sent.' });
  }
  try {
    const { bookKind } = await loadBookKind();
    const kind = await bookKind(req.file.path);
    logger.info(`[SCAN] vrsta knjige user=${req.user.id} strana=${kind.pageCount} vrsta=${kind.kind}`);
    res.json({ documentName: req.file.originalname, ...kind });
  } catch (err) {
    // Pages drawn for a book no glyph map reads (phase 3h) can fail in the
    // drawing process; that is the book's answer, said as a refusal.
    if (err.code === 'render_failed') {
      logger.warn(`[SCAN] Crtanje strana nije uspelo: ${err.cause?.message || err.message}`);
      return res.status(422).json({ error: err.message, code: err.code });
    }
    logger.error(`[SCAN] Vrsta knjige nije utvrdjena: ${err.stack || err.message}`);
    res.status(500).json({ error: 'Failed to read document.' });
  } finally {
    removeQuietly(req.file.path);
  }
});

// /scans/calibrations/:hash — a book's calibration, remembered on the account.
//
// Phase 3a of docs/PLAN-SKENER-SLIKE.md. `hash` is the SHA-256 of the book's
// file, worked out by the app. What is kept is what `POST /scans/images`
// takes as its calibration, checked by the same reader (`parseCalibration`) —
// positions and their place in the book, never a picture from it. Every query
// names the account: a hash is no secret, the same book is on many accounts.
const BOOK_HASH = /^[0-9a-f]{64}$/;

function badHash(req, res) {
  if (BOOK_HASH.test(String(req.params.hash))) return false;
  res.status(400).json({ error: 'That is not a book.', code: 'bad_book_hash' });
  return true;
}

router.get('/calibrations/:hash', authenticateToken, async (req, res) => {
  if (badHash(req, res)) return;
  try {
    const { rows } = await pool.query(
      `SELECT book_name, boards, absent, updated_at FROM book_calibrations
        WHERE user_id = $1 AND book_hash = $2`,
      [req.user.id, req.params.hash]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'This book has no calibration yet.', code: 'no_calibration' });
    }
    res.json({
      bookName: rows[0].book_name,
      boards: rows[0].boards,
      absent: rows[0].absent ?? [],
      updatedAt: rows[0].updated_at,
    });
  } catch (err) {
    logger.error(`[SCAN] Citanje kalibracije nije uspelo: ${err.message}`);
    res.status(500).json({ error: 'Failed to read the calibration.' });
  }
});

// GET /scans/calibrations/:hash/shared — the book as other users set it up
// (phase 3g): one calibration merged from every other account's, worked out
// each time, never stored. It names no account: what is shared is boards of a
// book, not who has it.
let sharedPromise = null;
function loadShared() {
  if (!sharedPromise) sharedPromise = import('../services/positionScanner/sharedCalibration.mjs');
  return sharedPromise;
}

router.get('/calibrations/:hash/shared', authenticateToken, async (req, res) => {
  if (badHash(req, res)) return;
  try {
    const { rows } = await pool.query(
      `SELECT boards, absent FROM book_calibrations WHERE book_hash = $1 AND user_id <> $2`,
      [req.params.hash, req.user.id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Nobody else has set up this book.', code: 'no_shared_calibration' });
    }
    const { mergeCalibrations } = await loadShared();
    const merged = mergeCalibrations(rows.map((r) => ({ boards: r.boards, absent: r.absent ?? [] })));
    if (!merged.boards.length) {
      return res.status(404).json({ error: 'Nobody else has set up this book.', code: 'no_shared_calibration' });
    }
    res.json(merged);
  } catch (err) {
    logger.error(`[SCAN] Deljena kalibracija nije procitana: ${err.message}`);
    res.status(500).json({ error: 'Failed to read the shared calibration.' });
  }
});

router.put('/calibrations/:hash', authenticateToken, async (req, res) => {
  if (badHash(req, res)) return;
  const { bookName, boards, absent } = req.body || {};
  let cleaned;
  let absentPieces;
  try {
    const { parseCalibration, parseAbsent } = await loadImageReader();
    const { ScanError } = await loadScanner();
    try {
      cleaned = parseCalibration(Array.isArray(boards) ? boards : null);
      absentPieces = parseAbsent(absent);
    } catch (err) {
      if (err instanceof ScanError) {
        return res.status(422).json({ error: err.message, code: err.code, details: err.details });
      }
      throw err;
    }
    if (!cleaned.length) {
      return res.status(422).json({ error: 'A calibration needs at least one board.', code: 'calibration_invalid' });
    }
    await pool.query(
      // `absent` left out of a request leaves what is stored alone; `[]`
      // clears it (rule 11: absence is a third answer).
      `INSERT INTO book_calibrations (user_id, book_hash, book_name, boards, absent, updated_at)
       VALUES ($1, $2, $3, $4, COALESCE($5::jsonb, '[]'::jsonb), CURRENT_TIMESTAMP)
       ON CONFLICT (user_id, book_hash) DO UPDATE
         SET book_name = EXCLUDED.book_name, boards = EXCLUDED.boards,
             absent = COALESCE($5::jsonb, book_calibrations.absent), updated_at = CURRENT_TIMESTAMP`,
      [req.user.id, req.params.hash, typeof bookName === 'string' ? bookName.slice(0, 255) : null,
        JSON.stringify(cleaned.map(({ page, index, fen, ignore }) => ({ page, index, fen, ignore }))),
        absentPieces === null ? null : JSON.stringify(absentPieces)]
    );
    res.json({ saved: cleaned.length });
  } catch (err) {
    logger.error(`[SCAN] Cuvanje kalibracije nije uspelo: ${err.message}`);
    res.status(500).json({ error: 'Failed to save the calibration.' });
  }
});

router.delete('/calibrations/:hash', authenticateToken, async (req, res) => {
  if (badHash(req, res)) return;
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM book_calibrations WHERE user_id = $1 AND book_hash = $2 RETURNING book_hash`,
      [req.user.id, req.params.hash]
    );
    if (!rowCount) {
      return res.status(404).json({ error: 'This book has no calibration.', code: 'no_calibration' });
    }
    res.sendStatus(204);
  } catch (err) {
    logger.error(`[SCAN] Brisanje kalibracije nije uspelo: ${err.message}`);
    res.status(500).json({ error: 'Failed to delete the calibration.' });
  }
});

// POST /scans/confirm — save the positions the trainer accepted.
router.post('/confirm', authenticateToken, async (req, res) => {
  const { sourceTitle, positions } = req.body || {};

  if (!Array.isArray(positions) || positions.length === 0) {
    return res.status(400).json({ error: 'No positions sent.' });
  }
  if (positions.length > MAX_POSITIONS_PER_CONFIRM) {
    return res.status(400).json({ error: `At most ${MAX_POSITIONS_PER_CONFIRM} positions at a time.` });
  }

  // Every FEN is re-validated in scanIntake before it can become a row; the
  // client is not the authority on whether what it sent is a position.
  const { rows, rejected } = prepareRows(positions);

  if (rows.length === 0) {
    return res.status(400).json({ error: 'No position is valid.', rejected });
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
           (puzzle_id, owner_id, fen, side_to_move, solution_san, instruction, themes, source_title, source_page, source_label, needs_review, solution_source, origin)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'book')
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
          row.solutionSource,
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
    res.status(500).json({ error: 'Failed to save positions.' });
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
      return res.status(404).json({ error: 'Position not found.' });
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
      return res.status(422).json({ error: `That side cannot be to move: ${err.message}` });
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
    res.status(500).json({ error: 'Failed to update position.' });
  }
});

// DELETE /scans/puzzles/:puzzleId — throw one away.
//
// Scoped by owner in the statement itself, and refused while a homework that
// is not finished holds the position (services/positionDeletion.js): a sent
// homework reads its positions by id, so deleting one would leave an item that
// cannot be opened. The refusal names the homework.
router.delete('/puzzles/:puzzleId', authenticateToken, async (req, res) => {
  try {
    const result = await positionDeletion.deleteOwnPosition(pool, {
      puzzleId: req.params.puzzleId,
      ownerId: req.user.id,
    });
    if (result.ok) return res.json({ deleted: req.params.puzzleId });
    if (result.status === 404) return res.status(404).json({ error: 'Position not found.' });
    return res.status(409).json({
      error: positionDeletion.inUseMessage(result.uses),
      code: 'position_in_use',
      uses: result.uses,
    });
  } catch (err) {
    logger.error(`[SCAN] Brisanje pozicije nije uspelo: ${err.message}`);
    res.status(500).json({ error: 'Failed to delete position.' });
  }
});

// GET /scans/puzzles — the list Saved Positions read — was deleted with that
// screen on 23.9.2026 (docs/PLAN-MATERIJAL.md, phase 3): the Library lists the
// same rows (`services/positionLibrary.js`), scoped by owner the same way.

/// Multer's own failures arrive here rather than as a 500 with no explanation.
/// The upload aborts mid-stream, so the route above never runs: without this,
/// a book over the ceiling reads to the trainer as an internal server error.
/// Same shape as the archive route, which has answered this way since 20.8.2026.
// eslint-disable-next-line no-unused-vars
router.use((err, req, res, next) => {
  const rejection = uploadRejection(err);
  if (!rejection) return next();
  logger.warn(`[SCAN] Otpremanje odbijeno: ${err.message}`);
  return res.status(rejection.status).json(rejection.body);
});

module.exports = router;
