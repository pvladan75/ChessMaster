// studyWords.js — the words of a position study: the request the app sends,
// the prompt this server writes from it, and the shape of the answer.
//
// docs/PLAN-STUDIJA-POZICIJE.md, §3. The review's path (`reviewWords.js`) and
// its rules, for a position instead of a game: **the client never sends a
// prompt** — it sends items as data (the lines the engine gave, the facts in
// words) and the prompt is written here from `prompts/study_words.txt`.
// **This checks shape; the app checks truth**, beside the facts it judges
// against.
//
// An item is something the study has words to offer for: the position, a move
// of the main line, a trap beside it, an alternative, a tempting move, the
// outcome. **One move and one position are the same request with one item** —
// „Generate AI comment" and the repertoire's „AI on position" send exactly
// that, so every sentence a model writes about a board goes through this file.

const fs = require('fs');
const path = require('path');

const { formatTemplate, rescueJson } = require('./tutorialWords');

const TEMPLATE = fs.readFileSync(path.join(__dirname, 'prompts', 'study_words.txt'), 'utf8');

/// The caps a request must keep. A study offers at most: the position, eight
/// main-line moves, three traps, two alternatives, two tempting moves and the
/// outcome — 17 items; 20 leaves room without leaving the door open.
const CAPS = Object.freeze({
  positionChars: 400,
  items: 20,
  labelChars: 40,
  sanChars: 12,
  lines: 4,
  lineNameChars: 16,
  linePlies: 16,
  slots: 4,
  slotTextChars: 2000,
  promptChars: 60000,
  // The answer's: the prompt asks for at most 320 characters a slot.
  answerSlotChars: 640,
});

const ITEM_ID = /^(s|e|[mwat]\d{1,2})$/;
const LINE_NAME = /^[a-z]{1,16}$/;

/// The slots each kind of item may offer.
const KINDS = Object.freeze({
  position: ['position', 'threat'],
  move: ['move'],
  trap: ['capture', 'punish'],
  alternative: ['move'],
  tempting: ['move', 'reply', 'greedy', 'punish'],
  outcome: ['outcome'],
});

/// What each slot is for, as the prompt says it — only the slots a request
/// offers are described, because a model that reads of a slot writes it: the
/// first run of phase 0 described `s.threat` to a position with no threat,
/// and the model wrote one, twice.
const SLOTS = Object.freeze({
  'position.position': 'the comment on the position before any move: who stands '
    + 'how, and the one or two things about the position that explain it.',
  'position.threat': 'what the other side is threatening, and what it would cost.',
  'move.move': 'the comment on a move of the main line: what it is for — what it '
    + 'achieves, prepares or allows.',
  'alternative.move': 'the comment on a move as good as the best: how it differs '
    + 'from the best move in what it aims at.',
  'tempting.move': 'the comment on a move the eye goes to: why it attracts, and '
    + 'why it is not the move.',
  'tempting.reply': 'the comment on the move that answers a tempting move.',
  'tempting.greedy': 'the comment on a capture that is a trap: it wins material '
    + 'and loses the position. Say what it takes and that it must not be taken, '
    + 'so that the reader wants to see why.',
  'tempting.punish': 'the comment on the move that punishes the trap: how it works.',
  'trap.capture': 'the comment on a capture that is a trap, or a recapture that '
    + 'only looks automatic. Say what it takes and that it must not be taken, so '
    + 'that the reader wants to see why.',
  'trap.punish': 'the comment on the move that punishes the trap: how it works.',
  'outcome.outcome': 'the comment at the end of the main line: what has been '
    + 'achieved, and what kind of game it is from here.',
});

/// What each kind is called in the prompt.
const HEADS = Object.freeze({
  position: 'the position',
  move: 'a move of the main line',
  trap: 'a capture that is a trap',
  alternative: 'a move as good as the best',
  tempting: 'a tempting move',
  outcome: 'the end of the main line',
});

function text(value, name, max) {
  if (typeof value !== 'string') throw new RangeError(`${name} must be text.`);
  if (value.length > max) throw new RangeError(`${name} is longer than ${max} characters.`);
  return value;
}

function linesOf(value, at) {
  if (value === null || value === undefined) return {};
  if (typeof value !== 'object' || Array.isArray(value)) {
    throw new RangeError(`${at}.lines must be an object of named lines.`);
  }
  const names = Object.keys(value);
  if (names.length > CAPS.lines) {
    throw new RangeError(`${at}.lines holds more than ${CAPS.lines} lines.`);
  }
  const out = {};
  for (const name of names) {
    if (!LINE_NAME.test(name)) {
      throw new RangeError(`${at}.lines names a line ${JSON.stringify(name)}; a name is lowercase letters.`);
    }
    const line = value[name];
    if (!Array.isArray(line) || line.length > CAPS.linePlies) {
      throw new RangeError(`${at}.lines.${name} must be a list of at most ${CAPS.linePlies} moves.`);
    }
    out[name] = line.map((san, k) => text(san, `${at}.lines.${name}[${k}]`, CAPS.sanChars));
  }
  return out;
}

