const test = require('node:test');
const assert = require('node:assert');

const { normaliseIntervals, buildFilterComplex } = require('../services/audioTrimmer');

test('intervals are ordered by start', () => {
  const out = normaliseIntervals([
    { startMs: 8000, endMs: 9000 },
    { startMs: 1000, endMs: 2000 },
  ]);
  assert.deepStrictEqual(out, [
    { startMs: 1000, endMs: 2000 },
    { startMs: 8000, endMs: 9000 },
  ]);
});

test('zero-length and inverted intervals are dropped', () => {
  // A double tap on pause, or a payload someone edited by hand. Passing these
  // through would put nonsense in the filter expression.
  const out = normaliseIntervals([
    { startMs: 5000, endMs: 5000 },
    { startMs: 9000, endMs: 3000 },
    { startMs: 1000, endMs: 2000 },
  ]);
  assert.deepStrictEqual(out, [{ startMs: 1000, endMs: 2000 }]);
});

test('overlapping intervals are merged', () => {
  // Overlaps must never reach the filter: two `between()` terms covering the
  // same instant sum to 2, and `not(2)` is 0 just like `not(1)`, so the cut
  // would still happen — but the arithmetic is only accidentally right, and
  // adjacent-but-separate merges keep the expression honest.
  const out = normaliseIntervals([
    { startMs: 1000, endMs: 5000 },
    { startMs: 4000, endMs: 8000 },
  ]);
  assert.deepStrictEqual(out, [{ startMs: 1000, endMs: 8000 }]);
});

test('touching intervals are merged', () => {
  const out = normaliseIntervals([
    { startMs: 1000, endMs: 2000 },
    { startMs: 2000, endMs: 3000 },
  ]);
  assert.deepStrictEqual(out, [{ startMs: 1000, endMs: 3000 }]);
});

test('garbage in the payload is ignored rather than trusted', () => {
  assert.deepStrictEqual(normaliseIntervals(null), []);
  assert.deepStrictEqual(normaliseIntervals('nope'), []);
  assert.deepStrictEqual(normaliseIntervals([{ startMs: 'a', endMs: 'b' }]), []);
  assert.deepStrictEqual(normaliseIntervals([{}]), []);
});

test('a negative start is clamped to the beginning of the file', () => {
  const out = normaliseIntervals([{ startMs: -500, endMs: 2000 }]);
  assert.deepStrictEqual(out, [{ startMs: 0, endMs: 2000 }]);
});

test('the graph keeps the stretches between the pauses', () => {
  const { filter, outLabel } = buildFilterComplex([
    { startMs: 5000, endMs: 35000 },
    { startMs: 60000, endMs: 61500 },
  ]);

  assert.strictEqual(
    filter,
    '[0:a]atrim=start=0.000:end=5.000,asetpts=N/SR/TB[s0];' +
    '[0:a]atrim=start=35.000:end=60.000,asetpts=N/SR/TB[s1];' +
    '[0:a]atrim=start=61.500,asetpts=N/SR/TB[s2];' +
    '[s0][s1][s2]concat=n=3:v=0:a=1[out]'
  );
  assert.strictEqual(outLabel, '[out]');
});

test('the tail after the last pause is left open-ended', () => {
  // The recording runs on past the last resume and its length is not known
  // here; pinning an end would truncate whatever came after.
  const { filter } = buildFilterComplex([{ startMs: 5000, endMs: 8000 }]);
  assert.match(filter, /atrim=start=8\.000,asetpts/);
  assert.doesNotMatch(filter, /atrim=start=8\.000:end=/);
});

test('a pause at the very start produces no empty leading stretch', () => {
  const { filter } = buildFilterComplex([{ startMs: 0, endMs: 4000 }]);
  assert.strictEqual(filter, '[0:a]atrim=start=4.000,asetpts=N/SR/TB[s0]');
});

test('a single surviving stretch needs no concat', () => {
  const { filter, outLabel } = buildFilterComplex([{ startMs: 0, endMs: 4000 }]);
  assert.doesNotMatch(filter, /concat/);
  assert.strictEqual(outLabel, '[s0]', 'concat is what produces [out]');
});

test('milliseconds survive the conversion to seconds', () => {
  // Truncating to whole seconds would shift every later move by up to a second.
  const { filter } = buildFilterComplex([{ startMs: 1234, endMs: 5678 }]);
  assert.match(filter, /end=1\.234/);
  assert.match(filter, /start=5\.678/);
});
