// tutorialTranslation.js — a tutorial's words in another language, and the
// proof that nothing else changed. Phase 9 of docs/PLAN-PRIPREMA.md.
//
// The same method as the batch tool (tools/tutorial_translate/translate.py),
// whose rules this ports and whose prompt it reads
// (prompts/tutorial_translate.md):
//
//   * **The model never sees a move.** Only prose leaves the tutorial — the
//     title, the description, each part's title unless the app generated it,
//     and the words inside each `{ }` comment with its `[%…]` commands taken
//     out. A comment is found by its braces alone, which a PGN comment cannot
//     contain: this is not a PGN reader, and the server does not grow one
//     (rule 13 of CLAUDE.md).
//   * **Every translated string is judged** before anything is written: every
//     id once and none invented, the chess notation of the source token for
//     token, no brace or `[%` in a comment, no Cyrillic in a Latin-script
//     language. The judge and the tool's are held to one fixture,
//     test/fixtures/translation_cases.json.
//   * **After writing, it is proved**: every part's `pgn` with its comments
//     emptied is byte for byte its source's, and so is every command and every
//     field that is not prose.

const fs = require('fs');
const path = require('path');

const PROMPT_FILE = path.join(__dirname, 'prompts', 'tutorial_translate.md');

/// The language each code is asked for in, in words — what the prompt's
/// `{language}` is filled with.
const LANGUAGE_NAMES = Object.freeze({
  en: 'English',
  'sr-Latn': 'Serbian (Latin script)',
  'sr-Cyrl': 'Serbian (Cyrillic script)',
  de: 'German',
  es: 'Spanish',
  it: 'Italian',
  fr: 'French',
});

/// A part title the app generated — „Part 3" — is not prose. The app's
/// `isGeneratedSectionTitle` and the tool's GENERATED_PART_TITLE.
const GENERATED_PART_TITLE = /^(Part|Deo|Primer)\s+\d+$/;

const COMMENT = /\{([^}]*)\}/g;
const COMMAND = /\[%[^\]]*\]/g;

// The notation a translation must keep — the tool's SAN and MOVE_NUMBER.
// Python's `\w` is Unicode, so „a word character" is a letter, a digit or `_`
// in any script here too; with ASCII `\w` a Serbian „č" beside a square would
// let the square match on one end and not the other.
const W = '[\\p{L}\\p{N}_]';
const SAN = new RegExp(
  `(?<!${W})(?:O-O-O|O-O|0-0-0|0-0`
  + '|[KQRBN][a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?[+#]?'
  + '|[a-h]x[a-h][1-8](?:=[QRBN])?[+#]?'
  + `|[a-h][1-8](?:=[QRBN])?[+#]?)(?!${W})`,
  'gu',
);
const MOVE_NUMBER = new RegExp(
  `(?<![\\p{L}\\p{N}_.])\\p{Nd}{1,3}\\.(?:\\.\\.)?(?=\\s*(?:O-O|0-0|[KQRBN]?[a-h]?x?[a-h][1-8]))`,
  'gu',
);
const CYRILLIC = /[Ѐ-ӿ]/;
const COMMENT_KEY = /\.c\d+$/;

/// Items per request, in characters of source text — the tool's number.
const CHUNK_CHARS = 12000;

function notation(text) {
  return [...(text.match(SAN) || []), ...(text.match(MOVE_NUMBER) || [])].sort();
}

function proseOf(commentBody) {
  return commentBody.replace(COMMAND, ' ').split(/\s+/).filter(Boolean).join(' ');
}

/// Every piece of prose in a tutorial, keyed by where it lives:
/// `title`, `description`, `p<n>.title`, `p<n>.c<m>` (n and m from 1).
function extractItems({ title, description, steps }) {
  const out = {};
  const put = (key, value) => {
    if (typeof value === 'string' && value.trim()) out[key] = value;
  };
  put('title', title);
  put('description', description);
  (steps || []).forEach((step, index) => {
    const n = index + 1;
    const partTitle = step && step.title;
    if (!(typeof partTitle === 'string' && GENERATED_PART_TITLE.test(partTitle.trim()))) {
      put(`p${n}.title`, partTitle);
    }
    let m = 0;
    for (const match of String((step && step.pgn) || '').matchAll(COMMENT)) {
      m += 1;
      put(`p${n}.c${m}`, proseOf(match[1]));
    }
  });
  return out;
}

