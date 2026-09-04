const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { frontier, withinBreadth } = require('../services/repertoireFrontier');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

/// The FEN after a line of UCI moves from the start, and its repertoire key.
///
/// Computed rather than pasted. Every hand-written FEN in a test like this is a
/// chance to assert against a position that does not exist, and the walk being
/// tested would then be right while the test was wrong.
function after(...ucis) {
  const board = new Chess();
  for (const uci of ucis) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return board.fen();
}

function keyAfter(...ucis) {
  return fenKey(after(...ucis));
}

/// A pool that answers the two questions the walk asks, from tables held here.
///
/// Keyed rather than a list of canned results in order: the walk asks once per
/// level and the number of levels is what is being tested, so a stub that
/// replays answers positionally would pass for the wrong reason.
function stubPool({ moves = [], replies = [], skips = [], extras = [] } = {}) {
  let levels = 0;
  const calls = [];
  return {
    calls,
    levels: () => levels,
    query: async (text, params) => {
      calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
      if (text.includes('FROM repertoire_moves')) {
        return { rows: moves, rowCount: moves.length };
      }
      if (text.includes('FROM repertoire_skips')) {
        const rows = skips.map((fen_key) => ({ fen_key }));
        return { rows, rowCount: rows.length };
      }
      if (text.includes('FROM opening_replies')) {
        levels += 1;
        const [band, keys] = params;
        // Every row for those positions, the way the table holds them and the
        // way the query now reads them: the cut and the "prepare this too" flag
        // are **columns**, not a WHERE clause, because breadth decides at read
        // time which of them the walk follows. A stub that filtered here would
        // be testing a narrowing that no longer happens in SQL.
        //
        // `covered` defaults to true, which is what every older fixture here
        // meant when it was written; a row that says `covered: false` still
        // says it.
        const rows = replies
          .filter((r) => Number(r.min_rating ?? 0) === band
            && keys.includes(r.fen_key))
          .map((r) => ({
            covered: true,
            ...r,
            asked: extras.some(
              (e) => e.fen_key === r.fen_key && e.uci === r.uci),
          }));
        return { rows, rowCount: rows.length };
      }
      throw new Error(`Neočekivan upit: ${text}`);
    },
  };
}

/// 1.e4, answered by 1...c5 (50%) and 1...e5 (20%).
/// Against the Sicilian the student plays 2.Nf3 and Black replies 2...d6 (60%),
/// leaving 1.e4 c5 2.Nf3 d6 unanswered at a reach of 0.30.
/// Against 1...e5 they have decided on 2.Bc4 but never took the replies.
function sicilianAndOpenGame() {
  return {
    moves: [
      { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'c7c5'), uci: 'g1f3', san: 'Nf3', role: 'primary' },
      { fen_key: keyAfter('e2e4', 'e7e5'), uci: 'f1c4', san: 'Bc4', role: 'primary' },
    ],
    replies: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5', games: 500, share: '0.50000' },
      { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5', games: 200, share: '0.20000' },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'),
        uci: 'd7d6', san: 'd6', games: 300, share: '0.60000',
      },
      // Nothing for the position after 2.Bc4 — that branch was decided and
      // then left, which is the whole point of the second kind of open node.
    ],
  };
}

test('the queue comes back from what was stored, without asking Lichess', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 2);
  assert.equal(walk.summary.decided, 3);
  assert.equal(walk.summary.undecided, 1);
  assert.equal(walk.summary.unopened, 1);
  assert.equal(walk.summary.truncated, false);
});

test('the main line outranks a shallower sideline, because it is reached more', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  // 0.5 × 0.6 = 0.30 at ply four beats 0.20 at ply two. This is the whole
  // ordering: neither breadth-first nor depth-first, but how often a game
  // actually arrives — which goes deep down a main line and widens on its own
  // once that line's probability has decayed.
  const [first, second] = walk.open;
  assert.deepEqual(first.path, ['e4', 'c5', 'Nf3', 'd6']);
  assert.equal(first.ply, 4);
  assert.ok(Math.abs(first.reach - 0.3) < 1e-9, `reach je ${first.reach}`);
  assert.equal(first.kind, 'undecided');

  assert.deepEqual(second.path, ['e4', 'e5']);
  assert.ok(Math.abs(second.reach - 0.2) < 1e-9, `reach je ${second.reach}`);
});

