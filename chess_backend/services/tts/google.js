// tts/google.js — Google Cloud Text-to-Speech.
//
// Chosen by the owner on 9.9.2026 over Azure, OpenAI and ElevenLabs, on price
// and on the size of the voice list: $4 per million characters for Standard and
// WaveNet, $16 for Neural2, with a free tier of 4M Standard/WaveNet characters
// a month. A tutorial is about 2,400 characters, so a narrated export costs
// under four cents at the Neural2 rate — and nothing at all the second time,
// because `../tts` caches by the sentence.
//
// **Neither Google nor Azure has a Serbian voice.** Checked against both voice
// lists on 9.9.2026 rather than remembered. The answer for Serbian text is
// `hr-HR` — Croatian is close enough phonetically that it reads as an accent
// rather than as a mistake — and that is a choice the trainer makes by picking
// the voice, not something this file decides for them.
//
// **Authentication is OAuth, not an API key.** The REST reference lists the
// `cloud-platform` scope and no key parameter, and the droplet is not a Google
// VM, so there is no attached service account to inherit: what this needs is a
// service-account JSON key file and `GOOGLE_TTS_CREDENTIALS` pointing at it.
// `google-auth-library` mints and refreshes the token; it is already installed
// as part of `@google/genai`, and is now a declared dependency rather than a
// borrowed one.
const fs = require('fs');

const logger = require('../logger');

const SYNTHESIZE_URL = 'https://texttospeech.googleapis.com/v1/text:synthesize';
const VOICES_URL = 'https://texttospeech.googleapis.com/v1/voices';
const SCOPE = 'https://www.googleapis.com/auth/cloud-platform';

/// The rate the narration track is built at. Asking Google for it directly
/// saves a resample, and a resample is a second place for a duration to change.
const SAMPLE_RATE = 22050;

let authClient = null;

function credentialsPath() {
  return process.env.GOOGLE_TTS_CREDENTIALS
    || process.env.GOOGLE_APPLICATION_CREDENTIALS
    || '';
}

function available() {
  const path = credentialsPath();
  return Boolean(path) && fs.existsSync(path);
}

async function token() {
  if (!authClient) {
    // Required lazily: a server with no credentials configured must not pay for
    // loading an auth library it will never call.
    const { GoogleAuth } = require('google-auth-library');
    authClient = new GoogleAuth({ keyFile: credentialsPath(), scopes: [SCOPE] });
  }
  const value = await authClient.getAccessToken();
  if (!value) throw new Error('no access token: check GOOGLE_TTS_CREDENTIALS');
  return typeof value === 'string' ? value : value.token;
}

/// `en-US-Neural2-F` → `en-US`, and `cmn-CN-Wavenet-A` → `cmn-CN`.
///
/// Read off the voice name rather than carried beside it, so the two cannot
/// disagree: a request whose `languageCode` does not match its voice is refused
/// by Google with a message about the voice, which is a confusing way to learn
/// that a picker sent the wrong pair.
function languageOf(voiceName) {
  const parts = String(voiceName || '').split('-');
  return parts.length >= 2 ? `${parts[0]}-${parts[1]}` : '';
}

/// Which price tier a voice belongs to, read off its own name.
///
/// Shown in the picker beside the voice, because the difference between
/// `Standard` and `Studio` is forty times the bill and nothing else a trainer
/// could see.
function tierOf(voiceName) {
  const name = String(voiceName || '').toLowerCase();
  if (name.includes('chirp')) return 'Chirp 3 HD';
  if (name.includes('studio')) return 'Studio';
  if (name.includes('neural2')) return 'Neural2';
  if (name.includes('wavenet')) return 'WaveNet';
  if (name.includes('polyglot')) return 'Polyglot';
  if (name.includes('news')) return 'News';
  return 'Standard';
}

/// Google's `voices.list`, as the app's picker wants it.
///
/// Everything, in every language, and that is the owner's decision of 9.9.2026:
/// a trainer picks the voice whose language matches what they wrote. Sorted by
/// language so the picker can group without re-deriving anything.
function toVoices(payload) {
  const voices = Array.isArray(payload?.voices) ? payload.voices : [];
  return voices
    // A null in the list is not a voice. Google does not send one; a proxy, a
    // cache or a hand-written fixture might, and a picker that throws while
    // being built is worse than one entry short.
    .filter(Boolean)
    .map((voice) => ({
      id: voice.name,
      name: voice.name,
      language: (voice.languageCodes && voice.languageCodes[0]) || languageOf(voice.name),
      gender: (voice.ssmlGender || '').toLowerCase(),
      tier: tierOf(voice.name),
    }))
    .filter((voice) => voice.id && voice.language)
    .sort((a, b) => a.language.localeCompare(b.language) || a.id.localeCompare(b.id));
}

async function voices() {
  const res = await fetch(VOICES_URL, {
    headers: { Authorization: `Bearer ${await token()}` },
  });
  if (!res.ok) {
    throw new Error(`voices.list answered ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }
  return toVoices(await res.json());
}

async function synthesize({ text, voice, outputPath }) {
  const name = voice || 'en-US-Neural2-F';
  const languageCode = languageOf(name);
  if (!languageCode) throw new Error(`not a Google voice name: ${name}`);

  const res = await fetch(SYNTHESIZE_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${await token()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      // `text`, never `ssml`: a trainer's sentence is prose, and prose with a
      // stray `<` in it is not markup that failed, it is a sentence that would
      // be refused as invalid SSML.
      input: { text },
      voice: { languageCode, name },
      // LINEAR16 comes back with its WAV header on, which is what
      // `../tts/wav.js` reads and what the narration track concatenates.
      audioConfig: { audioEncoding: 'LINEAR16', sampleRateHertz: SAMPLE_RATE },
    }),
  });

  if (!res.ok) {
    const detail = (await res.text()).slice(0, 300);
    // Loud, and with the status: a 403 here is almost always billing that was
    // never enabled on the project, and the alternative to saying so is a
    // silent film nobody can explain.
    logger.error({ status: res.status, voice: name }, `[TTS] Google refused: ${detail}`);
    throw new Error(`text:synthesize answered ${res.status}`);
  }

  const body = await res.json();
  if (!body.audioContent) throw new Error('text:synthesize returned no audio');
  fs.writeFileSync(outputPath, Buffer.from(body.audioContent, 'base64'));
  return outputPath;
}

module.exports = {
  available,
  voices,
  synthesize,
  // Exported for the tests: everything above that can be checked without a
  // network, a key, or somebody's credit card.
  languageOf,
  tierOf,
  toVoices,
  SAMPLE_RATE,
};
