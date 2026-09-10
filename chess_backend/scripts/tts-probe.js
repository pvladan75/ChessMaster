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

  // The languages that decide this project's answer: English for what is
  // written in English, and whatever is on offer for what is written in
  // Serbian. Azure writes that locale with its script in the middle
  // (`sr-Latn-RS`) while piper writes `sr-RS`, so both are asked for — and the
  // answer is read off this list rather than remembered in a comment, which is
  // how „neither has a Serbian voice" came to be repeated in three files.
  for (const code of ['en-US', 'en-GB', 'hr-HR', 'sr-RS', 'sr-Latn-RS']) {
    const some = list.filter((v) => v.language === code);
    console.log(`  ${code}: ${some.length ? some.slice(0, 6).map((v) => `${v.id} (${v.tier})`).join(', ') : 'none'}`);
  }

  if (!text) {
    console.log('\nPass a sentence to synthesise one, e.g.');
    console.log('  node scripts/tts-probe.js "Look at the d5 square." en-US-Neural2-F');
    return;
  }

  // **A voice, always, and named in the output.** piper falls back to the first
  // model it has; a cloud provider has no local list to fall back to, so asking
  // it to speak with no voice is refused before the request is built. The list
  // was just fetched — pick from it, and say which, or the wav that comes back
  // is anonymous.
  const chosen = voice
    || (list.find((v) => v.language === 'en-US') || list[0] || {}).id;
  if (!chosen) {
    console.log('\nThis provider offers no voice at all. Nothing to synthesise.');
    process.exit(1);
  }
  if (!voice) console.log(`\nvoice    : ${chosen}   <- pass another as the second argument`);

  const t0 = Date.now();
  const clip = await tts.speak({ text, voice: chosen });
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
