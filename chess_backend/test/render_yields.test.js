// render_yields.test.js — the server answers while a film is being drawn.
//
// The bar said „Starting…" from the first frame to the last and then the video
// appeared. The number was right, `renderProgress` held it, the route read it,
// the app polled every 900 ms — and **not one poll was answered until the
// render finished**, because nothing in the frame loop returns to the event
// loop. `canvas.toBuffer` draws the PNG on this thread, the piece set is cached
// after the first frame, and an `await` on an already-settled promise is a
// microtask: the whole render is one uninterrupted burst, and every request
// arriving during it — the progress poll, and everything else this process
// serves — waits behind it.
//
// So this test is not about a percentage. It asks whether an ordinary
// event-loop callback gets its turn while frames are being drawn, which is the
// property the bar, and every other request, depends on.
const test = require('node:test');
const assert = require('node:assert/strict');
const child = require('child_process');
const { EventEmitter } = require('events');

// `videoRenderer` destructures `spawn` at module load, so the fake has to be in
// place before it is required — and the module is reloaded here rather than
// taken from whatever earlier state the cache holds. This file keeps it to
// itself for that reason: nothing else in it uses the renderer.
const realSpawn = child.spawn;
const spawned = [];
child.spawn = () => {
  const proc = new EventEmitter();
  proc.stderr = new EventEmitter();
  proc.stdin = {
    frames: 0,
    write(buf) {
      proc.stdin.frames += 1;
      return true;
    },
    // A real stdin is a stream, and since the abort landed (9.9.2026) the
    // renderer listens on it for the EPIPE a killed ffmpeg raises. A fake
    // without this throws inside the promise executor, where the throw is
    // swallowed — so the render never settles and this file hangs for as long
    // as the runner allows rather than failing. **The assertions below are
    // unchanged**; only the fixture grew a method the real object always had.
    on() {},
    // ffmpeg answers when its input closes; a real one takes far longer, and
    // the point here is only that the render's own loop has finished.
    end() {
      setImmediate(() => proc.emit('close', 0));
    },
  };
  spawned.push(proc);
  return proc;
};
delete require.cache[require.resolve('../videoRenderer')];
const renderer = require('../videoRenderer');
child.spawn = realSpawn;

const EVENTS = [
  {
    timestampMs: 0,
    eventType: 'init',
    data: { fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' },
  },
  {
    timestampMs: 2000,
    eventType: 'move',
    data: {
      fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      san: 'e4',
      from: 'e2',
      to: 'e4',
    },
  },
];

test('the event loop gets a turn between frames, so a poll is answered', async () => {
  // A chain of `setImmediate`s is what an arriving request looks like from
  // inside this process: it can only run when the render lets the loop turn.
  let turns = 0;
  let stillRendering = true;
  const tick = () => {
    if (!stillRendering) return;
    turns += 1;
    setImmediate(tick);
  };
  setImmediate(tick);

  const drawn = [];
  await renderer.renderRecordingToMP4({
    title: 'Yielding',
    timelineEvents: EVENTS,
    audioFilePath: null,
    // Twelve frames: a silent film is drawn once a second, and three would not
    // tell a starved loop from a slow one.
    durationSeconds: 11,
    perspective: 'trainer',
    resolution: '480p',
    boardTheme: 'wood',
    showTitle: true,
    showTimer: true,
    showCoords: true,
    showMoveText: false,
    onProgress: (at, total) => drawn.push([at, total]),
    outputPath: 'unused-by-the-fake.mp4',
  });
  stillRendering = false;

  assert.equal(spawned.length, 1, 'the render spawned its encoder');
  assert.equal(spawned[0].stdin.frames, 12, 'twelve frames were written');
  assert.deepEqual(drawn[drawn.length - 1], [12, 12], 'and reported to the end');

  // Without the yield this is 1: `preloadPieceSet` does real I/O on the first
  // frame and nothing after it returns to the loop again.
  assert.ok(turns >= 8,
    `the loop turned ${turns} times during a twelve-frame render; a starved one turns once`);
});

test('asking for the board alone is a quarter of the drawing, in a real render',
  async () => {
    // **The one place the flag can be watched doing its work.** Everything else
    // about it is checked where a fake renderer records its options; this runs
    // `render` itself and counts the frames that reached the encoder. A film
    // whose sentences are written is drawn four times a second so the writing
    // looks like writing; with them hidden there is nothing moving between
    // beats, so it is drawn once — which is most of why hiding them is worth
    // offering at all.
    const talking = [
      {
        timestampMs: 0,
        eventType: 'init',
        data: {
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          text: 'We begin from the opening position and look at the centre, '
            + 'because that is where the first fight of every game happens.',
        },
      },
    ];
    const common = {
      title: 'Captions',
      timelineEvents: talking,
      audioFilePath: null,
      durationSeconds: 6,
      perspective: 'trainer',
      resolution: '480p',
      boardTheme: 'wood',
      showMoveText: false,
      outputPath: 'unused-by-the-fake.mp4',
    };

    const before = spawned.length;
    await renderer.renderRecordingToMP4({ ...common });
    const withCaptions = spawned[spawned.length - 1].stdin.frames;

    await renderer.renderRecordingToMP4({ ...common, captions: false });
    const without = spawned[spawned.length - 1].stdin.frames;

    // One more than `seconds * fps` in each: the film's last instant is drawn
    // too, the same way the silent eleven-second render above writes twelve.
    assert.equal(spawned.length - before, 2, 'two renders, two encoders');
    assert.equal(withCaptions, 25, 'six seconds at four frames a second');
    assert.equal(without, 7, 'and six at one');
    assert.ok(withCaptions > without * 3,
      'the saving is the whole reason this is offered');
  });
