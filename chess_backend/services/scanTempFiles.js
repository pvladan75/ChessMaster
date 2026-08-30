// scanTempFiles.js — the uploaded document's short life on disk.
//
// A scanned book is written to a temp file only because the PDF reader needs a
// path, and it is deleted as soon as the scan is done. This is the other half:
// what to do about the ones that were never deleted.
//
// Kept out of the route on purpose. Sweeping files is file work; the route
// carries authentication and a database pool, and a unit test that only wants
// to check a directory should not have to boot either. It did, and CI — which
// has no JWT_SECRET — died at import rather than at any assertion.
const fs = require('fs');
const os = require('os');
const path = require('path');

const logger = require('./logger');

const SCAN_TMP_DIR = path.join(os.tmpdir(), 'chess-scans');

/// Uploaded PGN archives get their own directory rather than sharing the
/// scanners'. Same short life and the same sweep, but a file left behind here
/// is a copy of somebody's game history and not of a book, and the log line
/// should be able to say which.
const PGN_TMP_DIR = path.join(os.tmpdir(), 'chess-archives');

/**
 * Deletes uploads orphaned by a process that died mid-scan.
 *
 * The route deletes its own upload in a `finally`, which cannot run when the
 * process is killed while a scan is in flight — nodemon restarting on a file
 * save is enough, and that is how this was found: a 5 MB copy of somebody's
 * book left sitting in the temp directory.
 *
 * At startup nothing is in flight by definition, so everything still here is
 * orphaned and goes.
 */
function sweepLeftovers(dir = SCAN_TMP_DIR, prefix = 'scan_') {
  if (!fs.existsSync(dir)) return 0;
  let removed = 0;
  for (const name of fs.readdirSync(dir)) {
    if (!name.startsWith(prefix)) continue;
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

/// Best-effort delete of one upload, for the route's `finally`.
function removeQuietly(filePath) {
  if (!filePath) return;
  fs.promises.unlink(filePath).catch((err) => {
    // Worth a line in the log: a temp file that survives is a copy of a book we
    // promised not to keep.
    logger.warn(`[SCAN] Nije obrisan privremeni fajl ${filePath}: ${err.message}`);
  });
}

module.exports = { SCAN_TMP_DIR, PGN_TMP_DIR, sweepLeftovers, removeQuietly };
