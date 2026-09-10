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
const { narrateFilm } = require('../services/tutorialNarration');

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

test('a probe says yes to a clean exit and to nothing else', () => {
  // **Anything but a clean exit is a no.** A provider that read „no answer" as
  // „yes" would put the whole render back where it started: the switch drawn,
  // the film drawn, and the silence found a minute later.
  assert.equal(piper.probeSaysReady({ status: 0 }), true);
  assert.equal(piper.probeSaysReady({ status: 1 }), false, 'no module named piper');
  assert.equal(piper.probeSaysReady({ error: new Error('spawn ENOENT') }), false,
    'no interpreter at all');
  assert.equal(piper.probeSaysReady({ status: null }), false, 'killed on the timeout');
  assert.equal(piper.probeSaysReady(null), false);
});

test('the engine is asked once per interpreter and remembered', async () => {
  // One interpreter start is a quarter of a second on a thread that is also
  // drawing somebody's film, and the answer cannot change while the process
  // lives — so it is asked once. The cost of that trade is written down where
  // `engineReady` is: installing piper under a running server needs a restart.
  const saved = process.env.PIPER_PYTHON;
  try {
    piper.forgetEngine();
    let asked = 0;
    const probe = async () => { asked += 1; return true; };

    process.env.PIPER_PYTHON = 'one-interpreter';
    assert.equal(await piper.engineReady(probe), true);
    assert.equal(await piper.engineReady(probe), true);
    assert.equal(asked, 1, 'remembered rather than asked again');

    process.env.PIPER_PYTHON = 'another-interpreter';
    assert.equal(await piper.engineReady(probe), true);
    assert.equal(asked, 2, 'a different interpreter is a different question');

    piper.forgetEngine();
    await piper.engineReady(probe);
    assert.equal(asked, 3, 'and the answer can be forgotten');
  } finally {
    piper.forgetEngine();
    if (saved === undefined) delete process.env.PIPER_PYTHON;
    else process.env.PIPER_PYTHON = saved;
  }
});

test('voices on disk and an engine that will not start is its own answer', async () => {
  // The fault of 10.9.2026, in one test. Six models sat in the voices
  // directory, `available()` said yes, the app drew the narration switch, the
  // server accepted `narrate: true` — and piper answered „No module named
  // piper" a minute later, so the film came back silent and was announced as
  // ready. „Installed" and „reachable from this process" are two questions.
  const saved = { provider: process.env.TTS_PROVIDER, python: process.env.PIPER_PYTHON };
  try {
    process.env.TTS_PROVIDER = 'piper';
    process.env.PIPER_PYTHON = path.join(os.tmpdir(), 'no-such-interpreter-here');
    piper.forgetEngine();

    await withVoicesDir(
      ['en_US-lessac-medium.onnx', 'en_US-lessac-medium.onnx.json'],
      async () => {
        assert.equal(piper.available(), true, 'the voices really are installed');
        assert.equal(await piper.engineReady(), false, 'and nothing can read them');
        assert.equal(await tts.narrationBlockedBy(), 'engine',
          'which is a different sentence from „no voices installed"');
        assert.equal(await tts.narrationAvailable(), false);
        assert.deepEqual(await tts.voices(), [],
          'and the picker offers none, so the switch is never drawn');
      },
    );
  } finally {
    piper.forgetEngine();
    if (saved.provider === undefined) delete process.env.TTS_PROVIDER;
    else process.env.TTS_PROVIDER = saved.provider;
    if (saved.python === undefined) delete process.env.PIPER_PYTHON;
    else process.env.PIPER_PYTHON = saved.python;
  }
});

test('the reason a film is silent is carried out of the narrator, not renamed', async () => {
  // Found by mutation: `narrateFilm` answering a hard-coded „unavailable" for
  // both refusals left every test green, and it is the answer a trainer reads.
  // „This server has no speech voices installed" sends somebody to install
  // models that are already sitting there, which is the wrong hour to lose.
  const saved = tts.narrationBlockedBy;
  const film = async (blocked) => {
    tts.narrationBlockedBy = async () => blocked;
    return narrateFilm({
      events: [{ timestampMs: 0, eventType: 'init', data: { fen: 'x', text: 'Look at d5.' } }],
      voice: 'en_US-lessac-medium',
      exportsDir: 'unused',
      filename: 'unused',
    });
  };
  try {
    assert.equal((await film('engine')).silentBecause, 'engine');
    assert.equal((await film('unavailable')).silentBecause, 'unavailable');
  } finally {
    tts.narrationBlockedBy = saved;
  }
});

test('an unconfigured server speaks nothing rather than throwing', async () => {
  const saved = { provider: process.env.TTS_PROVIDER, dir: process.env.PIPER_VOICES_DIR };
  try {
    process.env.TTS_PROVIDER = 'piper';
    process.env.PIPER_VOICES_DIR = 'D:/nothing/here';
    assert.equal(await tts.narrationAvailable(), false);
    assert.equal(await tts.narrationBlockedBy(), 'unavailable',
      'no voices, and the engine is not even asked');
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
