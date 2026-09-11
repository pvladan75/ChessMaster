// tutorial_language.test.js — a tutorial says which language it is written in.
// Phase 1 of docs/PLAN-JEZIK-GLASA.md.
//
// The column is small and the rules are three: absent leaves it alone, null
// means „not said", and a code outside the seven is refused. The test that
// matters most is the last one in this file — the student's own route — because
// a feature that reaches the trainer's list and not the child's screen is the
// shape this repository keeps meeting: every layer right, and the reader it was
// for never sees it.
//
// Routes are driven mounted, with `pool.query` faked, for the reason
// `lesson_update_keeps_labels.test.js` gives: the helper being right and the
// route asking it are two different things.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');
const { getAssignmentDetail } = require('../services/assignmentService');
const { TUTORIAL_LANGUAGES, readTutorialLanguage } = require('../services/tutorialLanguage');
const { VOCABULARIES, languageOf } = require('../services/spokenMoves');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

function handler(method, path) {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method]
  );
  assert.ok(layer, `${method.toUpperCase()} /lessons${path} must be mounted`);
  const handlers = layer.route.stack.map((s) => s.handle);
  return handlers[handlers.length - 1];
}

/// Runs a mounted handler against a fake pool. [answer] decides what each
/// query returns, by its text.
async function drive(method, path, req, answer) {
  const queries = [];
  const original = db.pool.query;
  db.pool.query = async (text, params) => {
    queries.push({ text, params });
    return answer(text, params);
  };
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  try {
    await handler(method, path)({ params: {}, query: {}, user: { id: 1 }, ...req }, res);
  } finally {
    db.pool.query = original;
  }
  return { res, queries };
}

/// The value one statement writes to [column], found by name rather than by
/// position — for an INSERT through its column list, for an UPDATE through
/// `column = $n`.
function writtenTo(query, column) {
  const insert = query.text.match(/INSERT INTO saved_lessons \(([^)]*)\)/);
  if (insert) {
    const columns = insert[1].split(',').map((c) => c.trim());
    const at = columns.indexOf(column);
    return at < 0 ? undefined : query.params[at - 1]; // user_id and trainer_id share $1
  }
  const marker = `${column} = $`;
  const at = query.text.indexOf(marker);
  if (at < 0) return undefined;
  const digits = query.text.slice(at + marker.length).match(/^[0-9]+/);
  return query.params[Number(digits[0]) - 1];
}

const STEPS = [{ fen: FEN, title: 'Part 1' }];
const insertOf = (queries) => queries.find((q) => /INSERT INTO saved_lessons/.test(q.text));
const updateOf = (queries) => queries.find((q) => /UPDATE saved_lessons/.test(q.text));

// --- The seven codes ----------------------------------------------------------

test('the seven codes are exactly the seven vocabularies the film can speak', () => {
  // The owner's rule: a language whose moves would be read out in English words
  // is not offered. `languageOf` falls back to English for anything it does not
  // know, so a code that reached a vocabulary only through that fallback would
  // pass a weaker test and be read wrongly.
  const reached = TUTORIAL_LANGUAGES.map(languageOf);
  assert.equal(new Set(reached).size, TUTORIAL_LANGUAGES.length,
    'two codes landing on one vocabulary means one of them fell back');
  assert.deepEqual([...reached].sort(), Object.keys(VOCABULARIES).sort(),
    'and every vocabulary is reachable by a code');
});

test('a code is one of the seven, nothing, or refused', () => {
  assert.deepEqual(readTutorialLanguage(null), { ok: true, value: null });
  assert.deepEqual(readTutorialLanguage(''), { ok: true, value: null },
    'a cleared dropdown is „not said"');
  for (const code of TUTORIAL_LANGUAGES) {
    assert.deepEqual(readTutorialLanguage(code), { ok: true, value: code });
  }
  // `sr` alone is refused on purpose: it does not say which script, and the
  // two are read by different voices.
  for (const bad of ['sr', 'EN', 'sr-latn', 'pt', 'english', 5, {}, []]) {
    const read = readTutorialLanguage(bad);
    assert.equal(read.ok, false, `${JSON.stringify(bad)} must be refused`);
    assert.match(read.error, /sr-Latn/, 'and the refusal names what is allowed');
  }
});

// --- POST /lessons/save ------------------------------------------------------

const saved = (text) => (/INSERT INTO saved_lessons/.test(text)
  ? { rows: [{ id: 9 }], rowCount: 1 } : { rows: [], rowCount: 0 });

test('a new tutorial is stored with its language', async () => {
  const { res, queries } = await drive('post', '/save',
    { body: { title: 'Opozicija', positionList: STEPS, language: 'sr-Latn' } }, saved);
  assert.equal(res.statusCode, 201);
  assert.equal(writtenTo(insertOf(queries), 'language'), 'sr-Latn');
});

test('a new tutorial that says nothing is stored as not said', async () => {
  const { queries } = await drive('post', '/save',
    { body: { title: 'Opozicija', positionList: STEPS } }, saved);
  assert.equal(writtenTo(insertOf(queries), 'language'), null,
    'not said, and not quietly English');
});

test('a new tutorial in a language nobody can read is refused, and nothing is written', async () => {
  const { res, queries } = await drive('post', '/save',
    { body: { title: 'Opozicija', positionList: STEPS, language: 'pt' } }, saved);
  assert.equal(res.statusCode, 400);
  assert.equal(queries.length, 0);
});

// --- PUT /lessons/:id --------------------------------------------------------

