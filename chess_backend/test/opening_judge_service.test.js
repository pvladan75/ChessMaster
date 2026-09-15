const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  createOpeningJudge,
  whiteRelativeCp,
  sanLine,
  COVERAGE_SHARE,
  MAX_REPLIES,
  MIN_MASTER_GAMES,
} = require('../services/openingJudgeService');
const {
  createOpeningBook, polyglotKey, OpeningBookUnavailable,
} = require('../services/openingBook');

// After 1.e4 e5 2.Nf3 Nc6 3.Bc4 — Black to move, the Italian.
const ITALIAN = 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 5 4';
const ITALIAN_NF6 = 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 6 5';
// After 1.e4 e5 — White to move.
const AFTER_E4_E5 = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
const AFTER_NF3 = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2';
const AFTER_BC4 = 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2';

const sq = (name) => (name.charCodeAt(0) - 97) + 8 * (Number(name[1]) - 1);

/// The opening book as a file in the shape the extraction writes, rather than a
/// stand-in for `answer()`: a fake of the book's answer is a second definition
/// of it, and the judge would be tested against whichever one was written
/// last. [rows] are `[fen, uci, white, draws, black]`; [totals] are what a
/// pruned file kept per position; [maxPly] is how deep it says it goes.
function bookWith(t, rows = [], { totals = [], maxPly = null } = {}) {
  const { DatabaseSync } = require('node:sqlite');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'judge-book-'));
  const file = path.join(dir, 'book.sqlite');
  const db = new DatabaseSync(file);
  db.exec(`CREATE TABLE position_stats (zobrist INTEGER, move INTEGER, w INTEGER,
           b INTEGER, d INTEGER, PRIMARY KEY (zobrist, move)) WITHOUT ROWID`);
  const insert = db.prepare('INSERT INTO position_stats VALUES (?, ?, ?, ?, ?)');
  for (const [fen, uci, white, draws, black] of rows) {
    const promotion = uci.length > 4 ? ' pnbrqk'.indexOf(uci[4]) : 0;
    insert.run(polyglotKey(fen), sq(uci.slice(0, 2)) | (sq(uci.slice(2, 4)) << 6)
      | (promotion << 12), white, black, draws);
  }
  if (totals.length > 0) {
    db.exec(`CREATE TABLE position_totals (zobrist INTEGER PRIMARY KEY,
             w INTEGER, b INTEGER, d INTEGER) WITHOUT ROWID`);
    const put = db.prepare('INSERT INTO position_totals VALUES (?, ?, ?, ?)');
    for (const [fen, white, draws, black] of totals) {
      put.run(polyglotKey(fen), white, black, draws);
    }
  }
  if (maxPly !== null) {
    db.exec("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)");
    db.prepare("INSERT INTO meta VALUES ('max_ply', ?)").run(String(maxPly));
    if (totals.length > 0) db.exec("INSERT INTO meta VALUES ('pruned', '1')");
  }
  db.close();
  const book = createOpeningBook({ path: file });
  t.after(() => {
    book.close();
    fs.rmSync(dir, { recursive: true, force: true });
  });
  return book;
}

/// A stubbed cloud evaluation, keyed by FEN so the two positions of one move —
/// before and after — can disagree, which is the whole subject of most of these
/// tests. It is the only thing the judge still asks over the network.
function cloudStub(evals = {}) {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url, headers: init?.headers ?? {} });
    const answer = evals[new URL(url).searchParams.get('fen')];
    // The cloud answers 404 for a position it has never been asked about, and
    // that is an answer, not a fault.
    if (!answer) return { ok: false, status: 404, json: async () => ({}) };
    return { ok: true, status: 200, json: async () => answer };
  };
  return { fetchImpl, requests, calls: () => requests.length };
}

/// A clock that only moves when something waits on it, so a test can spend a
/// minute of Lichess's cooldown without spending a minute.
function fakeClock() {
  let atMs = 0;
  const waits = [];
  return {
    waits,
    advance: (ms) => { atMs += ms; },
    options: {
      now: () => atMs,
      sleep: async (ms) => { waits.push(ms); atMs += ms; },
    },
  };
}

