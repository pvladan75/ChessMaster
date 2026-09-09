// tts_piper.test.js — the self-hosted voice, minus the part that needs a model.
//
// Piper is a 61 MB model file and a Python process, so what a test can hold is
// everything around that: which voices a directory offers, how an id names its
// language, and — the one that matters — that a batch whose output does not
// line up with its input is refused rather than mapped by guesswork. Putting one
// beat's sentence on another beat's board is exactly the silent fault this
// project keeps finding, and it would be inaudible in a finished film until
// somebody watched it to the end.
//
// The synthesis itself is proved by `scripts/tts-probe.js` against a real model.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const piper = require('../services/tts/piper');
const tts = require('../services/tts');

// `async` and `await`, and the first version of this was neither: `finally`
// runs when the `try` block *returns*, so a returned promise had its fixture
// directory deleted and its environment restored before the body it belonged to
// had run. The test failed for a reason that had nothing to do with the code
// under test, which is the most expensive kind of red.
async function withVoicesDir(names, run) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'piper-test-'));
  const saved = process.env.PIPER_VOICES_DIR;
  try {
    for (const name of names) {
      fs.writeFileSync(path.join(dir, name), '');
    }
    process.env.PIPER_VOICES_DIR = dir;
    return await run(dir);
  } finally {
    if (saved === undefined) delete process.env.PIPER_VOICES_DIR;
    else process.env.PIPER_VOICES_DIR = saved;
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('a voice id names its own language', () => {
  assert.equal(piper.languageOf('en_US-lessac-medium'), 'en-US');
  assert.equal(piper.languageOf('sr_RS-serbski_institut-medium'), 'sr-RS');
  assert.equal(piper.languageOf('de_DE-thorsten-high'), 'de-DE');
  // Piper's own catalogue has a few without a region.
  assert.equal(piper.languageOf('fa_IR-amir-medium'), 'fa-IR');
  assert.equal(piper.languageOf(''), '');
});

test('the quality is read off the id, since it is the whole cost difference', () => {
  assert.equal(piper.tierOf('en_US-lessac-medium'), 'medium');
  assert.equal(piper.tierOf('de_DE-thorsten-high'), 'high');
  assert.equal(piper.tierOf('en_US-lessac-low'), 'low');
});

test('a model without its config is not offered', async () => {
  // Half a download. Piper refuses it with a stack trace, and a picker that
  // lists it hands the trainer a voice that fails when they choose it.
  await withVoicesDir(
    ['en_US-lessac-medium.onnx', 'en_US-lessac-medium.onnx.json', 'sr_RS-broken-medium.onnx'],
    async () => {
      const voices = await piper.voices();
      assert.deepEqual(voices.map((v) => v.id), ['en_US-lessac-medium']);
      assert.equal(piper.available(), true);
    },
  );
});

test('an empty voices directory means narration is not available', async () => {
  await withVoicesDir([], async () => {
    assert.equal(piper.available(), false);
    assert.deepEqual(await piper.voices(), []);
  });

  const saved = process.env.PIPER_VOICES_DIR;
  try {
    process.env.PIPER_VOICES_DIR = 'D:/nothing/here';
    assert.equal(piper.available(), false, 'a path to nothing is not an installation');
    process.env.PIPER_VOICES_DIR = '';
    assert.equal(piper.available(), false);
  } finally {
    if (saved === undefined) delete process.env.PIPER_VOICES_DIR;
    else process.env.PIPER_VOICES_DIR = saved;
  }
});

test('voices are sorted by language, so the picker can group them', async () => {
  await withVoicesDir([
    'sr_RS-serbski_institut-medium.onnx', 'sr_RS-serbski_institut-medium.onnx.json',
    'en_US-lessac-medium.onnx', 'en_US-lessac-medium.onnx.json',
    'de_DE-thorsten-high.onnx', 'de_DE-thorsten-high.onnx.json',
  ], async () => {
    const voices = await piper.voices();
    assert.deepEqual(voices.map((v) => v.language), ['de-DE', 'en-US', 'sr-RS']);
  });
});

test('a batch whose output does not line up with its input is refused', () => {
  // Piper names its files by a timestamp, so they come back in the order the
  // sentences went in. If it ever produced a different number, mapping them by
  // position would put one beat's sentence on another beat's board — inaudible
  // until somebody watches a finished film to the end, which is the shape of
  // fault this project keeps finding one layer late.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'piper-map-'));
  try {
    const clips = ['a.wav', 'b.wav'].map((name) => {
      const file = path.join(dir, name);
      fs.writeFileSync(file, name);
      return file;
    });
    const jobs = ['one', 'two'].map((name) => ({ outputPath: path.join(dir, `${name}.out`) }));

    piper.assignOutputs(clips, jobs);
    assert.equal(fs.readFileSync(jobs[0].outputPath, 'utf8'), 'a.wav', 'in order');
    assert.equal(fs.readFileSync(jobs[1].outputPath, 'utf8'), 'b.wav');

    assert.throws(() => piper.assignOutputs(clips, [jobs[0]]), /2 files for 1 sentence/);
    assert.throws(() => piper.assignOutputs([clips[0]], jobs), /1 files for 2 sentences/);

    // And nothing was copied on the way to refusing.
    const third = path.join(dir, 'third.out');
    assert.throws(() => piper.assignOutputs(clips, [{ outputPath: third }]));
    assert.equal(fs.existsSync(third), false, 'refused before it wrote anything');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('the same sentence twice is synthesised once', async () => {
  // The cache is keyed by the sentence, so a tutorial that says „Look at the
  // centre." on three beats pays for one — and a reflowed copy of a sentence is
  // the same sentence.
  const texts = ['Look at d5.', '  Look at   d5. ', '', 'Find the move.', null];
  const keys = new Set(
    texts
      .map((t) => String(t || '').replace(/\s+/g, ' ').trim())
      .filter(Boolean)
      .map((text) => tts.cacheKey({ text, voice: 'en_US-lessac-medium', provider: 'piper' })),
  );
  assert.equal(keys.size, 2);
});

test('an unconfigured server speaks nothing rather than throwing', async () => {
  const saved = { provider: process.env.TTS_PROVIDER, dir: process.env.PIPER_VOICES_DIR };
  try {
    process.env.TTS_PROVIDER = 'piper';
    process.env.PIPER_VOICES_DIR = 'D:/nothing/here';
    assert.equal(tts.narrationAvailable(), false);
    assert.deepEqual(await tts.voices(), []);
    const beats = await tts.speakBeats(['One.', 'Two.'], { voice: 'en_US-lessac-medium' });
    assert.deepEqual(beats, [{ clipSeconds: null }, { clipSeconds: null }],
      'every beat comes back silent, and the film is rendered without a voice');
  } finally {
    if (saved.provider === undefined) delete process.env.TTS_PROVIDER;
    else process.env.TTS_PROVIDER = saved.provider;
    if (saved.dir === undefined) delete process.env.PIPER_VOICES_DIR;
    else process.env.PIPER_VOICES_DIR = saved.dir;
  }
});
