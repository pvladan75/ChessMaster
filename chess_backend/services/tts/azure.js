// tts/azure.js — Microsoft Azure Speech, the cloud voice that could be paid for.
//
// Added on 11.9.2026, on the owner's decision: he has a key and a region, which
// is the one thing Google Cloud never allowed — Cloud does not accept an
// individual payments profile in Serbia, so `google.js` has sat written and
// unreachable since 9.9.2026.
//
// **A plain regional Speech resource**, so both URLs are built from the region
// and the key travels in one header. There is no OAuth here and no key file:
// `Ocp-Apim-Subscription-Key` is the whole of it, which is why this file is
// shorter than the Google one while doing the same job.
//
// **The one real difference from Google is SSML.** The `cognitiveservices/v1`
// endpoint takes SSML and nothing else, while Google's takes plain text — which
// `google.js` chose deliberately, because a trainer's sentence is prose, and
// prose with a stray `<` in it is not markup that failed, it is a sentence that
// would be refused as invalid SSML. That choice is not available here, so the
// escaping is done in `ssmlFor` and tested: whatever the trainer wrote reaches
// the voice as text and never as markup.
//
// **655 voices across 154 languages**, from a real account on 11.9.2026 — and
// four of them Serbian, `sr-RS-NicholasNeural` and `sr-RS-SophieNeural` with
// their `sr-Latn-RS-` twins, which is the thing three files in this project
// said did not exist. That list is also why the export sheet asks for a
// language before it asks for a voice: one dropdown of 655 is a list nobody
// scrolls to the end of.
//
// Piper stays installed and stays the fallback — `TTS_PROVIDER` picks. It needs
// no account, no card and no network, which is worth keeping whatever the
// billing does next.
const fs = require('fs');

const logger = require('../logger');

/// The rate the narration track is built at, matching `google.js` and the piper
/// models: one sample rate through the whole film means no resample, and a
/// resample is a second place for a duration to change.
const SAMPLE_RATE = 22050;
const OUTPUT_FORMAT = 'riff-22050hz-16bit-mono-pcm';

/// Azure refuses a request with no `User-Agent`, and the refusal does not say so
/// in as many words.
const USER_AGENT = 'chess-coach-narration';

function key() {
  return (process.env.AZURE_SPEECH_KEY || '').trim();
}

/// The region short name — `northeurope`, `westeurope` — and not a URL.
///
/// Both endpoints are built from it, so a value with a slash or a scheme in it
/// would produce a URL that fails with something about a host rather than
/// something about configuration. Letters and digits is what a region is.
function region() {
  return (process.env.AZURE_SPEECH_REGION || '').trim().toLowerCase();
}

function available() {
  return Boolean(key()) && /^[a-z0-9]+$/.test(region());
}

function host() {
  return `https://${region()}.tts.speech.microsoft.com`;
}

/// `sr-Latn-RS-NicholasNeural` → `sr-Latn-RS`, and `en-US-JennyNeural` →
/// `en-US`.
///
/// **Everything before the last hyphen**, not the first two parts. Azure's
/// locales are not all two-part: Serbian is written `sr-Latn-RS`, with its
/// script in the middle, and a few regional Chinese voices carry a third
/// segment of their own (`zh-CN-liaoning`). Taking two parts would send
/// `xml:lang="sr-Latn"` and group the Serbian voices under a language that does
/// not exist.
function languageOf(shortName) {
  const name = String(shortName || '');
  const cut = name.lastIndexOf('-');
  return cut > 0 ? name.slice(0, cut) : '';
}

/// Which kind of voice it is, read off its own name.
///
/// Shown in the picker beside the voice like every other provider's tier. The HD
/// voices bill at a different rate from the ordinary neural ones, which is a
/// difference a trainer could not otherwise see.
function tierOf(shortName) {
  const name = String(shortName || '');
  if (/HD/.test(name)) return 'Neural HD';
  if (/Multilingual/i.test(name)) return 'Multilingual';
  return 'Neural';
}

