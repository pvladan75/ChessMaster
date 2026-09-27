// transcript.js — what a vendor heard in a recording, as sentences with times.
// Phase 7 of docs/PLAN-PRIPREMA.md. Pure: no database, no network, no clock.
//
// **R1 of that plan: text is cut at sentences and nowhere else.** A sentence
// is what the vendor returned between two sentence ends, with the time of its
// first word's start and its last word's end. The rule is the phase 5
// measurement's (`tools/stt_measure/beats.js`, `sentencesOf`), moved here so
// the server's transcript and the numbers the owner decided on are one rule.
//
// **Sentences are built from the vendor's words, not its segment text.**
// Whisper returns both, and they disagree: on the owner's corrected „proba 4"
// the word list got 2 of 185 words wrong and the segment text 6 (27.9.2026).
// The segments are used only for their punctuation, which the words lack.
//
// **What is refused, and what is not.** Whisper's times are not tidy, and a
// rule that refused every untidy answer would refuse every recording: on all
// five of the owner's recordings a sentence's end runs up to 480 ms past the
// next one's start, a word's start steps back by up to 260 ms once or twice a
// recording, and one last sentence ended 60 ms after the audio did. None of
// that is wrong enough to matter to R3, which reads a sentence's end. What is
// refused is what cannot be a recording at all: a sentence that starts before
// the one it follows, one that ends before it starts, and anything more than
// `MAX_OVERRUN_MS` past the end of the sound.

const { TUTORIAL_LANGUAGES } = require('./tutorialLanguage');

/// How far past the audio's end a time may run before the answer is refused.
/// Measured: 60 ms on large-v3, 472 ms on turbo (27.9.2026).
const MAX_OVERRUN_MS = 1000;

/// The longest a corrected sentence may be. Whisper's longest on the owner's
/// recordings was under 400 characters.
const MAX_SENTENCE_CHARS = 2000;

/// The languages a trainer may transcribe in, and the code the vendor takes.
///
/// A tutorial's languages (`tutorialLanguage.js`), because phase 8 gives the
/// tutorial the transcript's language — **less `sr-Cyrl`**, on the owner's
/// word of 27.9.2026: the vendor writes Serbian in Latin, and Latin cannot be
/// turned into Cyrillic without loss („nj" is „њ" or „нј"). A Cyrillic
/// tutorial comes from translation (phase 9).
const VENDOR_LANGUAGE = Object.freeze({
  en: 'en',
  'sr-Latn': 'sr',
  de: 'de',
  es: 'es',
  it: 'it',
  fr: 'fr',
});

const TRANSCRIPT_LANGUAGES = Object.freeze(
  TUTORIAL_LANGUAGES.filter((code) => code in VENDOR_LANGUAGE),
);

function isTranscriptLanguage(value) {
  return typeof value === 'string' && TRANSCRIPT_LANGUAGES.includes(value);
}

const LATIN = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', ђ: 'đ', е: 'e', ж: 'ž', з: 'z',
  и: 'i', ј: 'j', к: 'k', л: 'l', љ: 'lj', м: 'm', н: 'n', њ: 'nj', о: 'o',
  п: 'p', р: 'r', с: 's', т: 't', ћ: 'ć', у: 'u', ф: 'f', х: 'h', ц: 'c',
  ч: 'č', џ: 'dž', ш: 'š',
};

/// Serbian Cyrillic as Serbian Latin. One way only, and without loss: every
/// Cyrillic letter has one Latin spelling. The vendor answers Serbian in Latin
/// and now and then writes a passage in Cyrillic (phase 5).
function latinOf(text) {
  let out = '';
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const lower = ch.toLowerCase();
    const to = LATIN[lower];
    if (to === undefined) {
      out += ch;
    } else if (ch === lower) {
      out += to;
    } else {
      // „Љубав" is „Ljubav", „ЉУБАВ" is „LJUBAV".
      const next = text[i + 1];
      const shout = next !== undefined && next !== next.toLowerCase();
      out += shout ? to.toUpperCase() : to[0].toUpperCase() + to.slice(1);
    }
  }
  return out;
}

const ENDS_SENTENCE = /[.?!]$/;

/// R1. The vendor's words and segments in, sentences out:
/// `[{ startMs, endMs, text, heard }]`, `text` and `heard` the same until the
/// trainer corrects one.
///
/// A word belongs to the segment it starts in, and a segment's closing mark
/// goes onto its last word. A number with a full stop — „1." — is also how a
/// vendor writes „prvi", which ends nothing; what tells the two apart is that
/// a sentence begins with a capital.
function sentencesFrom({ words = [], segments = [] }, { language } = {}) {
  const say = language === 'sr-Latn' ? latinOf : (t) => t;
  const clean = words
    .map((w) => ({ text: say(String(w.text || '').trim()), startMs: w.startMs, endMs: w.endMs }))
    .filter((w) => w.text !== '');

  const groups = segments.length === 0
    ? [{ text: '', words: clean }]
    : segments.map((s, i) => {
      const from = s.startMs;
      const to = i + 1 < segments.length ? segments[i + 1].startMs : Infinity;
      // The first segment also takes any word the vendor put before it.
      return {
        text: String(s.text || '').trim(),
        words: clean.filter((w) => (i === 0 || w.startMs >= from) && w.startMs < to),
      };
    });

  const sentences = [];
  for (const group of groups) {
    const mark = ENDS_SENTENCE.exec(group.text);
    const last = group.words[group.words.length - 1];
    if (mark && last && !ENDS_SENTENCE.test(last.text)) {
      group.words[group.words.length - 1] = { ...last, text: last.text + mark[0] };
    }
    let open = [];
    const close = () => {
      if (open.length === 0) return;
      const text = open.map((w) => w.text).join(' ');
      sentences.push({
        startMs: open[0].startMs,
        endMs: open[open.length - 1].endMs,
        text,
        heard: text,
      });
      open = [];
    };
    group.words.forEach((word, i) => {
      open.push(word);
      if (!ENDS_SENTENCE.test(word.text)) return;
      const next = group.words[i + 1];
      const ordinal = /^\d+\.$/.test(word.text) && next !== undefined
        && next.text[0] === next.text[0].toLowerCase();
      if (!ordinal) close();
    });
    close();
  }
  return sentences;
}

