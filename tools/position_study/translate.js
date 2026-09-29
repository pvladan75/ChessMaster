// translate.js — a study's kept sentences in another language, by the server's
// own translation code without the server: phase 0 of
// docs/PLAN-JEZIK-STUDIJE.md.
//
//     node translate.js <kept.json> <code> <out.json>
//
// <kept.json> is what `chess_app/tool/position_study.dart` wrote: the slots
// the app's check kept, `{ "m1.move": "..." }`. They are translated by
// `translateSlots` (`chess_backend/services/studyTranslation.js`), the code
// `POST /study-words` runs: the tutorial translation's prompt, answer reader
// and judge, and a second request for what the judge refused. Written: every
// slot's translation, the slots refused at the first request and in the end,
// the requests, their tokens and the seconds.
//
// The key is read from the environment, or from the file STUDY_ENV names. It
// is never written anywhere.

const fs = require('fs');
const path = require('path');

const backend = path.join(__dirname, '..', '..', 'chess_backend');
const { LANGUAGE_NAMES } = require(path.join(backend, 'services', 'tutorialTranslation'));
const {
  TRANSLATION_MODEL, TRANSLATION_TIMEOUT_S, translateSlots,
} = require(path.join(backend, 'services', 'studyTranslation'));
const { createDeepSeek } = require(path.join(backend, 'services', 'llm', 'deepseek'));

const WANTED = ['DEEPSEEK_API_KEY', 'DEEPSEEK_URL'];

function readEnvFile(file) {
  if (!file || !fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!m || !WANTED.includes(m[1]) || process.env[m[1]]) continue;
    process.env[m[1]] = m[2].replace(/^(['"])(.*)\1$/, '$2');
  }
}

async function main() {
  const [keptFile, code, outFile] = process.argv.slice(2);
  if (!keptFile || !LANGUAGE_NAMES[code] || !outFile) {
    console.error(`usage: node translate.js <kept.json> <${Object.keys(LANGUAGE_NAMES).join('|')}> <out.json>`);
    process.exit(2);
  }
  readEnvFile(process.env.STUDY_ENV);
  const kept = JSON.parse(fs.readFileSync(keptFile, 'utf8'));
  const provider = createDeepSeek({
    model: TRANSLATION_MODEL,
    timeoutMs: TRANSLATION_TIMEOUT_S * 1000,
  });
  const tokens = [];
  const started = Date.now();
  const result = await translateSlots({
    provider,
    slots: kept,
    code,
    record: (total) => { tokens.push(total); },
    // The tool has no request that arrived earlier: the clock starts here.
    startedAt: started,
  });
  const out = {
    code,
    slots: result.slots,
    firstRefused: result.firstRefused,
    refused: result.refused,
    requests: result.requests,
    tokens,
    seconds: (Date.now() - started) / 1000,
  };
  fs.writeFileSync(outFile, `${JSON.stringify(out, null, 1)}\n`);
}

main().catch((err) => {
  console.error(`${err.name}: ${err.message}`);
  process.exit(1);
});
