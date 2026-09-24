// reviewWords.js — the words of a whole-game review: the request the app sends,
// the prompt this server writes from it, and the shape of the answer.
//
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, §3a and phase 3. The tutorial's path
// (`tutorialWords.js`) and its rules, for a different reader: **the client never
// sends a prompt** — it sends the moments as data (the game's move, the lines
// the engine gave, the facts in words) and the prompt is written here from
// `prompts/review_words.txt`. **This checks shape; the app checks truth**: a
// comment that names a move outside its moment's lines is found by the app's
// claim check, in its third mode, beside the facts it judges against.
//
// A moment is a mistake the review marked, or a move where only one move held
// and the player found it. A mistake has three slots — the game's move, the
// better line, the refutation — and a found move one.

const fs = require('fs');
const path = require('path');

const { formatTemplate, rescueJson } = require('./tutorialWords');

const TEMPLATE = fs.readFileSync(path.join(__dirname, 'prompts', 'review_words.txt'), 'utf8');

/// The caps a request must keep. **10 moments** is the owner's choice of
/// 25.9.2026 (the mistakes first, then the only moves found); the line lengths
/// are the reveal's twelve plies with room; the rest follow the tutorial's.
const CAPS = Object.freeze({
  gameChars: 20000,
  openingChars: 800,
  moments: 10,
  labelChars: 32,
  sanChars: 12,
  linePlies: 16,
  factsChars: 1500,
  slotTextChars: 1500,
  promptChars: 80000,
  // The answer's: the prompt asks for at most 200 characters a slot.
  answerSlotChars: 400,
});

const MOMENT_ID = /^m\d{1,2}$/;
const KINDS = Object.freeze({
  mistake: ['played', 'better', 'refutation'],
  found: ['played'],
});

function text(value, name, max, { optional = false } = {}) {
  if (optional && (value === null || value === undefined)) return null;
  if (typeof value !== 'string') throw new RangeError(`${name} must be text.`);
  if (value.length > max) throw new RangeError(`${name} is longer than ${max} characters.`);
  return value;
}

function line(value, name, { optional = false } = {}) {
  if (optional && (value === null || value === undefined)) return [];
  if (!Array.isArray(value) || value.length > CAPS.linePlies) {
    throw new RangeError(`${name} must be a list of at most ${CAPS.linePlies} moves.`);
  }
  return value.map((san, k) => text(san, `${name}[${k}]`, CAPS.sanChars));
}