/// The request as the app sends it, checked; a RangeError names what is wrong.
function validateStudyWordsRequest(body) {
  if (!body || typeof body !== 'object') throw new RangeError('The request is empty.');
  const position = text(body.position, 'position', CAPS.positionChars);
  if (!position.trim()) throw new RangeError('position is empty.');
  if (body.side !== 'White' && body.side !== 'Black') {
    throw new RangeError('side must be White or Black.');
  }
  if (!Array.isArray(body.items) || body.items.length === 0) {
    throw new RangeError('items must be a non-empty list.');
  }
  if (body.items.length > CAPS.items) {
    throw new RangeError(`At most ${CAPS.items} items can be offered.`);
  }
  const ids = new Set();
  const items = body.items.map((item, i) => {
    const at = `items[${i}]`;
    if (!item || typeof item !== 'object') throw new RangeError(`${at} is not an item.`);
    if (typeof item.id !== 'string' || !ITEM_ID.test(item.id) || ids.has(item.id)) {
      throw new RangeError(`${at}.id must be a new id like s, m1, w1, a1, t1 or e.`);
    }
    ids.add(item.id);
    const allowed = KINDS[item.kind];
    if (!allowed) {
      throw new RangeError(`${at}.kind must be one of ${Object.keys(KINDS).join(', ')}.`);
    }
    if (item.mover !== 'White' && item.mover !== 'Black') {
      throw new RangeError(`${at}.mover must be White or Black.`);
    }
    if (!Array.isArray(item.slots) || item.slots.length === 0 || item.slots.length > CAPS.slots) {
      throw new RangeError(`${at}.slots must hold 1 to ${CAPS.slots} slots.`);
    }
    const seen = new Set();
    const slots = item.slots.map((s, k) => {
      const name = s && typeof s.id === 'string' && s.id.startsWith(`${item.id}.`)
        ? s.id.slice(item.id.length + 1) : null;
      if (!name || !allowed.includes(name) || seen.has(name)) {
        throw new RangeError(`${at}.slots[${k}].id must be one of ${item.id}.${allowed.join(`, ${item.id}.`)}, once.`);
      }
      seen.add(name);
      const facts = text(s.text, `${at}.slots[${k}].text`, CAPS.slotTextChars);
      if (!facts.trim()) throw new RangeError(`${at}.slots[${k}].text is empty.`);
      return { id: s.id, text: facts };
    });
    return {
      id: item.id,
      kind: item.kind,
      label: text(item.label, `${at}.label`, CAPS.labelChars),
      mover: item.mover,
      lines: linesOf(item.lines, at),
      slots,
    };
  });
  return { position, side: body.side, items };
}

/// The prompt, from a checked request.
function buildStudyPrompt(request) {
  const blocks = request.items.map((item) => {
    const out = [`### ${item.id} — ${HEADS[item.kind]}: ${item.label}`];
    for (const [name, line] of Object.entries(item.lines)) {
      if (line.length) out.push(`Line "${name}": ${line.join(' ')}`);
    }
    out.push('', 'Slots:');
    for (const slot of item.slots) out.push(`- \`${slot.id}\`: ${slot.text}`);
    return out.join('\n');
  });
  const described = new Map();
  const example = {};
  for (const item of request.items) {
    for (const slot of item.slots) {
      const name = slot.id.slice(item.id.length + 1);
      const pattern = item.kind === 'position' || item.kind === 'outcome'
        ? slot.id : `<id>.${name}`;
      described.set(`${item.kind}.${name}`,
        `- \`${pattern}\` — ${SLOTS[`${item.kind}.${name}`]}`);
      example[slot.id] = '...';
    }
  }
  const prompt = formatTemplate(TEMPLATE, {
    slot_kinds: [...described.values()].join('\n'),
    example: JSON.stringify({ slots: example }),
    side: request.side,
    position: request.position,
    items: blocks.join('\n\n'),
  });
  if (prompt.length > CAPS.promptChars) {
    throw new RangeError('The study is too large to write words for.');
  }
  return prompt;
}

/// Whether [reply] is the shape asked for, against the slots offered. Returns
/// the slots as they came (the app judges their truth) or the reasons they
/// are not the shape. A slot the model left out is allowed — the prompt says
/// so — but an answer with none is not an answer.
///
/// **A slot that was not offered is dropped and named, not a reason to ask
/// again**: nothing of it is kept, so nothing untrue can come of it, and a
/// second call costs the user as much as the first.
function checkStudyAnswer(reply, request) {
  const json = rescueJson(reply);
  if (json === null) return { ok: false, problems: ['the answer is not JSON'] };
  let answer;
  try {
    answer = JSON.parse(json);
  } catch (_) {
    return { ok: false, problems: ['the answer is not JSON'] };
  }
  const slots = answer && typeof answer === 'object' && !Array.isArray(answer) ? answer.slots : null;
  if (!slots || typeof slots !== 'object' || Array.isArray(slots)) {
    return { ok: false, problems: ['the slots are not an object'] };
  }
  const offered = new Set([].concat(...request.items.map((i) => i.slots.map((s) => s.id))));
  const problems = [];
  const kept = {};
  const dropped = [];
  for (const [id, value] of Object.entries(slots)) {
    if (!offered.has(id)) {
      dropped.push(String(id).slice(0, 40));
    } else if (typeof value !== 'string' || value.length > CAPS.answerSlotChars) {
      problems.push(`slot ${id} is not text of at most ${CAPS.answerSlotChars} characters`);
    } else if (value.trim()) {
      kept[id] = value.trim();
    }
  }
  if (!problems.length && Object.keys(kept).length === 0) problems.push('no slot was written');
  return problems.length
    ? { ok: false, problems }
    : { ok: true, slots: kept, dropped };
}

module.exports = {
  CAPS,
  KINDS,
  SLOTS,
  TEMPLATE,
  validateStudyWordsRequest,
  buildStudyPrompt,
  checkStudyAnswer,
};