function countOf(list) {
  const counts = new Map();
  for (const x of list) counts.set(x, (counts.get(x) || 0) + 1);
  return counts;
}

function difference(a, b) {
  const out = [];
  for (const [x, n] of a) {
    const left = n - (b.get(x) || 0);
    for (let i = 0; i < left; i += 1) out.push(x);
  }
  return out.sort();
}

/// What is wrong with a translation: `{ id: { kind, reason } }`, empty when
/// nothing is. `kind` is one of missing, empty, notation, braces, cyrillic,
/// invented — the words the shared fixture names faults by.
function judgeTranslation(source, translated, { code }) {
  const faults = {};
  const latin = code !== 'sr-Cyrl';
  for (const [key, text] of Object.entries(source)) {
    if (!Object.prototype.hasOwnProperty.call(translated, key)) {
      faults[key] = { kind: 'missing', reason: 'missing from the translation' };
      continue;
    }
    const out = translated[key];
    if (typeof out !== 'string' || !out.trim()) {
      faults[key] = { kind: 'empty', reason: 'translated to nothing' };
      continue;
    }
    const want = countOf(notation(text));
    const got = countOf(notation(out));
    const lost = difference(want, got);
    const gained = difference(got, want);
    if (lost.length || gained.length) {
      faults[key] = {
        kind: 'notation',
        reason: `notation differs - lost ${lost.join(' ') || 'nothing'}, gained ${gained.join(' ') || 'nothing'}`,
      };
      continue;
    }
    if (COMMENT_KEY.test(key) && (out.includes('{') || out.includes('}') || out.includes('[%'))) {
      faults[key] = { kind: 'braces', reason: 'a comment must not contain {, } or [%' };
      continue;
    }
    if (latin && CYRILLIC.test(out)) {
      faults[key] = { kind: 'cyrillic', reason: 'Cyrillic letters in a Latin-script translation' };
    }
  }
  for (const key of Object.keys(translated)) {
    if (!Object.prototype.hasOwnProperty.call(source, key)) {
      faults[key] = { kind: 'invented', reason: 'not in the source - invented by the model' };
    }
  }
  return faults;
}

/// The tutorial with every string [translated] names replaced and the step ids
/// dropped — the server mints new ones for the copy, and a copy carrying the
/// source's ids would be two tutorials claiming the same parts.
function mergeTranslation({ title, description, steps }, translated) {
  const has = (key) => Object.prototype.hasOwnProperty.call(translated, key);
  const merged = {
    title: has('title') ? translated.title : title,
    description: has('description') ? translated.description : description,
    steps: (steps || []).map((step, index) => {
      const n = index + 1;
      const { id: _dropped, ...rest } = step || {};
      if (has(`p${n}.title`)) rest.title = translated[`p${n}.title`];
      if (typeof rest.pgn === 'string') {
        let m = 0;
        rest.pgn = rest.pgn.replace(COMMENT, (whole, body) => {
          m += 1;
          const key = `p${n}.c${m}`;
          if (!has(key)) return whole;
          const commands = body.match(COMMAND) || [];
          // Commands stay on the side of the words they were on.
          return body.trim().startsWith('[%')
            ? `{ ${[...commands, translated[key]].join(' ')} }`
            : `{ ${[translated[key], ...commands].join(' ')} }`;
        });
      }
      return rest;
    }),
  };
  return merged;
}

