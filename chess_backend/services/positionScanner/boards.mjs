// Finding a board in a picture and cutting it out.
//
// Phase 1 of docs/PLAN-SKENER-SLIKE.md, ported from phase 0's
// tools/diagram_vision/extract.py. Pictures are one byte of grey a pixel,
// row-major; a box is { top, bottom, left, right }, inclusive, in pixels.

export const BOARD = 512;

/**
 * The board's frame inside a diagram image, or null.
 *
 * Dark squares are hatched or grey, so the frame is found from long straight
 * runs of ink: a row or column counts as a frame line when most of it is dark.
 * The board is the box between the outermost such lines, and it must fill at
 * least half the image and be close to square — a picture with no frame is
 * refused rather than cut anyway.
 */
export function findBoard(gray, width, height) {
  const rowInk = new Uint32Array(height);
  const colInk = new Uint32Array(width);
  for (let y = 0; y < height; y++) {
    const row = y * width;
    for (let x = 0; x < width; x++) {
      if (gray[row + x] < 128) {
        rowInk[y]++;
        colInk[x]++;
      }
    }
  }
  let top = -1;
  let bottom = -1;
  for (let y = 0; y < height; y++) {
    if (rowInk[y] > 0.6 * width) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  let left = -1;
  let right = -1;
  for (let x = 0; x < width; x++) {
    if (colInk[x] > 0.6 * height) {
      if (left < 0) left = x;
      right = x;
    }
  }
  if (top < 0 || left < 0 || bottom === top || right === left) return null;
  const bh = bottom - top;
  const bw = right - left;
  if (bh < 0.5 * height || bw < 0.5 * width) return null;
  if (Math.abs(bh - bw) > 0.06 * Math.max(bh, bw)) return null;
  return { top, bottom, left, right };
}

function median(values) {
  const s = [...values].sort((a, b) => a - b);
  return s[s.length >> 1];
}

/**
 * Whether a square region alternates light and dark as a board does. The
 * middle half of each of the 64 cells is averaged; pieces sit on some cells,
 * so the medians of the light and the dark cells are compared.
 */
export function checkered(gray, width, box) {
  const size = box.right - box.left + 1;
  const cell = Math.floor(size / 8);
  const light = [];
  const dark = [];
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      let sum = 0;
      let n = 0;
      const y0 = box.top + r * cell + (cell >> 2);
      const x0 = box.left + c * cell + (cell >> 2);
      for (let y = y0; y < y0 + (cell >> 1); y++) {
        for (let x = x0; x < x0 + (cell >> 1); x++) {
          sum += gray[y * width + x];
          n++;
        }
      }
      ((r + c) % 2 === 0 ? light : dark).push(sum / Math.max(n, 1));
    }
  }
  return median(light) - median(dark) > 25;
}

/** Bounding boxes of the 8-connected regions of ink (grey < 150). */
function inkRegions(gray, width, height) {
  const seen = new Uint8Array(width * height);
  const stack = new Int32Array(width * height);
  const regions = [];
  for (let start = 0; start < gray.length; start++) {
    if (seen[start] || gray[start] >= 150) continue;
    let sp = 0;
    stack[sp++] = start;
    seen[start] = 1;
    let top = height, bottom = -1, left = width, right = -1;
    while (sp > 0) {
      const p = stack[--sp];
      const y = (p / width) | 0;
      const x = p - y * width;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
      if (x < left) left = x;
      if (x > right) right = x;
      for (let dy = -1; dy <= 1; dy++) {
        const ny = y + dy;
        if (ny < 0 || ny >= height) continue;
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx;
          if (nx < 0 || nx >= width) continue;
          const q = ny * width + nx;
          if (!seen[q] && gray[q] < 150) {
            seen[q] = 1;
            stack[sp++] = q;
          }
        }
      }
    }
    regions.push({ top, bottom, left, right });
  }
  return regions;
}

function sub(gray, width, box) {
  const w = box.right - box.left + 1;
  const h = box.bottom - box.top + 1;
  const out = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) {
    out.set(gray.subarray((box.top + y) * width + box.left, (box.top + y) * width + box.left + w), y * w);
  }
  return { gray: out, width: w, height: h };
}

