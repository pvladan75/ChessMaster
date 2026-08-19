// pdfjs-dist wrapper: a page becomes a flat list of positioned text spans.
//
// Coordinates are converted to a top-down y so the rest of the code can reason
// about "the row above" without inverting signs everywhere. PDF user space has
// y growing upwards; every layout question here is easier the other way round.
import { readFile } from 'node:fs/promises';
import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs';

export async function openPdf(path) {
  const data = new Uint8Array(await readFile(path));
  return pdfjs.getDocument({ data, fontExtraProperties: true }).promise;
}

/**
 * Spans on one page: { text, x, y, fontId, height }, sorted top-down then left
 * to right. `y` is the distance from the top of the page.
 */
export async function pageSpans(doc, pageNo) {
  const page = await doc.getPage(pageNo);
  const viewport = page.getViewport({ scale: 1 });
  const { items } = await page.getTextContent();
  const spans = [];
  for (const it of items) {
    if (!it.str || !it.str.trim()) continue;
    spans.push({
      text: it.str,
      x: it.transform[4],
      y: viewport.height - it.transform[5],
      width: it.width || 0,
      height: it.height || Math.abs(it.transform[3]) || 0,
      fontId: it.fontName,
    });
  }
  spans.sort((a, b) => a.y - b.y || a.x - b.x);
  page.cleanup();
  return spans;
}

/**
 * Join spans that pdfjs split mid-row back together.
 *
 * A diagram row is one run of glyphs, but pdfjs hands it back in two pieces
 * often enough to lose a fifth of the diagrams in a book. Only genuinely
 * touching spans are merged: in the first test book the rank coordinate sits a
 * few points left of the board, and gluing it on turns an 8-glyph row into a
 * 9-character string that no map recognises.
 */
const TOUCHING = 0.15; // multiples of glyph height

export function mergeSpans(spans) {
  const out = [];
  for (const s of [...spans].sort((a, b) => a.y - b.y || a.x - b.x)) {
    const prev = out[out.length - 1];
    const touching =
      prev &&
      Math.abs(prev.y - s.y) < 2 &&
      s.x - (prev.x + prev.width) < TOUCHING * Math.max(prev.height, 6) &&
      s.x >= prev.x;
    if (touching) {
      prev.text += s.text;
      prev.width = s.x + s.width - prev.x;
    } else {
      out.push({ ...s });
    }
  }
  return out;
}

/**
 * Real embedded font names, keyed by the internal id that spans carry.
 *
 * pdfjs only resolves font objects while building an operator list, and
 * `styles[].fontFamily` collapses every embedded font to "sans-serif", so the
 * name is unavailable from getTextContent alone. This is diagnostics only —
 * map selection goes by alphabet, which survives obfuscated subset names.
 */
export async function fontNames(doc, pageNo) {
  const page = await doc.getPage(pageNo);
  await page.getOperatorList();
  const { items } = await page.getTextContent();
  const names = new Map();
  for (const it of items) {
    if (!it.str || names.has(it.fontName)) continue;
    try {
      const font = page.commonObjs.get(it.fontName);
      const raw = font?.name ?? font?.loadedName ?? '';
      names.set(it.fontName, raw.replace(/^[A-Z]{6}\+/, ''));
    } catch {
      names.set(it.fontName, '(nepoznat)');
    }
  }
  page.cleanup();
  return names;
}

/** Plain text of a page, for the solutions section and running headers. */
export async function pageText(doc, pageNo) {
  const page = await doc.getPage(pageNo);
  const { items } = await page.getTextContent();
  const out = items.map((it) => it.str).join('');
  page.cleanup();
  return out;
}
