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

module.exports = {
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
