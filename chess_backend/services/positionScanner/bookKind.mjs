// What kind of book a PDF is, asked the moment it is chosen — phase 3f of
// docs/PLAN-SKENER-SLIKE.md. The owner, 23.9.2026: a trainer should not have
// to know whether a book's diagrams are set in a chess font or are pictures,
// and for a picture book the calibration comes before the choice of pages.
// Until then the app learned it only from a font scan of a page range that
// failed.
//
// A sample spread over the whole book, not its first pages: those are often a
// preface with no diagram at all.
import { openPdf } from './pdf.mjs';
import { pickFontMap, sampleForFont } from './index.mjs';
import { classifyUnreadable } from './diagrams.mjs';
import { findImageDiagrams } from './imageDiagrams.mjs';

/** Pages looked at: a few seconds on a scanned book (plan, 3e.0 (d)). */
export const KIND_SAMPLE = 16;

/** Up to `n` pages spread evenly from the first to the last, each once. */
export function samplePages(pageCount, n = KIND_SAMPLE) {
  if (pageCount <= n) return Array.from({ length: pageCount }, (_, k) => k + 1);
  const pages = new Set();
  for (let k = 0; k < n; k++) pages.add(1 + Math.round((k * (pageCount - 1)) / (n - 1)));
  return [...pages];
}

/**
 * `{ pageCount, kind, imageDiagrams?, code? }`: `font` when a glyph map reads
 * the sample, the font path's own test, which wins as it does in a scan;
 * otherwise `pictures` when boards are found on the same pages; otherwise
 * `unknown`, with the font path's reason — and the app then asks for pages and
 * scans, as before.
 */
export async function bookKind(filePath, { pickFont = pickFontMap } = {}) {
  const doc = await openPdf(filePath);
  let pageCount;
  let pages;
  let sample;
  let sampled;
  try {
    pageCount = doc.numPages;
    pages = samplePages(pageCount);
    ({ sample, sampled } = await sampleForFont(doc, pages));
  } finally {
    await doc.destroy();
  }
  if (pickFont(sample, sampled)) return { pageCount, kind: 'font' };
  const found = await findImageDiagrams(filePath, { pages });
  if (found.diagrams.length) {
    return { pageCount, kind: 'pictures', imageDiagrams: found.diagrams.length };
  }
  return { pageCount, kind: 'unknown', code: classifyUnreadable(sampled).code };
}
