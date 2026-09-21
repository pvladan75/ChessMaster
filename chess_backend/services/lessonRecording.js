// lessonRecording.js — a lesson an adult records alone in Preparation.
//
// Phase 5b.2 of docs/PLAN-SESIJA.md. The app records the take on the audio's
// own clock (`chess_app/.../lesson_take.dart`) and stamps each board event with
// its position in the audio; this decides whether what arrived is that take,
// and where its sound is kept.
//
// **The audio is judged exactly as a tutorial's narration is** — the same
// format, the same cap (derived from what one film render can draw), the same
// length read from the wav's own header, the same level — through the helpers
// in `narrationUpload.js`, so the two recordings cannot disagree about what a
// millisecond of audio is. What differs is the list beside it: a narration has
// a fixed beat list, a lesson has whatever the trainer did on the board.
//
// **The sound is private.** It lives in `uploads/lessons/`, which is never
// served by URL (`middleware/uploadsStatic.js`), and reaches a reader only
// through a link signed for them and for that one file, valid for thirty
// minutes. A room recording's sound was a plain path under `/uploads/`, and a
// recording that is shared with students must not be a URL that plays without
// an account.

const path = require('path');
const crypto = require('crypto');
const { signDownloadToken } = require('../middleware/auth');

/// The event kinds both readers replay: the app's player and the server's film
/// (`videoRenderer.applyEvent`). The room's recorder also wrote `lesson_loaded`
/// and `fen_change`, which the player understood and the film did not — a room
/// lesson's video stayed on the old board through every jump. A lesson
/// recorded here writes only these, and anything else is refused rather than
/// stored as something one of the two will skip.
const LESSON_EVENT_TYPES = ['init', 'move', 'arrow_drawn'];

/// A bound on the work of reading the list: a thirty-minute lesson with an
/// event every tenth of a second.
const MAX_EVENTS = 20000;

/// Where lessons are kept. Inside `uploads/` on purpose — a voice cannot be
/// reproduced — and `LESSON_RECORDING_DIR` moves it, which the tests do.
function lessonDir() {
  return process.env.LESSON_RECORDING_DIR || path.join(__dirname, '..', 'uploads', 'lessons');
}

/// Random rather than a clock: a clock is not a name.
function lessonFilename(userId) {
  return `lesson_${Number(userId)}_${crypto.randomBytes(8).toString('hex')}.wav`;
}

/// The file a row names, on disk — its basename only, because a row is not a
/// path.
function lessonAudioPath(filename) {
  return path.join(lessonDir(), path.basename(String(filename)));
}

/// The link a reader plays the sound through, or null when the recording has
/// no private sound (a room recording, whose `audio_url` is what it always was).
function lessonAudioUrl(row, userId) {
  if (!row || !row.audio_file) return null;
  const name = path.basename(String(row.audio_file));
  return `/recordings/lesson-audio/${encodeURIComponent(name)}`
    + `?token=${encodeURIComponent(signDownloadToken(userId, name))}`;
}

function refuse(error) {
  return { ok: false, status: 400, error };
}

function parseEvents(raw) {
  if (Array.isArray(raw)) return raw;
  if (typeof raw !== 'string') return null;
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

/// Whether [events] describe a lesson the player and the film can replay over
/// [durationMs] of audio, and why not.
function judgeLessonEvents({ events, durationMs }) {
  const list = parseEvents(events);
  if (!list) return refuse('The recording\'s moves could not be read. Upload it again.');
  if (list.length === 0) return refuse('The recording arrived without its board. Upload it again.');
  if (list.length > MAX_EVENTS) {
    return refuse('The recording has more moves than one recording may carry. Record a shorter one.');
  }
  const readable = list.every((e) => e
    && typeof e === 'object'
    && Number.isInteger(e.timestampMs) && e.timestampMs >= 0
    && typeof e.eventType === 'string'
    && e.data && typeof e.data === 'object' && !Array.isArray(e.data));
  if (!readable) return refuse('The recording\'s moves could not be read. Upload it again.');

  const first = list[0];
  if (first.eventType !== 'init' || first.timestampMs !== 0 || typeof first.data.fen !== 'string') {
    return refuse('The recording does not open on the board it was recorded from. Record it again.');
  }
  const unknown = list.find((e) => !LESSON_EVENT_TYPES.includes(e.eventType));
  if (unknown) {
    return refuse(`The recording contains „${unknown.eventType}", which the player and the video `
      + 'cannot replay. Update the app and record it again.');
  }
  for (let i = 1; i < list.length; i++) {
    if (list[i].timestampMs < list[i - 1].timestampMs) {
      return refuse('The recording\'s moves are out of order. Record it again.');
    }
  }
  if (list[list.length - 1].timestampMs > durationMs) {
    return refuse('A move in this recording comes after the recording ends. Record it again.');
  }
  return { ok: true, events: list };
}

module.exports = {
  LESSON_EVENT_TYPES,
  MAX_EVENTS,
  judgeLessonEvents,
  lessonAudioPath,
  lessonAudioUrl,
  lessonDir,
  lessonFilename,
};