function judgeWith(book, cloud, opts = {}) {
  const clock = opts.clock ?? fakeClock();
  return createOpeningJudge({ book, fetchImpl: cloud.fetchImpl, ...clock.options });
}

/// One cloud answer. `cp` is White-relative, which is how Lichess reports it.
const cloud = (cp, depth = 40) => ({ depth, pvs: [{ moves: 'e2e4', cp }] });
const cloudMate = (mate) => ({ depth: 40, pvs: [{ moves: 'e2e4', mate }] });

test('a move masters keep playing is theory, and the engine is not asked',
  async (t) => {
    const book = bookWith(t, [[ITALIAN, 'g8f6', 900, 400, 700]]);
    const c = cloudStub();

    const verdict = await judgeWith(book, c).judge(ITALIAN, 'Nf6');

    assert.equal(verdict.verdict, 'theory');
    assert.equal(verdict.san, 'Nf6');
    assert.equal(verdict.uci, 'g8f6');
    assert.equal(verdict.masters.games, 2000);
    assert.equal(c.calls(), 0);
  });

test('a handful of master games is not theory yet', async (t) => {
  const book = bookWith(t, [[ITALIAN, 'g8f6', MIN_MASTER_GAMES - 1, 0, 0]]);
  const c = cloudStub({ [ITALIAN]: cloud(20), [ITALIAN_NF6]: cloud(30) });

  const verdict = await judgeWith(book, c).judge(ITALIAN, 'Nf6');

  assert.equal(verdict.verdict, 'playable');
  assert.equal(verdict.masters.games, MIN_MASTER_GAMES - 1);
});

test('ten master games is theory — the threshold is the number, not past it',
  async (t) => {
    const book = bookWith(t, [[ITALIAN, 'g8f6', MIN_MASTER_GAMES, 0, 0]]);
    const verdict = await judgeWith(book, cloudStub()).judge(ITALIAN, 'Nf6');
    assert.equal(verdict.verdict, 'theory');
    assert.equal(MIN_MASTER_GAMES, 10);
  });

test('castling in the book is read as castling', async (t) => {
  // The book stores the move python-chess wrote, king to its castling square,
  // which is also what chess.js and this app's board write. Nothing is
  // translated on the way, and a castling move that did not match would read
  // as "not in the book" under a verdict computed from the engine alone.
  const before = 'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';
  const book = bookWith(t, [[before, 'e1g1', 300, 200, 250]]);
  const verdict = await judgeWith(book, cloudStub()).judge(before, 'O-O');
  assert.equal(verdict.uci, 'e1g1');
  assert.equal(verdict.verdict, 'theory');
});

test("a black move is judged from black's side, not from white's", async (t) => {
  // The one mistake here that no amount of reading catches: Lichess reports
  // cloud evaluations from White's point of view, so a move that hands White
  // three pawns reads as an *improvement* if the sign is left alone. Before:
  // -50, Black half a pawn better. After: +300, White three pawns better. From
  // Black's side that is a loss of 3.5 pawns.
  const book = bookWith(t);
  const c = cloudStub({ [ITALIAN]: cloud(-50), [ITALIAN_NF6]: cloud(300) });

  const verdict = await judgeWith(book, c).judge(ITALIAN, 'Nf6');

  assert.equal(verdict.moverIsWhite, false);
  assert.equal(verdict.eval.beforeCp, 50);
  assert.equal(verdict.eval.afterCp, -300);
  assert.equal(verdict.eval.lossCp, 350);
  assert.equal(verdict.verdict, 'mistake');
});

test('a white move that gives nothing away is playable', async (t) => {
  const book = bookWith(t);
  const c = cloudStub({ [AFTER_E4_E5]: cloud(22), [AFTER_NF3]: cloud(15) });

  const verdict = await judgeWith(book, c).judge(AFTER_E4_E5, 'Nf3');

  assert.equal(verdict.verdict, 'playable');
  assert.equal(verdict.eval.lossCp, 7);
});

