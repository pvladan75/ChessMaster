// game_archive.test.js — what becomes a row, what does not, and the count.
//
// The handles here are invented. Real ones are account identifiers and this
// repository is public, so the fixtures say `subjekat` and `protivnik` rather
// than anybody's Lichess name.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  SKIP,
  normaliseGame,
  createTally,
  speedFromTimeControl,
  clockToCentiseconds,
} = require('../services/gameArchive');

const OPTIONS = { subject: 'subjekat', source: 'lichess' };

/// A Lichess export of one game, with the headers a real one carries.
function pgn({
  white = 'subjekat',
  black = 'protivnik',
  result = '1-0',
  moves = '1. e4 c5 2. Nf3 d6 1-0',
  extra = '',
} = {}) {
  return `[Event "rated blitz game"]
[Site "https://lichess.org/SaaGKq5o"]
[Date "2026.07.05"]
[White "${white}"]
[Black "${black}"]
[Result "${result}"]
[GameId "SaaGKq5o"]
[UTCDate "2026.07.05"]
[UTCTime "13:04:55"]
[WhiteElo "1950"]
[BlackElo "2010"]
[Variant "Standard"]
[TimeControl "180+2"]
[ECO "B50"]
[Opening "Sicilian Defense"]
[Termination "Normal"]
${extra}
${moves}`;
}

test('a played game becomes a row seen from the subject\'s side', () => {
  const { ok, row } = normaliseGame(pgn(), OPTIONS);
  assert.equal(ok, true);
  assert.equal(row.subject, 'subjekat');
  assert.equal(row.subject_color, 'w');
  assert.equal(row.subject_score, 1);
  assert.equal(row.subject_elo, 1950);
  assert.equal(row.opponent, 'protivnik');
  assert.equal(row.opponent_elo, 2010);
  assert.equal(row.external_id, 'SaaGKq5o');
  assert.equal(row.eco, 'B50');
  assert.equal(row.opening, 'Sicilian Defense');
  assert.equal(row.speed, 'blitz');
  assert.equal(row.rated, true);
  assert.deepEqual(row.moves, ['e2e4', 'c7c5', 'g1f3', 'd7d6']);
  assert.equal(row.ply_count, 4);
  assert.equal(row.played_at.toISOString(), '2026-07-05T13:04:55.000Z');
});

test('the same game from the other side inverts colour and score', () => {
  // The row is written from the subject's point of view and not the owner's,
  // which is what lets one table hold an opponent's archive too. A score that
  // stayed White-relative would make every "how do I do here" query wrong for
  // half the games, and wrong while still returning numbers.
  const { row } = normaliseGame(
    pgn({ white: 'protivnik', black: 'subjekat' }),
    OPTIONS,
  );
  assert.equal(row.subject_color, 'b');
  assert.equal(row.subject_score, 0);
  assert.equal(row.subject_elo, 2010);
  assert.equal(row.opponent_elo, 1950);
});

test('a draw is half a point to whoever is asking', () => {
  for (const white of ['subjekat', 'protivnik']) {
    const black = white === 'subjekat' ? 'protivnik' : 'subjekat';
    const { row } = normaliseGame(
      pgn({ white, black, result: '1/2-1/2', moves: '1. e4 c5 1/2-1/2' }),
      OPTIONS,
    );
    assert.equal(row.subject_score, 0.5);
  }
});

test('clocks land per ply, in centiseconds', () => {
  const { row } = normaliseGame(pgn({
    moves: '1. e4 { [%clk 0:03:00] } c5 { [%clk 0:02:58] } '
      + '2. Nf3 { [%clk 0:02:59.5] } d6 1-0',
  }), OPTIONS);
  assert.deepEqual(row.clocks, [18000, 17800, 17950, null]);
  assert.equal(row.clocks.length, row.ply_count);
});

test('an export without clocks stores null, not a row of nulls', () => {
  // An array of nulls reads as "the clocks are known and they are empty", and
  // the time-trouble work would then quietly analyse an archive that never had
  // any. Absent has to look absent.
  const { row } = normaliseGame(pgn(), OPTIONS);
  assert.equal(row.clocks, null);
});

test('the fewest men and the ply that entered the tables are written once', () => {
  const { row } = normaliseGame(pgn({
    moves: '1. e4 e5 2. Qh5 Nf6 3. Qxe5+ Qe7 4. Qxe7+ Bxe7 1-0',
  }), OPTIONS);
  // Three captures off 32: the e-pawn, then the queens.
  assert.equal(row.min_men, 29);
  assert.equal(row.tb_entry_ply, null);

  const endgame = normaliseGame(
    `[White "subjekat"]
[Black "protivnik"]
[Result "1-0"]
[FEN "8/8/8/4k3/8/8/4P3/4K3 w - - 0 1"]

1. e4 Kd6 1-0`,
    OPTIONS,
  );
  assert.equal(endgame.row.min_men, 3);
  // Zero and not one: this game began inside tablebase range, and null has to
  // keep meaning "never got there".
  assert.equal(endgame.row.tb_entry_ply, 0);
  assert.equal(endgame.row.start_fen, '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1');
});

