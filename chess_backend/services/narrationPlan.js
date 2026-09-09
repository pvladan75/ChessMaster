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

/// Silence after a clip before the next beat begins, in seconds.
///
/// Not zero: two sentences butted together read as one, and the child needs the
/// gap to look at the board the sentence was about.
const BREATH_SECONDS = 0.6;

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

  const beatSeconds = [];
  const segments = [];
  const startMs = [];
  let atSeconds = 0;

  for (let i = 0; i < beats.length; i++) {
    const clip = beats[i] ? beats[i].clipSeconds : null;
    const hasClip = typeof clip === 'number'
      && Number.isFinite(clip)
      && clip > 0
      && clip <= maxBeat;
    const spoken = hasClip ? clip : 0;

    // Whole seconds, always at least one more than the voice needs, so the
    // breath is real and the boundary lands on a frame.
    const seconds = hasClip
      ? Math.max(1, Math.ceil(spoken + breath))
      : silentBeat;

    startMs.push(Math.round(atSeconds * 1000));
    beatSeconds.push(seconds);
    atSeconds += seconds;

    if (hasClip) {
      segments.push({ kind: 'clip', index: i, seconds: spoken });
      const rest = seconds - spoken;
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
    segments,
    totalSeconds: atSeconds,
  };
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
  return events.map((event, i) => ({
    ...event,
    timestampMs: plan.startMs[i] ?? event.timestampMs,
  }));
}

module.exports = {
  narrationPlan,
  retimeEvents,
  BREATH_SECONDS,
  SILENT_BEAT_SECONDS,
  MAX_BEAT_SECONDS,
};
