// age.test.js
// How old somebody says they are, and the single rule that follows from it.
//
// The rule: **a minor is somebody's student, never somebody's trainer.** With
// it, the app is not a place where children connect to each other — which is
// the answer to the question about which countries it can ship in, and the
// reason it is cheap is that the edge with consent on it already existed.
//
// What these tests deliberately do *not* pin is any protection resting on the
// number itself. A child can type any year. The guest list and the consent on
// each relationship hold whatever is typed here; the age decides which flow
// somebody goes through, not how safe they are.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_AGE_OF_CONSENT,
  parseAgeOfConsent,
  parseStatedYear,
  statedAge,
  ageStatus,
  mayRelate,
  MINIMUM_AGE,
  isUnderMinimumAge,
} = require('../services/ageService');

test('an unset threshold is the strictest applicable one, not none', () => {
  assert.equal(parseAgeOfConsent(undefined), DEFAULT_AGE_OF_CONSENT);
  assert.equal(parseAgeOfConsent(''), DEFAULT_AGE_OF_CONSENT);
  assert.equal(DEFAULT_AGE_OF_CONSENT, 16);
});

test('the threshold is configuration, within the range that has a meaning', () => {
  // Per country, and never above 16 under the GDPR — 18 would be friction
  // without legal benefit. Anything outside 13–18 is implementing no regime at
  // all, so it is a mistake rather than a choice.
  assert.equal(parseAgeOfConsent('13'), 13);
  assert.equal(parseAgeOfConsent(' 15 '), 15);
  for (const bad of ['12', '19', '0', 'sixteen', '16.5', '-16']) {
    assert.throws(() => parseAgeOfConsent(bad), RangeError, `primljeno: ${bad}`);
  }
});

test('a year that was never given is not an age', () => {
  assert.equal(statedAge(null), null);
  assert.equal(statedAge(undefined), null);
  assert.equal(statedAge(''), null);
  assert.equal(statedAge('nešto'), null);
  // Neither is one that cannot be true.
  assert.equal(statedAge(1899), null);
  assert.equal(statedAge(2999, new Date('2026-08-25')), null);
});

test('the ambiguous year resolves towards the younger reading', () => {
  // A year says which of two ages somebody is, and the younger one is taken:
  // born in 2010, they count as 15 for the whole of 2026 — including the day
  // after their sixteenth birthday. That asks a parent when it need not have,
  // which is the direction to be wrong in.
  const during2026 = new Date('2026-12-31');
  assert.equal(statedAge(2010, during2026), 15);
  assert.equal(statedAge(2009, during2026), 16);
  assert.equal(statedAge(2026, during2026), 0);
});

/// Answers `SELECT birth_year` for whoever is asked about.
const poolOfAges = (ages) => ({
  async query(text, params) {
    if (!/birth_year/.test(text)) throw new Error(`neočekivan upit: ${text}`);
    const year = ages[params[0]];
    if (year === 'nema') return { rows: [], rowCount: 0 };
    return {
      rows: [{ birth_year: year === undefined ? null : year }],
      rowCount: 1,
    };
  },
});

const thisYear = new Date().getFullYear();
const bornAgo = (years) => thisYear - years - 1;

test('an age nobody has ever been asked for is unknown, not adult', async () => {
  // Today this is every account: `users` has an email, a name and a password,
  // and nothing has ever asked. "Unknown" collapsing into "adult" is how a rule
  // ends up looking implemented while doing nothing, so it is a value callers
  // have to see.
  const status = await ageStatus(poolOfAges({ 1: null }), 1);
  assert.deepEqual(status, { known: false, minor: false, age: null });

  const missing = await ageStatus(poolOfAges({ 2: 'nema' }), 2);
  assert.equal(missing.known, false);
  assert.equal((await ageStatus(poolOfAges({}), null)).known, false);
});

test('a stated age is known, and either side of the threshold', async () => {
  const child = await ageStatus(poolOfAges({ 1: bornAgo(10) }), 1);
  assert.deepEqual(child, { known: true, minor: true, age: 10 });

  const grown = await ageStatus(poolOfAges({ 1: bornAgo(40) }), 1);
  assert.deepEqual(grown, { known: true, minor: false, age: 40 });
});

test('a minor cannot be the trainer in a relationship', async () => {
  const verdict = await mayRelate(poolOfAges({ 5: bornAgo(12) }),
    { trainerId: 5, studentId: 6 });

  assert.equal(verdict.allowed, false);
  assert.equal(verdict.reason, 'minor-as-trainer');
  assert.match(verdict.message, /Maloletnik/);
});

test('two children are refused whichever way round they ask', async () => {
  // There is no third possibility: one of them has to be the trainer, and that
  // is the one the rule refuses. This is the case the rule exists for — the app
  // is not a place where children connect to each other.
  const ages = { 5: bornAgo(12), 6: bornAgo(11) };
  assert.equal(
    (await mayRelate(poolOfAges(ages), { trainerId: 5, studentId: 6 })).allowed,
    false);
  assert.equal(
    (await mayRelate(poolOfAges(ages), { trainerId: 6, studentId: 5 })).allowed,
    false);
});

