// tts_google.test.js — everything about the Google voice that can be checked
// without a network, a key, or somebody's credit card.
//
// The two calls themselves are one `fetch` each and are proved by
// `scripts/tts-probe.js` against a real project. What is tested here is the
// part that decides *what gets asked for*: the voice's language, its price
// tier, and the shape the picker is handed — because a request whose
// `languageCode` disagrees with its voice is refused by Google with a message
// about the voice, which is a confusing way to learn that a picker sent a
// mismatched pair.
const test = require('node:test');
const assert = require('node:assert/strict');

const google = require('../services/tts/google');
const tts = require('../services/tts');

test('a language is read off the voice, never carried beside it', () => {
  assert.equal(google.languageOf('en-US-Neural2-F'), 'en-US');
  assert.equal(google.languageOf('hr-HR-Standard-A'), 'hr-HR');
  assert.equal(google.languageOf('cmn-CN-Wavenet-A'), 'cmn-CN');
  assert.equal(google.languageOf('en-GB-Chirp3-HD-Aoede'), 'en-GB');

  // Not a voice name: refused rather than guessed at. The alternative is a
  // request with an empty `languageCode`, which Google answers with a message
  // about the voice rather than about the code.
  assert.equal(google.languageOf('Zira'), '');
  assert.equal(google.languageOf(''), '');
  assert.equal(google.languageOf(null), '');
});

test('the price tier is read off the name, because nothing else shows it', () => {
  // Forty times the bill between the cheapest and the dearest, and no other
  // difference a trainer could see in a dropdown.
  assert.equal(google.tierOf('en-US-Standard-C'), 'Standard');
  assert.equal(google.tierOf('en-US-Wavenet-D'), 'WaveNet');
  assert.equal(google.tierOf('en-US-Neural2-F'), 'Neural2');
  assert.equal(google.tierOf('en-US-Studio-O'), 'Studio');
  assert.equal(google.tierOf('en-US-Chirp3-HD-Aoede'), 'Chirp 3 HD');
  // Unknown shapes read as the cheapest rather than as the dearest: a wrong
  // guess that overstates the price frightens somebody off a voice that is free.
  assert.equal(google.tierOf('hr-HR-A'), 'Standard');
});

test('the voice list is every language, sorted so a picker can group it', () => {
  // Every language, since 9.9.2026: the trainer picks the voice whose language
  // matches what they wrote, and Serbian text is read by a Croatian voice
  // because neither Google nor Azure has a Serbian one.
  const voices = google.toVoices({
    voices: [
      { name: 'en-US-Neural2-F', languageCodes: ['en-US'], ssmlGender: 'FEMALE' },
      { name: 'hr-HR-Standard-A', languageCodes: ['hr-HR'], ssmlGender: 'FEMALE' },
      { name: 'en-GB-Standard-B', languageCodes: ['en-GB'], ssmlGender: 'MALE' },
      { name: 'hr-HR-Standard-B', languageCodes: ['hr-HR'], ssmlGender: 'MALE' },
    ],
  });

  assert.deepEqual(voices.map((v) => v.id), [
    'en-GB-Standard-B', 'en-US-Neural2-F', 'hr-HR-Standard-A', 'hr-HR-Standard-B',
  ]);
  assert.ok(voices.some((v) => v.language === 'hr-HR'), 'Croatian is in the list');
  assert.equal(voices[1].tier, 'Neural2');
  assert.equal(voices[1].gender, 'female');
});

test('a malformed entry is dropped rather than offered', () => {
  const voices = google.toVoices({
    voices: [
      { name: 'en-US-Neural2-F', languageCodes: ['en-US'] },
      { name: '', languageCodes: ['en-US'] },
      { languageCodes: ['en-US'] },
      { name: 'Zira' },
      null,
    ],
  });
  assert.deepEqual(voices.map((v) => v.id), ['en-US-Neural2-F'],
    'a picker that lists a voice the server cannot use produces a refusal');
  assert.deepEqual(google.toVoices({}), []);
  assert.deepEqual(google.toVoices(null), []);
});

test('the provider is off unless a credentials file is actually there', () => {
  // Config-only, and it checks the file rather than the variable: a path
  // pointing at nothing is how a server ends up offering a switch that fails
  // two minutes into a render.
  const saved = process.env.GOOGLE_TTS_CREDENTIALS;
  try {
    process.env.GOOGLE_TTS_CREDENTIALS = '';
    assert.equal(google.available(), false, 'no path, no narration');
    process.env.GOOGLE_TTS_CREDENTIALS = 'D:/nothing/here/service-account.json';
    assert.equal(google.available(), false, 'a path to nothing is not credentials');
  } finally {
    if (saved === undefined) delete process.env.GOOGLE_TTS_CREDENTIALS;
    else process.env.GOOGLE_TTS_CREDENTIALS = saved;
  }
});

test('the sample rate asked for is the rate the track is built at', () => {
  // Otherwise every clip is resampled on the way into the concatenation, and a
  // resample is a second place for a duration to change.
  const { RATE } = require('../services/narrationTrack');
  assert.equal(google.SAMPLE_RATE, RATE);
});

test('an unconfigured server offers nothing and says so', async () => {
  const saved = process.env.TTS_PROVIDER;
  try {
    process.env.TTS_PROVIDER = 'google';
    process.env.GOOGLE_TTS_CREDENTIALS = '';
    assert.equal(tts.narrationAvailable(), false);
    assert.deepEqual(await tts.voices(), []);
    assert.equal(await tts.speak({ text: 'Hello.', voice: 'en-US-Neural2-F' }), null,
      'and speaking answers null rather than throwing into the middle of a render');

    process.env.TTS_PROVIDER = 'nonesuch';
    assert.equal(tts.narrationAvailable(), false);
    assert.deepEqual(await tts.voices(), []);
  } finally {
    if (saved === undefined) delete process.env.TTS_PROVIDER;
    else process.env.TTS_PROVIDER = saved;
  }
});

test('the cache key changes with the voice, not with the whitespace', () => {
  // A trainer who reflows a sentence has not changed a word of it, and the
  // voice cannot tell the difference either. A trainer who changes the voice
  // has changed everything about the sound.
  const one = tts.cacheKey({ text: 'Look at d5.', voice: 'en-US-Neural2-F', provider: 'google' });
  const reflowed = tts.cacheKey({ text: '  Look   at\n d5. ', voice: 'en-US-Neural2-F', provider: 'google' });
  const otherVoice = tts.cacheKey({ text: 'Look at d5.', voice: 'hr-HR-Standard-A', provider: 'google' });
  const otherProvider = tts.cacheKey({ text: 'Look at d5.', voice: 'en-US-Neural2-F', provider: 'windows' });

  assert.equal(one, reflowed);
  assert.notEqual(one, otherVoice);
  assert.notEqual(one, otherProvider);
});