/// The words of each sentence with their times, in the sentences' order — or
/// null when the two do not tally. Phase 8b of docs/PLAN-PRIPREMA.md: the app
/// cuts a sentence where the board changed inside it, and needs to know when
/// each of its words was said.
///
/// **Nothing is stored for this**: a sentence is a run of the vendor's words
/// (`sentencesFrom`), so walking the words in order and handing each sentence
/// as many as its `heard` has gives them back. The text of a word is the
/// sentence's own — Latin where the vendor wrote Cyrillic, with the closing
/// mark a segment gave it — and its times are the vendor's, brought inside
/// the sentence where `judgeSentences` brought the sentence inside the sound.
///
/// The walk is checked, not trusted: every sentence must begin where its
/// first word does, and every word must be used. A word with a space in it
/// would break the count, and a transcript whose words were replaced would
/// break the times; either way the answer is null and the sentences stay
/// whole, which is the rule before phase 8b.
function wordsBySentence(sentences, words) {
  if (!Array.isArray(sentences) || !Array.isArray(words)) return null;
  const clean = words.filter((w) => w && String(w.text || '').trim() !== ''
    && isTime(w.startMs) && isTime(w.endMs));
  const result = [];
  let at = 0;
  for (const s of sentences) {
    const tokens = typeof s.heard === 'string' ? s.heard.split(' ') : [];
    const mine = clean.slice(at, at + tokens.length);
    if (tokens.length === 0 || mine.length !== tokens.length) return null;
    if (Math.min(mine[0].startMs, s.endMs) !== s.startMs) return null;
    result.push(mine.map((w, i) => ({
      text: tokens[i],
      startMs: Math.min(w.startMs, s.endMs),
      endMs: Math.min(w.endMs, s.endMs),
    })));
    at += tokens.length;
  }
  return at === clean.length ? result : null;
}

const isTime = (v) => Number.isInteger(v) && v >= 0;

/// Whether [sentences] can stand as a recording's transcript, and the
/// sentences as they are kept: `{ ok: true, sentences }` or
/// `{ ok: false, error }`. An end a little past the sound is brought back to
/// it; nothing else is changed.
function judgeSentences(sentences, durationMs) {
  if (!isTime(durationMs) || durationMs === 0) {
    return { ok: false, error: 'The recording has no length to hold a transcript against.' };
  }
  if (!Array.isArray(sentences) || sentences.length === 0) {
    return { ok: false, error: 'Nothing was heard in this recording.' };
  }
  const kept = [];
  for (let i = 0; i < sentences.length; i++) {
    const s = sentences[i];
    const n = i + 1;
    if (!s || !isTime(s.startMs) || !isTime(s.endMs)) {
      return { ok: false, error: `Sentence ${n} came back without its times.` };
    }
    if (s.endMs < s.startMs) {
      return { ok: false, error: `Sentence ${n} ends before it starts.` };
    }
    if (i > 0 && s.startMs < sentences[i - 1].startMs) {
      return { ok: false, error: `Sentence ${n} starts before the one it follows.` };
    }
    if (s.endMs > durationMs + MAX_OVERRUN_MS) {
      return { ok: false, error: `Sentence ${n} runs past the end of the recording.` };
    }
    if (typeof s.text !== 'string' || s.text.trim() === '') {
      return { ok: false, error: `Sentence ${n} came back without words.` };
    }
    const endMs = Math.min(s.endMs, durationMs);
    kept.push({
      startMs: Math.min(s.startMs, endMs),
      endMs,
      text: s.text,
      heard: typeof s.heard === 'string' ? s.heard : s.text,
    });
  }
  return { ok: true, sentences: kept };
}

/// A trainer's correction: one text per sentence, in order. **A correction
/// changes text and never a time** — the times are the sound's, and nothing
/// the trainer sends is read for one. A sentence may be emptied: it is what
/// the vendor invented over silence, and it has no text to keep.
function applyCorrection(stored, texts) {
  if (!Array.isArray(texts)) {
    return { ok: false, error: 'A correction is a list of the sentences\' texts.' };
  }
  if (texts.length !== stored.length) {
    return {
      ok: false,
      error: `This transcript has ${stored.length} sentences, and the correction ${texts.length}.`,
    };
  }
  const sentences = [];
  for (let i = 0; i < texts.length; i++) {
    const text = texts[i];
    if (typeof text !== 'string') {
      return { ok: false, error: `Sentence ${i + 1} of the correction is not text.` };
    }
    if (text.length > MAX_SENTENCE_CHARS) {
      return { ok: false, error: `Sentence ${i + 1} is longer than ${MAX_SENTENCE_CHARS} characters.` };
    }
    const s = stored[i];
    sentences.push({ startMs: s.startMs, endMs: s.endMs, text: text.trim(), heard: s.heard });
  }
  return { ok: true, sentences };
}

module.exports = {
  MAX_OVERRUN_MS,
  MAX_SENTENCE_CHARS,
  TRANSCRIPT_LANGUAGES,
  VENDOR_LANGUAGE,
  applyCorrection,
  isTranscriptLanguage,
  judgeSentences,
  latinOf,
  sentencesFrom,
  wordsBySentence,
};
