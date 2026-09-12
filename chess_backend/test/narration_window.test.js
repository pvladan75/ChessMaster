// narration_window.test.js — where the voice is inside a clip, and what pacing
// the film off that window rather than off the file's length changes.
//
// Two reports from the owner on 12.9.2026, watching the first published
// tutorial: the first word of the film was not heard, and „govor ide brže od
// ispisa teksta, pa posle govora čekamo da se tekst ispiše, nekad i po 2
// sekunde, pa tek onda ide dalje."
//
// Measured before anything was written. Across all 22 clips of that film, Azure
// pads its sentence with 0.12–0.14 s of silence in front and **0.80–0.93 s
// behind** — 18.6 s of the film's 175. Everything was paced off the file:
//
//   * the caption was written over the clip's whole length, so it started
//     before the first word and was still being written after the last;
//   * the breath was added to the file's end, so the wait after the voice was
//     the tail *plus* the breath *plus* the rounding to a whole second — the
//     two seconds the owner counted.
//
// The audio itself was whole: the film's first 0.129 s and the clip's measure
// identical, to the decibel. So the lead-in here is room, not a repair.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { speechWindow, wavSeconds } = require('../services/tts/wav');
const {
  narrationPlan,
  retimeEvents,
  BREATH_SECONDS,
  LEAD_SECONDS,
} = require('../services/narrationPlan');
const { captionRevealAt } = require('../videoRenderer');

const RATE = 22050;

