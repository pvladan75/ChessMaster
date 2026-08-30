// narrative_guard.test.js — the model may restate the numbers, and may not invent one.
//
// The interesting cases are not the obvious lie. They are the helpful ones: a
// rounded percentage, a total nobody asked for, a "nearly 50" that is close
// enough to look computed. Every one of those reads like the rest of the
// sentence, and the point of this guard is that none of them get through.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  checkNarrative, inventedNumerals, numeralsIn, normalise,
} = require('../services/narrativeGuard');

/// A report of the shape section 1 produces, pointed at an opponent.
const FACTS = {
  subject: 'rival',
  games: 4126,
  nodes: [
    { fen: 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      ply: 2, games: 121, score: 0.413,
      moves: [{ san: 'c5', games: 92, score: 0.38, share: 0.76 }] },
  ],
};

test('a sentence that only restates computed numbers is allowed', () => {
  const verdict = checkNarrative(
    'Na 1.e4 odgovara sa 1...c5 u 92 od 121 partije, sa prolaznošću 41.3%.',
    FACTS,
  );
  assert.equal(verdict.ok, true, verdict.invented?.join(', '));
});

test('a rounded percentage is refused, however close it is', () => {
  // The whole failure mode in one line. 40 is not 41.3, and a player cannot
  // tell which of the two came out of their archive.
  const verdict = checkNarrative('Prolaznost mu je oko 40% u toj poziciji.', FACTS);

  assert.equal(verdict.ok, false);
  assert.equal(verdict.reason, 'invented-numbers');
  assert.deepEqual(verdict.invented, ['40']);
});

test('a total nobody computed is refused', () => {
  const verdict = checkNarrative('U preko 200 partija bira isti plan.', FACTS);

  assert.equal(verdict.ok, false);
  assert.deepEqual(verdict.invented, ['200']);
});

test('the refusal names every invented number, not just the first', () => {
  // A refusal that says "no" and nothing else is one nobody can debug, and this
  // guard will sometimes be wrong.
  const verdict = checkNarrative('Igrao je 300 partija sa 55% i 12 pobeda.', FACTS);

  assert.equal(verdict.ok, false);
  assert.deepEqual(verdict.invented, ['300', '55', '12']);
});

test('a share in the data may be said as a percentage', () => {
  // 0.76 is how the report holds it; "76%" is how a sentence says it. Both
  // roundings are computed here from the input, never taken from the output.
  assert.equal(checkNarrative('Taj potez bira u 76% slučajeva.', FACTS).ok, true);
  assert.equal(checkNarrative('Skor mu je 38%.', FACTS).ok, true);
});

test('move numbers and small counts are not statistics', () => {
  // "1.e4" and "2. potez" are how chess prose writes moves. Refusing them would
  // make the guard unusable, and a guard that is unusable gets switched off.
  assert.equal(checkNarrative('Posle 1.e4 c5 2.Nf3 bira mirniji plan.', FACTS).ok, true);
});

test('an empty answer is a failure, not an empty sentence', () => {
  // A model that returns nothing must not read as a player with nothing to say.
  for (const answer of ['', '   ', null, undefined]) {
    const verdict = checkNarrative(answer, FACTS);
    assert.equal(verdict.ok, false);
    assert.equal(verdict.reason, 'empty');
  }
});

test('the same number written two ways is the same number', () => {
  assert.equal(normalise('41,30'), '41.3');
  assert.equal(normalise('41.3'), '41.3');
  assert.equal(normalise('4.126'), '4126', 'a thousands separator is not a decimal');
  assert.equal(normalise('4126'), '4126');

  assert.equal(checkNarrative('Odigrao je 4.126 partija.', FACTS).ok, true);
  assert.equal(checkNarrative('Prolaznost 41,3%.', FACTS).ok, true);
});

test('numerals are found however deeply they are nested', () => {
  const found = numeralsIn(FACTS);

  assert.equal(found.has('121'), true, 'a count two levels down');
  assert.equal(found.has('92'), true, 'and one three levels down');
  assert.equal(found.has('41.3'), true, 'a share, as the percentage it will be said as');
  assert.equal(found.has('4126'), true);
});

test('a numeral inside a FEN or a key counts as given', () => {
  // Not a licence — an acknowledgement. Those numerals really are in the input,
  // and pretending otherwise would refuse sentences that quote a position.
  const verdict = checkNarrative('U poziciji posle 2. poteza stoji 0 pešaka viška.', FACTS);
  assert.equal(verdict.ok, true);
});

test('the guard fails closed when the facts are empty', () => {
  // Nothing computed means nothing may be said with a number in it. The
  // dangerous default would be the other one.
  const verdict = inventedNumerals('Skor mu je 47% u 88 partija.', {});
  assert.deepEqual(verdict, ['47', '88']);
});
