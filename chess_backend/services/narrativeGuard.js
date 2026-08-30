// narrativeGuard.js — the model may restate the numbers, and may not invent one.
//
// Section 7 asks for a sentence over the report: "he answers 1.e4 with the
// French, scores 38% against it, and nearly always goes for the same pawn
// break." That sentence is worth having and the model writes it well.
//
// The failure mode is not that the model lies. It is that it **rounds, averages
// and totals** — helpfully, fluently, and into numbers nobody computed. "Scores
// 38%" becomes "scores about 40%"; three separate counts become "in over 200
// games". Every one of those reads exactly like the rest of the sentence, and a
// player has no way to tell which numbers came from their archive and which the
// model produced to make the prose flow.
//
// **A prompt is not a guardrail.** "Only restate the numbers you were given" is
// a request; the model complies most of the time, which is the worst possible
// rate — often enough to look reliable, rarely enough to be wrong unnoticed.
// The enforcement has to be structural, and there are only two structural
// options: template the numbers outside the model entirely, or check the output
// and refuse it. This is the second, for the cases where the sentence has to be
// written rather than filled in.
//
// The check is deliberately dumb: every numeral in the output must appear in
// the input. It cannot be argued with, it needs no model, and it fails closed.

/// Numbers as they appear in prose, including decimals and thousands
/// separators in both conventions. `41.3`, `41,3` and `4.126` are all one token
/// here, because the point is to catch a numeral the input never contained —
/// not to parse arithmetic.
const NUMERAL = /\d[\d.,]*/g;

/// Numerals a sentence may contain without anyone having computed them.
///
/// Ordinals and small counts appear in ordinary Serbian prose — „u 3 partije"
/// is a claim, but „1.e4" and „2. potez" are how moves are written. Move
/// numbers are the specific hazard: they are numerals, they are everywhere in
/// chess prose, and they are not statistics. So the input side is what gets
/// widened, below, rather than this list.
const ALWAYS_ALLOWED = new Set(['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10']);

/// Strips a numeral to something comparable: `41,30` and `41.3` are the same
/// number said two ways, and `4.126` and `4126` are the same count.
function normalise(token) {
  // Trailing separators belong to the prose, not to the number: `2.Nf3` and
  // `1...c5` are a move number followed by punctuation, and leaving the dots
  // attached turns `1` into the unrecognised token `1...` — which the guard
  // then refuses, in the single most common sentence this feature writes.
  const trimmed = String(token).replace(/[.,]+$/, '');
  const cleaned = trimmed.replace(/[.,](?=\d{3}\b)/g, '');
  const dotted = cleaned.replace(',', '.');
  const value = Number(dotted);
  if (!Number.isFinite(value)) return String(token);
  // Trailing zeros are not a different number.
  return String(value);
}

/// Every numeral anywhere in a value, however deeply nested.
///
/// Walks the whole structure rather than a chosen list of fields, because the
/// alternative is a list somebody has to remember to extend — and the failure of
/// forgetting is a refused sentence that was actually correct, which reads as
/// the guard being broken and gets the guard turned off.
function numeralsIn(value, into = new Set()) {
  if (value === null || value === undefined) return into;
  if (typeof value === 'number') {
    if (Number.isFinite(value)) {
      into.add(normalise(value));
      // A share of 0.413 is how the data holds it and "41.3%" is how a sentence
      // says it. Refusing the percentage would make the guard unusable for the
      // one phrasing this feature exists to produce, so both forms of the same
      // fact are admissible — and both round trips are computed here, from the
      // input, never taken from the output.
      if (value > 0 && value < 1) {
        into.add(normalise(Math.round(value * 1000) / 10));
        into.add(normalise(Math.round(value * 100)));
      }
    }
    return into;
  }
  if (typeof value === 'string') {
    for (const match of value.match(NUMERAL) || []) into.add(normalise(match));
    return into;
  }
  if (Array.isArray(value)) {
    for (const item of value) numeralsIn(item, into);
    return into;
  }
  if (typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      // Keys carry numbers too — a bucket named "KRP" does not, but one named
      // "2024" does, and the sentence is allowed to say the year it grouped by.
      numeralsIn(key, into);
      numeralsIn(item, into);
    }
    return into;
  }
  return into;
}

/// Which numerals in `text` were not in `facts`.
///
/// Returns the offenders rather than a boolean, so a refusal can say what it
/// refused over. A guard that only says "no" is a guard nobody can debug, and
/// this one will occasionally be wrong.
function inventedNumerals(text, facts) {
  const known = numeralsIn(facts);
  const invented = [];
  for (const match of String(text || '').match(NUMERAL) || []) {
    const token = normalise(match);
    if (ALWAYS_ALLOWED.has(token) || known.has(token)) continue;
    if (!invented.includes(match)) invented.push(match);
  }
  return invented;
}

/// The gate itself: the narrative, or the reason there is none.
///
/// **Fails closed.** A sentence carrying a number nobody computed is not
/// returned with a warning beside it — there is no version of this where the
/// player sees the invented figure. The report's own numbers are the answer;
/// the sentence was always the decoration.
function checkNarrative(text, facts) {
  const narrative = String(text || '').trim();
  if (!narrative) return { ok: false, reason: 'empty', invented: [] };

  const invented = inventedNumerals(narrative, facts);
  if (invented.length > 0) {
    return { ok: false, reason: 'invented-numbers', invented, narrative };
  }
  return { ok: true, narrative };
}

module.exports = {
  checkNarrative,
  inventedNumerals,
  numeralsIn,
  normalise,
  ALWAYS_ALLOWED,
};
