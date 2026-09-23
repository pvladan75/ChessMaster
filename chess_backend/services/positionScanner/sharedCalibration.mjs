// One calibration made from every user's calibration of the same book —
// phase 3g of docs/PLAN-SKENER-SLIKE.md. The owner, 23.9.2026: a calibration
// is no private thing, and the second user to scan a book should not set it
// up again. The same file is the same book (its SHA-256).
//
// Nothing is stored for this: every account keeps its own calibration, and the
// shared one is worked out from them each time, so a board one user fixes is
// fixed for the next at once.
import { placementCells, isDark } from './reader.mjs';

/** Boards a shared calibration offers: the server's MAX_CALIBRATION. */
export const SHARED_MAX = 8;

const PIECES = 'PNBRQKpnbrqk';

/** The classes a placement shows, `R/dark` and the like — a8 is light. */
export function classesOf(placement) {
  const out = new Set();
  placementCells(placement).forEach((p, i) => {
    if (p !== '.') out.add(`${p}/${isDark(i) ? 'dark' : 'light'}`);
  });
  return out;
}

/**
 * `calibrations` is one `{ boards: [{ page, index, fen, ignore? }], absent }`
 * per account. The answer is `{ boards: [{ page, index, fen, ignore, votes }],
 * absent, contributors }`, with no account named anywhere in it.
 *
 * - A board is named by its page and place, so the same board from two
 *   users is one board. Set up the same way it gains a vote; set up two
 *   ways, the one more users agree on wins, and a tie leaves the board out —
 *   one of them is wrong and nobody can say which.
 * - From what remains, at most SHARED_MAX boards are taken, each the one that
 *   shows most classes not yet shown, the one more users agree on first
 *   among equals, the earlier in the book after that.
 * - A piece said to be absent stays absent only if no board of the book, from
 *   anybody, shows it: a board is evidence, a „there is none" is not.
 */
export function mergeCalibrations(calibrations, max = SHARED_MAX) {
  const byBoard = new Map();
  const absentSaid = new Set();
  for (const calibration of calibrations) {
    for (const p of calibration.absent ?? []) absentSaid.add(p);
    for (const board of calibration.boards ?? []) {
      const key = `${board.page}:${board.index}`;
      const placement = String(board.fen).split(' ')[0];
      if (!byBoard.has(key)) byBoard.set(key, { page: board.page, index: board.index, votes: new Map() });
      const entry = byBoard.get(key).votes;
      const vote = entry.get(placement) ?? { count: 0, ignore: new Set() };
      vote.count += 1;
      for (const square of board.ignore ?? []) vote.ignore.add(square);
      entry.set(placement, vote);
    }
  }

  const pool = [];
  const seenPieces = new Set();
  for (const { page, index, votes } of byBoard.values()) {
    const ranked = [...votes.entries()].sort((a, b) => b[1].count - a[1].count);
    for (const [placement] of ranked) for (const c of classesOf(placement)) seenPieces.add(c[0]);
    if (ranked.length > 1 && ranked[0][1].count === ranked[1][1].count) continue;
    const [placement, { count, ignore }] = ranked[0];
    pool.push({ page, index, fen: placement, ignore: [...ignore].sort(), votes: count, classes: classesOf(placement) });
  }

  const shown = new Set();
  const chosen = [];
  while (chosen.length < max) {
    let best = null;
    let bestNew = 0;
    for (const b of pool) {
      if (chosen.includes(b)) continue;
      const fresh = [...b.classes].filter((c) => !shown.has(c)).length;
      if (fresh === 0) continue;
      const better = !best || fresh > bestNew
        || (fresh === bestNew && (b.votes > best.votes
          || (b.votes === best.votes && (b.page - best.page || b.index - best.index) < 0)));
      if (better) { best = b; bestNew = fresh; }
    }
    if (!best) break;
    chosen.push(best);
    for (const c of best.classes) shown.add(c);
  }

  return {
    boards: chosen.map(({ page, index, fen, ignore, votes }) => ({ page, index, fen, ignore, votes })),
    absent: [...PIECES].filter((p) => absentSaid.has(p) && !seenPieces.has(p)),
    contributors: calibrations.length,
  };
}
