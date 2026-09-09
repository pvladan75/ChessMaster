// render_abort.test.js — a film nobody is waiting for stops being drawn.
//
// Watched on 9.9.2026: a client hit the 300 s ceiling, went away, and the
// server drew for minutes more, wrote a 14 MB MP4 whose download URL had been
// in the response nobody received, and held the one render slot for all of it —
// so every other trainer was queued behind a film that would never be
// collected, or turned away with a 429. `RENDER_QUEUE_MAX` bounds the queue and
// says nothing about one render outliving its own connection.
//
// ffmpeg is faked here, as in `render_yields.test.js`: the questions are about
// what the loop and the handlers do, and a real encoder would only make the
// answers slower and machine-dependent.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const child = require('child_process');
const { EventEmitter } = require('events');

const {
  RenderAborted,
  abortOnDisconnect,
  throwIfAborted,
  killOnAbort,
} = require('../services/renderAbort');
const renderQueue = require('../services/renderQueue');

// ---------------------------------------------------------------- the wiring

/// A response object as far as this mechanism is concerned.
function fakeRes({ finished = false } = {}) {
  const res = new EventEmitter();
  res.writableFinished = finished;
  res.off = res.removeListener;
  return res;
}

test('a response that closes unfinished aborts the render', () => {
  const res = fakeRes();
  const { signal } = abortOnDisconnect(res);
  assert.equal(signal.aborted, false);
  res.emit('close');
  assert.equal(signal.aborted, true);
});

test('a response that finished normally does not abort anything', () => {
  // Every successful render answers and *then* closes. A listener that did not
  // ask this question would cancel every render at the moment it succeeded —
  // harmless only while nothing is still running by then, and a silent
  // cancellation the first time something is.
  const res = fakeRes({ finished: true });
  const { signal } = abortOnDisconnect(res);
  res.emit('close');
  assert.equal(signal.aborted, false);
});

test('dispose stops listening, so a later close cannot abort', () => {
  const res = fakeRes();
  const { signal, dispose } = abortOnDisconnect(res);
  dispose();
  res.emit('close');
  assert.equal(signal.aborted, false);
});

test('throwIfAborted throws RenderAborted, and nothing when there is no signal', () => {
  const controller = new AbortController();
  assert.doesNotThrow(() => throwIfAborted(null));
  assert.doesNotThrow(() => throwIfAborted(controller.signal));
  controller.abort();
  assert.throws(() => throwIfAborted(controller.signal), RenderAborted);
});

// ------------------------------------------------------------- child process

function fakeProc() {
  const proc = new EventEmitter();
  proc.killed = null;
  proc.kill = (sig) => { proc.killed = sig; };
  return proc;
}

test('killOnAbort kills the process when the client goes', () => {
  const controller = new AbortController();
  const proc = fakeProc();
  killOnAbort(proc, controller.signal);
  assert.equal(proc.killed, null);
  controller.abort();
  // SIGKILL and not SIGTERM: ffmpeg asked politely finishes writing the file
  // this exists to prevent, and piper inside the model ignores the ask.
  assert.equal(proc.killed, 'SIGKILL');
});

test('killOnAbort kills at once when the signal has already fired', () => {
  const controller = new AbortController();
  controller.abort();
  const proc = fakeProc();
  killOnAbort(proc, controller.signal);
  assert.equal(proc.killed, 'SIGKILL');
});

test('a process that exited on its own is not killed by a later abort', () => {
  // The signal outlives the render. A listener left on it holds a dead child
  // and would call `kill` on a pid the system may have given to somebody else.
  const controller = new AbortController();
  const proc = fakeProc();
  killOnAbort(proc, controller.signal);
  proc.emit('close', 0);
  controller.abort();
  assert.equal(proc.killed, null);
});

// ------------------------------------------------------------------ the loop

/// Installs a fake ffmpeg and hands back the renderer that will use it.
///
/// `onFrame` is called with the frame count after every write, which is where
/// these tests abort from: it is the one place that knows the loop is running.
function rendererWithFakeFfmpeg({ onFrame = () => {}, writesFile = null }) {
  const realSpawn = child.spawn;
  const spawns = [];

  child.spawn = () => {
    const proc = new EventEmitter();
    proc.stderr = new EventEmitter();
    proc.killed = null;
    proc.kill = (sig) => {
      proc.killed = sig;
      setImmediate(() => proc.emit('close', null));
    };
    proc.stdin = {
      frames: 0,
      write() {
        proc.stdin.frames += 1;
        // A real ffmpeg has the output open from its first frame. Written here
        // so „the half-written file is removed" is a question this test can
        // actually ask.
        if (writesFile && proc.stdin.frames === 1) fs.writeFileSync(writesFile, 'partial');
        onFrame(proc.stdin.frames);
        return true;
      },
      on() {},
      end() { setImmediate(() => proc.emit('close', 0)); },
    };
    spawns.push(proc);
    return proc;
  };

  delete require.cache[require.resolve('../videoRenderer')];
  const renderer = require('../videoRenderer');

  return {
    renderer,
    spawns,
    restore() {
      child.spawn = realSpawn;
      delete require.cache[require.resolve('../videoRenderer')];
    },
  };
}

/// Fails rather than hangs.
///
/// Every question in this file is about something *stopping*, and the way that
/// breaks is a promise nobody settles. A bare `await` on one of those is a test
/// suite that stalls until CI kills it and reports nothing useful about which
/// check failed.
function withDeadline(promise, message, ms = 5000) {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      const timer = setTimeout(() => reject(new Error(message)), ms);
      if (timer.unref) timer.unref();
    }),
  ]);
}

