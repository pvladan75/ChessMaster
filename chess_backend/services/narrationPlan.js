// narrationPlan.js — when each beat starts, once a voice decides how long it is.
//
// Phase 2 of `docs/PLAN-ZAVRSNICA.md`, the narrated half. Without a voice a
// beat lasts `dwellSecondsFor(text)` — twelve characters a second, a guess made
// in the app. With a voice the guess is not needed: a beat lasts as long as the
// sentence takes to say. That is also how the app's own narrated walk behaves,
// where the move is played when the sentence in front of it has been read out.
//
// **One function owns both the picture and the sound**, and that is the whole
// reason this file exists. The frame timestamps and the audio track are two
// readings of the same list of durations; computed apart they drift, and a
// drift of half a second between a sentence and the board it is about is worse
// than no narration at all.
//
// **Every beat is a whole number of seconds.** The renderer draws one picture
// per second, so a beat boundary inside a second would show the next position
// while the previous sentence is still being read — up to a second of the voice
// talking about a board that has already changed. Rounding up costs a fraction
// of a second of silence at the end of a beat, which is a breath rather than a
// fault.

/// Silence after the **voice** before the next beat begins, in seconds.
///
/// Not zero: two sentences butted together read as one, and the child needs the
/// gap to look at the board the sentence was about.
///
/// **Counted from where the voice stops, not from where the file ends.** Azure
/// hands back every sentence with about 0.85 s of silence behind it - measured
/// across all 22 clips of the owner's film of 12.9.2026, 0.80 to 0.93. Added to
/// the file's length it made the breath nearly twice what it says here, and the
/// owner reported exactly that: the film waits, sometimes two seconds, after
/// the voice has stopped.
const BREATH_SECONDS = 0.6;

/// Silence before the film's first clip, in seconds.
///
/// A synthesiser's own lead-in is about an eighth of a second - measured, 0.12
/// to 0.14 - and a first word that starts there is a first word a player can
/// swallow. The owner heard "Checkmating..." begin at "mating" on the published
/// film, where the audio was in fact whole: the track and the clip measure
/// identical in that window, to the decibel. So this is room rather than a
/// repair, and it is spent on the first beat that speaks - a film whose first
/// beat is wordless already opens with two seconds of silence.
const LEAD_SECONDS = 0.4;

/// What a beat with nothing written gets, in seconds.
///
/// A part can open on a position with no sentence — „look at this" is a whole
/// beat — and the film still has to stay on it long enough to be seen.
const SILENT_BEAT_SECONDS = 2;

/// The longest a single beat may hold the screen, in seconds.
///
/// A clip longer than this is a synthesiser that has run away — a beat's
/// caption is four lines at most, which is about fifteen seconds of speech — so
/// the beat is played **silent** rather than trimmed.
///
/// Trimming was the first answer and it was wrong: shortening the number here
/// does not shorten the *file*, so the track would have carried the whole
/// runaway clip while the pictures moved on at the trimmed length, and every
/// beat after it would have drifted further from its board. Dropping the clip
/// keeps the one property this file exists for — the sound and the picture are
/// two readings of the same durations.
const MAX_BEAT_SECONDS = 60;

/**
 * Turn per-beat clip lengths into a film.
 *
 * `beats` is one entry per event, in the film's order, each `{ clipSeconds }`
 * — a number for a beat that has a recording, and `null` for one that does not
 * (nothing written, or a synthesiser that refused this sentence).
 *
 * Returns:
 *
 *   * `beatSeconds` — how long each beat holds the screen, whole seconds;
 *   * `startMs` — when each beat starts, which is what the renderer's events
 *     carry as `timestampMs`;
 *   * `segments` — the audio track, in order: a `clip` is the beat's own
 *     recording, a `silence` is the rest of that beat's second and every second
 *     of a beat that has no recording. Concatenated, they are exactly
 *     `totalSeconds` long, so the sound cannot end before the picture or run
 *     past it.
 */
