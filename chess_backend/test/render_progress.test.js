// render_progress.test.js — the number the app draws its bar from.
//
// „Nema info o tome" was the report: a render takes tens of seconds and the app
// had a spinner. The renderer knows how many frames it has drawn of how many,
// so what was missing was somewhere to put that number where the client can
// read it while the request it already made is still in flight.
const test = require('node:test');
const assert = require('node:assert/strict');

const progress = require('../services/renderProgress');

test('a job id from a request body is bounded and checked', () => {
  // It comes from a client and is used as a map key, so an unbounded string is
  // a way to grow this process's memory from outside it.
  assert.equal(progress.jobIdFrom('job1788948017205123'), 'job1788948017205123');
  assert.equal(progress.jobIdFrom('  job-abc_123  '), 'job-abc_123');
  assert.equal(progress.jobIdFrom('short'), null, 'six characters at least');
  assert.equal(progress.jobIdFrom('x'.repeat(65)), null, 'and sixty-four at most');
  assert.equal(progress.jobIdFrom('job id with spaces'), null);
  assert.equal(progress.jobIdFrom('job/../../etc'), null);
  assert.equal(progress.jobIdFrom(42), null);
  assert.equal(progress.jobIdFrom(null), null);
});

test('progress is what has been drawn, and never reaches 100 on its own', () => {
  // The frames are drawn well before ffmpeg has finished writing the file. A
  // bar that sits full while the app is still waiting is worse than one that
  // visibly has something left to do.
  const id = 'job-percent-1';
  progress.report(id, 0, 80);
  assert.equal(progress.statusOf(id).percent, 0);
  progress.report(id, 40, 80);
  assert.equal(progress.statusOf(id).percent, 50);
  progress.report(id, 80, 80);
  assert.equal(progress.statusOf(id).percent, 99, 'the last frame is not the last step');
  assert.equal(progress.statusOf(id).done, false);

  progress.finish(id);
  assert.deepEqual(progress.statusOf(id),
    { percent: 100, done: true, known: true, etaSeconds: 0 });
});

test('a render that failed stops the bar rather than leaving it creeping', () => {
  const id = 'job-failed-1';
  progress.report(id, 10, 100);
  progress.finish(id, { ok: false });
  assert.equal(progress.statusOf(id).done, true);
  assert.equal(progress.statusOf(id).percent, 100,
    'the bar closes; whether the file exists is the response\'s answer, not the bar\'s');
});

test('an unknown job is nothing to report, not an error', () => {
  // A poll can arrive before the render has drawn its first frame, or after the
  // entry was swept. Both are „nothing yet" rather than something for the app
  // to draw a failure about.
  assert.deepEqual(progress.statusOf('job-never-seen'), {
    percent: 0,
    done: false,
    known: false,
    etaSeconds: null,
  });
});

test('a job with no total does not divide by zero', () => {
  const id = 'job-zero-1';
  progress.report(id, 5, 0);
  assert.equal(progress.statusOf(id).percent, 0);
});

test('reporting on no job at all is ignored', () => {
  // The route passes `jobIdFrom(...)`, which is null when the client sent none
  // — an export without a bar is an ordinary export.
  progress.report(null, 5, 10);
  progress.finish(null);
  assert.deepEqual(progress.statusOf(null),
    { percent: 0, done: false, known: false, etaSeconds: null });
});

test('the time left is measured on this render, not assumed', () => {
  // „i procenu vremena završetka". A film with captions is drawn four times a
  // second and one without it once a second, so the only honest source for a
  // number of seconds is the rate this render is actually going at.
  const id = 'job-eta-1';
  progress.report(id, 72, 721);
  assert.equal(progress.statusOf(id).etaSeconds, null,
    'one report is a point, not a rate');

  // Reach into the store rather than sleeping: the arithmetic is what is under
  // test, not the clock. Four seconds for the first tenth.
  progress._jobs.get(id).first.at = Date.now() - 4000;
  progress.report(id, 144, 721);
  // 4 s for 72 frames is 55.6 ms each, and 577 are left: 33 s.
  assert.equal(progress.statusOf(id).etaSeconds, 33);

  progress._jobs.get(id).first.at = Date.now() - 40000;
  progress.report(id, 648, 721);
  // 576 more frames in 40 s is 69.4 ms each, and 73 are left: 6 s. The estimate
  // falls as the render goes; it is not fixed at the first reading.
  assert.equal(progress.statusOf(id).etaSeconds, 6);

  // The last frame is drawn and ffmpeg is still closing the file. „0 s left" on
  // a render that is still running is the same lie as a bar sitting at 100 %.
  progress.report(id, 721, 721);
  assert.equal(progress.statusOf(id).etaSeconds, null);
  assert.equal(progress.statusOf(id).percent, 99);
});

test('a render that starts a second time is estimated from its own start', () => {
  // A client that retries reuses its job id. The rate must be measured from
  // the second render's own opening frame: carrying the first one's forward
  // puts the whole of a finished render into the estimate for a new one.
  const id = 'job-eta-2';
  progress.report(id, 5, 100);
  progress.finish(id);

  progress.report(id, 10, 100);
  progress._jobs.get(id).first.at = Date.now() - 1000;
  progress.report(id, 20, 100);
  // 10 frames in a second, 80 left: 8 s. Measured from the first render's
  // opening frame it would be 15 frames in that second, and 6.
  assert.equal(progress.statusOf(id).etaSeconds, 8);
});

test('old jobs are swept, so a tab left open cannot hold an entry', () => {
  const id = 'job-swept-1';
  progress.report(id, 1, 10);
  assert.equal(progress.statusOf(id).known, true);

  // Reach into the store rather than waiting five minutes: the sweep is what is
  // under test, not the clock.
  progress._jobs.get(id).touchedAt = Date.now() - progress.TTL_MS - 1000;
  progress.report('job-something-else', 1, 10);
  assert.equal(progress.statusOf(id).known, false, 'the stale entry is gone');
  assert.equal(progress.statusOf('job-something-else').known, true);
});