test('a game with no id of its own gets one derived from its moves', () => {
  const withoutId = `[White "subjekat"]
[Black "protivnik"]
[Result "1-0"]

1. e4 c5 1-0`;
  const first = normaliseGame(withoutId, { subject: 'subjekat', source: 'pgn' });
  const again = normaliseGame(withoutId, { subject: 'subjekat', source: 'pgn' });
  assert.match(first.row.external_id, /^g_[0-9a-f]{20}$/);
  assert.equal(first.row.external_id, again.row.external_id);

  const different = normaliseGame(
    withoutId.replace('1. e4 c5', '1. d4 d5'),
    { subject: 'subjekat', source: 'pgn' },
  );
  assert.notEqual(first.row.external_id, different.row.external_id);
});

test('the five refusals are named, and none of them throws', () => {
  const cases = [
    ['this is not a pgn at all', SKIP.UNPARSABLE],
    [pgn({ extra: '[Variant "Chess960"]\n' }), SKIP.NOT_STANDARD],
    [pgn({ result: '*', moves: '1. e4 c5 *' }), SKIP.NO_RESULT],
    [pgn({ white: 'neko', black: 'drugi' }), SKIP.SUBJECT_ABSENT],
    [pgn({ moves: '1-0' }), SKIP.NO_MOVES],
  ];
  for (const [text, reason] of cases) {
    const outcome = normaliseGame(text, OPTIONS);
    assert.equal(outcome.ok, false, `expected a refusal for ${reason}`);
    assert.equal(outcome.reason, reason);
  }
});

test('the subject is matched without regard to case', () => {
  const { ok, row } = normaliseGame(pgn({ white: 'SubJekat' }), OPTIONS);
  assert.equal(ok, true);
  assert.equal(row.subject_color, 'w');
});

test('a missing subject or an unknown source is a bug, not a skip', () => {
  // These cannot come from the archive — they come from the caller — so they
  // fail loudly instead of being counted as one more unusable game.
  assert.throws(() => normaliseGame(pgn(), { source: 'lichess' }), TypeError);
  assert.throws(
    () => normaliseGame(pgn(), { subject: 'subjekat', source: 'chessbase' }),
    TypeError,
  );
});

test('speed comes from the time control, not from the event line', () => {
  assert.equal(speedFromTimeControl('180+2'), 'blitz');
  assert.equal(speedFromTimeControl('60+0'), 'bullet');
  assert.equal(speedFromTimeControl('15+0'), 'ultrabullet');
  assert.equal(speedFromTimeControl('600+0'), 'rapid');
  assert.equal(speedFromTimeControl('1800+0'), 'classical');
  // Increment counts: 3+2 is blitz, but 2+12 is a rapid game on the clock.
  assert.equal(speedFromTimeControl('120+12'), 'rapid');
  assert.equal(speedFromTimeControl('-'), null);
  assert.equal(speedFromTimeControl(undefined), null);
});

test('a clock is read only where one was written', () => {
  assert.equal(clockToCentiseconds('[%clk 0:01:00]'), 6000);
  assert.equal(clockToCentiseconds('[%eval 0.24]'), null);
  assert.equal(clockToCentiseconds(''), null);
  assert.equal(clockToCentiseconds(undefined), null);
});

test('the tally closes only when every game read is accounted for', () => {
  const tally = createTally();
  for (let i = 0; i < 5; i += 1) tally.read();
  tally.stored();
  tally.stored();
  tally.duplicate();
  tally.skipped(SKIP.NOT_STANDARD);
  tally.skipped(SKIP.NO_MOVES);

  const snapshot = tally.assertBalanced();
  assert.equal(snapshot.read, 5);
  assert.equal(snapshot.stored, 2);
  assert.equal(snapshot.duplicate, 1);
  assert.equal(snapshot.skipped, 2);
  assert.deepEqual(snapshot.skipped_by_reason, {
    'not-standard-variant': 1,
    'no-moves': 1,
  });
});

test('a game that goes missing stops the run instead of being reported done', () => {
  // This is the whole reason the tally exists. Two hundred games in, one
  // vanishes between reading and writing; without this the import writes
  // 'done' next to a number that is short and nobody ever learns which games
  // are not there.
  const tally = createTally();
  tally.read();
  tally.read();
  tally.stored();
  assert.throws(() => tally.assertBalanced(), /import lost games: read 2, accounted 1/);
});

test('an unnamed skip reason is refused', () => {
  // Otherwise a typo becomes a second bucket that looks like a third kind of
  // failure, and the reasons shown to the user stop adding up to the total.
  const tally = createTally();
  assert.throws(() => tally.skipped('zato sto'), RangeError);
});