test('a move that keeps a lost position lost is not playable', async (t) => {
  // Loses nothing - there is nothing left to lose - and calling it playable
  // would be true arithmetic and a lie to the child looking at it.
  const book = bookWith(t);
  const c = cloudStub({ [AFTER_E4_E5]: cloud(-400), [AFTER_NF3]: cloud(-400) });

  const verdict = await judgeWith(book, c).judge(AFTER_E4_E5, 'Nf3');

  assert.equal(verdict.eval.lossCp, 0);
  assert.equal(verdict.verdict, 'mistake');
});

test('a move that walks into mate is a mistake, and the mate is passed on',
  async (t) => {
    const book = bookWith(t);
    const c = cloudStub({ [AFTER_E4_E5]: cloud(20), [AFTER_NF3]: cloudMate(-3) });

    const verdict = await judgeWith(book, c).judge(AFTER_E4_E5, 'Nf3');

    assert.equal(verdict.verdict, 'mistake');
    // White played, so a mate for Black is a mate against the mover.
    assert.equal(verdict.eval.mateAfter, -3);
  });

test('a mistake says what to play instead, and how it gets punished',
  async (t) => {
    // Both lines come with the evaluations that were fetched anyway. A verdict
    // that only scores the move teaches nothing - that lesson was already paid
    // for in the endgame trainer, where a count of remaining moves without the
    // moves themselves had to be replaced.
    const book = bookWith(t);
    const c = cloudStub({
      [AFTER_E4_E5]: { depth: 40, pvs: [{ moves: 'g1f3 b8c6', cp: 20 }] },
      [AFTER_BC4]: { depth: 40, pvs: [{ moves: 'd8h4 g1f3 h4e4', cp: -400 }] },
    });

    const verdict = await judgeWith(book, c).judge(AFTER_E4_E5, 'Bc4');

    assert.equal(verdict.verdict, 'mistake');
    assert.equal(verdict.eval.better, 'Nf3');
    assert.deepEqual(verdict.eval.punishment, ['Qh4', 'Nf3', 'Qxe4+']);
  });

test('a playable move is not given advice it does not need', async (t) => {
  const book = bookWith(t);
  const c = cloudStub({
    [AFTER_E4_E5]: { depth: 40, pvs: [{ moves: 'g1f3 b8c6', cp: 22 }] },
    [AFTER_BC4]: { depth: 40, pvs: [{ moves: 'g8f6', cp: 15 }] },
  });

  const verdict = await judgeWith(book, c).judge(AFTER_E4_E5, 'Bc4');

  assert.equal(verdict.verdict, 'playable');
  assert.equal(verdict.eval.better, null);
  assert.deepEqual(verdict.eval.punishment, []);
});

test('a line that does not fit the position is dropped, not half-printed', () => {
  assert.deepEqual(sanLine(AFTER_E4_E5, ['g1f3', 'a1a8', 'b8c6'], 3), ['Nf3']);
  assert.deepEqual(sanLine('not a fen', ['g1f3'], 1), []);
  assert.deepEqual(sanLine(AFTER_E4_E5, [], 3), []);
});

test('a line castling the way Lichess writes it is read as castling', () => {
  // `e1h1` is Lichess's "king takes rook". Read literally it does not play, and
  // the line used to stop there: "better was O-O" came out as nothing at all.
  const ready = 'r3k2r/pppqbppp/2np1n2/4p3/4P3/2NP1N2/PPPQBPPP/R3K2R w KQkq - 4 8';
  assert.deepEqual(sanLine(ready, ['e1h1', 'e8a8'], 2), ['O-O', 'O-O-O']);
  assert.deepEqual(sanLine(ready, ['e1a1'], 1), ['O-O-O']);
  // A rook on e1 sliding to h1 is not castling, and must not be turned into a
  // move to g1: only a king standing on e1 castles. (Here h1 holds White's own
  // king, so the literal move does not play either and the line is empty —
  // where the rewrite would have played Rg1.)
  const rookOnE1 = '4k3/8/8/8/8/8/8/4R2K w - - 0 1';
  assert.deepEqual(sanLine(rookOnE1, ['e1h1'], 1), []);
});

test('a position the cloud has never seen is not called a mistake', async (t) => {
  const verdict = await judgeWith(bookWith(t), cloudStub()).judge(AFTER_E4_E5, 'Nf3');

  assert.equal(verdict.verdict, 'unknown');
  assert.equal(verdict.reason, 'no-eval');
  assert.equal(verdict.eval, null);
});

