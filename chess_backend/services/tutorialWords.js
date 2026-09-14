// tutorialWords.js — the words of a tutorial made from a game: the request the
// app sends, the prompt this server writes from it, and the shape of the answer.
//
// docs/PLAN-SKELET.md, phase 3. **The client never sends a prompt.** A route
// that forwarded one would be this server's model key as an open proxy for
// anything. The app sends the skeleton as data — moments, their labels, the
// moves, the correct answers, the slot ids and their fact texts — and the
// prompt is written here from `prompts/tutorial_words.txt`, which is the one
// copy of the template: the harness reads the same file.
//
// **What a modified client can still do** is put words into the fact texts it
// sends. That is bounded, not prevented: every field has a length cap, the
// counts are capped, the answer must be the schema, the route is behind an
// entitlement and a monthly quota, and the model's ceiling is fixed here.
//
// **This checks shape; the app checks truth.** A slot that claims a fork the
// facts do not name is found by the app's `claimsFor`, beside the facts it
// judges against, and reported in the studio. Here an answer is refused only
// when it is not the schema: moments not offered, slots not offered, too long.
// `test/tutorial_words.test.js` holds `buildPrompt` to the harness's own prompt
// on every fixture game, byte for byte.

const fs = require('fs');
const path = require('path');

const TEMPLATE = fs.readFileSync(path.join(__dirname, 'prompts', 'tutorial_words.txt'), 'utf8');

/// The caps a request must keep. Each is several times what the ten fixture
/// games reach; the test says so for each one, so a cap cannot quietly become
/// narrower than a real game.
const CAPS = Object.freeze({
  gameChars: 20000,
  openingChars: 800,
  moments: 8,
  labelChars: 32,
  sanChars: 12,
  costTextChars: 120,
  boardChars: 1200,
  correct: 4,
  slotsPerMoment: 40,
  slotTextChars: 1500,
  promptChars: 120000,
  // The answer's: the prompt asks for a title under 60 characters and slots of
  // at most 140, and the harness trims tags to two. These refuse an answer
  // that is not the thing asked for, with room for a model that ran long.
  titleChars: 120,
  descriptionChars: 500,
  tags: 5,
  tagChars: 60,
  answerSlotChars: 600,
});

const MOMENT_ID = /^m\d{1,2}$/;
const SLOT_ID = /^m\d{1,2}\.[a-z]+(?:\.[a-z0-9]+)?$/;

function text(value, name, max, { optional = false } = {}) {
  if (optional && (value === null || value === undefined)) return null;
  if (typeof value !== 'string') throw new RangeError(`${name} must be text.`);
  if (value.length > max) throw new RangeError(`${name} is longer than ${max} characters.`);
  return value;
}

