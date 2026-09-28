// words.js — the words for one study's request, written by the server's own
// code without the server: phase 0 of docs/PLAN-STUDIJA-POZICIJE.md.
//
//     node words.js <request.json> <answer.json>
//
// Reads the request the app's builder wrote, checks it and writes the prompt
// with `chess_backend/services/studyWords.js` — the code the route will run —
// asks DeepSeek through `services/llm/deepseek.js`, and writes what came back:
// the slots when the answer is the shape asked for, the problems when it is
// not, the prompt and the tokens either way.
//
// The key is read from the environment, or from the file STUDY_ENV names (a
// `.env` of the backend's). It is never written anywhere.

const fs = require('fs');
const path = require('path');

const backend = path.join(__dirname, '..', '..', 'chess_backend');
const {
  MODEL, EFFORT, validateStudyWordsRequest, buildStudyPrompt, checkStudyAnswer,
} = require(path.join(backend, 'services', 'studyWords'));
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
  const [requestFile, answerFile] = process.argv.slice(2);
  if (!requestFile || !answerFile) {
    console.error('usage: node words.js <request.json> <answer.json>');
    process.exit(2);
  }
  readEnvFile(process.env.STUDY_ENV);

  const request = validateStudyWordsRequest(
    JSON.parse(fs.readFileSync(requestFile, 'utf8')),
  );
  const prompt = buildStudyPrompt(request);
  // STUDY_MODEL and STUDY_EFFORT choose what is measured; unset, what the
  // server asks.
  const provider = createDeepSeek({
    model: process.env.STUDY_MODEL || MODEL,
    reasoningEffort: process.env.STUDY_EFFORT || EFFORT,
  });
  const out = { prompt, attempts: [] };
  const started = Date.now();
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    const reply = await provider.complete(prompt);
    const checked = checkStudyAnswer(reply.content, request);
    out.attempts.push({
      model: reply.model,
      tokens: reply.usage,
      finish: reply.finish,
      ok: checked.ok,
      problems: checked.problems || [],
      dropped: checked.dropped || [],
    });
    if (checked.ok) {
      out.slots = checked.slots;
      break;
    }
  }
  out.seconds = (Date.now() - started) / 1000;
  fs.writeFileSync(answerFile, `${JSON.stringify(out, null, 1)}\n`);
  if (!out.slots) process.exit(3);
}

main().catch((err) => {
  console.error(`${err.name}: ${err.message}`);
  process.exit(1);
});