test('nobody brings a token, and nothing sent to Lichess carries one',
  async (t) => {
    // The gate this judge used to have: the caller's own Lichess token for all
    // four questions, which in practice meant a feature nobody had. The book
    // is a file now and the cloud evaluation answers anonymously.
    const c = cloudStub({ [AFTER_E4_E5]: cloud(20), [AFTER_NF3]: cloud(15) });
    const verdict = await judgeWith(bookWith(t), c).judge(AFTER_E4_E5, 'Nf3');

    assert.equal(verdict.verdict, 'playable');
    assert.equal(c.calls(), 2);
    for (const { url, headers } of c.requests) {
      assert.ok(url.includes('cloud-eval'), url);
      assert.equal(headers.Authorization, undefined);
    }
  });

test('the verdict says nothing about a rating band', async (t) => {
  // There is one book. A `band` or a `minRating` in the answer would be read by
  // somebody as still meaning something.
  const book = bookWith(t, [[ITALIAN, 'g8f6', 900, 400, 700]]);
  const verdict = await judgeWith(book, cloudStub()).judge(ITALIAN, 'Nf6', { minRating: 1600 });
  assert.equal('band' in verdict, false);
  assert.equal('minRating' in verdict, false);
  assert.deepEqual(Object.keys(verdict.masters).sort(), ['beyondBook', 'games', 'total']);
});

test('a missing book is a loud refusal, not a move that is "not theory"',
  async () => {
    // Judged by the engine alone, a theory gambit a pawn down would come back a
    // mistake — with nothing on the screen saying the book was never read.
    const c = cloudStub({ [AFTER_E4_E5]: cloud(20), [AFTER_NF3]: cloud(15) });
    const judge = createOpeningJudge({
      book: createOpeningBook({ path: '' }), fetchImpl: c.fetchImpl, ...fakeClock().options,
    });

    await assert.rejects(() => judge.judge(AFTER_E4_E5, 'Nf3'),
      (err) => err instanceof OpeningBookUnavailable && err.reason === 'not-configured');
    await assert.rejects(() => judge.replies(AFTER_E4_E5),
      (err) => err instanceof OpeningBookUnavailable);
    assert.equal(c.calls(), 0);
  });

test('an impossible move and a broken position are the caller\'s mistake',
  async (t) => {
    const c = cloudStub();
    const j = judgeWith(bookWith(t), c);

    await assert.rejects(() => j.judge(AFTER_E4_E5, 'Nf6'), RangeError);
    await assert.rejects(() => j.judge('not a fen', 'Nf3'), RangeError);
    await assert.rejects(() => j.judge(AFTER_E4_E5, ''), RangeError);
    await assert.rejects(() => j.replies('not a fen'), RangeError);
    assert.equal(c.calls(), 0);
  });

test('the same move is judged once, and two moves share the "before" eval',
  async (t) => {
    const c = cloudStub({
      [AFTER_E4_E5]: cloud(20), [AFTER_NF3]: cloud(15), [AFTER_BC4]: cloud(18),
    });
    const j = judgeWith(bookWith(t), c);

    await j.judge(AFTER_E4_E5, 'Nf3');
    assert.equal(c.calls(), 2);
    await j.judge(AFTER_E4_E5, 'Nf3');
    assert.equal(c.calls(), 2, 'isti potez se ne sudi dvaput');

    await j.judge(AFTER_E4_E5, 'Bc4');
    assert.equal(c.calls(), 3, 'only the new position had to be evaluated');
  });

test('a spent allowance and a failed answer are two different answers',
  async (t) => {
    for (const [status, reason] of [[503, 'network'], [429, 'rate-limited']]) {
      const s = { fetchImpl: async () => ({ ok: false, status, json: async () => ({}) }) };
      await assert.rejects(
        () => judgeWith(bookWith(t), s).judge(AFTER_E4_E5, 'Nf3'),
        (err) => {
          assert.equal(err.reason, reason);
          return true;
        },
      );
    }
  });

