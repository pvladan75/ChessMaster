// tts_azure.test.js — everything about the Azure voice that can be checked
// without a network, a key, or somebody's subscription.
//
// The two calls themselves are one `fetch` each and are proved by
// `scripts/tts-probe.js` against a real resource. What is tested here is what
// gets *asked for*: the voice's language, the shape the picker is handed, and —
// the one that matters — the document a trainer's sentence is wrapped in. Azure
// takes SSML and nothing else, so every sentence written in the studio becomes
// part of an XML document on its way to the voice, and a sentence containing
// „1 < 2" or „Nimzo & Bogo" must arrive as those characters rather than as
// markup that fails.
const test = require('node:test');
const assert = require('node:assert/strict');

const azure = require('../services/tts/azure');
const tts = require('../services/tts');

/// Both variables, restored afterwards. The provider reads them on every call
/// rather than at import, so a test can configure it and the next test is not
/// looking at this one's leftovers.
async function withAzure({ key = 'test-key', region = 'northeurope' }, run) {
  const saved = {
    key: process.env.AZURE_SPEECH_KEY,
    region: process.env.AZURE_SPEECH_REGION,
    provider: process.env.TTS_PROVIDER,
  };
  try {
    process.env.AZURE_SPEECH_KEY = key;
    process.env.AZURE_SPEECH_REGION = region;
    process.env.TTS_PROVIDER = 'azure';
    return await run();
  } finally {
    for (const [name, value] of [
      ['AZURE_SPEECH_KEY', saved.key],
      ['AZURE_SPEECH_REGION', saved.region],
      ['TTS_PROVIDER', saved.provider],
    ]) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

test('a language is read off the voice, and Serbian is why it is not two parts', () => {
  // **Everything before the last hyphen.** Azure's locales are not all
  // two-part: Serbian carries its script in the middle, and a few regional
  // Chinese voices carry a third segment of their own. Reading two parts would
  // send `xml:lang="sr-Latn"` — a language that does not exist — and group
  // every Serbian voice under it in the picker.
  assert.equal(azure.languageOf('sr-Latn-RS-NicholasNeural'), 'sr-Latn-RS');
  assert.equal(azure.languageOf('zh-CN-liaoning-XiaobeiNeural'), 'zh-CN-liaoning');
  assert.equal(azure.languageOf('en-US-JennyNeural'), 'en-US');
  assert.equal(azure.languageOf('hr-HR-SreckoNeural'), 'hr-HR');

  // Not a voice name: refused rather than guessed at, because the guess would
  // travel as an `xml:lang` and be answered with a message about the voice.
  assert.equal(azure.languageOf('Zira'), '');
  assert.equal(azure.languageOf(''), '');
  assert.equal(azure.languageOf(null), '');
});

test('the tier is read off the name, because nothing else shows the rate', () => {
  assert.equal(azure.tierOf('en-US-JennyNeural'), 'Neural');
  assert.equal(azure.tierOf('en-US-Ava:DragonHDLatestNeural'), 'Neural HD');
  assert.equal(azure.tierOf('en-US-AndrewMultilingualNeural'), 'Multilingual');
  // An unknown shape reads as the ordinary tier rather than as the dearest: a
  // wrong guess that overstates the price frightens somebody off a voice that
  // costs the least.
  assert.equal(azure.tierOf('sr-Latn-RS-SophieNeural'), 'Neural');
});

test('the voice list is every language, sorted so a picker can group it', () => {
  const voices = azure.toVoices([
    {
      ShortName: 'en-US-JennyNeural', DisplayName: 'Jenny', Locale: 'en-US', Gender: 'Female',
    },
    {
      ShortName: 'sr-Latn-RS-NicholasNeural', DisplayName: 'Nicholas', Locale: 'sr-Latn-RS', Gender: 'Male',
    },
    null,
    {
      ShortName: 'en-GB-RyanNeural', DisplayName: 'Ryan', Locale: 'en-GB', Gender: 'Male',
    },
    // No display name and no locale: both are read off the short name rather
    // than dropping a voice the account really has.
    { ShortName: 'hr-HR-SreckoNeural' },
    // Not a voice at all.
    { DisplayName: 'Nameless' },
  ]);

  assert.deepEqual(voices.map((v) => v.id), [
    'en-GB-RyanNeural', 'en-US-JennyNeural', 'hr-HR-SreckoNeural', 'sr-Latn-RS-NicholasNeural',
  ]);
  assert.equal(voices[3].language, 'sr-Latn-RS');
  assert.equal(voices[3].gender, 'male', 'lowercased, like every other provider');
  assert.equal(voices[2].language, 'hr-HR', 'read off the name when the locale is missing');
  assert.match(voices[0].name, /Ryan/);
  assert.match(voices[0].name, /en-GB-RyanNeural/,
    'and the id too, or two languages\' Ryan are one entry in the picker');
});

test('a trainer\'s sentence reaches the voice as text, never as markup', () => {
  // The whole reason this provider has an `ssmlFor` with a test. Google's
  // endpoint takes plain text and `google.js` sends prose; this one takes SSML,
  // so the escaping is the boundary between „a sentence with a `<` in it" and
  // „a request Azure refuses".
  const ssml = azure.ssmlFor({
    text: 'If 1 < 2 & you play "Bd5", it\'s over.',
    voice: 'sr-Latn-RS-NicholasNeural',
  });

  assert.match(ssml, /&lt; 2 &amp; /);
  assert.match(ssml, /&quot;Bd5&quot;/);
  assert.match(ssml, /it&apos;s over\./);
  // The ampersand goes first, or the four escapes written after it are escaped
  // a second time and the voice says „and a m p semicolon".
  assert.ok(!ssml.includes('&amp;lt;'), 'nothing is escaped twice');
  assert.ok(!/<(?!speak|\/speak|voice|\/voice)/.test(ssml), 'no tag but the two this writes');

  assert.match(ssml, /xml:lang="sr-Latn-RS"/);
  assert.match(ssml, /<voice name="sr-Latn-RS-NicholasNeural">/);

  // A name that carries no language cannot be turned into a document at all,
  // and saying so here is better than a 400 with a message about the voice.
  assert.throws(() => azure.ssmlFor({ text: 'Hello.', voice: 'Zira' }), /not an Azure voice/);
});

test('the request is built from the region, and says what it wants back', async () => {
  await withAzure({ key: 'k-123', region: 'northeurope' }, async () => {
    const { url, options } = azure.requestFor({
      text: 'Look at d5.',
      voice: 'en-US-JennyNeural',
    });

    assert.equal(url, 'https://northeurope.tts.speech.microsoft.com/cognitiveservices/v1');
    assert.equal(options.method, 'POST');
    assert.equal(options.headers['Ocp-Apim-Subscription-Key'], 'k-123');
    assert.equal(options.headers['Content-Type'], 'application/ssml+xml');
    // Azure refuses a request with no User-Agent, and does not say so in as
    // many words.
    assert.ok(options.headers['User-Agent'], 'a User-Agent, which Azure requires');
    assert.match(options.body, /Look at d5\./);

    // The format is the whole sample rate of the film. A track built from
    // clips at two rates drifts out of step with the board.
    const { RATE } = require('../services/narrationTrack');
    assert.equal(options.headers['X-Microsoft-OutputFormat'], `riff-${RATE}hz-16bit-mono-pcm`);
    assert.equal(azure.SAMPLE_RATE, RATE);
    assert.match(options.headers['X-Microsoft-OutputFormat'], /^riff-/,
      'a RIFF body, which is the WAV header wav.js reads');
  });
});

test('a key without a region is not a configured server', async () => {
  // Both, or the URL is built from an empty string and the failure arrives as
  // something about a host rather than something about configuration.
  await withAzure({ key: 'k-123', region: '' }, async () => {
    assert.equal(azure.available(), false);
    assert.equal(await tts.narrationAvailable(), false);
    assert.deepEqual(await tts.voices(), []);
  });

  await withAzure({ key: '', region: 'northeurope' }, async () => {
    assert.equal(azure.available(), false);
  });

  // A whole URL pasted where a region goes is the likely mistake, and it must
  // not build `https://https://….tts.speech.microsoft.com`.
  await withAzure({ key: 'k-123', region: 'https://northeurope.api.cognitive.microsoft.com/' }, async () => {
    assert.equal(azure.available(), false, 'a URL is not a region');
  });

  await withAzure({ key: 'k-123', region: 'NorthEurope' }, async () => {
    assert.equal(azure.available(), true, 'but the portal\'s capitals are fine');
  });
});

test('an unconfigured Azure speaks nothing rather than throwing', async () => {
  await withAzure({ key: '', region: '' }, async () => {
    assert.equal(await tts.narrationAvailable(), false);
    assert.deepEqual(await tts.voices(), []);
    assert.equal(await tts.speak({ text: 'Hello.', voice: 'en-US-JennyNeural' }), null,
      'and speaking answers null rather than throwing into the middle of a render');
  });
});

test('the cache key tells two providers apart for the same sentence', () => {
  // Azure and piper both have an English voice, and a film narrated by one must
  // never be handed the other's clips out of the cache.
  const asAzure = tts.cacheKey({ text: 'Look at d5.', voice: 'en-US-JennyNeural', provider: 'azure' });
  const asPiper = tts.cacheKey({ text: 'Look at d5.', voice: 'en-US-JennyNeural', provider: 'piper' });
  assert.notEqual(asAzure, asPiper);
});