/// The request as the app sends it, checked; a RangeError names what is wrong.
function validateWordsRequest(body) {
  if (!body || typeof body !== 'object') throw new RangeError('The request is empty.');
  const game = text(body.game, 'game', CAPS.gameChars);
  if (!game.trim()) throw new RangeError('game is empty.');
  if (/^\s*\[/m.test(game)) {
    // Headers name the players — a trainer's students — and a model has no
    // use for them. Refused rather than stripped, so the app is the one place
    // that decides what leaves the device.
    throw new RangeError('game must be the moves only, without PGN headers.');
  }
  const opening = text(body.opening, 'opening', CAPS.openingChars, { optional: true });

  if (!Array.isArray(body.moments) || body.moments.length === 0) {
    throw new RangeError('moments must be a non-empty list.');
  }
  if (body.moments.length > CAPS.moments) {
    throw new RangeError(`At most ${CAPS.moments} moments can be offered.`);
  }
  const momentIds = new Set();
  const slotIds = new Set();
  const moments = body.moments.map((m, i) => {
    const at = `moments[${i}]`;
    if (!m || typeof m !== 'object') throw new RangeError(`${at} is not a moment.`);
    if (typeof m.id !== 'string' || !MOMENT_ID.test(m.id) || momentIds.has(m.id)) {
      throw new RangeError(`${at}.id must be a new id like m1.`);
    }
    momentIds.add(m.id);
    if (m.mover !== 'White' && m.mover !== 'Black') {
      throw new RangeError(`${at}.mover must be White or Black.`);
    }
    if (typeof m.asks !== 'boolean' || typeof m.left_book !== 'boolean') {
      throw new RangeError(`${at}.asks and left_book must be true or false.`);
    }
    // **Optional, unlike the two above, and that is deliberate.** The server is
    // deployed apart from the app, so an app already on a trainer's machine
    // sends a request with no `turning_point` at all; requiring it would answer
    // every one of them 400 the day this ships. Absent means false - there is
    // no third answer to have here, the way there is for a stored column.
    if (typeof m.turning_point !== 'undefined' && typeof m.turning_point !== 'boolean') {
      throw new RangeError(`${at}.turning_point must be true or false.`);
    }
    if (!Array.isArray(m.correct) || m.correct.length > CAPS.correct) {
      throw new RangeError(`${at}.correct must be a list of at most ${CAPS.correct} moves.`);
    }
    if (!Array.isArray(m.slots) || m.slots.length === 0 || m.slots.length > CAPS.slotsPerMoment) {
      throw new RangeError(`${at}.slots must hold 1 to ${CAPS.slotsPerMoment} slots.`);
    }
    const slots = m.slots.map((s, k) => {
      if (!s || typeof s.id !== 'string' || !SLOT_ID.test(s.id)
          || !s.id.startsWith(`${m.id}.`) || slotIds.has(s.id)) {
        throw new RangeError(`${at}.slots[${k}].id must be a new slot of ${m.id}.`);
      }
      slotIds.add(s.id);
      return { id: s.id, text: text(s.text, `${at}.slots[${k}].text`, CAPS.slotTextChars) };
    });
    return {
      id: m.id,
      label: text(m.label, `${at}.label`, CAPS.labelChars),
      mover: m.mover,
      played: text(m.played, `${at}.played`, CAPS.labelChars),
      cost_text: text(m.cost_text, `${at}.cost_text`, CAPS.costTextChars),
      best: text(m.best, `${at}.best`, CAPS.sanChars),
      asks: m.asks,
      correct: m.correct.map((c, k) => text(c, `${at}.correct[${k}]`, CAPS.sanChars)),
      left_book: m.left_book,
      turning_point: m.turning_point === true,
      board: text(m.board, `${at}.board`, CAPS.boardChars, { optional: true }),
      slots,
    };
  });
  return { game, opening, moments };
}

/// Python's `str.format` for the names the template uses: `{{` and `}}` are
/// literal braces, and a name the template asks for must be given.
function formatTemplate(template, values) {
  return template.replace(/\{\{|\}\}|\{(\w+)\}/g, (match, name) => {
    if (match === '{{') return '{';
    if (match === '}}') return '}';
    if (!Object.prototype.hasOwnProperty.call(values, name)) {
      throw new Error(`The template names {${name}}, which is not given.`);
    }
    return values[name];
  });
}

/// The prompt, from a checked request: `prompt_from_request` in
/// tools/game_annotate/skeleton.py, line for line.
function buildPrompt(request) {
  const blocks = request.moments.map((m) => {
    let head = `### ${m.id} - at ${m.label}, ${m.mover} to move\n`
      + `In the game ${m.played} was played and it ${m.cost_text}; `
      + `the best move was ${m.best}. `
      + (m.asks
        ? `There is a question here; correct answers: ${m.correct.join(', ')}.`
        : 'No question here: too many moves are about as good.');
    if (m.turning_point) head += '\nThis is the moment the game turned on.';
    if (m.left_book) head += '\nThis is the move that left the masters database.';
    if (m.board) head += `\nOn the board: ${m.board}`;
    const lines = [head, '', 'Slots, in the order the student meets them:'];
    for (const slot of m.slots) lines.push(`- \`${slot.id}\`: ${slot.text}`);
    return lines.join('\n');
  });
  const prompt = formatTemplate(TEMPLATE, {
    game: request.game,
    opening: request.opening ? `${request.opening}\n\n` : '',
    moments: blocks.join('\n\n'),
  });
  if (prompt.length > CAPS.promptChars) {
    throw new RangeError('The skeleton is too large to write words for.');
  }
  return prompt;
}

/// The JSON object out of a model's reply: the reply itself when it is one,
/// else a fenced block, else the text between the first `{` and the last `}` —
/// `rescue_json` in tools/game_annotate/run_arm.py.
function rescueJson(reply) {
  const body = String(reply || '');
  if (body.trim().startsWith('{')) return body;
  const fence = body.match(/```(?:json)?\s*\n(\{[\s\S]*?\})\s*\n```/);
  if (fence) return fence[1];
  const start = body.indexOf('{');
  const end = body.lastIndexOf('}');
  if (start >= 0 && end > start) {
    const candidate = body.slice(start, end + 1);
    try {
      JSON.parse(candidate);
      return candidate;
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Whether [reply] is the schema asked for, against the moments offered.
/// Returns the answer as it came (the app assembles and judges it) or the
/// reasons it is not one.
function checkAnswer(reply, request) {
  const json = rescueJson(reply);
  if (json === null) return { ok: false, problems: ['the answer is not JSON'] };
  let answer;
  try {
    answer = JSON.parse(json);
  } catch (_) {
    return { ok: false, problems: ['the answer is not JSON'] };
  }
  if (!answer || typeof answer !== 'object' || Array.isArray(answer)) {
    return { ok: false, problems: ['the answer is not a JSON object'] };
  }

  const problems = [];
  const offered = new Map(request.moments.map((m) => [m.id, new Set(m.slots.map((s) => s.id))]));
  const isText = (v, max) => typeof v === 'string' && v.trim().length > 0 && v.length <= max;

  if (!isText(answer.title, CAPS.titleChars)) problems.push('the title is missing or too long');
  if (answer.description !== undefined && !(typeof answer.description === 'string'
      && answer.description.length <= CAPS.descriptionChars)) {
    problems.push('the description is too long');
  }
  if (answer.tags !== undefined && !(Array.isArray(answer.tags) && answer.tags.length <= CAPS.tags
      && answer.tags.every((t) => isText(t, CAPS.tagChars)))) {
    problems.push('the tags are not a short list of short words');
  }

  const chosen = Array.isArray(answer.chosen) ? answer.chosen : null;
  if (!chosen) {
    problems.push('no moments were chosen');
  } else {
    for (const c of chosen) {
      if (!offered.has(c)) problems.push(`chose ${JSON.stringify(c)}, which was not offered`);
    }
    if (new Set(chosen).size !== chosen.length) problems.push('a moment was chosen twice');
    if (chosen.length < 2 || chosen.length > 3) {
      problems.push(`chose ${chosen.length} moments, not two or three`);
    }
  }

  const slots = answer.slots;
  if (!slots || typeof slots !== 'object' || Array.isArray(slots)) {
    problems.push('the slots are not an object');
  } else {
    const allSlots = new Set([].concat(...[...offered.values()].map((s) => [...s])));
    for (const [id, value] of Object.entries(slots)) {
      if (!allSlots.has(id)) {
        problems.push(`wrote slot ${JSON.stringify(id)}, which was not offered`);
      } else if (typeof value !== 'string' || value.length > CAPS.answerSlotChars) {
        problems.push(`slot ${id} is not text of at most ${CAPS.answerSlotChars} characters`);
      }
    }
  }

  return problems.length ? { ok: false, problems } : { ok: true, answer };
}

module.exports = {
  CAPS,
  TEMPLATE,
  validateWordsRequest,
  formatTemplate,
  buildPrompt,
  rescueJson,
  checkAnswer,
};
