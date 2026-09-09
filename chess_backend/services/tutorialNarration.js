// tutorialNarration.js — a silent event list, spoken.
//
// The one door between the export route and everything narration needs. The
// route asks for a narrated film and gets back the two things the renderer
// takes: events whose timestamps match the voice, and one audio file.
//
// Nothing here decides *what* is said. The caption on a beat is what the
// trainer wrote plus, on the last beat of a part that asks something, the task
// — `tutorialVideoOf` in the app already composed that, and reading it here is
// the difference between one sentence and two writers of it.
const path = require('path');

const logger = require('./logger');
const tts = require('./tts');
const { narrationPlan, retimeEvents } = require('./narrationPlan');
const { buildNarrationTrack } = require('./narrationTrack');

/**
 * Narrate a film.
 *
 * Returns `{ events, audioPath, seconds, spokenBeats }`. When narration is
 * unavailable, refused or empty it returns the events **untouched** and
 * `audioPath: null`, so the caller renders exactly the silent film it would
 * have rendered anyway. There is no half-narrated state: either the timestamps
 * came from the voice or they came from the app's reading-speed guess.
 */
async function narrateFilm({ events, voice, exportsDir, filename }) {
  if (!tts.narrationAvailable()) {
    return { events, audioPath: null, seconds: null, spokenBeats: 0 };
  }

  const captions = events.map((event) => (event && event.data ? event.data.text : '') || '');
  if (!captions.some((text) => text.trim())) {
    // Every beat is wordless. A voice has nothing to add and the film keeps the
    // timings the app computed.
    return { events, audioPath: null, seconds: null, spokenBeats: 0 };
  }

  const clips = await tts.speakBeats(captions, { voice });
  const spokenBeats = clips.filter((c) => c.clipSeconds).length;
  if (spokenBeats === 0) {
    logger.warn('[TTS] narration was asked for and every beat came back silent');
    return { events, audioPath: null, seconds: null, spokenBeats: 0 };
  }

  const plan = narrationPlan(clips);
  const audioPath = await buildNarrationTrack({
    segments: plan.segments,
    clips,
    outputPath: path.join(exportsDir, `${filename}.wav`),
  });

  if (!audioPath) {
    // The clips exist and the track does not. Falling back to the app's timings
    // is the only honest answer: the retimed events are longer than the silent
    // film by exactly the pauses nobody will hear.
    return { events, audioPath: null, seconds: null, spokenBeats: 0 };
  }

  return {
    events: retimeEvents(events, plan),
    audioPath,
    seconds: Math.ceil(plan.totalSeconds),
    spokenBeats,
  };
}

module.exports = { narrateFilm };
