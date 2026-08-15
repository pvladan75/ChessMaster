const fs = require('fs');
const path = require('path');
const logger = require('./logger');

const EXPORTS_DIR = path.join(__dirname, '..', 'exports');
const DEFAULT_MAX_AGE_DAYS = 14;

/// Deletes MP4 exports older than [maxAgeDays]. An export is a rendering of the
/// underlying recording and can always be regenerated on demand — unlike the
/// audio in uploads/, which is the only copy of a lesson's voice — so only the
/// exports directory is subject to automatic cleanup. uploads/ is left alone.
async function cleanupOldExports(pool, { dir = EXPORTS_DIR, maxAgeDays = DEFAULT_MAX_AGE_DAYS } = {}) {
  if (!fs.existsSync(dir)) return { deleted: 0, freedBytes: 0 };

  const cutoff = Date.now() - maxAgeDays * 24 * 60 * 60 * 1000;
  let deleted = 0;
  let freedBytes = 0;
  const deletedFilenames = [];

  for (const filename of fs.readdirSync(dir)) {
    const filePath = path.join(dir, filename);
    let stats;
    try {
      stats = fs.statSync(filePath);
    } catch (_) {
      continue; // deleted between readdir and stat — nothing to do
    }
    if (!stats.isFile() || stats.mtimeMs > cutoff) continue;

    try {
      fs.unlinkSync(filePath);
      deleted += 1;
      freedBytes += stats.size;
      deletedFilenames.push(filename);
    } catch (err) {
      logger.error(`[RETENTION] Failed to delete ${filename}: ${err.message}`);
    }
  }

  // video_url carries the filename as its last path segment. Clearing it once
  // the file is gone keeps the app from offering a download link that 404s —
  // the recording itself and its audio are untouched, only the stale export ref.
  if (pool) {
    for (const filename of deletedFilenames) {
      try {
        await pool.query(
          'UPDATE session_recordings SET video_url = NULL WHERE video_url LIKE $1',
          [`%/${filename}%`]
        );
      } catch (err) {
        logger.error(`[RETENTION] Failed to clear video_url for ${filename}: ${err.message}`);
      }
    }
  }

  if (deleted > 0) {
    logger.info(`[RETENTION] Deleted ${deleted} export(s) older than ${maxAgeDays}d, freed ${(freedBytes / 1024 / 1024).toFixed(1)}MB`);
  }

  return { deleted, freedBytes };
}

module.exports = { cleanupOldExports, EXPORTS_DIR, DEFAULT_MAX_AGE_DAYS };
