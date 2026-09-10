// narrationUpload.js — what the server checks before a trainer's voice is kept.
//
// Phase 3 of `docs/PLAN-SNIMANJE.md`. The app records the take and places the
// beats in it (`chess_app/.../narration_take.dart`); this decides whether the
// file that arrived is the take the app says it is, and whether a video could
// be made of it.
//
// **The server reads the file, not the app's description of it.** The length
// comes from the wav's own header — the same arithmetic the app used, bytes ÷
// byte rate, so a take that arrived whole agrees to the millisecond and one
// that was cut short on the wire does not. The level comes from the samples.
// A disagreement is refused with a sentence, never corrected: a film whose
// audio is shorter than its beats ends early, and one whose audio is longer
// trails silence, and both look like the renderer is broken.
//
// **A recording cannot be reproduced**, which is why it lives under
// `uploads/`: never swept by a timer, never committed, deleted only as
// somebody's explicit act — the tutorial's own deletion, or a new take
// replacing it. And never served by URL (`middleware/uploadsStatic.js`): the
// renderer reads it from disk.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const logger = require('./logger');
const { wavInfo } = require('./tts/wav');

/// The one format the app records in: 16 kHz mono 16-bit PCM
/// (`narration_take.dart`). Anything else did not come from this app's
/// recorder, and its markers mean nothing.
const NARRATION_SAMPLE_RATE = 16000;
const NARRATION_CHANNELS = 1;
const NARRATION_BITS = 16;

/// The longest recording accepted — fifteen minutes, the owner's decision of
/// 10.9.2026.
///
/// **It is a consequence of where the render runs, not a judgement about
/// lessons.** The film is still drawn inside the export request, and nginx ends
/// a proxied request after 300 s (`deploy/app-setup.sh`). A recorded film draws
/// at roughly a quarter of real time, so fifteen minutes of voice is about four
/// minutes of drawing, which fits with a margin; twenty would not. When step 5
/// of the plan's part two takes the render out of the request, this cap has no
/// reason left and goes with it.
const NARRATION_MAX_SECONDS = 15 * 60;

/// The most bytes an upload may carry: the cap's worth of audio, and room for a
/// header. Given to multer, so a file over the cap is refused while it arrives
/// rather than after it has been written out whole.
const NARRATION_MAX_BYTES = NARRATION_MAX_SECONDS * NARRATION_SAMPLE_RATE
  * NARRATION_CHANNELS * (NARRATION_BITS / 8) + 64 * 1024;

/// Above this the microphone was live — the app's `liveMicrophoneDbfs`, for the
/// same reason: a muted microphone on the development machine recorded −91 dB
/// with a flawless clock, a correct header and nothing anywhere saying so.
const LIVE_MICROPHONE_DBFS = -70;
const SILENCE_FLOOR_DBFS = -96;

/// More beats than any tutorial has; a bound on the work of reading the list.
const MAX_MARKERS = 5000;

/// Where recordings are kept. Inside `uploads/` on purpose; `NARRATION_DIR`
/// moves it, which the tests do so they never touch the real directory.
function narrationDir() {
  return process.env.NARRATION_DIR || path.join(__dirname, '..', 'uploads', 'narration');
}

/// A name for one recording of one tutorial. Random rather than a clock: a
/// clock is not a name, and two uploads in one millisecond would share it.
function narrationFilename(lessonId) {
  return `narration_${lessonId}_${crypto.randomBytes(8).toString('hex')}.wav`;
}

/// Deletes a file and says so in the log when it cannot. A recording that
/// could not be deleted is a voice left behind, which somebody has to know.
function removeQuietly(file) {
  if (!file) return;
  try {
    fs.unlinkSync(file);
  } catch (err) {
    if (err.code !== 'ENOENT') {
      logger.error(`[NARRATION] Could not delete ${path.basename(file)}: ${err.message}`);
    }
  }
}