/// The request as the app sends it, checked; a RangeError names what is wrong.
function validateReviewWordsRequest(body) {
  if (!body || typeof body !== 'object') throw new RangeError('The request is empty.');
  const game = text(body.game, 'game', CAPS.gameChars);
  if (!game.trim()) throw new RangeError('game is empty.');
  if (/^\s*\[/m.test(game)) {
    // Headers name the players; the app is the one place that decides what
    // leaves the device (as for the tutorial).
    throw new RangeError('game must be the moves only, without PGN headers.');
  }
  const opening = text(body.opening, 'opening', CAPS.openingChars, { optional: true });

  if (!Array.isArray(body.moments) || body.moments.length === 0) {
    throw new RangeError('moments must be a non-empty list.');
  }
  if (body.moments.length > CAPS.moments) {
    throw new RangeError(`At most ${CAPS.moments} moments can be offered.`);
  }
  const ids = new Set();
  const moments = body.moments.map((m, i) => {
    const at = `moments[${i}]`;
    if (!m || typeof m !== 'object') throw new RangeError(`${at} is not a moment.`);
    if (typeof m.id !== 'string' || !MOMENT_ID.test(m.id) || ids.has(m.id)) {
      throw new RangeError(`${at}.id must be a new id like m1.`);
    }
    ids.add(m.id);
    const allowed = KINDS[m.kind];
    if (!allowed) throw new RangeError(`${at}.kind must be "mistake" or "found".`);
    if (m.mover !== 'White' && m.mover !== 'Black') {
      throw new RangeError(`${at}.mover must be White or Black.`);
    }
    const lines = m.lines && typeof m.lines === 'object' && !Array.isArray(m.lines) ? m.lines : {};
    const better = line(lines.better, `${at}.lines.better`);
    if (better.length === 0) throw new RangeError(`${at}.lines.better is empty.`);
    const refutation = line(lines.refutation, `${at}.lines.refutation`, { optional: true });
    if (m.kind === 'found' && refutation.length > 0) {
      throw new RangeError(`${at} is a move the player found; it has no refutation.`);
    }
    if (!Array.isArray(m.slots) || m.slots.length === 0 || m.slots.length > allowed.length) {
      throw new RangeError(`${at}.slots must hold 1 to ${allowed.length} slots.`);
    }
    const seen = new Set();
    const slots = m.slots.map((s, k) => {
      const name = s && typeof s.id === 'string' && s.id.startsWith(`${m.id}.`)
        ? s.id.slice(m.id.length + 1) : null;
      if (!name || !allowed.includes(name) || seen.has(name)) {
        throw new RangeError(`${at}.slots[${k}].id must be one of ${m.id}.${allowed.join(`, ${m.id}.`)}, once.`);
      }
      seen.add(name);
      return { id: s.id, text: text(s.text, `${at}.slots[${k}].text`, CAPS.slotTextChars) };
    });
    return {
      id: m.id,
      kind: m.kind,
      label: text(m.label, `${at}.label`, CAPS.labelChars),
      mover: m.mover,
      played: text(m.played, `${at}.played`, CAPS.sanChars),
      best: text(m.best, `${at}.best`, CAPS.sanChars),
      lines: { better, refutation, second: line(lines.second, `${at}.lines.second`, { optional: true }) },
      facts: text(m.facts, `${at}.facts`, CAPS.factsChars, { optional: true }),
      slots,
    };
  });
  return { game, opening, moments };
}

/// The prompt, from a checked request.
function buildReviewPrompt(request) {
  const blocks = request.moments.map((m) => {
    const head = m.kind === 'mistake'
      ? `### ${m.id} — at ${m.label}, ${m.mover} to move: a mistake\n`
        + `In the game ${m.played} was played; the engine's best was ${m.best}.`
      : `### ${m.id} — at ${m.label}, ${m.mover} to move: the only move, found\n`
        + `Only ${m.best} held here, and the game played it.`;
    const lines = [head];
    lines.push(`Better line: ${m.lines.better.join(' ')}`);
    if (m.lines.refutation.length) lines.push(`Refutation after ${m.played}: ${m.lines.refutation.join(' ')}`);
    if (m.lines.second.length) lines.push(`Second line: ${m.lines.second.join(' ')}`);
    if (m.facts) lines.push(`Facts: ${m.facts}`);
    lines.push('', 'Slots:');
    for (const slot of m.slots) lines.push(`- \`${slot.id}\`: ${slot.text}`);
    return lines.join('\n');
  });
  const prompt = formatTemplate(TEMPLATE, {
    game: request.game,
    opening: request.opening ? `${request.opening}\n\n` : '',
    moments: blocks.join('\n\n'),
  });
  if (prompt.length > CAPS.promptChars) {
    throw new RangeError('The review is too large to write words for.');
  }
  return prompt;
}

/// Whether [reply] is the shape asked for, against the slots offered. Returns
/// the slots as they came (the app judges their truth) or the reasons they
/// are not the shape. A slot the model left out is allowed — the prompt says
/// so — but an answer with none is not an answer.
function checkReviewAnswer(reply, request) {
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
  const offered = new Set([].concat(...request.moments.map((m) => m.slots.map((s) => s.id))));
  const problems = [];
  const kept = {};
  for (const [id, value] of Object.entries(slots)) {
    if (!offered.has(id)) {
      problems.push(`wrote slot ${JSON.stringify(id)}, which was not offered`);
    } else if (typeof value !== 'string' || value.length > CAPS.answerSlotChars) {
      problems.push(`slot ${id} is not text of at most ${CAPS.answerSlotChars} characters`);
    } else if (value.trim()) {
      kept[id] = value.trim();
    }
  }
  if (!problems.length && Object.keys(kept).length === 0) problems.push('no slot was written');
  return problems.length ? { ok: false, problems } : { ok: true, slots: kept };
}

module.exports = {
  CAPS,
  TEMPLATE,
  validateReviewWordsRequest,
  buildReviewPrompt,
  checkReviewAnswer,
};