/// A film with a caption on it, so the loop runs at CAPTION_FPS.
function events() {
  return [
    {
      timestampMs: 0,
      eventType: 'init',
      data: {
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        text: 'A sentence, so the film has a caption band and four frames a second.',
        orientation: 'white',
      },
    },
  ];
}

test('a client that goes stops the drawing and removes the half-written file', async () => {
  const outputPath = path.join(os.tmpdir(), `abort_${process.pid}_${Date.now()}.mp4`);
  const controller = new AbortController();

  const harness = rendererWithFakeFfmpeg({
    writesFile: outputPath,
    onFrame: (n) => { if (n === 5) controller.abort(); },
  });

  try {
    const promise = harness.renderer.renderRecordingToMP4({
      title: 'abort',
      timelineEvents: events(),
      durationSeconds: 60, // 241 frames at 4 fps, so the abort lands well inside
      resolution: '720p',
      signal: controller.signal,
      outputPath,
    });

    // Raced, because the failure mode of a broken abort is a render that never
    // settles — and a test that hangs tells you nothing at three in the
    // morning. `killOnAbort` doing nothing is exactly that shape.
    await assert.rejects(withDeadline(promise, 'the render never settled'), RenderAborted);

    const proc = harness.spawns[0];
    assert.equal(proc.killed, 'SIGKILL', 'ffmpeg is killed rather than asked');
    assert.equal(fs.existsSync(outputPath), false,
      'the half-written file does not survive the abort');

    // **The loop stopped, not „had not got far yet".** Counting frames at the
    // moment of the rejection cannot tell those apart: the promise settles a
    // turn or two after the kill, so a loop that ignores the abort entirely is
    // still only a few frames further on when the count is read — a mutation
    // deleting the check survived exactly that assertion. So the count is read
    // twice, with the event loop given room in between.
    const atRejection = proc.stdin.frames;
    await new Promise((r) => setTimeout(r, 150));
    assert.equal(proc.stdin.frames, atRejection,
      `the loop is still drawing: ${atRejection} frames at the rejection, ${proc.stdin.frames} now`);
    assert.ok(atRejection < 241, `${atRejection} frames drawn of 241`);
  } finally {
    harness.restore();
    try { fs.unlinkSync(outputPath); } catch { /* the point is that it is gone */ }
  }
});

test('a render whose client left before its turn never starts', async () => {
  const outputPath = path.join(os.tmpdir(), `abort_pre_${process.pid}_${Date.now()}.mp4`);
  const controller = new AbortController();
  controller.abort();

  const harness = rendererWithFakeFfmpeg({ writesFile: outputPath });
  try {
    await assert.rejects(withDeadline(harness.renderer.renderRecordingToMP4({
      title: 'abort',
      timelineEvents: events(),
      durationSeconds: 60,
      resolution: '720p',
      signal: controller.signal,
      outputPath,
    }), 'the render never settled'), RenderAborted);

    // Nothing was spawned and nothing was drawn: this is the render that waited
    // behind two others while its client gave up, and the slot has to pass
    // straight to the next trainer.
    assert.equal(harness.spawns.length, 0, 'no ffmpeg for a client that is gone');
    assert.equal(fs.existsSync(outputPath), false);
  } finally {
    harness.restore();
  }
});

test('a render with no signal is unaffected', async () => {
  const outputPath = path.join(os.tmpdir(), `abort_none_${process.pid}_${Date.now()}.mp4`);
  const harness = rendererWithFakeFfmpeg({});
  try {
    const done = await withDeadline(harness.renderer.renderRecordingToMP4({
      title: 'plain',
      timelineEvents: events(),
      durationSeconds: 3,
      resolution: '720p',
      outputPath,
    }), 'the plain render never settled');
    assert.equal(done, outputPath);
    assert.equal(harness.spawns[0].killed, null);
  } finally {
    harness.restore();
  }
});

// ----------------------------------------------------------------- the slot

test('an aborted render hands its slot to the next trainer at once', async () => {
  // The whole point of the mechanism. Before it, the abandoned render held the
  // slot for the rest of its film and everyone else queued behind it.
  const order = [];
  let releaseSecond;
  const secondStarted = new Promise((r) => { releaseSecond = r; });

  const abandoned = renderQueue.run('abandoned', async () => {
    order.push('first started');
    throw new RenderAborted();
  }).catch((err) => { order.push(`first ${err.name}`); });

  const next = renderQueue.run('next', async () => {
    order.push('second started');
    releaseSecond();
  });

  // Raced rather than awaited: the failure this test exists to catch is a slot
  // that is never given back, and a bare `await` on that is a test that hangs
  // instead of one that fails.
  const outcome = await Promise.race([
    secondStarted.then(() => 'started'),
    new Promise((r) => setTimeout(() => r('never started'), 2000)),
  ]);
  assert.equal(outcome, 'started', 'the next render waited for a slot that was never released');

  await abandoned;
  await next;

  // The second job starts **before** the first render's rejection reaches its
  // own caller: the queue releases in a `finally`, and the `.catch` above is a
  // microtask behind it. Which is the right way round — the slot is not held
  // for as long as it takes somebody to notice the failure.
  assert.deepEqual(order, ['first started', 'second started', 'first RenderAborted']);
  assert.equal(renderQueue.snapshot().waiting, 0);
  assert.equal(renderQueue.snapshot().running, 0);
});
