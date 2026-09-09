// narrationTrack.js — the beats' clips and the gaps between them, as one file.
//
// The renderer has always taken a single audio file, so nothing about it
// changes here: the work is turning a list of clips into that one file, exactly
// as long as the film, with each clip starting on the second its beat does.
//
// **Concatenation rather than positioning.** ffmpeg can lay clips at absolute
// offsets with `adelay` and mix them, and that is the version that drifts: the
// offsets are computed here and the film's timestamps are computed in
// `narrationPlan`, so two pieces of arithmetic have to agree forever. Instead
// the track is built from the same `segments` the plan returns, in order —
// clip, silence, clip, silence — so the sound cannot disagree with the picture
// unless the plan disagrees with itself.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const logger = require('./logger');

/// The sample rate and shape every segment is normalised to.
///
/// `concat` refuses to join files that disagree about rate or channel count,
/// and a synthesiser is free to hand back whatever it likes — Windows' own
/// writes 22.05 kHz mono. Normalising once here is cheaper than discovering it
/// in the middle of a two-minute render.
const RATE = 22050;
const CHANNELS = 1;

/**
 * Build the film's audio track.
 *
 * `segments` comes from `narrationPlan`, `clips[i].path` is the wav for beat
 * `i`. Returns the path to a wav exactly `plan.totalSeconds` long, or `null`
 * when there is nothing to say at all — a film with no narration keeps the
 * silent track the renderer already generates for itself.
 */
async function buildNarrationTrack({ segments, clips, outputPath }) {
  const spoken = segments.filter((s) => s.kind === 'clip' && clips[s.index]?.path);
  if (spoken.length === 0) return null;

  const listFile = path.join(
    os.tmpdir(),
    `narration_${Date.now()}_${Math.random().toString(36).slice(2)}.txt`,
  );
  const silences = new Map();
  const lines = [];

  try {
    for (const segment of segments) {
      if (segment.kind === 'clip') {
        const clip = clips[segment.index];
        if (!clip || !clip.path) continue;
        lines.push(`file '${clip.path.replace(/\\/g, '/').replace(/'/g, "'\\''")}'`);
        continue;
      }
      // One file per distinct silence length, made once and named as often as
      // it is needed. A film of thirty beats otherwise writes thirty near
      // identical files for no reason.
      const key = segment.seconds.toFixed(3);
      if (!silences.has(key)) {
        const file = path.join(os.tmpdir(), `silence_${key.replace('.', '_')}_${process.pid}.wav`);
        await makeSilence(file, segment.seconds);
        silences.set(key, file);
      }
      lines.push(`file '${silences.get(key).replace(/\\/g, '/')}'`);
    }

    fs.writeFileSync(listFile, lines.join('\n'), 'utf8');
    await ffmpeg([
      '-y',
      '-f', 'concat',
      // The list names absolute paths written by this process, not by a user.
      '-safe', '0',
      '-i', listFile,
      '-ar', String(RATE),
      '-ac', String(CHANNELS),
      outputPath,
    ]);
    return outputPath;
  } catch (err) {
    // A film without its voice is still a film. This is the one place where
    // failing loudly would be worse than carrying on: the pictures are already
    // drawn by the time anything here runs.
    logger.error({ err: err.message }, '[TTS] narration track could not be built');
    return null;
  } finally {
    safeUnlink(listFile);
    for (const file of silences.values()) safeUnlink(file);
  }
}

function makeSilence(file, seconds) {
  return ffmpeg([
    '-y',
    '-f', 'lavfi',
    '-i', `anullsrc=r=${RATE}:cl=mono`,
    '-t', seconds.toFixed(3),
    file,
  ]);
}

function ffmpeg(args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('ffmpeg', args);
    let stderr = '';
    proc.stderr.on('data', (d) => { stderr += d.toString(); });
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code === 0) return resolve();
      reject(new Error(`ffmpeg exited ${code}: ${stderr.slice(-400)}`));
    });
  });
}

function safeUnlink(file) {
  try { fs.unlinkSync(file); } catch { /* it was never written */ }
}

module.exports = { buildNarrationTrack, RATE, CHANNELS };