test('requests to Lichess are spaced out, not fired in a burst', async (t) => {
  const clock = fakeClock();
  const c = cloudStub({ [AFTER_E4_E5]: cloud(20), [AFTER_NF3]: cloud(15) });

  await judgeWith(bookWith(t), c, { clock }).judge(AFTER_E4_E5, 'Nf3');

  assert.equal(c.calls(), 2);
  // One gap between two requests, and the first one goes at once.
  assert.equal(clock.waits.length, 1);
  assert.ok(clock.waits[0] >= 100, `razmak je bio ${clock.waits[0]} ms`);
});

test('after a 429 nothing is sent until the block has passed', async (t) => {
  // Lichess blocks the address for a minute, and for longer if the knocking
  // continues - and this server has one address for every child in the app.
  const clock = fakeClock();
  let sent = 0;
  const s = {
    fetchImpl: async () => {
      sent += 1;
      return { ok: false, status: 429, json: async () => ({}) };
    },
  };
  const j = judgeWith(bookWith(t), s, { clock });

  await assert.rejects(() => j.judge(AFTER_E4_E5, 'Nf3'));
  assert.ok(j.stats().blockedForMs > 0);
  const whileBlocked = sent;

  await assert.rejects(
    () => j.judge(AFTER_E4_E5, 'Bc4'),
    (err) => {
      assert.equal(err.reason, 'rate-limited');
      return true;
    },
  );
  assert.equal(sent, whileBlocked, 'za vreme blokade se ne šalje ništa');

  clock.advance(61 * 1000);
  assert.equal(j.stats().blockedForMs, 0);
  await assert.rejects(() => j.judge(AFTER_E4_E5, 'Bc4'));
  assert.ok(sent > whileBlocked, 'posle isteka blokade se opet pita');
});

// --- The replies a repertoire is built against ----------------------------------

/// Book rows for AFTER_E4_E5 with the given counts, as White-win games.
function repliesBook(t, counts, options) {
  const ucis = { Nf3: 'g1f3', Nc3: 'b1c3', Bc4: 'f1c4', d4: 'd2d4', f4: 'f2f4', a3: 'a2a3' };
  return bookWith(t, counts.map(([san, games]) => [AFTER_E4_E5, ucis[san], games, 0, 0]), options);
}

test('a reply list carries how the games went, not only how many', async (t) => {
  // Popularity answers "how often"; the student comparing two candidates is
  // asking "how well", and that is a different column.
  const book = bookWith(t, [
    [AFTER_E4_E5, 'g1f3', 300, 200, 500],
    [AFTER_E4_E5, 'b1c3', 120, 40, 40],
  ]);

  const answer = await judgeWith(book, cloudStub()).replies(AFTER_E4_E5);

  const [first] = answer.replies;
  assert.equal(first.san, 'Nf3');
  assert.equal(first.games, 1000);
  assert.deepEqual(
    { white: first.white, draws: first.draws, black: first.black },
    { white: 300, draws: 200, black: 500 },
  );
  // And the same on the longer list that gets stored for the drill.
  assert.equal(answer.all[1].san, 'Nc3');
  assert.equal(answer.all[1].white, 120);
});

test('replies stop once enough of what will be met is covered', async (t) => {
  // 60 + 25 = 85%, past the 80% line, so the third is left out. The point is
  // not the two moves - it is that the position now has an end.
  const book = repliesBook(t, [['Nf3', 600], ['Nc3', 250], ['Bc4', 100], ['d4', 50]]);

  const answer = await judgeWith(book, cloudStub()).replies(AFTER_E4_E5);

  assert.deepEqual(answer.replies.map((r) => r.san), ['Nf3', 'Nc3']);
  assert.ok(answer.coveredShare >= COVERAGE_SHARE);
  assert.equal(answer.tail.moves, 2);
  assert.equal(answer.tail.games, 150);
  assert.ok(Math.abs(answer.tail.share - 0.15) < 1e-9);
});