test('a decided position whose replies were never taken comes back as unopened', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  const dangling = walk.open.find((node) => node.kind === 'unopened');
  assert.ok(dangling, 'grana bez knjige mora da se vrati');
  // The position handed back is the one *before* the student's move: that is
  // the board the build screen puts up, and where the button that takes the
  // replies lives. Handing back the position after 2.Bc4 would be a board the
  // screen cannot ask a question about.
  assert.deepEqual(dangling.path, ['e4', 'e5']);
  assert.equal(dangling.fenKey, keyAfter('e2e4', 'e7e5'));
});

test('a position reached two ways is queued once', async () => {
  // Black meets 1.e4 with 1...c5 and answers both 2.Nf3 and 2.Nc3 with 2...Nc6.
  // White's next move transposes the two: 2.Nf3 Nc6 3.Nc3 and 2.Nc3 Nc6 3.Nf3
  // are one board. A walk that queued it twice would ask the same question
  // twice and report a repertoire bigger than it is.
  const pool = stubPool({
    moves: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5', role: 'primary' },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'),
        uci: 'b8c6', san: 'Nc6', role: 'primary',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'b1c3'),
        uci: 'b8c6', san: 'Nc6', role: 'primary',
      },
    ],
    replies: [
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        uci: 'g1f3', san: 'Nf3', games: 5, share: '0.50000',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        uci: 'b1c3', san: 'Nc3', games: 5, share: '0.50000',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6'),
        uci: 'b1c3', san: 'Nc3', games: 5, share: '1.00000',
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5', 'b1c3', 'b8c6'),
        uci: 'g1f3', san: 'Nf3', games: 5, share: '1.00000',
      },
    ],
  });
  const walk = await frontier(pool, 7, {
    color: 'b', rootFen: after('e2e4'), rootPath: ['e4'],
  });

  const keys = walk.open.map((node) => node.fenKey);
  assert.equal(new Set(keys).size, keys.length, 'ista pozicija dva puta u redu');
  assert.equal(walk.open.length, 1, 'transpozicija je jedna pozicija, ne dve');
  assert.equal(
    walk.open[0].fenKey,
    keyAfter('e2e4', 'c7c5', 'g1f3', 'b8c6', 'b1c3'),
  );
});

test('the book is asked once per wave, not once per branch', async () => {
  const pool = stubPool(sicilianAndOpenGame());
  await frontier(pool, 7, { color: 'w', rootFen: START });

  // Two: the wave after 1.e4, and the wave after 2.Nf3 / 2.Bc4. The last wave
  // has nothing decided in it, so there is no branch to look up and the walk
  // does not ask — five branches, two queries. That is the shape that keeps a
  // wide repertoire from turning one request into a minute of database time.
  assert.equal(pool.levels(), 2, `upita: ${pool.levels()}`);
});

test('an empty repertoire is a walk with one question in it', async () => {
  const pool = stubPool({ moves: [], replies: [] });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 1);
  assert.equal(walk.open[0].kind, 'undecided');
  assert.deepEqual(walk.open[0].path, []);
  assert.equal(walk.open[0].reach, 1);
  assert.equal(walk.summary.decided, 0);
});

test('the moves that led to the root travel with the walk', async () => {
  const pool = stubPool({ moves: [], replies: [] });
  const walk = await frontier(pool, 7, {
    color: 'b',
    rootFen: after('e2e4', 'c7c5', 'd2d4'),
    rootPath: ['e4', 'c5', 'd4'],
  });

  // Each node's own path starts at the root; the root's path is handed back
  // once. Without it a breadcrumb for a repertoire built from move four reads
  // as though the game began there.
  assert.deepEqual(walk.root.path, ['e4', 'c5', 'd4']);
  assert.deepEqual(walk.open[0].path, []);
});