/**
 * The boards on a scanned page. A candidate is an ink region that is square
 * and between 15% and 90% of the page's width, whose inside is checkered and
 * holds a frame. Three rules from phase 0 on a real scan:
 *  - largest first, so an outer frame wins over an inner one (keeping the
 *    inner one cut the h-file short);
 *  - no test that the outline is closed — a scanned frame is sometimes
 *    broken, and the checkered test is the stronger one;
 *  - a candidate overlapping a board already taken is skipped.
 */
export function boardsOnScan(gray, width, height) {
  const regions = inkRegions(gray, width, height)
    .map((r) => ({ ...r, w: r.right - r.left + 1, h: r.bottom - r.top + 1 }))
    .filter((r) => r.w >= 0.15 * width && r.w <= 0.9 * width && Math.abs(r.w - r.h) <= 0.05 * r.w)
    .sort((a, b) => b.w * b.h - a.w * a.h);
  const found = [];
  for (const r of regions) {
    if (!checkered(gray, width, r)) continue;
    const crop = sub(gray, width, r);
    const inner = findBoard(crop.gray, crop.width, crop.height);
    if (!inner) continue;
    const box = {
      top: r.top + inner.top,
      bottom: r.top + inner.bottom,
      left: r.left + inner.left,
      right: r.left + inner.right,
    };
    const overlaps = found.some((f) => box.top < f.bottom && f.top < box.bottom
      && box.left < f.right && f.left < box.right);
    if (!overlaps) found.push(box);
  }
  return found;
}

/**
 * The board inside `box`, resized to BOARD x BOARD as OpenCV's INTER_AREA does
 * (phase 0 cut its boards so):
 *  - shrinking averages every source pixel an output pixel covers — picking
 *    pixels would drop the thin outline that is all that tells a white piece
 *    from an empty square;
 *  - enlarging interpolates bilinearly. A scanned board is often smaller than
 *    512, and enlarging a 1-bit picture in blocks lost the same outline:
 *    measured on a real scan (phase 2), white pawns on light squares read as
 *    empty on 4 boards in 24 until this was bilinear.
 */
export function cropBoard(gray, width, box, size = BOARD) {
  const w = box.right - box.left + 1;
  const h = box.bottom - box.top + 1;
  const out = new Uint8Array(size * size);
  if (w < size || h < size) {
    const at = (x, y) => gray[(box.top + y) * width + box.left + x];
    for (let oy = 0; oy < size; oy++) {
      const sy = Math.min(Math.max((oy + 0.5) * (h / size) - 0.5, 0), h - 1);
      const y0 = Math.floor(sy);
      const y1 = Math.min(y0 + 1, h - 1);
      const fy = sy - y0;
      for (let ox = 0; ox < size; ox++) {
        const sx = Math.min(Math.max((ox + 0.5) * (w / size) - 0.5, 0), w - 1);
        const x0 = Math.floor(sx);
        const x1 = Math.min(x0 + 1, w - 1);
        const fx = sx - x0;
        const top = at(x0, y0) * (1 - fx) + at(x1, y0) * fx;
        const bottom = at(x0, y1) * (1 - fx) + at(x1, y1) * fx;
        out[oy * size + ox] = Math.round(top * (1 - fy) + bottom * fy);
      }
    }
    return out;
  }
  for (let oy = 0; oy < size; oy++) {
    const y0 = box.top + Math.floor((oy * h) / size);
    const y1 = Math.max(y0 + 1, box.top + Math.floor(((oy + 1) * h) / size));
    for (let ox = 0; ox < size; ox++) {
      const x0 = box.left + Math.floor((ox * w) / size);
      const x1 = Math.max(x0 + 1, box.left + Math.floor(((ox + 1) * w) / size));
      let sum = 0;
      for (let y = y0; y < y1; y++) {
        const row = y * width;
        for (let x = x0; x < x1; x++) sum += gray[row + x];
      }
      out[oy * size + ox] = sum / ((y1 - y0) * (x1 - x0));
    }
  }
  return out;
}