/// Azure's `voices/list`, as the app's picker wants it.
///
/// Everything, in every language: the owner's rule of 9.9.2026 is that a trainer
/// picks the voice whose language matches what they wrote, and nothing here
/// guesses at a language for them.
function toVoices(payload) {
  const voices = Array.isArray(payload) ? payload : [];
  return voices
    // A null in the list is not a voice. Azure does not send one; a proxy, a
    // cache or a hand-written fixture might, and a picker that throws while
    // being built is worse than one entry short.
    .filter(Boolean)
    .map((voice) => ({
      id: voice.ShortName,
      name: voice.DisplayName || voice.ShortName,
      language: voice.Locale || languageOf(voice.ShortName),
      // **What a person calls that language.** 655 voices across 154 languages
      // came back from a real account on 11.9.2026, which is a picker nobody
      // can use without narrowing it first — and „Serbian (Latin, Serbia)" is
      // the difference between narrowing it and guessing at `sr-Latn-RS`.
      // Azure is the only provider that sends this; the app falls back to the
      // code, which is what piper and Google have always shown.
      languageName: voice.LocaleName || '',
      gender: String(voice.Gender || '').toLowerCase(),
      tier: tierOf(voice.ShortName),
    }))
    .filter((voice) => voice.id && voice.language)
    .sort((a, b) => a.language.localeCompare(b.language) || a.id.localeCompare(b.id));
}

async function voices() {
  const res = await fetch(`${host()}/cognitiveservices/voices/list`, {
    headers: { 'Ocp-Apim-Subscription-Key': key(), 'User-Agent': USER_AGENT },
  });
  if (!res.ok) {
    throw new Error(`voices/list answered ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }
  return toVoices(await res.json());
}

/// The five characters that are markup, and nothing else.
///
/// `&` first, or the ampersands written by the other four are escaped a second
/// time and the voice says „and a m p semicolon". The quotes are escaped too,
/// even though the text lands in element content where they are legal: it costs
/// nothing and it means this function is still right if a caller ever puts its
/// result in an attribute.
function escapeXml(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/// The document sent to the synthesiser.
///
/// A named function with a test rather than three lines inside the request,
/// because this is the one place a trainer's own words become part of a
/// document: a sentence containing `<` or `&` has to arrive as those characters
/// and never as markup.
function ssmlFor({ text, voice }) {
  const lang = languageOf(voice);
  if (!lang) throw new Error(`not an Azure voice name: ${voice}`);
  return '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"'
    + ` xml:lang="${escapeXml(lang)}"><voice name="${escapeXml(voice)}">`
    + `${escapeXml(text)}</voice></speak>`;
}

/// Everything the synthesis request is, without sending it.
///
/// Same reason as `ssmlFor`: the output format decides the sample rate of every
/// clip in the film, and a test that cannot read the headers cannot notice it
/// changing.
function requestFor({ text, voice }) {
  return {
    url: `${host()}/cognitiveservices/v1`,
    options: {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': key(),
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': OUTPUT_FORMAT,
        'User-Agent': USER_AGENT,
      },
      body: ssmlFor({ text, voice }),
    },
  };
}

async function synthesize({ text, voice, outputPath, signal = null }) {
  if (!voice) throw new Error('Azure needs a voice name; the picker sends one');
  const { url, options } = requestFor({ text, voice });

  // The export's own signal. A trainer who has gone must not be synthesised for
  // either — and unlike a local engine, there is a bill on the other end of this
  // one.
  const res = await fetch(url, signal ? { ...options, signal } : options);

  if (!res.ok) {
    const detail = (await res.text()).slice(0, 300);
    // Loud, and with the status: 401 is the key, 403 is a region that does not
    // match the resource, 429 is the quota — three different evenings, and the
    // alternative to saying which is a silent film nobody can explain.
    logger.error({ status: res.status, voice }, `[TTS] Azure refused: ${detail}`);
    throw new Error(`cognitiveservices/v1 answered ${res.status}`);
  }

  // A RIFF body, which is what `./wav.js` reads and what the narration track
  // concatenates — the same shape Google's LINEAR16 comes back in.
  fs.writeFileSync(outputPath, Buffer.from(await res.arrayBuffer()));
  return outputPath;
}

module.exports = {
  available,
  voices,
  synthesize,
  // Exported for the tests: everything above that can be checked without a
  // network, a key, or somebody's subscription.
  languageOf,
  tierOf,
  toVoices,
  escapeXml,
  ssmlFor,
  requestFor,
  SAMPLE_RATE,
  OUTPUT_FORMAT,
};