test('a broken position is a bad request rather than an empty answer', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => frontier(pool, 7, { color: 'w', rootFen: 'nije fen' }),
    RangeError,
  );
  await assert.rejects(
    () => frontier(pool, 7, { color: 'x', rootFen: START }),
    RangeError,
  );
});

test('a move that no longer fits its position drops its branch, not the walk', async () => {
  // The repertoire is a graph keyed on positions, so this should not happen —
  // but a walk that throws here would take out the whole screen for one bad
  // row, and the rest of the repertoire is still worth showing.
  const pool = stubPool({
    moves: [
      { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
      { fen_key: fenKey(START), uci: 'h7h5', san: '??', role: 'alternate' },
    ],
    replies: [
      { fen_key: keyAfter('e2e4'), uci: 'c7c5', san: 'c5', games: 5, share: '1.00000' },
    ],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 1);
  assert.deepEqual(walk.open[0].path, ['e4', 'c5']);
});

test('a cut branch leaves the queue and is handed back as cut', async () => {
  // Cutting is the one control that makes the tree smaller, so it is also the
  // one that could quietly make the repertoire *look* finished. The branch has
  // to leave `open` — that is the point — and it has to arrive somewhere the
  // student can see it again.
  const pool = stubPool({
    ...sicilianAndOpenGame(),
    skips: [keyAfter('e2e4', 'e7e5')],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.deepEqual(walk.open.map((node) => node.path), [['e4', 'c5', 'Nf3', 'd6']]);
  assert.equal(walk.summary.pruned, 1);
  assert.deepEqual(walk.pruned.map((node) => node.path), [['e4', 'e5']]);
  assert.equal(walk.pruned[0].kind, 'pruned');
  // 1...e5 is played in 20% of games, and those games are still going to be
  // played. `openReach` no longer counts them; this number does, and the two
  // are never added together.
  assert.equal(Math.round(walk.summary.prunedReach * 100), 20);
  assert.equal(Math.round(walk.summary.openReach * 100), 30);
});

test('cutting a branch takes everything under it', async () => {
  // The whole value of the lever. Cutting 1...c5 must not leave the positions
  // below it in the queue — otherwise the student cuts a branch and the tree
  // stays exactly as big, which is how a control teaches people not to use it.
  const pool = stubPool({
    ...sicilianAndOpenGame(),
    skips: [keyAfter('e2e4', 'c7c5')],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(
    walk.open.some((node) => node.path.includes('c5')),
    false,
    'pozicija ispod odsečene grane je ostala u redu',
  );
  // And the move kept there stops being counted as a decision the walk passed
  // through — three before the cut, two after. The row is still in
  // `repertoire_moves` and still drilled: cutting says how far to prepare, not
  // what to forget.
  assert.equal(walk.summary.decided, 2);
});

test('a cut root is a walk with no questions and one cut', async () => {
  // Nothing to answer and nothing pretending otherwise. The screen refuses to
  // offer this cut, but a repertoire whose root was cut on another device must
  // still read honestly rather than as "finished".
  const pool = stubPool({ ...sicilianAndOpenGame(), skips: [fenKey(START)] });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(walk.open.length, 0);
  assert.equal(walk.summary.pruned, 1);
  assert.equal(walk.summary.decided, 0);
  assert.equal(walk.summary.prunedReach, 1);
});

test('the walk says how far each of the opponent\'s answers has been taken',
  async () => {
    // The coverage map, out of the walk that was already running. A branch is
    // one of the opponent's first answers, because the student's own first
    // move is already decided and it is the opponent's choice that names the
    // thing — the Advance, the Exchange, the Two Knights.
    const pool = stubPool(sicilianAndOpenGame());
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    assert.deepEqual(walk.branches.map((b) => b.key), ['e4 c5', 'e4 e5']);
    // Most played first: that is the order they are worth finishing in, not
    // the order they were built in.
    assert.equal(walk.branches[0].share, 0.5);
    assert.equal(walk.branches[0].maxPly, 4);
    assert.equal(walk.branches[0].decided, 1);
    assert.equal(walk.branches[0].open, 1);
  });

test('a rare sideline does not read as nearly finished', async () => {
  // The number that would have been wrong if it were measured against the
  // whole repertoire. 1...e5 is entirely unanswered — there is one decided
  // position in it and its replies were never taken — but it is played in a
  // fifth of games, so against the whole it would look four-fifths done.
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  const openGame = walk.branches.find((b) => b.key === 'e4 e5');
  assert.equal(Math.round(openGame.openReach * 100), 20);
  assert.equal(Math.round(openGame.openWithin * 100), 100);

  // And the Sicilian, where one of two waves is answered.
  const sicilian = walk.branches.find((b) => b.key === 'e4 c5');
  assert.equal(Math.round(sicilian.openWithin * 100), 60);
});

test('a cut branch shows on the map as cut, not as done', async () => {
  // The map must never turn a refusal into progress. `openWithin` falls to
  // zero because there is nothing open there any more, and the only honest
  // reading of that comes from the number beside it.
  const pool = stubPool({
    ...sicilianAndOpenGame(),
    skips: [keyAfter('e2e4', 'e7e5')],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  const openGame = walk.branches.find((b) => b.key === 'e4 e5');
  assert.equal(openGame.open, 0);
  assert.equal(openGame.pruned, 1);
  assert.equal(Math.round(openGame.prunedWithin * 100), 100);
});

test('a repertoire with nothing decided has no map yet', async () => {
  // The root is in no branch — it is the position every branch leaves from —
  // so an empty repertoire is one open question and an empty map, which is
  // exactly the truth about it.
  const pool = stubPool();
  const walk = await frontier(pool, 7, { color: 'b', rootFen: START });

  assert.deepEqual(walk.branches, []);
  assert.equal(walk.open.length, 1);
});

/// The same repertoire, plus a tail move: 1...d5 is played in 5% of games and
/// falls outside the 80% the wave covers.
function withTail() {
  const base = sicilianAndOpenGame();
  return {
    moves: base.moves,
    replies: [
      ...base.replies,
      {
        fen_key: keyAfter('e2e4'),
        uci: 'd7d5', san: 'd5', games: 50, share: '0.05000', covered: false,
      },
    ],
  };
}

test('a move outside the covered wave is not walked into', async () => {
  // The default, and it has to stay the default: following the whole tail would
  // grow the queue by moves the build loop never enqueued, and hand back a walk
  // that does not match the one the student was on.
  const pool = stubPool(withTail());
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  assert.equal(
    walk.open.some((node) => node.path.includes('d5')),
    false,
    'rep je ušao u red bez pitanja',
  );
});

test('a move the student asked for by name is walked into', async () => {
  // "Prepare this one too". The wave covers 80% and names the remainder, which
  // is a good default and a bad wall — the tail was countable and unreachable.
  //
  // The walk has to follow it, or the position would be asked once and lost the
  // moment the screen closed: the queue is derived, not stored.
  const pool = stubPool({
    ...withTail(),
    extras: [{ fen_key: keyAfter('e2e4'), uci: 'd7d5' }],
  });
  const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

  const added = walk.open.find((node) => node.path.includes('d5'));
  assert.ok(added, 'potez dodat u pripremu nije u redu');
  assert.deepEqual(added.path, ['e4', 'd5']);
  assert.equal(added.kind, 'undecided');
  // Ordered like everything else: it is played in a twentieth of games and it
  // waits behind the lines that are not.
  assert.equal(Math.round(added.reach * 100), 5);
});

test('the extra replies are read for this student, not for everybody',
  async () => {
    // `opening_replies.covered` is shared — the rows are about a position and a
    // rating band, never about a person. One child pressing "prepare this too"
    // must not rewrite the walk every other child follows.
    const pool = stubPool(sicilianAndOpenGame());
    await frontier(pool, 7, { color: 'w', rootFen: START });

    const book = pool.calls.find((c) => c.text.includes('FROM opening_replies'));
    assert.match(book.text, /repertoire_extra_replies/);
    assert.equal(book.params[2], 7);
    assert.equal(book.params[3], 'w');
  });

test('a position whose only moves were generated is a draft, not a decision',
  async () => {
    // The archive seed's whole failure, and the reason this column exists: a
    // move nobody chose must never be counted as one. The map says "odlučeno"
    // about decisions and keeps the drafts in a number of their own.
    const base = sicilianAndOpenGame();
    const pool = stubPool({
      ...base,
      moves: base.moves.map((m) => (
        m.fen_key === keyAfter('e2e4', 'c7c5')
          ? { ...m, source: 'auto' }
          : m)),
    });
    const walk = await frontier(pool, 7, { color: 'w', rootFen: START });

    assert.equal(walk.summary.draft, 1);
    // Three positions had moves before; one of them is now a draft.
    assert.equal(walk.summary.decided, 2);
    const sicilian = walk.branches.find((b) => b.key === 'e4 c5');
    assert.equal(sicilian.draft, 1);
    // And the walk still goes through it — a draft you cannot reach is a draft
    // you cannot confirm.
    assert.ok(walk.open.some((node) => node.path.includes('Nf3')));
  });

// --- breadth -----------------------------------------------------------
//
// How wide a repertoire is walked. The rule is `withinBreadth`, in one place,
// and it is read by the queue, the tree, the coverage map, the prune engine and
// the drill's live opponent — so it is tested against rows here and threaded
// through `frontier` in the two tests after it.

/// One position's book as the table holds it: in games order, each row saying
/// whether it is inside the shared 80% cut.
const BOOK = [
  { uci: 'c7c5', san: 'c5', games: 500, share: '0.50000', covered: true },
  { uci: 'e7e5', san: 'e5', games: 250, share: '0.25000', covered: true },
  { uci: 'e7e6', san: 'e6', games: 120, share: '0.12000', covered: false },
  { uci: 'c7c6', san: 'c6', games: 80, share: '0.08000', covered: false },
  { uci: 'd7d5', san: 'd5', games: 50, share: '0.05000', covered: false },
];

const sansOf = (rows, breadth) =>
  withinBreadth(rows, breadth).map((reply) => reply.san);

test('main follows the one move that is actually played', async () => {
  assert.deepEqual(sansOf(BOOK, 'main'), ['c5']);
});

test('standard is the stored cut and not a number recomputed here', async () => {
  // The 80% cut is `opening_replies.covered`, written when the position was
  // first opened and **shared by every user of this server**. Recomputing it
  // from the shares would be a second implementation of somebody else's
  // decision, and the two would drift the first time the cut's caps changed.
  assert.deepEqual(sansOf(BOOK, 'standard'), ['c5', 'e5']);
  // Which is also what an absent breadth means: every caller written before
  // the column existed is asking for exactly this.
  assert.deepEqual(sansOf(BOOK), ['c5', 'e5']);
});

test('broad goes on past the cut, to the moves that make up 95%', async () => {
  assert.deepEqual(sansOf(BOOK, 'broad'), ['c5', 'e5', 'e6', 'c6']);
  // 0.50 + 0.25 + 0.12 + 0.08 is 0.95, so 1...d5 at a twentieth is the first
  // move outside it. Widening is not "follow everything" — the tail is still
  // named and still not walked.
});

test('the three breadths are nested, so widening only ever adds', async () => {
  // The property that matters more than the numbers do. If `broad` could drop
  // something `standard` follows, widening a repertoire would silently orphan
  // the work under it — and the prune engine reads reachability from this walk.
  const main = new Set(sansOf(BOOK, 'main'));
  const standard = new Set(sansOf(BOOK, 'standard'));
  const broad = new Set(sansOf(BOOK, 'broad'));
  for (const san of main) assert.ok(standard.has(san), `main ⊄ standard: ${san}`);
  for (const san of standard) assert.ok(broad.has(san), `standard ⊄ broad: ${san}`);
});

test('a move asked for by name is followed at every breadth, main included',
  async () => {
    // "Prepare this one too" is stored per student precisely so it does not
    // depend on where anybody's cut falls. Dropping it at `main` would ask the
    // position once and lose it the moment the screen closed.
    const asked = BOOK.map((row) => ({ ...row, asked: row.uci === 'd7d5' }));
    for (const breadth of ['main', 'standard', 'broad']) {
      assert.ok(sansOf(asked, breadth).includes('d5'),
        `širina ${breadth} je odbacila potez koji je tražen po imenu`);
    }
    // And it keeps its place in games order rather than being appended last: a
    // reply played in a twentieth of games is not the main line because of the
    // order the rule happened to collect it in.
    assert.deepEqual(sansOf(asked, 'main'), ['c5', 'd5']);
  });

test('a breadth nobody defined is refused rather than guessed at', async () => {
  assert.throws(() => withinBreadth(BOOK, 'everything'), RangeError);
});

test('the walk follows what the breadth says, not what the cut says',
  async () => {
    // Threaded, not merely defined: a rule this good that no walk passes its
    // parameter to is a rule with no effect. 1...d5 is outside the cut, so
    // `standard` never reaches it and `broad` does.
    const standard = await frontier(stubPool(withTail()), 7, {
      color: 'w', rootFen: START,
    });
    assert.equal(standard.open.some((n) => n.path.includes('d5')), false);

    const broad = await frontier(stubPool(withTail()), 7, {
      color: 'w', rootFen: START, breadth: 'broad',
    });
    const added = broad.open.find((n) => n.path.includes('d5'));
    assert.ok(added, 'široka širina nije ušla u rep');
    assert.equal(added.kind, 'undecided');
  });

test('narrowing never hides a branch the student has decided in', async () => {
  // This test used to assert the opposite, and the opposite was wrong.
  //
  // 1...e5 is the second most played reply, so `main` — one reply a position —
  // does not follow it. But the student has decided 2.Bc4 there, and hiding
  // their own move from their own tree is not a narrower view: measured on a
  // live repertoire 4.9.2026, `main` reached four nodes and none of that
  // repertoire's twenty-one drafts, `standard` reached seventy-nine and all of
  // them. It was the true cause of three separate live findings — a spine that
  // „wrote nothing", a review that found no drafts, and a tree that did not
  // grow.
  //
  // The old wording accepted it because the row survived in `repertoire_moves`
  // „for the day they widen again". The row did survive. Nothing on screen said
  // so, and no reader is going to widen a repertoire to look for work they do
  // not know is there.
  const pool = stubPool(sicilianAndOpenGame());
  const walk = await frontier(pool, 7, {
    color: 'w', rootFen: START, breadth: 'main',
  });

  assert.ok(walk.open.some((n) => n.path.includes('e5')),
    'sopstvena odluka je ostala van sopstvenog stabla');
  // Nothing was deleted to achieve any of it: the walk asked the book and the
  // moves table, and wrote to neither.
  assert.equal(
    pool.calls.some((c) => /DELETE|UPDATE|INSERT/.test(c.text)), false,
    'suženje je nešto upisalo',
  );
});

test('and it widens for nothing else', async () => {
  // The other half, and the one that keeps the rule honest: `main` still walks
  // one reply a position everywhere the student has decided nothing. Without
  // this the change reads as „breadth stopped working", which would be a fair
  // description of a walk that followed every reply it was handed.
  const pool = stubPool(withTail());
  const walk = await frontier(pool, 7, {
    color: 'w', rootFen: START, breadth: 'main',
  });

  assert.equal(walk.open.some((n) => n.path.includes('d5')), false,
    'širina više ništa ne sužava');
});
