// homework_template.test.js
//
// Phase 3 of docs/PLAN-DOMACI-ZADATAK.md: the homework a trainer writes and
// keeps. Run against a real PostgreSQL, because everything that matters here
// is a constraint, a transaction or a WHERE clause — an `ON CONFLICT` and a
// „delete what was not sent" cannot be seen by a stub pool.
//
// The gate of the phase: **an item keeps its key across a reorder.** Positions
// are rewritten, keys are not. It is the third time this codebase pays
// attention to it (`assignment_items.step_key`, `review_items.step_key`), and
// the first time by design rather than by migration.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const realtime = require('../services/realtime');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

realtime.init({ to: () => ({ emit: () => {} }) });

const skip = skipUnlessDatabase();

describe('the homework a trainer writes', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let template;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    template = require('../services/homeworkTemplate');
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function trainer() {
    minted++;
    const tag = `${process.pid}_h${minted}`;
    const t = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', 'Trainer') RETURNING id`,
      [`ht${tag}@test.invalid`]
    );
    return { id: t.rows[0].id, tag };
  }

  /// A tutorial of the trainer's own, and a scanned position of theirs: what a
  /// homework's items point at.
  async function lessonOf(who, title = 'Pins') {
    const r = await pool.query(
      `INSERT INTO saved_lessons (user_id, title, fen, pgn)
       VALUES ($1, $2, 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', '')
       RETURNING id`,
      [who.id, title]
    );
    return r.rows[0].id;
  }

  async function positionOf(who, { solved = true, needsReview = false } = {}) {
    const id = `cust_${who.tag}_${Math.random().toString(36).slice(2, 8)}`;
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, solution_san, needs_review, origin)
       VALUES ($1, $2, '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'w', $3, $4, 'book')`,
      [id, who.id, solved ? 'Rd8#' : null, needsReview]
    );
    return id;
  }

  const GAME_TASK = {
    fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
    side: 'w',
    goal: 'survive',
    surviveMoves: 5,
    level: 'lako',
    thinkSeconds: 2,
    plyCap: 40,
  };

  async function create(who, items, title = 'Thursday') {
    const result = await template.saveHomework(pool, {
      trainerId: who.id,
      payload: { title, instructions: 'Read first, then solve.', items },
    });
    assert.equal(result.ok, true, result.error);
    return result.homework;
  }

  // ---- writing one ---------------------------------------------------------

  test('a homework is written with its items in order, each with a minted key', async () => {
    const who = await trainer();
    const lessonId = await lessonOf(who);
    const positionId = await positionOf(who);

    const homework = await create(who, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'positions', task: { puzzleIds: [positionId] }, gate: true },
      { kind: 'engine_game', task: GAME_TASK, gate: true },
    ]);

    assert.equal(homework.title, 'Thursday');
    assert.equal(homework.instructions, 'Read first, then solve.');
    assert.deepEqual(homework.items.map((i) => i.position), [0, 1, 2]);
    assert.deepEqual(homework.items.map((i) => i.kind), ['lesson', 'positions', 'engine_game']);
    assert.deepEqual(homework.items.map((i) => i.gate), [false, true, true]);

    // Minted, not an index: nothing in a key may be read as „the third item".
    const keys = homework.items.map((i) => i.item_key);
    assert.equal(new Set(keys).size, 3);
    for (const [index, key] of keys.entries()) {
      assert.match(key, /^i[0-9a-f]{8}$/, `key ${key}`);
      assert.ok(!key.includes(String(index)) || key.length > 4);
    }

    // The engine game's task comes back as the server will judge it.
    assert.deepEqual(homework.items[2].task, GAME_TASK);
  });

  test('a homework with no items is allowed; one with no title is not', async () => {
    const who = await trainer();
    const empty = await create(who, []);
    assert.deepEqual(empty.items, []);

    for (const payload of [{ title: '   ', items: [] }, { title: 'x'.repeat(256), items: [] }, {}]) {
      const refused = await template.saveHomework(pool, { trainerId: who.id, payload });
      assert.equal(refused.ok, false);
      assert.equal(refused.status, 400);
    }
  });

  // ---- the gate of the phase ----------------------------------------------

  test('reordering the items keeps every key and rewrites only the positions', async () => {
    const who = await trainer();
    const lessonId = await lessonOf(who);
    const positionId = await positionOf(who);
    const homework = await create(who, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'positions', task: { puzzleIds: [positionId] } },
      { kind: 'puzzles', task: { count: 5, themes: ['pin'] } },
    ]);
    const before = homework.items.map((i) => ({ key: i.item_key, kind: i.kind }));

    // The editor sends the list as it now shows it: last first.
    const reordered = await template.saveHomework(pool, {
      trainerId: who.id,
      homeworkId: homework.id,
      payload: {
        title: homework.title,
        instructions: homework.instructions,
        items: [...homework.items].reverse().map((i) => ({
          itemKey: i.item_key,
          kind: i.kind,
          task: i.task,
          gate: i.gate,
        })),
      },
    });
    assert.equal(reordered.ok, true, reordered.error);
    const after = reordered.homework.items;

    assert.deepEqual(after.map((i) => i.position), [0, 1, 2], 'positions renumbered');
    assert.deepEqual(
      after.map((i) => ({ key: i.item_key, kind: i.kind })),
      [...before].reverse(),
      'the same keys, in the new order — no key follows the position'
    );
  });

  test('an item added in the middle disturbs no existing key', async () => {
    const who = await trainer();
    const lessonId = await lessonOf(who);
    const homework = await create(who, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'puzzles', task: { count: 5 } },
    ]);
    const [first, second] = homework.items.map((i) => i.item_key);

    const grown = await template.saveHomework(pool, {
      trainerId: who.id,
      homeworkId: homework.id,
      payload: {
        title: homework.title,
        items: [
          { itemKey: first, kind: 'lesson', task: { lessonId } },
          { kind: 'engine_game', task: GAME_TASK },
          { itemKey: second, kind: 'puzzles', task: { count: 5 } },
        ],
      },
    });
    const keys = grown.homework.items.map((i) => i.item_key);
    assert.equal(keys[0], first);
    assert.equal(keys[2], second);
    assert.ok(!keys.includes(undefined));
    assert.equal(new Set(keys).size, 3);
    assert.notEqual(keys[1], first);
    assert.notEqual(keys[1], second);
  });

  test('an item the editor did not send is gone, and the rest keep their keys', async () => {
    const who = await trainer();
    const lessonId = await lessonOf(who);
    const homework = await create(who, [
      { kind: 'lesson', task: { lessonId } },
      { kind: 'puzzles', task: { count: 5 } },
    ]);
    const kept = homework.items[1].item_key;

    const shrunk = await template.saveHomework(pool, {
      trainerId: who.id,
      homeworkId: homework.id,
      payload: {
        title: homework.title,
        items: [{ itemKey: kept, kind: 'puzzles', task: { count: 7 } }],
      },
    });
    assert.deepEqual(shrunk.homework.items.map((i) => i.item_key), [kept]);
    assert.equal(shrunk.homework.items[0].task.count, 7, 'and it was edited, not replaced');

    const rows = await pool.query(
      'SELECT COUNT(*)::int AS n FROM homework_items WHERE homework_id = $1',
      [homework.id]
    );
    assert.equal(rows.rows[0].n, 1);
  });

  test('a key that is not this homework\'s is a new item, not a hijacked row', async () => {
    const who = await trainer();
    const other = await create(who, [{ kind: 'puzzles', task: { count: 5 } }], 'Other');
    const stolen = other.items[0].item_key;

    const mine = await create(who, []);
    const saved = await template.saveHomework(pool, {
      trainerId: who.id,
      homeworkId: mine.id,
      payload: { title: 'Mine', items: [{ itemKey: stolen, kind: 'puzzles', task: { count: 9 } }] },
    });
    assert.equal(saved.ok, true, saved.error);
    assert.notEqual(saved.homework.items[0].item_key, stolen);

    const untouched = await template.loadHomework(pool, other.id, who.id);
    assert.equal(untouched.items[0].item_key, stolen);
    assert.equal(untouched.items[0].task.count, 5, 'the other homework is as it was');
  });

  test('two items cannot claim one key', async () => {
    const who = await trainer();
    const homework = await create(who, [{ kind: 'puzzles', task: { count: 5 } }]);
    const key = homework.items[0].item_key;
    const refused = await template.saveHomework(pool, {
      trainerId: who.id,
      homeworkId: homework.id,
      payload: {
        title: 'x',
        items: [
          { itemKey: key, kind: 'puzzles', task: { count: 5 } },
          { itemKey: key, kind: 'puzzles', task: { count: 6 } },
        ],
      },
    });
    assert.equal(refused.ok, false);
    assert.match(refused.error, /same key/);
  });

  // ---- what an item may point at ------------------------------------------

  test('a task is read per kind, and a bad one is refused rather than stored', async () => {
    const who = await trainer();
    const cases = [
      [{ kind: 'lesson', task: {} }, /needs a tutorial/],
      [{ kind: 'positions', task: { puzzleIds: [] } }, /at least one position/],
      [{ kind: 'puzzles', task: { count: 0 } }, /count from 1 to 50/],
      [{ kind: 'puzzles', task: { count: 5, minRating: 2000, maxRating: 1000 } }, /backwards/],
      [{ kind: 'engine_game', task: { ...GAME_TASK, goal: 'draw' } }, /goal must be one of/],
      [{ kind: 'engine_game', task: { ...GAME_TASK, goal: 'survive', surviveMoves: null } }, /number of moves/],
      [{ kind: 'video', task: {} }, /kind must be one of/],
      ['not an item', /is not an item/],
    ];
    for (const [item, pattern] of cases) {
      const refused = await template.saveHomework(pool, {
        trainerId: who.id,
        payload: { title: 'x', items: [item] },
      });
      assert.equal(refused.ok, false, `accepted: ${JSON.stringify(item)}`);
      assert.match(refused.error, pattern);
    }
    const none = await template.listHomeworks(pool, who.id);
    assert.deepEqual(none, [], 'nothing was written by any refusal');
  });

  test('a tutorial or a position that is not the trainer\'s own is refused', async () => {
    const who = await trainer();
    const stranger = await trainer();
    const theirLesson = await lessonOf(stranger, 'Not yours');
    const theirPosition = await positionOf(stranger);

    const lesson = await template.saveHomework(pool, {
      trainerId: who.id,
      payload: { title: 'x', items: [{ kind: 'lesson', task: { lessonId: theirLesson } }] },
    });
    assert.equal(lesson.ok, false);
    assert.equal(lesson.status, 422);
    assert.match(lesson.error, /not yours/);

    const position = await template.saveHomework(pool, {
      trainerId: who.id,
      payload: {
        title: 'x',
        items: [{ kind: 'positions', task: { puzzleIds: [theirPosition] } }],
      },
    });
    assert.equal(position.ok, false);
    assert.match(position.error, /not yours/);
  });

  test('a position that cannot be judged or is under review is refused here, not at the board', async () => {
    const who = await trainer();
    const noSolution = await positionOf(who, { solved: false });
    const underReview = await positionOf(who, { needsReview: true });

    for (const [id, pattern] of [[noSolution, /answer cannot be judged/], [underReview, /marked for review/]]) {
      const refused = await template.saveHomework(pool, {
        trainerId: who.id,
        payload: { title: 'x', items: [{ kind: 'positions', task: { puzzleIds: [id] } }] },
      });
      assert.equal(refused.ok, false, id);
      assert.match(refused.error, pattern);
    }
  });

  test('a homework holds at most twenty items', async () => {
    const who = await trainer();
    const items = Array.from({ length: 21 }, () => ({ kind: 'puzzles', task: { count: 5 } }));
    const refused = await template.saveHomework(pool, {
      trainerId: who.id,
      payload: { title: 'x', items },
    });
    assert.equal(refused.ok, false);
    assert.match(refused.error, /at most 20/);
  });

  // ---- whose homework it is -----------------------------------------------

  test('a homework is read, edited and deleted only by the trainer who wrote it', async () => {
    const who = await trainer();
    const stranger = await trainer();
    const homework = await create(who, [{ kind: 'puzzles', task: { count: 5 } }]);

    assert.equal(await template.loadHomework(pool, homework.id, stranger.id), null);
    const edit = await template.saveHomework(pool, {
      trainerId: stranger.id,
      homeworkId: homework.id,
      payload: { title: 'mine now', items: [] },
    });
    assert.equal(edit.ok, false);
    assert.equal(edit.status, 404);
    assert.equal(await template.deleteHomework(pool, homework.id, stranger.id), false);

    const still = await template.loadHomework(pool, homework.id, who.id);
    assert.equal(still.title, 'Thursday');
    assert.equal(still.items.length, 1, 'the stranger\'s empty list did not apply');

    assert.deepEqual((await template.listHomeworks(pool, stranger.id)), []);
    assert.equal((await template.listHomeworks(pool, who.id)).length, 1);
  });

  test('the list counts items and copies sent, newest edit first', async () => {
    const who = await trainer();
    const first = await create(who, [{ kind: 'puzzles', task: { count: 5 } }], 'First');
    const second = await create(who, [], 'Second');

    const list = await template.listHomeworks(pool, who.id);
    assert.deepEqual(list.map((h) => h.title), ['Second', 'First']);
    assert.equal(list.find((h) => h.id === first.id).item_count, 1);
    assert.equal(list.find((h) => h.id === second.id).item_count, 0);
    assert.equal(list[0].sent_count, 0);
  });

  // ---- the routes ---------------------------------------------------------

  /// Runs a real handler from routes/homeworks.js as [userId], with the route
  /// module's pool pointed at this test's database.
  async function route(method, path, { userId, params = {}, body = {} }) {
    const dbModule = require('../db');
    const router = require('../routes/homeworks');
    const layer = router.stack.find(
      (l) => l.route && l.route.path === path && l.route.methods[method]
    );
    assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
    const handlers = layer.route.stack.map((x) => x.handle);
    const handler = handlers[handlers.length - 1];

    const original = dbModule.pool.query;
    const originalConnect = dbModule.pool.connect;
    dbModule.pool.query = (text, values) => pool.query(text, values);
    dbModule.pool.connect = () => pool.connect();
    const answered = { status: 200, body: null };
    const res = {
      status(code) { answered.status = code; return this; },
      json(payload) { answered.body = payload; return this; },
      send() { return this; },
    };
    try {
      await handler({ user: { id: userId }, params, query: {}, body, headers: {} }, res);
    } finally {
      dbModule.pool.query = original;
      dbModule.pool.connect = originalConnect;
    }
    return answered;
  }

  test('the routes write, read, edit and withdraw one homework', async () => {
    const who = await trainer();
    const lessonId = await lessonOf(who);

    const created = await route('post', '/', {
      userId: who.id,
      body: { title: 'From the route', items: [{ kind: 'lesson', task: { lessonId } }] },
    });
    assert.equal(created.status, 201, JSON.stringify(created.body));
    const id = created.body.id;
    const key = created.body.items[0].item_key;

    const list = await route('get', '/', { userId: who.id });
    assert.equal(list.status, 200);
    assert.deepEqual(list.body.homeworks.map((h) => h.id), [id]);

    const read = await route('get', '/:id', { userId: who.id, params: { id: String(id) } });
    assert.equal(read.status, 200);
    assert.equal(read.body.items[0].item_key, key);

    const saved = await route('put', '/:id', {
      userId: who.id,
      params: { id: String(id) },
      body: {
        title: 'Renamed',
        items: [
          { kind: 'puzzles', task: { count: 4 } },
          { itemKey: key, kind: 'lesson', task: { lessonId } },
        ],
      },
    });
    assert.equal(saved.status, 200);
    assert.deepEqual(saved.body.items.map((i) => i.item_key), [saved.body.items[0].item_key, key]);
    assert.equal(saved.body.title, 'Renamed');

    const gone = await route('delete', '/:id', { userId: who.id, params: { id: String(id) } });
    assert.equal(gone.status, 200);
    assert.equal(
      (await route('get', '/:id', { userId: who.id, params: { id: String(id) } })).status,
      404
    );
  });

  test('the routes refuse a stranger, a bad body and an id that is not one', async () => {
    const who = await trainer();
    const stranger = await trainer();
    const homework = await create(who, [{ kind: 'puzzles', task: { count: 5 } }]);

    for (const [method, path] of [['get', '/:id'], ['put', '/:id'], ['delete', '/:id']]) {
      const r = await route(method, path, {
        userId: stranger.id,
        params: { id: String(homework.id) },
        body: { title: 'x', items: [] },
      });
      assert.equal(r.status, 404, `${method} as a stranger`);
    }

    const bad = await route('post', '/', { userId: who.id, body: { items: [] } });
    assert.equal(bad.status, 400);

    const notAnId = await route('get', '/:id', { userId: who.id, params: { id: 'abc' } });
    assert.equal(notAnId.status, 400);
  });

  // ---- the two halves stay apart ------------------------------------------

  test('editing or deleting a homework changes nothing that was already sent', async () => {
    const who = await trainer();
    const student = await trainer();
    const lessonId = await lessonOf(who);
    const homework = await create(who, [{ kind: 'lesson', task: { lessonId } }]);

    // A sent copy, as phase 4 will write it: a parent pointing back at the
    // template, and one child per item.
    const parent = await pool.query(
      `INSERT INTO assignments (trainer_id, student_id, title, kind, homework_id)
       VALUES ($1, $2, 'Thursday', 'homework', $3) RETURNING id`,
      [who.id, student.id, homework.id]
    );
    const parentId = parent.rows[0].id;
    await pool.query(
      `INSERT INTO assignments
         (trainer_id, student_id, title, kind, parent_id, position, item_key)
       VALUES ($1, $2, 'item', 'lesson', $3, 0, $4)`,
      [who.id, student.id, parentId, homework.items[0].item_key]
    );

    const withSent = await template.loadHomework(pool, homework.id, who.id);
    assert.equal(withSent.sent.length, 1);
    assert.equal(withSent.sent[0].id, parentId);
    assert.equal(withSent.sent[0].child_total, 1);
    assert.equal(withSent.sent[0].student_name, 'Trainer');
    assert.equal((await template.listHomeworks(pool, who.id))[0].sent_count, 1);

    // Empty the template, then delete it.
    await template.saveHomework(pool, {
      trainerId: who.id,
      homeworkId: homework.id,
      payload: { title: 'Thursday, changed', items: [] },
    });
    assert.equal(await template.deleteHomework(pool, homework.id, who.id), true);

    const sentStill = await pool.query(
      `SELECT title, kind, homework_id,
              (SELECT COUNT(*)::int FROM assignments c WHERE c.parent_id = $1) AS children
         FROM assignments WHERE id = $1`,
      [parentId]
    );
    assert.equal(sentStill.rows[0].title, 'Thursday', 'the sent copy kept its own title');
    assert.equal(sentStill.rows[0].children, 1, 'and its items');
    assert.equal(sentStill.rows[0].homework_id, null, 'only the link to the template is gone');
  });
});
