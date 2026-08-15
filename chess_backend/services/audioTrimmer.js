const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const logger = require('./logger');

/// Agora offers no way to pause a recording, so the microphone keeps capturing
/// while the trainer has the lesson paused. The board timeline, meanwhile, has
/// that time subtracted out. Left alone the two drift apart by the length of
/// every pause, and the tail of the audio never gets reached at all.
///
/// Rather than splitting the capture into a file per segment, the recording
/// stays one file and the paused stretches are cut out of it here, once, on
/// save. After that the audio is the same length as the timeline and the two
/// line up by construction — nothing downstream has to know a pause happened.

/// Drops junk, orders by start, and merges anything that overlaps or touches.
///
/// Overlaps should not occur — pause and resume alternate — but a malformed or
/// hand-edited payload must not reach the filter expression, where overlapping
/// `between()` terms would sum above 1 and quietly change what gets cut.
function normaliseIntervals(intervals) {
  const clean = (Array.isArray(intervals) ? intervals : [])
    .map((i) => ({ startMs: Number(i.startMs), endMs: Number(i.endMs) }))
    .filter((i) => Number.isFinite(i.startMs) && Number.isFinite(i.endMs))
    .map((i) => ({ startMs: Math.max(0, i.startMs), endMs: i.endMs }))
    .filter((i) => i.endMs > i.startMs)
    .sort((a, b) => a.startMs - b.startMs);

  const merged = [];
  for (const interval of clean) {
    const last = merged[merged.length - 1];
    if (last && interval.startMs <= last.endMs) {
      last.endMs = Math.max(last.endMs, interval.endMs);
    } else {
      merged.push({ ...interval });
    }
  }
  return merged;
}

const sec = (ms) => (ms / 1000).toFixed(3);

/// A filter graph that keeps everything *outside* [intervals], expressed as the
/// surviving stretches rather than the dropped ones.
///
/// The obvious spelling — `aselect='not(between(t,a,b))'` — was tried first and
/// silently does nothing here: ffmpeg exits 0 and returns a file of the original
/// length. Cutting by naming the parts to keep, then concatenating them, was
/// measured to actually shorten the file, so that is what this builds.
///
/// Returns the graph and the label its result carries, because a single
/// surviving stretch needs no concat and so ends up on a different label.
function buildFilterComplex(intervals) {
  const keeps = [];
  let cursor = 0;
  for (const pause of intervals) {
    if (pause.startMs > cursor) keeps.push({ startMs: cursor, endMs: pause.startMs });
    cursor = Math.max(cursor, pause.endMs);
  }
  // The tail has no end: the recording may run on well past the last resume,
  // and its real length is not known here.
  keeps.push({ startMs: cursor, endMs: null });

  const parts = keeps.map((keep, i) => {
    const range = keep.endMs === null
      ? `atrim=start=${sec(keep.startMs)}`
      : `atrim=start=${sec(keep.startMs)}:end=${sec(keep.endMs)}`;
    return `[0:a]${range},asetpts=N/SR/TB[s${i}]`;
  });

  if (keeps.length === 1) {
    return { filter: parts[0], outLabel: '[s0]' };
  }

  const labels = keeps.map((_, i) => `[s${i}]`).join('');
  return {
    filter: `${parts.join(';')};${labels}concat=n=${keeps.length}:v=0:a=1[out]`,
    outLabel: '[out]',
  };
}

function runFfmpeg(args) {
  return new Promise((resolve, reject) => {
    const ffmpeg = spawn('ffmpeg', args);
    let stderr = '';
    ffmpeg.stderr.on('data', (d) => { stderr += d.toString(); });
    ffmpeg.on('error', reject);
    ffmpeg.on('close', (code) => {
      if (code === 0) return resolve();
      reject(new Error(`ffmpeg exited with ${code}: ${stderr.slice(-500)}`));
    });
  });
}

/// Removes [intervals] from the audio at [filePath], in place.
///
/// Returns true when the file was rewritten. A failure is reported false rather
/// than thrown: a lesson whose audio still contains its pauses is worth far more
/// than a save that fails, and the caller is in the middle of one.
async function trimPauses(filePath, intervals) {
  const merged = normaliseIntervals(intervals);
  if (merged.length === 0) return false;
  if (!filePath || !fs.existsSync(filePath)) return false;

  const parsed = path.parse(filePath);
  const tempPath = path.join(parsed.dir, `${parsed.name}.trimmed${parsed.ext}`);

  try {
    const { filter, outLabel } = buildFilterComplex(merged);
    await runFfmpeg([
      '-y',
      '-i', filePath,
      '-filter_complex', filter,
      '-map', outLabel,
      '-c:a', 'aac',
      tempPath,
    ]);

    // Only replace the original once ffmpeg has actually produced something:
    // an empty output would otherwise trade a slightly-off recording for none.
    const stats = fs.statSync(tempPath);
    if (stats.size === 0) throw new Error('ffmpeg produced an empty file');

    fs.renameSync(tempPath, filePath);
    const cutMs = merged.reduce((sum, i) => sum + (i.endMs - i.startMs), 0);
    logger.info(`[AUDIO TRIM] Cut ${merged.length} pause(s), ${cutMs}ms total, from ${path.basename(filePath)}`);
    return true;
  } catch (err) {
    logger.error(`[AUDIO TRIM] Leaving audio untrimmed for ${path.basename(filePath)}: ${err.message}`);
    try { if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath); } catch (_) {}
    return false;
  }
}

module.exports = { trimPauses, normaliseIntervals, buildFilterComplex };
