const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createOpeningJudge,
  whiteRelativeCp,
  sanLine,
  COVERAGE_SHARE,
  MAX_REPLIES,
  OpeningJudgeUnavailable,
  MIN_MASTER_GAMES,
} = require('../services/openingJudgeService');

// After 1.e4 e5 2.Nf3 Nc6 3.Bc4 — Black to move, the Italian.
const ITALIAN = 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 5 4';
// After 1.e4 — White to move next is not the point; this one has White to move.
const AFTER_E4_E5 = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';

/// A stubbed Lichess: masters, the rating-band explorer, and the cloud
/// evaluation, told apart by the URL the way the service tells them apart.
///
/// `evals` is keyed by the FEN so the two positions of one move - before and
/// after - can disagree, which is the whole subject of most of these tests.
function stub({ masters = { moves: [] }, band = { moves: [] }, evals = {} } = {}) {
  const urls = [];
  const fetchImpl = async (url) => {
    urls.push(url);
    const parsed = new URL(url);
    const fen = parsed.searchParams.get('fen');

    // Matched in this order and by these exact paths: `https://lichess.org`
    // contains the substring `/lichess`, so a looser test for the band
    // explorer swallows every cloud-eval request and every verdict comes back
    // "unknown" for a reason nothing in the service explains.
    if (url.includes('explorer.lichess.ovh/masters')) {
      return { ok: true, status: 200, json: async () => masters };
    }
    if (url.includes('explorer.lichess.ovh/lichess')) {
      return { ok: true, status: 200, json: async () => band };
    }
    const answer = evals[fen];
    // The cloud answers 404 for a position it has never been asked about, and
    // that is an answer, not a fault.
    if (!answer) return { ok: false, status: 404, json: async () => ({}) };
    return { ok: true, status: 200, json: async () => answer };
  };
  return {
    fetchImpl,
    urls,
    calls: () => urls.length,
    to: (part) => urls.filter((u) => u.includes(part)).length,
  };
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

function judge(s, opts = {}) {
  const clock = opts.clock ?? fakeClock();
  const { clock: _ignored, ...rest } = opts;
  return createOpeningJudge({
    fetchImpl: s.fetchImpl, ...clock.options, ...rest,
  });
}

/// One cloud answer. `cp` is White-relative, which is how Lichess reports it.
const cloud = (cp, depth = 40) => ({ depth, pvs: [{ moves: 'e2e4', cp }] });
const cloudMate = (mate) => ({ depth: 40, pvs: [{ moves: 'e2e4', mate }] });

test('a move masters keep playing is theory, and the engine is not asked',
  async () => {
    const s = stub({
      masters: {
        moves: [{ uci: 'g8f6', san: 'Nf6', white: 900, draws: 400, black: 700 }],
      },
    });

    const verdict = await judge(s).judge(ITALIAN, 'Nf6', { token: 'lip_x' });

    assert.equal(verdict.verdict, 'theory');
    assert.equal(verdict.san, 'Nf6');
    assert.equal(verdict.uci, 'g8f6');
    assert.equal(verdict.masters.games, 2000);
    // The books outrank the engine, so nothing else was asked - which is also
    // three requests of somebody's allowance not spent.
    assert.equal(s.to('cloud-eval'), 0);
    assert.equal(s.to('explorer.lichess.ovh/lichess'), 0);
  });

test('a handful of master games is not theory yet', async () => {
  const games = MIN_MASTER_GAMES - 1;
  const s = stub({
    masters: { moves: [{ uci: 'g8f6', san: 'Nf6', white: games, draws: 0, black: 0 }] },
    band: { moves: [{ uci: 'g8f6', san: 'Nf6', white: 40, draws: 10, black: 50 }] },
    evals: {
      [ITALIAN]: cloud(20),
      // Black to move played Nf6; White is a shade better after it either way.
      'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 6 5': cloud(30),
    },
  });

  const verdict = await judge(s).judge(ITALIAN, 'Nf6', { token: 'lip_x' });

  assert.equal(verdict.verdict, 'playable');
  assert.equal(verdict.band.games, 100);
});

test("a black move is judged from black's side, not from white's", async () => {
  // The one mistake here that no amount of reading catches: Lichess reports
  // cloud evaluations from White's point of view, so a move that hands White
  // three pawns reads as an *improvement* if the sign is left alone. Before:
  // -50, Black half a pawn better. After: +300, White three pawns better. From
  // Black's side that is a loss of 3.5 pawns.
  const s = stub({
    masters: { moves: [] },
    band: { moves: [] },
    evals: {
      [ITALIAN]: cloud(-50),
      'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 6 5': cloud(300),
    },
  });

  const verdict = await judge(s).judge(ITALIAN, 'Nf6', { token: 'lip_x' });

  assert.equal(verdict.moverIsWhite, false);
  assert.equal(verdict.eval.beforeCp, 50);
  assert.equal(verdict.eval.afterCp, -300);
  assert.equal(verdict.eval.lossCp, 350);
  assert.equal(verdict.verdict, 'mistake');
});

test('a white move that gives nothing away is playable', async () => {
  const s = stub({
    masters: { moves: [] },
    band: { moves: [{ uci: 'g1f3', san: 'Nf3', white: 10, draws: 2, black: 8 }] },
    evals: {
      [AFTER_E4_E5]: cloud(22),
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2': cloud(15),
    },
  });

  const verdict = await judge(s).judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });

  assert.equal(verdict.verdict, 'playable');
  assert.equal(verdict.eval.lossCp, 7);
});