test('a position nobody agrees on is capped rather than endless', async (t) => {
  // Six replies, none of them common: without the cap this is where a position
  // becomes an afternoon.
  const book = repliesBook(t,
    [['Nf3', 20], ['Nc3', 19], ['Bc4', 18], ['d4', 17], ['f4', 16], ['a3', 10]]);

  const answer = await judgeWith(book, cloudStub()).replies(AFTER_E4_E5);

  assert.equal(answer.replies.length, MAX_REPLIES);
  assert.ok(answer.coveredShare < COVERAGE_SHARE,
    'kad se ne stigne do praga, to se vidi u broju');
  assert.equal(answer.tail.moves, 2);
});

test('one overwhelming reply is still one reply', async (t) => {
  const book = repliesBook(t, [['Nf3', 950], ['Nc3', 50]]);
  const answer = await judgeWith(book, cloudStub()).replies(AFTER_E4_E5);
  assert.deepEqual(answer.replies.map((r) => r.san), ['Nf3']);
  assert.equal(answer.tail.moves, 1);
});

test('a position no one has played answers with nothing, not with a guess',
  async (t) => {
    const answer = await judgeWith(bookWith(t), cloudStub()).replies(AFTER_E4_E5);

    assert.deepEqual(answer.replies, []);
    assert.equal(answer.total, 0);
    assert.equal(answer.coveredShare, 0);
    assert.equal(answer.tail.moves, 0);
    assert.equal(answer.beyondBook, false);
  });

test('shares are of the games that reached a position, not of the moves kept',
  async (t) => {
    // A pruned file lists 800 games in two moves of a position 1000 games
    // reached; the other 200 were moves played once each. Taking shares of 800
    // would tell a student two replies cover everything.
    const book = repliesBook(t, [['Nf3', 600], ['Nc3', 200]], {
      totals: [[AFTER_E4_E5, 1000, 0, 0]], maxPly: 50,
    });

    const answer = await judgeWith(book, cloudStub()).replies(AFTER_E4_E5);

    assert.equal(answer.total, 1000);
    assert.equal(answer.all[0].share, 0.6);
    assert.deepEqual(answer.replies.map((r) => r.san), ['Nf3', 'Nc3']);
    assert.equal(answer.coveredShare, 0.8);
    assert.equal(answer.tail.games, 200, 'the unlisted games are the tail too');
    assert.equal(answer.tail.moves, 0, 'and no move is invented to hold them');

    const verdict = await judgeWith(book, cloudStub()).judge(AFTER_E4_E5, 'Nf3');
    assert.deepEqual(verdict.masters, { games: 600, total: 1000, beyondBook: false });
  });

test('a position past the book\'s depth says so, and the engine still judges',
  async (t) => {
    // Ply 30 is White to move on move 16. "Nobody played this" and "this file
    // does not go that far" send a student to different places.
    const deep = 'r1bq1rk1/pp2bppp/2n1pn2/2pp4/3P4/2PBPN2/PP1N1PPP/R2QK2R w KQ - 0 16';
    const deepAfter = 'r1bq1rk1/pp2bppp/2n1pn2/2pp4/3P4/2PBPN2/PP1N1PPP/R2Q1RK1 b - - 1 16';
    // A row exists at the deep position — as a transposition from a shallower
    // ply would leave one — and is still not the book speaking about it.
    const book = bookWith(t, [[deep, 'e1g1', 40, 40, 40]], { maxPly: 30 });
    const c = cloudStub({ [deep]: cloud(30), [deepAfter]: cloud(25) });

    const replies = await judgeWith(book, c).replies(deep);
    assert.equal(replies.beyondBook, true);
    assert.deepEqual(replies.replies, []);

    const verdict = await judgeWith(book, c).judge(deep, 'O-O');
    assert.deepEqual(verdict.masters, { games: 0, total: 0, beyondBook: true });
    assert.equal(verdict.verdict, 'playable');
  });

test('mate is ordered by distance and keeps its side', () => {
  assert.ok(whiteRelativeCp({ mate: 2 }) > whiteRelativeCp({ mate: 9 }));
  assert.ok(whiteRelativeCp({ mate: -2 }) < whiteRelativeCp({ mate: -9 }));
  assert.ok(whiteRelativeCp({ mate: 9 }) > whiteRelativeCp({ cp: 900 }));
  assert.equal(whiteRelativeCp({ cp: -35 }), -35);
  assert.equal(whiteRelativeCp(undefined), null);
});
