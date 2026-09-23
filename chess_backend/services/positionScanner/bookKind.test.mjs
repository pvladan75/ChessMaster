// What kind of book a PDF is — phase 3f of docs/PLAN-SKENER-SLIKE.md. The
// books are drawn in test/support/drawnBooks.mjs; none is in the repository.
import test from 'node:test';
import assert from 'node:assert/strict';

import { bookKind, samplePages, KIND_SAMPLE } from './bookKind.mjs';
import { positionImage, tempPdf } from '../../test/support/drawnBooks.mjs';

const picturePage = (placement, seed) => ({
  size: [400, 400],
  images: [{ picture: positionImage(placement, { seed }), storage: 'gray8', rect: [40, 40, 268, 240] }],
});

test('the sample is spread over the whole book, first and last page included', () => {
  assert.deepEqual(samplePages(3), [1, 2, 3]);
  const pages = samplePages(435);
  assert.equal(pages.length, KIND_SAMPLE);
  assert.equal(pages[0], 1);
  assert.equal(pages.at(-1), 435);
  for (let k = 1; k < pages.length; k++) assert.ok(pages[k] > pages[k - 1], `not increasing at ${k}: ${pages}`);
  // Not bunched at the front: a preface of 40 pages would otherwise decide it.
  assert.ok(pages.filter((p) => p > 40).length >= KIND_SAMPLE - 2, `${pages}`);
});

test('a book of diagram pictures is a picture book, with its boards counted', async (t) => {
  const file = await tempPdf(t, [picturePage('4k3/8/8/8/8/8/8/R3K3', 3), { size: [400, 400], images: [] },
    picturePage('8/5k2/8/3Q4/8/2n5/5B2/6K1', 4)]);
  assert.deepEqual(await bookKind(file), { pageCount: 3, kind: 'pictures', imageDiagrams: 2 });
});

test('a font the scanner reads wins over pictures, as it does in a scan', async (t) => {
  const file = await tempPdf(t, [picturePage('4k3/8/8/8/8/8/8/R3K3', 3)]);
  const asked = [];
  const kind = await bookKind(file, { pickFont: (sample, sampled) => { asked.push(sampled.length); return { map: {} }; } });
  assert.deepEqual(kind, { pageCount: 1, kind: 'font' });
  assert.deepEqual(asked, [1], 'the font path was asked about the sampled page');
});

test('a book with neither is unknown, with the font path\'s reason', async (t) => {
  const file = await tempPdf(t, [{ size: [400, 400], images: [] }, { size: [400, 400], images: [] }]);
  assert.deepEqual(await bookKind(file), { pageCount: 2, kind: 'unknown', code: 'no_text' });
});