/// Throws when anything but prose differs between a tutorial's steps and its
/// translation's. A failure here is a fault of this file, never of a
/// translation.
function proveUntouched(sourceSteps, mergedSteps) {
  const a = sourceSteps || [];
  const b = mergedSteps || [];
  if (a.length !== b.length) throw new Error('the number of parts changed');
  const stripped = (pgn) => String(pgn || '').replace(COMMENT, '{}');
  const commands = (pgn) => [...String(pgn || '').matchAll(COMMENT)]
    .map((match) => (match[1].match(COMMAND) || []).join('|'));
  a.forEach((s, i) => {
    const n = b[i];
    for (const field of ['fen', 'kind', 'blackOrientation']) {
      if (JSON.stringify(s[field]) !== JSON.stringify(n[field])) {
        throw new Error(`part ${i + 1}: ${field} changed`);
      }
    }
    if (stripped(s.pgn) !== stripped(n.pgn)) {
      throw new Error(`part ${i + 1}: the pgn changed outside its comments`);
    }
    if (JSON.stringify(commands(s.pgn)) !== JSON.stringify(commands(n.pgn))) {
      throw new Error(`part ${i + 1}: an arrow or a coloured square changed`);
    }
  });
}

/// [items] cut into requests of at most CHUNK_CHARS characters of source.
function chunksOf(items) {
  const out = [];
  let batch = {};
  let size = 0;
  for (const [key, text] of Object.entries(items)) {
    if (Object.keys(batch).length && size + text.length > CHUNK_CHARS) {
      out.push(batch);
      batch = {};
      size = 0;
    }
    batch[key] = text;
    size += text.length;
  }
  if (Object.keys(batch).length) out.push(batch);
  return out;
}

let promptTemplate = null;

/// The prompt for [items] in [code]'s language, and — for a second attempt —
/// the reasons the first was refused. Read from the file the tool reads.
function buildTranslationPrompt(items, code, note = null) {
  if (promptTemplate === null) promptTemplate = fs.readFileSync(PROMPT_FILE, 'utf8');
  let prompt = promptTemplate.split('{language}').join(LANGUAGE_NAMES[code]);
  if (note) prompt += `\n\n## A correction\n\n${note}`;
  prompt += `\n\n## Items\n\n${JSON.stringify(
    Object.entries(items).map(([id, text]) => ({ id, text })), null, 1)}`;
  return prompt;
}

/// The model's answer as `{ id: text }`, or null when it is not the shape
/// asked for. An id given twice is not a shape the judge can trust.
function readTranslationAnswer(content) {
  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (_) {
    return null;
  }
  const items = parsed && Array.isArray(parsed.items) ? parsed.items : null;
  if (!items) return null;
  const out = {};
  for (const entry of items) {
    if (!entry || typeof entry.id !== 'string' || typeof entry.text !== 'string') return null;
    if (Object.prototype.hasOwnProperty.call(out, entry.id)) return null;
    out[entry.id] = entry.text;
  }
  return out;
}

/// [tutorial] (`{ title, description, steps }`) translated into [code], judged
/// and proved — the one home of the steps both `POST /lessons/:id/translate`
/// and `POST /lessons/from-game/translate` take.
///
/// Every piece of prose is asked for by chunk; what the judge refused is asked
/// for once more, with the reasons. An id the model invented stays in the
/// answer and refuses it: a model that makes up an item is not trusted with the
/// ones it did not make up, and with nothing else wrong there is nothing to ask
/// again. [onReply] is told every reply and its attempt, before it is read — a
/// refused attempt is billed as an accepted one.
///
/// `{ ok: true, merged }`, the tutorial with its words replaced and nothing
/// else changed, or `{ ok: false, faults }`. Throws the provider's
/// `LlmUnavailable`, and an Error when the merge changed anything but words —
/// a fault of this file, never of a translation.
async function translateTutorial({
  provider, tutorial, code, onReply = async () => {},
}) {
  const items = extractItems(tutorial);

  /// One request per chunk of [wanted]; what came back, by id.
  async function ask(wanted, note, attempt) {
    const answered = {};
    for (const chunk of chunksOf(wanted)) {
      const reply = await provider.complete(buildTranslationPrompt(chunk, code, note));
      await onReply(reply, { attempt, items: Object.keys(chunk).length });
      // A reply that is not the shape asked for answers nothing; the judge
      // then reads every item of the chunk as missing, and asks again.
      Object.assign(answered, readTranslationAnswer(reply.content) || {});
    }
    return answered;
  }

  let translated = await ask(items, null, 1);
  let faults = judgeTranslation(items, translated, { code });
  const retry = Object.fromEntries(
    Object.keys(faults).filter((key) => key in items).map((key) => [key, items[key]]),
  );
  if (Object.keys(retry).length) {
    const note = 'Your earlier translation of the items below was rejected. '
      + 'Translate them again and follow every rule above.\n\n'
      + Object.keys(retry).map((key) => `- ${key}: ${faults[key].reason}`).join('\n');
    translated = { ...translated, ...(await ask(retry, note, 2)) };
    faults = judgeTranslation(items, translated, { code });
  }
  if (Object.keys(faults).length) return { ok: false, faults };

  const merged = mergeTranslation(tutorial, translated);
  proveUntouched(tutorial.steps, merged.steps);
  return { ok: true, merged };
}