test('a move that keeps a lost position lost is not playable', async () => {
  // Loses nothing - there is nothing left to lose - and calling it playable
  // would be true arithmetic and a lie to the child looking at it.
  const s = stub({
    masters: { moves: [] },
    band: { moves: [] },
    evals: {
      [AFTER_E4_E5]: cloud(-400),
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2': cloud(-400),
    },
  });

  const verdict = await judge(s).judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });

  assert.equal(verdict.eval.lossCp, 0);
  assert.equal(verdict.verdict, 'mistake');
});

test('a move that walks into mate is a mistake, and the mate is passed on',
  async () => {
    const s = stub({
      masters: { moves: [] },
      band: { moves: [] },
      evals: {
        [AFTER_E4_E5]: cloud(20),
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2':
          cloudMate(-3),
      },
    });

    const verdict = await judge(s).judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });

    assert.equal(verdict.verdict, 'mistake');
    // White played, so a mate for Black is a mate against the mover.
    assert.equal(verdict.eval.mateAfter, -3);
  });

test('a mistake says what to play instead, and how it gets punished',
  async () => {
    // Both lines come with the evaluations that were fetched anyway. A verdict
    // that only scores the move teaches nothing - that lesson was already paid
    // for in the endgame trainer, where a count of remaining moves without the
    // moves themselves had to be replaced.
    const s = stub({
      masters: { moves: [] },
      band: { moves: [] },
      evals: {
        [AFTER_E4_E5]: { depth: 40, pvs: [{ moves: 'g1f3 b8c6', cp: 20 }] },
        'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2':
          { depth: 40, pvs: [{ moves: 'd8h4 g1f3 h4e4', cp: -400 }] },
      },
    });

    const verdict = await judge(s).judge(AFTER_E4_E5, 'Bc4', { token: 'lip_x' });

    assert.equal(verdict.verdict, 'mistake');
    assert.equal(verdict.eval.better, 'Nf3');
    assert.deepEqual(verdict.eval.punishment, ['Qh4', 'Nf3', 'Qxe4+']);
  });

test('a playable move is not given advice it does not need', async () => {
  const s = stub({
    masters: { moves: [] },
    band: { moves: [] },
    evals: {
      [AFTER_E4_E5]: { depth: 40, pvs: [{ moves: 'g1f3 b8c6', cp: 22 }] },
      'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2':
        { depth: 40, pvs: [{ moves: 'g8f6', cp: 15 }] },
    },
  });

  const verdict = await judge(s).judge(AFTER_E4_E5, 'Bc4', { token: 'lip_x' });

  assert.equal(verdict.verdict, 'playable');
  assert.equal(verdict.eval.better, null);
  assert.deepEqual(verdict.eval.punishment, []);
});

test('a line that does not fit the position is dropped, not half-printed', () => {
  assert.deepEqual(sanLine(AFTER_E4_E5, ['g1f3', 'a1a8', 'b8c6'], 3), ['Nf3']);
  assert.deepEqual(sanLine('not a fen', ['g1f3'], 1), []);
  assert.deepEqual(sanLine(AFTER_E4_E5, [], 3), []);
});

test('a position the cloud has never seen is not called a mistake', async () => {
  const s = stub({ masters: { moves: [] }, band: { moves: [] }, evals: {} });

  const verdict = await judge(s).judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });

  assert.equal(verdict.verdict, 'unknown');
  assert.equal(verdict.reason, 'no-eval');
  assert.equal(verdict.eval, null);
});