function narrationPlan(beats, options = {}) {
  const breath = options.breathSeconds ?? BREATH_SECONDS;
  const silentBeat = options.silentBeatSeconds ?? SILENT_BEAT_SECONDS;
  const maxBeat = options.maxBeatSeconds ?? MAX_BEAT_SECONDS;
  const lead = Math.max(0, options.leadSeconds ?? LEAD_SECONDS);
  // **The grid a beat boundary may land on**, which is the rate the film is
  // drawn at - `videoRenderer.framesPerSecondOf`, passed in by the caller. A
  // boundary between two frames would show the next position while the previous
  // sentence is still being read, so it is rounded up to the next frame; at
  // four frames a second that costs a quarter of a second instead of the whole
  // one this file rounded to when every film was drawn once a second.
  const fps = Number.isFinite(options.fps) && options.fps > 0 ? options.fps : 1;
  const upToFrame = (seconds) => Math.ceil(seconds * fps - 1e-9) / fps;

  const beatSeconds = [];
  const segments = [];
  const startMs = [];
  const spoken = [];
  let atSeconds = 0;
  let leadLeft = lead;

  for (let i = 0; i < beats.length; i++) {
    const clip = beats[i] ? beats[i].clipSeconds : null;
    const hasClip = typeof clip === 'number'
      && Number.isFinite(clip)
      && clip > 0
      && clip <= maxBeat;
    const clipSeconds = hasClip ? clip : 0;

    // Where the voice is inside the clip. Absent - a wav this server could not
    // scan - means the whole clip counts as speech, which is what everything
    // here did before the silence around it was measured.
    const voiceFrom = hasClip ? finiteOr(beats[i].speechStart, 0) : 0;
    const voiceTo = hasClip ? finiteOr(beats[i].speechEnd, clipSeconds) : 0;
    // The film's lead-in, spent on the first beat that has anything to say.
    const before = hasClip ? leadLeft : 0;
    if (hasClip) leadLeft = 0;

    // Long enough for the whole clip, and for a breath after the **voice**.
    // The clip's own tail usually covers that breath by itself.
    const seconds = hasClip
      ? Math.max(1 / fps, upToFrame(before + Math.max(clipSeconds, voiceTo + breath)))
      : silentBeat;

    startMs.push(Math.round(atSeconds * 1000));
    beatSeconds.push(seconds);
    spoken.push(hasClip
      ? {
        startMs: Math.round((before + voiceFrom) * 1000),
        ms: Math.max(1, Math.round((voiceTo - voiceFrom) * 1000)),
      }
      : null);
    atSeconds += seconds;

    if (hasClip) {
      // Before the clip rather than after the last beat: a lead-in at the end
      // of a film is a film that appears to have stopped.
      if (before > 0.001) segments.push({ kind: 'silence', index: i, seconds: before });
      segments.push({ kind: 'clip', index: i, seconds: clipSeconds });
      const rest = seconds - before - clipSeconds;
      // Guarded rather than assumed: `ceil(x + breath) - x` is at least the
      // breath, but a clip cut to `maxBeat` makes it exactly zero and ffmpeg
      // given a zero-length silence writes a file nobody can concatenate.
      if (rest > 0.001) segments.push({ kind: 'silence', index: i, seconds: rest });
    } else {
      segments.push({ kind: 'silence', index: i, seconds });
    }
  }

  return {
    beatSeconds,
    startMs,
    // Where the voice is, per beat, in the film's own clock - one computation,
    // read by `retimeEvents` and by nothing else, so the caption cannot be
    // written to a different window than the one the track holds.
    spoken,
    segments,
    totalSeconds: atSeconds,
  };
}

function finiteOr(value, fallback) {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0
    ? value
    : fallback;
}

/**
 * The same events, re-timed to the plan.
 *
 * The app sent timestamps computed from sentence length, which is the right
 * answer when nobody is speaking. Once a voice has been recorded its durations
 * are the truth, so the timestamps are replaced rather than adjusted — there is
 * no arithmetic here that could disagree with the audio track, because both
 * come out of the same call.
 */
function retimeEvents(events, plan) {
  return events.map((event, i) => {
    // How long this beat's clip runs, for whoever draws the sentence: the
    // renderer writes the caption on screen at the speed it is being spoken,
    // and without this it would have to guess from the gap to the next beat —
    // which includes the breath, so the writing would lag the voice by half a
    // second and finish after it.
    // **The window the voice occupies inside this beat**, for whoever draws
    // the sentence: the renderer writes the caption on screen at the speed it is
    // being spoken, and it has to be given that speed rather than guess it.
    //
    // It was the clip's whole length until 12.9.2026, and that was half a
    // mistake: a clip begins with an eighth of a second of silence and ends
    // with most of a second of it, so the writing started early, ran slow, and
    // went on after the voice had stopped.
    const window = plan.spoken ? plan.spoken[i] : null;
    const spokenMs = window ? window.ms : 0;
    const spokenStartMs = window ? window.startMs : 0;
    return {
      ...event,
      timestampMs: plan.startMs[i] ?? event.timestampMs,
      data: event.data ? { ...event.data, spokenMs, spokenStartMs } : event.data,
    };
  });
}

module.exports = {
  narrationPlan,
  retimeEvents,
  BREATH_SECONDS,
  LEAD_SECONDS,
  SILENT_BEAT_SECONDS,
  MAX_BEAT_SECONDS,
};