/// The caps of a tutorial sent to be translated in the body. The twenty
/// tutorials measured from games held at most 5,048 characters of prose and
/// 12 parts (docs/PLAN-JEZIK-STUDIJE.md, §8a); these leave room without
/// leaving the door open.
const BODY_CAPS = Object.freeze({
  steps: 80,
  titleChars: 200,
  descriptionChars: 4000,
  fenChars: 100,
  pgnChars: 20000,
  proseChars: 40000,
});

function capped(value, name, max, { nullable = false } = {}) {
  if (nullable && (value === null || value === undefined)) return value;
  if (typeof value !== 'string') throw new RangeError(`${name} must be text.`);
  if (value.length > max) throw new RangeError(`${name} is longer than ${max} characters.`);
  return value;
}

/// A tutorial that is not saved, as `POST /lessons/from-game/translate`
/// receives it, and the language it is to be in: `{ code, tutorial }`, or a
/// RangeError that names what is wrong. English is not a translation — the
/// words were written in it. Every field of a part that is not prose is kept
/// as it came, and the merge's proof holds it there.
function readTutorialToTranslate(body) {
  if (!body || typeof body !== 'object') throw new RangeError('The request is empty.');
  const code = body.language;
  if (typeof code !== 'string' || !LANGUAGE_NAMES[code] || code === 'en') {
    throw new RangeError(`language must be one of ${Object.keys(LANGUAGE_NAMES)
      .filter((c) => c !== 'en').join(', ')}.`);
  }
  const t = body.tutorial;
  if (!t || typeof t !== 'object') throw new RangeError('tutorial must be a tutorial.');
  if (!Array.isArray(t.steps) || t.steps.length === 0 || t.steps.length > BODY_CAPS.steps) {
    throw new RangeError(`tutorial.steps must hold 1 to ${BODY_CAPS.steps} parts.`);
  }
  const steps = t.steps.map((step, i) => {
    const at = `tutorial.steps[${i}]`;
    if (!step || typeof step !== 'object' || Array.isArray(step)) {
      throw new RangeError(`${at} is not a part.`);
    }
    capped(step.fen, `${at}.fen`, BODY_CAPS.fenChars);
    capped(step.pgn, `${at}.pgn`, BODY_CAPS.pgnChars);
    capped(step.title, `${at}.title`, BODY_CAPS.titleChars, { nullable: true });
    return step;
  });
  const tutorial = {
    title: capped(t.title, 'tutorial.title', BODY_CAPS.titleChars, { nullable: true }),
    description: capped(t.description, 'tutorial.description', BODY_CAPS.descriptionChars,
      { nullable: true }),
    steps,
  };
  const prose = Object.values(extractItems(tutorial)).reduce((n, s) => n + s.length, 0);
  if (prose === 0) throw new RangeError('The tutorial has no words to translate.');
  if (prose > BODY_CAPS.proseChars) {
    throw new RangeError(`The tutorial has more than ${BODY_CAPS.proseChars} characters of words.`);
  }
  return { code, tutorial };
}

module.exports = {
  translateTutorial,
  readTutorialToTranslate,
  BODY_CAPS,
  LANGUAGE_NAMES,
  CHUNK_CHARS,
  notation,
  extractItems,
  judgeTranslation,
  mergeTranslation,
  proveUntouched,
  chunksOf,
  buildTranslationPrompt,
  readTranslationAnswer,
};
