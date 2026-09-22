// A page's images as 8-bit grey, with where each one sits on the page.
//
// Phase 1 of docs/PLAN-SKENER-SLIKE.md. pdfjs hands back an image's pixels
// without a canvas: the operator list names every `paintImageXObject`, and the
// page's object store holds the decoded pixels. Measured on the owner's three
// books, 10–100 ms a page. A board drawn in vectors has no image to hand back,
// and is out of scope (§6).
import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs';

const { OPS, ImageKind } = pdfjs;

/**
 * Grey, one byte a pixel, from a pdfjs image of any kind.
 *
 * GRAYSCALE_1BPP packs eight pixels a byte, rows padded to a byte, with 1 as
 * white; RGB and RGBA are averaged. A kind this does not know throws: a picture
 * read the wrong way round would look like a board of the other colour.
 */
export function toGray({ width, height, kind, data }) {
  const gray = new Uint8Array(width * height);
  if (kind === ImageKind.GRAYSCALE_1BPP) {
    const rowBytes = (width + 7) >> 3;
    for (let y = 0; y < height; y++) {
      const row = y * rowBytes;
      for (let x = 0; x < width; x++) {
        gray[y * width + x] = data[row + (x >> 3)] & (0x80 >> (x & 7)) ? 255 : 0;
      }
    }
  } else if (kind === ImageKind.RGB_24BPP || kind === ImageKind.RGBA_32BPP) {
    const step = kind === ImageKind.RGB_24BPP ? 3 : 4;
    for (let i = 0, j = 0; i < gray.length; i++, j += step) {
      gray[i] = (data[j] + data[j + 1] + data[j + 2]) / 3;
    }
  } else {
    throw new Error(`image kind ${kind} is not one pdfjs is known to hand back`);
  }
  return gray;
}

function multiply(m, n) {
  return [
    m[0] * n[0] + m[2] * n[1], m[1] * n[0] + m[3] * n[1],
    m[0] * n[2] + m[2] * n[3], m[1] * n[2] + m[3] * n[3],
    m[0] * n[4] + m[2] * n[5] + m[4], m[1] * n[4] + m[3] * n[5] + m[5],
  ];
}

/** The unit square under `ctm`, as [x, y, width, height] with y from the top. */
function placed(ctm, pageHeight) {
  const xs = [ctm[4], ctm[4] + ctm[0], ctm[4] + ctm[2], ctm[4] + ctm[0] + ctm[2]];
  const ys = [ctm[5], ctm[5] + ctm[1], ctm[5] + ctm[3], ctm[5] + ctm[1] + ctm[3]];
  const x = Math.min(...xs);
  const top = pageHeight - Math.max(...ys);
  return [x, top, Math.max(...xs) - x, Math.max(...ys) - Math.min(...ys)];
}

function objectOf(page, name) {
  const store = name.startsWith('g_') ? page.commonObjs : page.objs;
  return new Promise((resolve) => store.get(name, resolve));
}

/**
 * Every image painted on page `pageNo` (1-based): { width, height, gray, rect,
 * pageSize }. `rect` is where the image sits, in points, y from the top.
 * An image pdfjs could not decode to pixels is left out and counted in
 * `undecoded`, never passed on as a blank picture.
 */
export async function pageImages(doc, pageNo) {
  const page = await doc.getPage(pageNo);
  const { width: pageWidth, height: pageHeight } = page.getViewport({ scale: 1 });
  const ops = await page.getOperatorList();
  const images = [];
  let undecoded = 0;
  let ctm = [1, 0, 0, 1, 0, 0];
  const stack = [];
  for (let i = 0; i < ops.fnArray.length; i++) {
    const fn = ops.fnArray[i];
    const args = ops.argsArray[i];
    if (fn === OPS.save) stack.push(ctm);
    else if (fn === OPS.restore) ctm = stack.pop() ?? [1, 0, 0, 1, 0, 0];
    else if (fn === OPS.transform) ctm = multiply(ctm, args);
    else if (fn === OPS.paintFormXObjectBegin) {
      stack.push(ctm);
      if (args[0]) ctm = multiply(ctm, args[0]);
    } else if (fn === OPS.paintFormXObjectEnd) ctm = stack.pop() ?? [1, 0, 0, 1, 0, 0];
    else if (fn === OPS.paintImageXObject) {
      const img = await objectOf(page, args[0]);
      if (!img || !img.data) {
        undecoded++;
        continue;
      }
      images.push({
        width: img.width,
        height: img.height,
        gray: toGray(img),
        rect: placed(ctm, pageHeight),
        pageSize: [pageWidth, pageHeight],
      });
    }
  }
  page.cleanup();
  return { images, undecoded };
}
