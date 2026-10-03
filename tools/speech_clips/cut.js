// cut.js — the pure parts of `render.js`: counting a carrier's words, cutting
// words out of a carrier at the midpoints between neighbours, and deciding
// from the lock whether a clip is already rendered as asked.
'use strict';

/// Words the way the Dart vocabulary counts them (`wordCountOf`): split on
/// spaces, punctuation stripped.
function wordCount(carrier) {
  return carrier.replace(/[.,?]/g, '').trim().split(/\s+/).filter(Boolean).length;
}

/// The frame range of words [a..b] (1-based, inclusive) of a carrier whose
/// SDK word times are [words] and whose voice runs from [startMs] to [endMs]
/// (`speechWindow`): the first word starts where the voice starts, the last
/// ends where it ends, and every other edge is the midpoint between the two
/// words it parts.
function wordRangeMs(words, a, b, { startMs, endMs }) {
  if (a < 1 || b > words.length || a > b) throw new Error(`words ${a}..${b} of ${words.length}`);
  const from = a === 1 ? startMs : (words[a - 2].endMs + words[a - 1].startMs) / 2;
  const to = b === words.length ? endMs : (words[b - 1].endMs + words[b].startMs) / 2;
  return { fromMs: from, toMs: to };
}

/// The PCM of [pcm] (16-bit frames of [channels]) between two times.
function slicePcm(pcm, { sampleRate, channels }, fromMs, toMs) {
  const frameBytes = 2 * channels;
  const frames = Math.floor(pcm.length / frameBytes);
  const at = (ms) => Math.min(frames, Math.max(0, Math.round((ms / 1000) * sampleRate)));
  return pcm.subarray(at(fromMs) * frameBytes, at(toMs) * frameBytes);
}

/// What the lock records for a token: everything that changes the sound.
function lockEntry(token, voice) {
  return {
    kind: token.kind,
    carrier: token.carrier,
    wordFrom: token.wordFrom ?? null,
    wordTo: token.wordTo ?? null,
    voice,
  };
}

function sameLock(a, b) {
  return Boolean(a) && Boolean(b) && a.kind === b.kind && a.carrier === b.carrier
    && a.wordFrom === b.wordFrom && a.wordTo === b.wordTo && a.voice === b.voice;
}

module.exports = { wordCount, wordRangeMs, slicePcm, lockEntry, sameLock };
