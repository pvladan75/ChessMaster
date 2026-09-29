// translation_reading.js — a run's translations set beside their English, to
// be read: phase 0 of docs/PLAN-JEZIK-STUDIJE.md.
//
//     node translation_reading.js <run folder> <out.md> <code> [<code>...]
//
// The run folder holds, for every position, `<id>_kept.json` (the sentences the
// app's check kept, from `chess_app/tool/position_study.dart`) and
// `<id>_<code>.json` for each language (from `translate.js`). The report opens
// with the totals — sentences, how many passed the translation judge at the
// first attempt and after the second, tokens and seconds — and then every
// sentence with its translations under it.

const fs = require('fs');
const path = require('path');

function main() {
  const [dir, outFile, ...codes] = process.argv.slice(2);
  if (!dir || !outFile || !codes.length) {
    console.error('usage: node translation_reading.js <run folder> <out.md> <code> [<code>...]');
    process.exit(2);
  }
  const ids = fs.readdirSync(dir)
    .filter((f) => f.endsWith('_kept.json'))
    .map((f) => f.slice(0, -'_kept.json'.length))
    .sort();
  const totals = Object.fromEntries(codes.map((c) => [c, {
    sentences: 0, first: 0, passed: 0, tokens: 0, seconds: [], secondAsked: 0,
  }]));
  const body = [];
  for (const id of ids) {
    const kept = JSON.parse(fs.readFileSync(path.join(dir, `${id}_kept.json`), 'utf8'));
    const runs = {};
    for (const code of codes) {
      const file = path.join(dir, `${id}_${code}.json`);
      runs[code] = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
      const t = totals[code];
      const n = Object.keys(kept).length;
      t.sentences += n;
      const run = runs[code];
      if (!run) continue;
      t.first += n - run.firstRefused.length;
      t.passed += Object.keys(run.slots).length;
      t.tokens += run.tokens.reduce((s, x) => s + x, 0);
      if (run.firstRefused.length) t.secondAsked += 1;
      if (typeof run.seconds === 'number') t.seconds.push(run.seconds);
    }
    body.push(`## ${id}`, '');
    for (const code of codes) {
      const run = runs[code];
      if (!run) {
        body.push(`- ${code}: **not translated**`);
        continue;
      }
      const tokens = run.tokens.reduce((s, x) => s + x, 0);
      body.push(`- ${code}: ${Object.keys(run.slots).length} of ${Object.keys(kept).length} passed, `
        + `${run.requests} request(s), ${tokens} tokens, ${run.seconds} s`);
      for (const slot of run.firstRefused) {
        body.push(`  - first request refused \`${slot}\``);
      }
      for (const slot of run.refused) {
        body.push(`  - **left out** \`${slot}\``);
      }
    }
    body.push('');
    for (const [slot, english] of Object.entries(kept)) {
      body.push(`**\`${slot}\`**`, '', `> ${english}`, '');
      for (const code of codes) {
        const said = runs[code] && runs[code].slots[slot];
        body.push(`> **${code}**: ${said === undefined || said === null ? '*(left out)*' : said}`, '');
      }
    }
  }
  const head = ['# Study sentences in other languages', '',
    '| language | sentences | passed at once | passed | second request | tokens | seconds (median, max) |',
    '|---|---|---|---|---|---|---|'];
  for (const code of codes) {
    const t = totals[code];
    const s = [...t.seconds].sort((a, b) => a - b);
    const median = s.length ? s[Math.floor(s.length / 2)] : 0;
    const max = s.length ? s[s.length - 1] : 0;
    head.push(`| ${code} | ${t.sentences} | ${t.first} | ${t.passed} | ${t.secondAsked} of ${ids.length} studies | ${t.tokens} | ${median}, ${max} |`);
  }
  fs.writeFileSync(outFile, `${[...head, '', ...body].join('\n')}\n`);
}

main();