test('without a token of their own, nothing is asked and nothing is spent',
  async () => {
    const s = stub({ masters: { moves: [] } });

    await assert.rejects(
      () => judge(s).judge(AFTER_E4_E5, 'Nf3', { token: '' }),
      (err) => {
        assert.ok(err instanceof OpeningJudgeUnavailable);
        assert.equal(err.reason, 'no-token');
        assert.equal(err.status, 403);
        return true;
      },
    );
    assert.equal(s.calls(), 0);
  });

test('an impossible move and a broken position are the caller\'s mistake',
  async () => {
    const s = stub();
    const j = judge(s);

    await assert.rejects(() => j.judge(AFTER_E4_E5, 'Nf6', { token: 'lip_x' }),
      RangeError);
    await assert.rejects(() => j.judge('not a fen', 'Nf3', { token: 'lip_x' }),
      RangeError);
    await assert.rejects(() => j.judge(AFTER_E4_E5, '', { token: 'lip_x' }),
      RangeError);
    assert.equal(s.calls(), 0);
  });

test('the same move is judged once, and two moves share one book and one eval',
  async () => {
    const s = stub({
      masters: { moves: [] },
      band: { moves: [] },
      evals: {
        [AFTER_E4_E5]: cloud(20),
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2': cloud(15),
        'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2': cloud(18),
      },
    });
    const j = judge(s);

    await j.judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });
    const first = s.calls();
    await j.judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });
    assert.equal(s.calls(), first, 'isti potez se ne sudi dvaput');

    await j.judge(AFTER_E4_E5, 'Bc4', { token: 'lip_x' });
    // Only the evaluation of the new position had to be fetched: both books and
    // the "before" evaluation were already known.
    assert.equal(s.calls(), first + 1);
  });

test('a refused token and a spent allowance are two different answers',
  async () => {
    for (const [status, reason] of [[401, 'unauthorized'], [429, 'rate-limited']]) {
      const s = {
        fetchImpl: async () => ({ ok: false, status, json: async () => ({}) }),
      };
      await assert.rejects(
        () => judge(s).judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' }),
        (err) => {
          assert.equal(err.reason, reason);
          return true;
        },
      );
    }
  });

test('requests to Lichess are spaced out, not fired in a burst', async () => {
  // Their Explorer is computed, not served from a file, and the documented ask
  // is 100-200 ms between calls. Judging one move is four of them.
  const clock = fakeClock();
  const s = stub({
    masters: { moves: [] },
    band: { moves: [] },
    evals: {
      [AFTER_E4_E5]: cloud(20),
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2': cloud(15),
    },
  });

  await judge(s, { clock }).judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });

  assert.equal(s.calls(), 4);
  // Three gaps between four requests, and the first one goes at once.
  assert.equal(clock.waits.length, 3);
  for (const waited of clock.waits) {
    assert.ok(waited >= 100, `razmak je bio ${waited} ms`);
  }
});