/// A 16-bit mono wav of [seconds], with a tone from [from] to [to] and silence
/// around it — the shape a synthesiser hands back.
function wavWith({ seconds, from, to, amplitude = 12000, rate = RATE }) {
  const frames = Math.round(seconds * rate);
  const data = Buffer.alloc(frames * 2);
  for (let i = 0; i < frames; i++) {
    const at = i / rate;
    const loud = at >= from && at < to;
    // Not digital silence outside the tone: a real clip's quiet part is around
    // −50 dB peak, and a scan for the first non-zero sample would answer 0 for
    // every clip ever made.
    const value = loud
      ? Math.round(amplitude * Math.sin(2 * Math.PI * 220 * at))
      : Math.round(60 * Math.sin(2 * Math.PI * 50 * at));
    data.writeInt16LE(value, i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(data.length, 40);

  const file = path.join(os.tmpdir(), `win_${process.pid}_${Math.random().toString(36).slice(2)}.wav`);
  fs.writeFileSync(file, Buffer.concat([header, data]));
  return file;
}

const made = [];
function clip(options) {
  const file = wavWith(options);
  made.push(file);
  return file;
}

test.after(() => {
  for (const file of made) {
    try { fs.unlinkSync(file); } catch { /* gone */ }
  }
});

test('the window is the voice, not the file', () => {
  // The proportions of a real Azure clip: an eighth of a second in front, most
  // of a second behind.
  const file = clip({ seconds: 5.0, from: 0.12, to: 4.15 });
  assert.ok(Math.abs(wavSeconds(file) - 5.0) < 0.01);

  const window = speechWindow(file);
  // Within one 20 ms block either way, which is the grid the peaks are taken on.
  assert.ok(Math.abs(window.startSeconds - 0.12) <= 0.02,
    `starts at ${window.startSeconds}`);
  assert.ok(Math.abs(window.endSeconds - 4.15) <= 0.02,
    `ends at ${window.endSeconds}`);
  assert.ok(Math.abs(window.seconds - 5.0) < 0.01);
});

test('a clip with nothing above the floor has no window at all', () => {
  // Not „the whole file is speech": a silent take is the fault the recording
  // screen exists to catch, and a plan told it was 5 s of voice would hold the
  // board for it.
  assert.equal(speechWindow(clip({ seconds: 2, from: 0, to: 0 })), null);
});

test('a file that is not 16-bit PCM answers null rather than guessing', () => {
  // The caller then paces off the file's length, which is what everything did
  // before the window was measured.
  const file = clip({ seconds: 1, from: 0.1, to: 0.9 });
  const bytes = fs.readFileSync(file);
  bytes.writeUInt16LE(3, 20); // IEEE float
  fs.writeFileSync(file, bytes);
  assert.equal(speechWindow(file), null);
});

test('the breath is counted from the voice, not from the end of the file', () => {
  // The clip's own tail is longer than the breath, so the beat is the clip and
  // nothing is added. Before 12.9.2026 this was `ceil(clip + breath)`, which
  // paid for the tail twice.
  const plan = narrationPlan(
    [{ clipSeconds: 5.0, speechStart: 0.12, speechEnd: 4.15 }],
    { leadSeconds: 0, fps: 4 },
  );
  assert.equal(plan.beatSeconds[0], 5.0);

  // And when the tail is shorter than the breath, the breath is what decides.
  const tight = narrationPlan(
    [{ clipSeconds: 5.0, speechStart: 0.1, speechEnd: 4.95 }],
    { leadSeconds: 0, fps: 4 },
  );
  assert.ok(tight.beatSeconds[0] >= 4.95 + BREATH_SECONDS - 1e-9,
    `a breath after the voice: ${tight.beatSeconds[0]}`);
  assert.equal(tight.beatSeconds[0], 5.75);
});

test('a beat never ends before its clip does', () => {
  // The track is concatenated in beat order, so a beat shorter than its own
  // clip would push every later clip past the board it belongs to.
  for (const speechEnd of [0.5, 2, 4.9]) {
    const plan = narrationPlan(
      [{ clipSeconds: 5.0, speechStart: 0.1, speechEnd }, { clipSeconds: 2 }],
      { leadSeconds: 0, fps: 4 },
    );
    assert.ok(plan.beatSeconds[0] >= 5.0, `speech ending at ${speechEnd}`);
  }
});

test('the film opens with a lead-in, once, on the first beat that speaks', () => {
  const plan = narrationPlan(
    [{ clipSeconds: null }, { clipSeconds: 3, speechStart: 0.1, speechEnd: 2.2 },
      { clipSeconds: 3, speechStart: 0.1, speechEnd: 2.2 }],
    { fps: 4 },
  );
  const silences = plan.segments.filter((s) => s.kind === 'silence' && s.index === 1);
  assert.ok(silences.some((s) => Math.abs(s.seconds - LEAD_SECONDS) < 1e-9),
    'the lead-in is in the track, in front of the first clip');

  // In front of it, not after it: the first segment of beat 1 is the silence.
  const beatOne = plan.segments.filter((s) => s.index === 1);
  assert.equal(beatOne[0].kind, 'silence');
  assert.equal(beatOne[1].kind, 'clip');

  // And only once in the film.
  const leads = plan.segments.filter((s) => s.kind === 'silence'
    && Math.abs(s.seconds - LEAD_SECONDS) < 1e-9);
  assert.equal(leads.length, 1);
});

test('the voice window travels with the events, in the film\'s own clock', () => {
  const events = [
    { timestampMs: 0, data: { fen: 'x', text: 'One.' } },
    { timestampMs: 9999, data: { fen: 'y', text: 'Two.' } },
  ];
  const plan = narrationPlan(
    [{ clipSeconds: 5, speechStart: 0.12, speechEnd: 4.15 },
      { clipSeconds: 3, speechStart: 0.2, speechEnd: 2.1 }],
    { leadSeconds: 0.4, fps: 4 },
  );
  const out = retimeEvents(events, plan);

  // Beat 0 carries the lead-in, so its voice starts 0.4 + 0.12 in.
  assert.equal(out[0].data.spokenStartMs, 520);
  assert.equal(out[0].data.spokenMs, 4030);
  // Beat 1 has no lead of its own.
  assert.equal(out[1].data.spokenStartMs, 200);
  assert.equal(out[1].data.spokenMs, 1900);
});

test('an unmeasured clip is paced off its whole length, as before', () => {
  const plan = narrationPlan([{ clipSeconds: 4 }], { leadSeconds: 0, fps: 4 });
  const out = retimeEvents([{ timestampMs: 0, data: { text: 'x' } }], plan);
  assert.equal(out[0].data.spokenStartMs, 0);
  assert.equal(out[0].data.spokenMs, 4000);
  assert.ok(plan.beatSeconds[0] >= 4 + BREATH_SECONDS - 1e-9);
});

test('a beat may end on a frame, not only on a whole second', () => {
  // Captions are drawn four times a second, so rounding a beat up to the next
  // whole second spent up to three quarters of a second doing nothing. At one
  // frame a second — a film with the comments hidden — the old rule stands.
  const beats = [{ clipSeconds: 5.02, speechStart: 0.12, speechEnd: 4.17 }];
  assert.equal(narrationPlan(beats, { leadSeconds: 0, fps: 4 }).beatSeconds[0], 5.25);
  assert.equal(narrationPlan(beats, { leadSeconds: 0, fps: 1 }).beatSeconds[0], 6);
  assert.equal(narrationPlan(beats, { leadSeconds: 0 }).beatSeconds[0], 6,
    'and a caller that says nothing gets whole seconds');
});

test('the writing starts with the voice and ends with it', () => {
  const beat = {
    beatStartMs: 1000,
    nextBeatStartMs: 6250,
    spokenMs: 4030,
    spokenStartMs: 520,
  };
  assert.equal(captionRevealAt({ ...beat, currentMs: 1000 }), 0,
    'nothing is written before the first word');
  assert.equal(captionRevealAt({ ...beat, currentMs: 1519 }), 0);
  assert.ok(Math.abs(captionRevealAt({ ...beat, currentMs: 3535 }) - 0.5) < 0.01,
    'halfway through the voice is halfway through the sentence');
  assert.equal(captionRevealAt({ ...beat, currentMs: 5550 }), 1,
    'and the last word lands with the last word said');
  assert.equal(captionRevealAt({ ...beat, currentMs: 6000 }), 1,
    'and stays there for the breath');
});

test('with no voice the writing takes three quarters of the beat', () => {
  // Unchanged, and it has to be: a silent film has nothing to follow, and the
  // last quarter is there so the finished sentence is on screen before the
  // board moves.
  const silent = { beatStartMs: 0, nextBeatStartMs: 4000 };
  assert.equal(captionRevealAt({ ...silent, currentMs: 1500 }), 0.5);
  assert.equal(captionRevealAt({ ...silent, currentMs: 3000 }), 1);
  // A lead-in is ignored without a voice rather than delaying the writing.
  assert.equal(captionRevealAt({ ...silent, currentMs: 1500, spokenStartMs: 500 }), 0.5);
});

test('a beat with no room at all cannot divide by zero', () => {
  assert.equal(captionRevealAt({ currentMs: 0, beatStartMs: 0, nextBeatStartMs: 0 }), 0);
  assert.equal(captionRevealAt({ currentMs: 5, beatStartMs: 0, nextBeatStartMs: 0 }), 1);
});

test('a clip comes back from the cache with its window measured', async () => {
  // **The gap this closes.** `speechWindow` is proved above and `narrationPlan`
  // is proved above, and neither of them says the two are wired together: a
  // `speakBeats` that forgot to attach the window would leave every clip paced
  // off its file again, with both files' tests green. („A proved function is not
  // a proved caller" — CLAUDE.md.)
  //
  // No synthesiser runs. A cached clip is one `speakBeats` does not ask for, so
  // the clip is written into the cache under the key it would look for, and the
  // voices directory holds a file named like a model so the provider reports
  // itself available.
  const cache = fs.mkdtempSync(path.join(os.tmpdir(), 'ttscache-'));
  const voices = fs.mkdtempSync(path.join(os.tmpdir(), 'voices-'));
  fs.writeFileSync(path.join(voices, 'en_US-test.onnx'), 'not a model');
  fs.writeFileSync(path.join(voices, 'en_US-test.onnx.json'), '{}');

  const saved = {
    cache: process.env.TTS_CACHE_DIR,
    provider: process.env.TTS_PROVIDER,
    dir: process.env.PIPER_VOICES_DIR,
  };
  process.env.TTS_CACHE_DIR = cache;
  process.env.TTS_PROVIDER = 'piper';
  process.env.PIPER_VOICES_DIR = voices;

  try {
    // Required here rather than at the top of the file: the cache directory is
    // read once, when the module loads.
    const tts = require('../services/tts');
    const text = 'One sentence.';
    const voice = 'en_US-test';
    const key = tts.cacheKey({ text, voice, provider: 'piper' });
    fs.copyFileSync(clip({ seconds: 5, from: 0.12, to: 4.15 }),
      path.join(cache, `${key}.wav`));

    const beats = await tts.speakBeats([text], { voice });
    assert.ok(Math.abs(beats[0].clipSeconds - 5) < 0.01, 'the file is five seconds');
    assert.ok(Math.abs(beats[0].speechStart - 0.12) <= 0.02,
      `the voice starts at ${beats[0].speechStart}`);
    assert.ok(Math.abs(beats[0].speechEnd - 4.15) <= 0.02,
      `and ends at ${beats[0].speechEnd}`);

    // And the plan reads it: the beat is the clip, with no breath added on top
    // of the tail the clip already carries.
    const plan = narrationPlan(beats, { leadSeconds: 0, fps: 4 });
    assert.equal(plan.beatSeconds[0], 5);
  } finally {
    for (const [name, value] of [['TTS_CACHE_DIR', saved.cache],
      ['TTS_PROVIDER', saved.provider], ['PIPER_VOICES_DIR', saved.dir]]) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
    fs.rmSync(cache, { recursive: true, force: true });
    fs.rmSync(voices, { recursive: true, force: true });
  }
});