test('a child with an adult teacher is the ordinary case', async () => {
  const verdict = await mayRelate(
    poolOfAges({ 5: bornAgo(40), 6: bornAgo(9) }),
    { trainerId: 5, studentId: 6 });

  assert.deepEqual(verdict, { allowed: true, reason: null, message: null });
});

test('while nobody has stated an age, the rule refuses nothing', async () => {
  // Written down rather than discovered later: this is the honest state of the
  // rule until the age gate fills `users.birth_year` — and that gate has to ask
  // **existing** accounts as well as new ones, or this stays a comment. It is
  // the shape of failure this codebase keeps paying for: a step that skips in
  // silence and reports success one layer up.
  const verdict = await mayRelate(poolOfAges({}), { trainerId: 5, studentId: 6 });

  assert.equal(verdict.allowed, true);
});

test('a year that is not a year is refused before it reaches the row', () => {
  // The quiet failure this guards: a value that survives the check but that
  // `statedAge` then reads as no age at all. The account goes back to being one
  // nobody has ever asked, while the screen says the year was saved — the gate
  // undone by the gate.
  const now = new Date('2026-08-25');
  for (const bad of [
    undefined, null, '', '   ', 'dve hiljade', '2014abc', '2014.5', 2014.5,
    0, -2014, 1899, 2027, true, false, [], {},
  ]) {
    const { year, error } = parseStatedYear(bad, now);
    assert.equal(year, null, `primljeno: ${JSON.stringify(bad)}`);
    assert.match(error, /1900/);
  }
});

test('a year that is one is taken, typed or numeric', () => {
  const now = new Date('2026-08-25');
  assert.deepEqual(parseStatedYear(2014, now), { year: 2014, error: null });
  assert.deepEqual(parseStatedYear('2014', now), { year: 2014, error: null });
  assert.deepEqual(parseStatedYear(' 2014 ', now), { year: 2014, error: null });
  // Both ends of the range are inside it.
  assert.equal(parseStatedYear(1900, now).year, 1900);
  assert.equal(parseStatedYear(2026, now).year, 2026);
});

test('every year the check accepts is a year statedAge can read', () => {
  // The two halves have to agree, or a saved year is an account with no age.
  const now = new Date('2026-08-25');
  for (let year = 1900; year <= 2026; year += 1) {
    assert.equal(parseStatedYear(year, now).error, null);
    assert.notEqual(statedAge(year, now), null, `godina: ${year}`);
  }
});


// --------------------------------------------------------------------------
// The floor, added 8.9.2026 with the audience declaration
// --------------------------------------------------------------------------
//
// The app ships as a General Audience product, 13+, rather than as one directed
// to children. That declaration is only true if a stated year below thirteen is
// **refused** — until this existed the code did the opposite, calling such a
// user a minor and routing them into a parent's confirmation, which is
// machinery built to let a child in. COPPA triggers on actual knowledge, and an
// app that asks for a birth year has it.

test('the floor is thirteen, and it is not configuration', () => {
  assert.equal(MINIMUM_AGE, 13);
  // `AGE_OF_CONSENT` varies by country because the law does. This does not:
  // nowhere is the answer below thirteen, and a floor an environment variable
  // can lower is not a floor.
  assert.equal(process.env.MINIMUM_AGE, undefined);
});

test('a year that puts somebody under thirteen is under age', () => {
  assert.equal(isUnderMinimumAge(bornAgo(8)), true);
  assert.equal(isUnderMinimumAge(bornAgo(12)), true);
});

test('and thirteen itself is not', () => {
  assert.equal(isUnderMinimumAge(bornAgo(13)), false);
  assert.equal(isUnderMinimumAge(bornAgo(40)), false);
});

test('it reads the same conservative age everything else does', () => {
  // A year alone cannot say whether a birthday has passed, so `statedAge`
  // answers with the age certainly reached — and this asks that same function
  // rather than inventing a more generous one. Two definitions of one number
  // is a fault this codebase has paid for more than once.
  //
  // The cost, stated rather than hidden: somebody born exactly thirteen
  // calendar years ago is read as twelve until their birthday year turns.
  const thirteenCalendarYearsAgo = thisYear - 13;
  assert.equal(statedAge(thirteenCalendarYearsAgo), 12);
  assert.equal(isUnderMinimumAge(thirteenCalendarYearsAgo), true);
});

test('a year nobody stated is not under age', () => {
  // No statement is not a statement of eleven. `parseStatedYear` is what
  // refuses unreadable input; this must not turn silence into a refusal.
  assert.equal(isUnderMinimumAge(null), false);
  assert.equal(isUnderMinimumAge(undefined), false);
  assert.equal(isUnderMinimumAge('nonsense'), false);
});

test('the parental band is what is left between the floor and the threshold',
  () => {
    // The whole of the „re-pointing" the audience decision asked for. Nothing
    // below thirteen reaches the parent flow any more, so that flow now answers
    // a different question: is this teenager in a country whose threshold is
    // above thirteen? The GDPR's own age is 16 and member states may lower it
    // as far as 13.
    for (let age = MINIMUM_AGE; age < DEFAULT_AGE_OF_CONSENT; age += 1) {
      assert.equal(isUnderMinimumAge(bornAgo(age)), false,
        `${age} must be allowed an account`);
      assert.ok(age < DEFAULT_AGE_OF_CONSENT,
        `${age} must still be asked for a parent where the threshold is 16`);
    }
  });
