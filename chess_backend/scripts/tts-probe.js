// tts-probe.js — does the voice work, and what does it sound like?
//
//   node scripts/tts-probe.js                        # list the voices
//   node scripts/tts-probe.js "Look at the d5 square."
//   node scripts/tts-probe.js "Pogledaj polje d5." hr-HR-Standard-A
//
// The one thing a test cannot do: call the real service. Everything about the
// Google provider that can be checked without a network is in
// `test/tts_google.test.js`; this is the rest, and it is a script rather than a
// test because a test that needs somebody's credentials and bills their card is
// a test that fails on every machine but one.
//
// Reads `TTS_PROVIDER` and the credentials from the environment, prints nothing
// that came out of the key file, and writes its wav where you can play it.
require('dotenv').config();

const path = require('path');
const tts = require('../services/tts');

const OUT = path.join(__dirname, '..', 'exports', 'tts-probe.wav');

(async () => {
  const [, , text, voice] = process.argv;

  console.log(`provider : ${tts.providerName()}`);
  const blockedBy = await tts.narrationBlockedBy();
  console.log(`available: ${blockedBy === null}${blockedBy ? ` (${blockedBy})` : ''}`);
  if (blockedBy) {
    console.log('\nNothing is configured. Set TTS_PROVIDER=google and point');
    console.log('GOOGLE_TTS_CREDENTIALS at a service-account JSON key file.');
    process.exit(1);
  }

  const list = await tts.voices();
  console.log(`voices   : ${list.length}`);

  const byLanguage = new Map();
  for (const one of list) {
    byLanguage.set(one.language, (byLanguage.get(one.language) || 0) + 1);
  }
  console.log(`languages: ${byLanguage.size}`);

  // The two that decide this project's answer: English for what is written in
  // English, Croatian for what is written in Serbian, because neither Google
  // nor Azure has a Serbian voice.
  for (const code of ['en-US', 'en-GB', 'hr-HR', 'sr-RS']) {
    const some = list.filter((v) => v.language === code);
    console.log(`  ${code}: ${some.length ? some.slice(0, 6).map((v) => `${v.id} (${v.tier})`).join(', ') : 'none'}`);
  }

  if (!text) {
    console.log('\nPass a sentence to synthesise one, e.g.');
    console.log('  node scripts/tts-probe.js "Look at the d5 square." en-US-Neural2-F');
    return;
  }

  const t0 = Date.now();
  const clip = await tts.speak({ text, voice });
  if (!clip) {
    console.log('\nNothing came back. Check the log above for the refusal.');
    process.exit(1);
  }

  console.log(`\nsaid in ${Date.now() - t0} ms${clip.cached ? ' (from the cache)' : ''}`);
  console.log(`seconds : ${clip.seconds.toFixed(2)}`);
  console.log(`file    : ${clip.path}`);

  require('fs').copyFileSync(clip.path, OUT);
  console.log(`copy    : ${OUT}   <- play this one`);
})().catch((err) => {
  console.error(`\nFAILED: ${err.message}`);
  process.exit(1);
});
