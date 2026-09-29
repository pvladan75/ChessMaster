// measure.js — a tutorial made from a game, translated whole by the server's
// own tutorial translation code: phase 5 of docs/PLAN-JEZIK-STUDIJE.md, the
// measurement before anything is built.
//
//     node measure.js <out folder> <code> [<code>...]
//
// Reads the twenty tutorials the app's test fixtures hold — ten games, each
// as „Key moments" and „Whole game" (`chess_app/test/fixtures/game_tutorial/
// g*.json`, `expected.tutorial` and `expected.tutorialGame`, the app's own
// assembly of the recorded model answers) — and translates each with
// `translateTutorial` (`chess_backend/services/tutorialTranslation.js`): its
// items, its prompt, its judge, one more request for what the judge refused,
// the merge and the proof that nothing but words changed — the steps both
// `POST /lessons/:id/translate` and `POST /lessons/from-game/translate` take.
//
// Written: `<game>_<kind>_<code>.json` for each, and `report.md` with the
// totals and every text beside its translation. The key is read from the
// environment, or from the file STUDY_ENV names; it is never written anywhere.

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', '..');
const {
  LANGUAGE_NAMES, extractItems, readTranslationAnswer, translateTutorial,
} = require(path.join(root, 'chess_backend', 'services', 'tutorialTranslation'));
const { createDeepSeek } = require(path.join(root, 'chess_backend', 'services', 'llm', 'deepseek'));

const WANTED = ['DEEPSEEK_API_KEY', 'DEEPSEEK_URL'];

function readEnvFile(file) {
  if (!file || !fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!m || !WANTED.includes(m[1]) || process.env[m[1]]) continue;
    process.env[m[1]] = m[2].replace(/^(['"])(.*)\1$/, '$2');
  }
}

function tutorials() {
  const dir = path.join(root, 'chess_app', 'test', 'fixtures', 'game_tutorial');
  const out = [];
  for (const file of fs.readdirSync(dir).filter((f) => /^g\d+_.*\.json$/.test(f)).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
    const game = file.replace(/\.json$/, '').slice(0, 3);
    for (const [kind, key] of [['moments', 'tutorial'], ['whole', 'tutorialGame']]) {
      const t = data.expected[key];
      if (!t) continue;
      out.push({
        id: `${game}_${kind}`,
        tutorial: { title: t.title, description: t.description, steps: t.positionList },
      });
    }
  }
  return out;
}

async function translate(provider, tutorial, code) {
  const items = extractItems(tutorial);
  const run = {
    items: Object.keys(items).length,
    chars: Object.values(items).reduce((n, t) => n + t.length, 0),
    requests: [],
  };
  let last = Date.now();
  const started = last;
  const outcome = await translateTutorial({
    provider,
    tutorial,
    code,
    onReply: async (reply, { attempt, items: n }) => {
      run.requests.push({
        attempt,
        items: n,
        seconds: (Date.now() - last) / 1000,
        tokens: reply.usage.total,
        readable: readTranslationAnswer(reply.content) !== null,
      });
      last = Date.now();
    },
  });
  run.seconds = (Date.now() - started) / 1000;
  run.source = items;
  if (outcome.ok) {
    run.proved = true;
    run.faults = {};
    // The merged tutorial's texts, read back by the same items.
    run.translated = extractItems(outcome.merged);
  } else {
    run.faults = outcome.faults;
    run.translated = {};
  }
  run.firstFaults = run.requests.some((q) => q.attempt === 2) ? { second: true } : {};
  return run;
}

async function main() {
  const [outDir, ...codes] = process.argv.slice(2);
  if (!outDir || !codes.length || codes.some((c) => !LANGUAGE_NAMES[c])) {
    console.error(`usage: node measure.js <out folder> <${Object.keys(LANGUAGE_NAMES).join('|')}>...`);
    process.exit(2);
  }
  readEnvFile(process.env.STUDY_ENV);
  fs.mkdirSync(outDir, { recursive: true });
  const provider = createDeepSeek();
  const all = tutorials();
  const results = {};
  for (const code of codes) {
    // Five at a time: each tutorial's own wait is what is measured.
    for (let i = 0; i < all.length; i += 5) {
      await Promise.all(all.slice(i, i + 5).map(async ({ id, tutorial }) => {
        const file = path.join(outDir, `${id}_${code}.json`);
        let run;
        if (fs.existsSync(file)) {
          run = JSON.parse(fs.readFileSync(file, 'utf8'));
        } else {
          try {
            run = await translate(provider, tutorial, code);
          } catch (err) {
            run = { error: `${err.name}: ${err.message}` };
          }
          fs.writeFileSync(file, `${JSON.stringify(run, null, 1)}\n`);
        }
        results[`${id}_${code}`] = run;
        console.log(`${id} ${code}: ${run.error || `${run.items} items, ${run.seconds} s, `
          + `${Object.keys(run.faults).length} left`}`);
      }));
    }
  }
  fs.writeFileSync(path.join(outDir, 'report.md'), report(all, codes, results));
}

function report(all, codes, results) {
  const lines = ['# A tutorial from a game, translated whole', '',
    '| language | tutorials | passed whole | with a second request | items | characters | requests | seconds (median, max) | tokens |',
    '|---|---|---|---|---|---|---|---|---|'];
  for (const code of codes) {
    const runs = all.map(({ id }) => results[`${id}_${code}`]).filter((r) => r && !r.error);
    const seconds = runs.map((r) => r.seconds).sort((a, b) => a - b);
    lines.push(`| ${code} | ${runs.length} of ${all.length} | `
      + `${runs.filter((r) => !Object.keys(r.faults).length && r.proved).length} | `
      + `${runs.filter((r) => Object.keys(r.firstFaults).length).length} | `
      + `${runs.reduce((n, r) => n + r.items, 0)} | ${runs.reduce((n, r) => n + r.chars, 0)} | `
      + `${runs.reduce((n, r) => n + r.requests.length, 0)} | `
      + `${seconds[Math.floor(seconds.length / 2)]}, ${seconds[seconds.length - 1]} | `
      + `${runs.reduce((n, r) => n + r.requests.reduce((m, q) => m + q.tokens, 0), 0)} |`);
  }
  lines.push('');
  for (const { id } of all) {
    lines.push(`## ${id}`, '');
    const first = results[`${id}_${codes[0]}`];
    for (const code of codes) {
      const r = results[`${id}_${code}`];
      if (!r || r.error) { lines.push(`- ${code}: **${r ? r.error : 'not run'}**`); continue; }
      lines.push(`- ${code}: ${r.items} items, ${r.chars} characters, ${r.requests.length} request(s), `
        + `${r.seconds} s; left refused: ${Object.keys(r.faults).join(', ') || 'none'}; `
        + `first refused: ${Object.keys(r.firstFaults).join(', ') || 'none'}`);
    }
    lines.push('');
    if (!first || first.error) continue;
    for (const [key, english] of Object.entries(first.source)) {
      lines.push(`**\`${key}\`**`, '', `> ${english}`, '');
      for (const code of codes) {
        const r = results[`${id}_${code}`];
        const said = r && !r.error ? r.translated[key] : undefined;
        lines.push(`> **${code}**: ${said === undefined ? '*(none)*' : said}`, '');
      }
    }
  }
  return `${lines.join('\n')}\n`;
}

main().catch((err) => {
  console.error(`${err.name}: ${err.message}`);
  process.exit(1);
});
