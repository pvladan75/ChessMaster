// Boards on pages drawn by the server — phase 3h of docs/PLAN-SKENER-SLIKE.md.
//
// A book whose diagrams are set in a chess font no glyph map knows, or drawn
// as lines, has no picture for the image path to read. Drawn at 300 dpi, its
// page is a clean picture, and the scanned-page finder cuts its boards out.
// Measured 23.9.2026 on eight font books whose answers the font path knows:
// 146 of 146 boards found and nothing else; calibrated as a trainer would,
// 116 read with one wrong square in all, and that one marked. At 200 dpi a
// white pawn on the a-file's hatching read as empty, unmarked, three times.
//
// The drawing happens in a child process (renderWorker.mjs) under a deadline.
// A crash or a hang there ends that process and fails this call, loudly; it
// cannot take the server with it, and it cannot come back as "no boards".
import { fork } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const RENDER_DPI = 300;
// A page larger than about A3 is drawn smaller rather than at any size.
export const MAX_PIXELS = 16e6;
const WORKER = fileURLToPath(new URL('./renderWorker.mjs', import.meta.url));

/** Starting the process and loading pdfjs, then each page drawn and searched. */
export const deadlineFor = (pages) => 10_000 + 3_000 * pages;

/**
 * `[{ page, rect, found: [{ box, board }] }]`, one entry a page, in the order
 * asked. `rect` is the page in PDF points, `box` a board in the drawn page's
 * pixels, `board` the 512 x 512 crop.
 */
export function renderedBoards(filePath, pages, {
  worker = WORKER, dpi = RENDER_DPI, maxPixels = MAX_PIXELS, deadline = deadlineFor(pages.length),
} = {}) {
  return new Promise((resolve, reject) => {
    const child = fork(worker, [], { serialization: 'advanced', stdio: ['ignore', 'ignore', 'pipe', 'ipc'] });
    const results = [];
    let stderr = '';
    let settled = false;
    const fail = (why) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      child.kill('SIGKILL');
      // The line that names the error, where there is one: the last lines of
      // a Node crash are the error object's closing brace and the version.
      const lines = stderr.trim().split('\n').map((l) => l.trim()).filter(Boolean);
      const tail = lines.find((l) => /^\w*Error\b|^Error:/.test(l)) ?? lines.slice(-3).join(' | ');
      reject(new Error(`drawing the pages failed: ${why}${tail ? ` — ${tail}` : ''}`));
    };
    const timer = setTimeout(() => fail(`no answer within ${deadline} ms`), deadline);
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('message', (message) => {
      if (message.done) {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        resolve(results);
      } else {
        results.push(message);
      }
    });
    child.on('error', (err) => fail(err.message));
    // `close`, not `exit`: it comes after the IPC channel has delivered what
    // the child sent, so a clean ending is never mistaken for a missing one.
    child.on('close', (code, signal) => {
      if (!settled) fail(signal ? `the process was ended by ${signal}` : `the process exited with ${code}`);
    });
    child.send({ filePath, pages, dpi, maxPixels });
  });
}