/// Deletes the stored recording [filename] names. The name is reduced to its
/// basename first: it came out of a database row, and a row is not a path.
function removeNarrationFile(filename) {
  if (!filename) return;
  removeQuietly(path.join(narrationDir(), path.basename(String(filename))));
}

/// The loudest sample in the audio, in dBFS, read in blocks so a fifteen-minute
/// take is never held in memory whole.
function peakDbfsOf(file, offset, length) {
  const fd = fs.openSync(file, 'r');
  try {
    const block = Buffer.alloc(64 * 1024);
    let peak = 0;
    let at = 0;
    while (at < length) {
      const want = Math.min(block.length, length - at);
      const got = fs.readSync(fd, block, 0, want, offset + at);
      if (got <= 0) break;
      for (let i = 0; i + 1 < got; i += 2) {
        const sample = Math.abs(block.readInt16LE(i));
        if (sample > peak) peak = sample;
      }
      at += got;
    }
    if (peak === 0) return SILENCE_FLOOR_DBFS;
    return Math.max(20 * Math.log10(peak / 32768), SILENCE_FLOOR_DBFS);
  } finally {
    fs.closeSync(fd);
  }
}

/// „3:07" — how the app writes a length, so the two ends of a refusal read
/// alike.
function clockOf(ms) {
  const seconds = Math.floor(ms / 1000);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

/// The marker list the app sent: JSON text in a multipart field, or already an
/// array. Null when it is neither.
function parseMarkers(raw) {
  if (Array.isArray(raw)) return raw;
  if (typeof raw !== 'string') return null;
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function refuse(status, error) {
  return { ok: false, status, error };
}

/// Whether [file] is a take a video can be made of, and why not.
///
/// [durationMs] and [beats] are what the app says: how long it recorded, and
/// how many beats the film has. The file answers the first; the second can only
/// be compared with the markers, and the export compares it again with the film
/// it is asked to draw.
///
/// Cheapest first: the header, then the list, and the samples last — a take
/// refused for its length is not read end to end to find out it is also quiet.
function judgeNarration({ file, markersMs, durationMs, beats }) {
  const info = wavInfo(file);
  if (!info) {
    return refuse(400, 'The recording is not a wav file this app made. Record it again.');
  }
  if (info.audioFormat !== 1
    || info.channels !== NARRATION_CHANNELS
    || info.sampleRate !== NARRATION_SAMPLE_RATE
    || info.bitsPerSample !== NARRATION_BITS) {
    return refuse(400, 'The recording is not in the format this app records in. Record it again in the app.');
  }

  const measuredMs = Math.floor(info.dataBytes * 1000 / info.byteRate);
  if (measuredMs > NARRATION_MAX_SECONDS * 1000) {
    return refuse(413, `This recording is ${clockOf(measuredMs)} long, and one recording may be at `
      + `most ${NARRATION_MAX_SECONDS / 60} minutes. Split the tutorial into two, or record a shorter narration.`);
  }
  if (!Number.isInteger(durationMs)) {
    return refuse(400, 'The app did not say how long the recording is. Upload it again.');
  }
  if (durationMs !== measuredMs) {
    return refuse(400, `The recording arrived incomplete: ${clockOf(measuredMs)} of the `
      + `${clockOf(durationMs)} that were recorded. Upload it again.`);
  }

  const markers = parseMarkers(markersMs);
  if (!markers || markers.length === 0) {
    return refuse(400, 'The recording arrived without its beats. Upload it again.');
  }
  if (markers.length > MAX_MARKERS || !markers.every(Number.isInteger)) {
    return refuse(400, 'The beats of this recording could not be read. Record it again.');
  }
  // The audio's zero is its first sample, and the film opens on beat 0.
  if (markers[0] !== 0) {
    return refuse(400, 'The first beat does not start at the beginning of the recording. Record it again.');
  }
  for (let i = 1; i < markers.length; i++) {
    if (markers[i] <= markers[i - 1]) {
      return refuse(400, `Beats ${i} and ${i + 1} start at the same moment, so the video would never `
        + 'show the first of them. Record it again.');
    }
  }
  if (markers[markers.length - 1] >= measuredMs) {
    return refuse(400, 'The last beat starts after the recording ends. Record it again.');
  }
  if (!Number.isInteger(beats) || beats < 1) {
    return refuse(400, 'The app did not say how many beats the tutorial has. Upload it again.');
  }
  if (markers.length !== beats) {
    return refuse(400, `The recording stops at beat ${markers.length} of ${beats}. A video needs a `
      + 'recording that reaches the last beat — record it again to the end.');
  }

  const peak = peakDbfsOf(file, info.dataOffset, info.dataBytes);
  if (peak <= LIVE_MICROPHONE_DBFS) {
    // The app's own sentence for the same take, so the trainer reads one answer.
    return refuse(422, 'Nothing reached the microphone during this recording, so it is silent. '
      + 'Check the mute key and the input device, then record again.');
  }

  return { ok: true, durationMs: measuredMs, markers, peakDbfs: peak };
}

/// The name the app gives a take (`take-<id>.wav` on the device), kept beside
/// the recording so the app can tell whether the take on the server is the one
/// it holds without sending it again. Hex only: it is compared, never used as
/// a path, but a value that is only ever hex cannot become one.
const TAKE_ID = /^[0-9a-f]{8,64}$/;

/// The film's events on a stored recording's own timing, or why they cannot be.
///
/// Phase 4. The markers replace the app's reading-speed guess — the same
/// substitution `retimeEvents` makes for a synthesised voice, from another
/// source — and `spokenMs` is the gap to the next marker, so the caption is
/// revealed across the time the trainer actually spent on that beat. The
/// request's own events are copied, never rewritten in place.
///
/// Refused rather than bent: a recording made for another number of beats names
/// beats that are not in this film, and a film drawn against it is wrong from
/// the first place the two disagree.
function recordingForFilm({ row, takeId, events }) {
  if (!row || !row.narration_filename) {
    return { ok: false, code: 'none', error: 'This tutorial has no recording on the server. Export again to send it.' };
  }
  if (takeId && row.narration_take_id && takeId !== row.narration_take_id) {
    return {
      ok: false,
      code: 'other',
      error: 'The recording on the server is not the one on this device. Export again to send this one.',
    };
  }
  const markers = Array.isArray(row.narration_markers) ? row.narration_markers : [];
  if (!Array.isArray(events) || markers.length !== events.length) {
    return {
      ok: false,
      code: 'beats',
      error: `The recording was made for ${markers.length} beats, and the tutorial has `
        + `${Array.isArray(events) ? events.length : 0} now. Record it again, or export without your voice.`,
    };
  }
  const audioPath = path.join(narrationDir(), path.basename(String(row.narration_filename)));
  if (!fs.existsSync(audioPath)) {
    // A voice the row names and the disk does not have. It cannot be made
    // again, so this is worth a line in the log as well as a sentence.
    logger.error(`[NARRATION] A tutorial names ${path.basename(audioPath)}, which is not on disk`);
    return { ok: false, code: 'gone', error: 'The recording is missing on the server. Record it again.' };
  }

  const durationMs = Number(row.narration_ms) || 0;
  const timed = events.map((event, i) => {
    const next = i + 1 < markers.length ? markers[i + 1] : durationMs;
    return {
      ...event,
      timestampMs: markers[i],
      data: { ...(event && event.data ? event.data : {}), spokenMs: Math.max(0, next - markers[i]) },
    };
  });
  return { ok: true, events: timed, audioPath, seconds: Math.ceil(durationMs / 1000) };
}

module.exports = {
  TAKE_ID,
  recordingForFilm,
  LIVE_MICROPHONE_DBFS,
  NARRATION_MAX_BYTES,
  NARRATION_MAX_SECONDS,
  judgeNarration,
  narrationDir,
  narrationFilename,
  peakDbfsOf,
  removeNarrationFile,
  removeQuietly,
};