const updated = (text) => (/SELECT position_list/.test(text)
  ? { rows: [{ position_list: [] }], rowCount: 1 } : { rows: [{ id: 7 }], rowCount: 1 });

test('a save that never mentions the language leaves it alone', async () => {
  // Exactly what `commitDraft` sends today, and what every client written
  // before this column sends for ever.
  const { queries } = await drive('put', '/:id',
    { params: { id: '7' }, body: { title: 'Opozicija', positionList: STEPS } }, updated);
  assert.doesNotMatch(updateOf(queries).text, /language/);
});

test('a save that names a language writes it, and an explicit null clears it', async () => {
  const set = await drive('put', '/:id',
    { params: { id: '7' }, body: { title: 'Opozicija', positionList: STEPS, language: 'de' } }, updated);
  assert.equal(writtenTo(updateOf(set.queries), 'language'), 'de');

  const cleared = await drive('put', '/:id',
    { params: { id: '7' }, body: { title: 'Opozicija', positionList: STEPS, language: null } }, updated);
  assert.match(updateOf(cleared.queries).text, /language = /,
    '„this tutorial no longer says" has to stay sayable');
  assert.equal(writtenTo(updateOf(cleared.queries), 'language'), null);
});

test('an edit to a language nobody can read is refused before anything is read', async () => {
  const { res, queries } = await drive('put', '/:id',
    { params: { id: '7' }, body: { title: 'Opozicija', positionList: STEPS, language: 'sr' } }, updated);
  assert.equal(res.statusCode, 400);
  assert.equal(queries.length, 0);
});

// --- POST /lessons/:id/clone --------------------------------------------------

function cloned(language) {
  return (text) => {
    if (/^\s*SELECT title/.test(text)) {
      // Only what was selected comes back — see `assignmentPool` below.
      const selected = /\blanguage\b/.test(text.split('FROM saved_lessons')[0]);
      return {
        rows: [{ title: 'Opozicija', description: null, tags: null, fen: FEN, pgn: null,
          position_list: [{ id: 'a3f9c1d2', fen: FEN, title: 'Part 1', kind: 'show' }],
          ...(selected ? { language } : {}) }],
        rowCount: 1,
      };
    }
    return { rows: [{ id: 99 }], rowCount: 1 };
  };
}

test('a new version keeps the language of the tutorial it was made from', async () => {
  const serbian = await drive('post', '/:id/clone', { params: { id: '7' } }, cloned('sr-Cyrl'));
  assert.equal(serbian.res.statusCode, 201);
  assert.equal(writtenTo(insertOf(serbian.queries), 'language'), 'sr-Cyrl');

  const unsaid = await drive('post', '/:id/clone', { params: { id: '7' } }, cloned(null));
  assert.equal(writtenTo(insertOf(unsaid.queries), 'language'), null);
});

// --- GET /lessons ------------------------------------------------------------

test('the trainer\'s list carries each tutorial\'s language', async () => {
  const { queries } = await drive('get', '/', {}, () => ({ rows: [], rowCount: 0 }));
  const list = queries.find((q) => /FROM saved_lessons/.test(q.text));
  assert.match(list.text.split('FROM saved_lessons')[0], /\blanguage\b/,
    'the column list is explicit, so a new column is absent until it is named');
});

// --- GET /assignments/:id, as the student ------------------------------------

/// A fake pool for `getAssignmentDetail`: one assignment, its items, its
/// tutorial.
function assignmentPool({ kind = 'lesson', language }) {
  const queries = [];
  return {
    queries,
    async query(text, params) {
      queries.push({ text, params });
      if (/FROM assignments a/.test(text)) {
        return {
          rows: [{ id: 5, kind, lesson_id: kind === 'lesson' ? 7 : null, trainer_id: 1, student_id: 2 }],
          rowCount: 1,
        };
      }
      if (/FROM assignment_items/.test(text)) {
        return { rows: [{ puzzle_id: null, position: 0 }], rowCount: 1 };
      }
      if (/FROM saved_lessons/.test(text)) {
        // **Only what was asked for comes back**, as from a real database. The
        // first version of this fake handed `language` over whatever the query
        // selected, and a mutation deleting the column from the SELECT survived
        // it — the one edit that would lose the language on the student's route
        // was the one edit this file could not see.
        const selected = /\blanguage\b/.test(text.split('FROM saved_lessons')[0]);
        return {
          rows: [{ title: 'Opozicija', fen: FEN, pgn: null,
            position_list: [{ id: 'a3f9c1d2', fen: FEN, title: 'Part 1', kind: 'show' }],
            ...(selected ? { language } : {}) }],
          rowCount: 1,
        };
      }
      return { rows: [], rowCount: 0 };
    },
  };
}

test('the student\'s own screen is told the language of the tutorial it opens', async () => {
  const pool = assignmentPool({ language: 'sr-Latn' });
  const detail = await getAssignmentDetail(pool, 5, 2); // user 2 is the student
  assert.equal(detail.lessonLanguage, 'sr-Latn');
  assert.ok(Array.isArray(detail.steps) && detail.steps.length === 1,
    'and still gets the steps it always got');
});

test('a tutorial that said nothing reaches the student as nothing', async () => {
  const detail = await getAssignmentDetail(assignmentPool({ language: null }), 5, 2);
  assert.equal(detail.lessonLanguage, null);
});

test('an assignment that is not a tutorial has no language', async () => {
  const detail = await getAssignmentDetail(assignmentPool({ kind: 'puzzles', language: 'de' }), 5, 2);
  assert.equal(detail.lessonLanguage, null);
});