test('after a 429 nothing is sent until the block has passed', async () => {
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
  const j = judge(s, { clock });

  await assert.rejects(() => j.judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' }));
  assert.equal(sent, 1);
  assert.ok(j.stats().blockedForMs > 0);

  // Second attempt while the block stands: refused here, and nothing leaves.
  await assert.rejects(
    () => j.judge(AFTER_E4_E5, 'Bc4', { token: 'lip_x' }),
    (err) => {
      assert.equal(err.reason, 'rate-limited');
      return true;
    },
  );
  assert.equal(sent, 1, 'za vreme blokade se ne šalje ništa');

  clock.advance(61 * 1000);
  assert.equal(j.stats().blockedForMs, 0);
  await assert.rejects(() => j.judge(AFTER_E4_E5, 'Bc4', { token: 'lip_x' }));
  assert.equal(sent, 2, 'posle isteka blokade se opet pita');
});

/// A band answer with the given game counts, in the order Lichess returns them.
function bandOf(counts) {
  return {
    moves: counts.map(([san, games], i) => ({
      uci: `x${i}`, san, white: games, draws: 0, black: 0,
    })),
  };
}

test('a reply list carries how the games went, not only how many', async () => {
  // Popularity answers "how often"; the student comparing two candidates is
  // asking "how well", and that is a different column.
  const s = stub({
    band: {
      moves: [
        { uci: 'b8c6', san: 'Nc6', white: 300, draws: 200, black: 500 },
        { uci: 'd7d6', san: 'd6', white: 120, draws: 40, black: 40 },
      ],
    },
  });

  const answer = await judge(s).replies(AFTER_E4_E5, { token: 'lip_x' });

  const [first] = answer.replies;
  assert.equal(first.san, 'Nc6');
  assert.equal(first.games, 1000);
  assert.deepEqual(
    { white: first.white, draws: first.draws, black: first.black },
    { white: 300, draws: 200, black: 500 },
  );
  // And the same on the longer list that gets stored for the drill.
  assert.equal(answer.all[1].san, 'd6');
  assert.equal(answer.all[1].white, 120);
});

test('replies stop once enough of what will be met is covered', async () => {
  // 60 + 25 = 85%, past the 80% line, so the third is left out. The point is
  // not the two moves - it is that the position now has an end.
  const s = stub({ band: bandOf([['Nc6', 600], ['d6', 250], ['e6', 100], ['a6', 50]]) });

  const answer = await judge(s).replies(AFTER_E4_E5, { token: 'lip_x' });

  assert.deepEqual(answer.replies.map((r) => r.san), ['Nc6', 'd6']);
  assert.ok(answer.coveredShare >= COVERAGE_SHARE);
  assert.equal(answer.tail.moves, 2);
  assert.equal(answer.tail.games, 150);
  assert.ok(Math.abs(answer.tail.share - 0.15) < 1e-9);
});

test('a position nobody agrees on is capped rather than endless', async () => {
  // Six replies, none of them common: without the cap this is where a position
  // becomes an afternoon.
  const s = stub({
    band: bandOf([['a', 20], ['b', 19], ['c', 18], ['d', 17], ['e', 16], ['f', 10]]),
  });

  const answer = await judge(s).replies(AFTER_E4_E5, { token: 'lip_x' });

  assert.equal(answer.replies.length, MAX_REPLIES);
  assert.ok(answer.coveredShare < COVERAGE_SHARE,
    'kad se ne stigne do praga, to se vidi u broju');
  assert.equal(answer.tail.moves, 2);
});

test('one overwhelming reply is still one reply', async () => {
  const s = stub({ band: bandOf([['Nc6', 950], ['d6', 50]]) });

  const answer = await judge(s).replies(AFTER_E4_E5, { token: 'lip_x' });

  assert.deepEqual(answer.replies.map((r) => r.san), ['Nc6']);
  assert.equal(answer.tail.moves, 1);
});

test('a position no one has played answers with nothing, not with a guess',
  async () => {
    const s = stub({ band: { moves: [] } });

    const answer = await judge(s).replies(AFTER_E4_E5, { token: 'lip_x' });

    assert.deepEqual(answer.replies, []);
    assert.equal(answer.total, 0);
    assert.equal(answer.coveredShare, 0);
    assert.equal(answer.tail.moves, 0);
  });

test("replies are not fetched without the caller's own token", async () => {
  const s = stub({ band: bandOf([['Nc6', 100]]) });

  await assert.rejects(
    () => judge(s).replies(AFTER_E4_E5, { token: '' }),
    (err) => {
      assert.equal(err.reason, 'no-token');
      return true;
    },
  );
  assert.equal(s.calls(), 0);
});

test('the book a reply list reads is the one the verdict already paid for',
  async () => {
    // Building asks for the replies and then judges the move the student picks;
    // both read the same band answer, so the second costs nothing.
    const s = stub({
      band: bandOf([['Nc6', 900]]),
      masters: { moves: [] },
      evals: {
        [AFTER_E4_E5]: cloud(20),
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2': cloud(15),
      },
    });
    const j = judge(s);

    await j.replies(AFTER_E4_E5, { token: 'lip_x' });
    const afterReplies = s.calls();
    await j.judge(AFTER_E4_E5, 'Nf3', { token: 'lip_x' });

    assert.equal(s.to('explorer.lichess.ovh/lichess'), 1,
      'traka se čita jednom po poziciji');
    assert.equal(s.calls(), afterReplies + 3, 'majstori i dve ocene');
  });

test('mate is ordered by distance and keeps its side', () => {
  assert.ok(whiteRelativeCp({ mate: 2 }) > whiteRelativeCp({ mate: 9 }));
  assert.ok(whiteRelativeCp({ mate: -2 }) < whiteRelativeCp({ mate: -9 }));
  assert.ok(whiteRelativeCp({ mate: 9 }) > whiteRelativeCp({ cp: 900 }));
  assert.equal(whiteRelativeCp({ cp: -35 }), -35);
  assert.equal(whiteRelativeCp(undefined), null);
});
