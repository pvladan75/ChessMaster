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
//
// One thing does happen to the text on its way to the voice: the notation in it
// is written out (`spokenMoves`). „Bd5" is not language, and every voice spells
// it — an English one says „bee dee five" and a French one „boulevard cinq".
// The caption is untouched, so the screen still reads „Bd5" while the voice
// says „bishop d 5", which is what a trainer at a board does.
const path = require('path');

const logger = require('./logger');
const tts = require('./tts');
const { narrationPlan, retimeEvents } = require('./narrationPlan');
const { spokenMoves } = require('./spokenMoves');
const { buildNarrationTrack } = require('./narrationTrack');
const { throwIfAborted } = require('./renderAbort');

/**
 * Narrate a film.
 *
 * Returns `{ events, audioPath, seconds, spokenBeats, silentBecause }`. When
 * narration is unavailable, refused or empty it returns the events
 * **untouched** and `audioPath: null`, so the caller renders exactly the silent
 * film it would have rendered anyway. There is no half-narrated state: either
 * the timestamps came from the voice or they came from the app's reading-speed
 * guess.
 *
 * `silentBecause` is null when the film speaks, and otherwise says which of the
 * ways it came back silent — because **a trainer who asked for a voice and
 * got a silent film has to be told why.** Piper failing to start looks exactly
 * like a tutorial with nothing written in it from where the trainer sits, and
 * on 9.9.2026 it was exactly that: the engine was missing on the owner's
 * machine, the log said so, and the app said „Video ready!". The value is a
 * word rather than a sentence, so the copy stays with the route that answers.
 */
async function narrateFilm({ events, voice, exportsDir, filename, signal = null }) {
  // Narration is inside the render queue with the drawing, so a client that has
  // already gone must not be synthesised for either — a twenty-five beat
  // tutorial is a minute of piper holding the one slot.
  throwIfAborted(signal);

  // Asked for a reason rather than a boolean: „no voice is installed" and „the
  // engine will not start" send a trainer to two different places, and the
  // route turns each into its own sentence.
  const blocked = await tts.narrationBlockedBy();
  if (blocked) {
    return { events, audioPath: null, seconds: null, spokenBeats: 0, silentBecause: blocked };
  }

  const captions = events.map((event) => (event && event.data ? event.data.text : '') || '');
  if (!captions.some((text) => text.trim())) {
    // Every beat is wordless. A voice has nothing to add and the film keeps the
    // timings the app computed — and this is the one silence nobody needs to be
    // told about, because there was nothing to say.
    return { events, audioPath: null, seconds: null, spokenBeats: 0, silentBecause: null };
  }

  // Said, not spelled — and in the language of the voice, which is the one
  // thing the voice id already tells us.
  const clips = await tts.speakBeats(
    captions.map((text) => spokenMoves(text, voice)),
    { voice, signal },
  );
  // Between the two long phases. Synthesis of a whole tutorial is the longest
  // stretch of a narrated export, and the track that follows it is written into
  // `exports/`.
  throwIfAborted(signal);
  const spokenBeats = clips.filter((c) => c.clipSeconds).length;
  if (spokenBeats === 0) {
    logger.warn('[TTS] narration was asked for and every beat came back silent');
    return { events, audioPath: null, seconds: null, spokenBeats: 0, silentBecause: 'voice' };
  }

  const plan = narrationPlan(clips);
  const audioPath = await buildNarrationTrack({
    segments: plan.segments,
    clips,
    outputPath: path.join(exportsDir, `${filename}.wav`),
    signal,
  });
  // `buildNarrationTrack` returns null for a track its ffmpeg did not finish,
  // and a killed ffmpeg is exactly that — but „no track" and „no client" are
  // different answers, and only one of them should be reported as a silent
  // film. Asked after the call so the partial file is already gone.
  throwIfAborted(signal);

  if (!audioPath) {
    // The clips exist and the track does not. Falling back to the app's timings
    // is the only honest answer: the retimed events are longer than the silent
    // film by exactly the pauses nobody will hear.
    return { events, audioPath: null, seconds: null, spokenBeats: 0, silentBecause: 'track' };
  }

  return {
    events: retimeEvents(events, plan),
    audioPath,
    seconds: Math.ceil(plan.totalSeconds),
    spokenBeats,
    silentBecause: null,
  };
}

module.exports = { narrateFilm };
