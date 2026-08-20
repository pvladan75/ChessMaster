// CLI: scan a PDF into verified positions and report how well it went.
//
//   node scan.mjs <file.pdf> --pages 16-965 --solutions 972-1184 [--out x.json]
//                            [--baseline python-output.json]
//
// The report matters as much as the output. A scanner that cannot say how much
// of a book it failed to read is the same silent-success trap as the prototype
// that returned empty boards when its model was missing.
import { writeFile, readFile } from 'node:fs/promises';
import { openPdf, pageSpans, fontNames } from './pdf.mjs';
import { selectFontMap, unknownGlyphs } from './fonts.mjs';
import { extractDiagrams } from './diagrams.mjs';
import { readSolutions } from './solutions.mjs';
import { buildPosition } from './verify.mjs';
import { flagDuplicateNumbers } from './index.mjs';

function parseArgs(argv) {
  const args = { file: argv[0] };
  for (let i = 1; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith('--')) continue;
    const value = argv[i + 1];
    if (key === '--pages' || key === '--solutions') {
      const [from, to] = value.split('-').map(Number);
      args[key.slice(2)] = { from, to: to ?? from };
      i += 1;
    } else {
      args[key.slice(2)] = value;
      i += 1;
    }
  }
  return args;
}

function pct(n, total) {
  return total ? `${((100 * n) / total).toFixed(2)}%` : '—';
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.file) {
    console.error('Upotreba: node scan.mjs <file.pdf> --pages 16-965 [--solutions 972-1184]');
    process.exit(2);
  }

  const doc = await openPdf(args.file);
  const pages = args.pages ?? { from: 1, to: doc.numPages };
  console.log(`Fajl: ${args.file} (${doc.numPages} strana)`);
  console.log(`Skeniram strane ${pages.from}–${pages.to}`);

  // --- pick a glyph map by alphabet, from a sample of pages -----------------
  const sample = [];
  const step = Math.max(1, Math.floor((pages.to - pages.from) / 8));
  for (let p = pages.from; p <= pages.to && sample.length < 400; p += step) {
    for (const s of await pageSpans(doc, p)) {
      if (!/\s/.test(s.text) && s.text.length >= 8 && s.text.length <= 12) sample.push(s.text);
    }
  }
  const picked = selectFontMap(sample);
  if (!picked) {
    console.error('\nNijedna mapa fonta ne objašnjava dijagrame u ovoj knjizi.');
    console.error('Nepoznati glifovi (znak, koliko puta):');
    for (const [glyph, count] of unknownGlyphs(sample).slice(0, 40)) {
      console.error(`   ${JSON.stringify(glyph)} ${count}`);
    }
    console.error('\nNapisati mapu za ovaj font u fonts.mjs i pokrenuti ponovo.');
    process.exit(1);
  }
  const map = picked.map;
  const names = await fontNames(doc, pages.from);
  console.log(`Mapa fonta: ${map.label} (pokriva ${picked.covered} uzoraka)`);
  console.log(`Fontovi na prvoj strani: ${[...new Set(names.values())].join(', ')}`);

  // --- solutions ------------------------------------------------------------
  let solutions = new Map();
  if (args.solutions) {
    solutions = await readSolutions(doc, args.solutions.from, args.solutions.to);
    console.log(`Rešenja: ${solutions.size} (strane ${args.solutions.from}–${args.solutions.to})`);
  }

  // --- extract --------------------------------------------------------------
  const positions = [];
  const anomalies = [];
  const glyphErrors = [];
  for (let p = pages.from; p <= pages.to; p += 1) {
    let result;
    try {
      result = extractDiagrams(await pageSpans(doc, p), map, p);
    } catch (err) {
      glyphErrors.push(`str. ${p}: ${err.message}`);
      continue;
    }
    anomalies.push(...result.anomalies);
    for (const diagram of result.diagrams) {
      const id = diagram.label ? Number(diagram.label) : null;
      const solution = id !== null ? solutions.get(id) : undefined;
      positions.push({ id, ...diagram, solution, ...buildPosition(diagram, solution) });
    }
    if ((p - pages.from) % 100 === 0) process.stdout.write(`  …strana ${p}\r`);
  }

  // --- report ---------------------------------------------------------------
  // Same guard the library applies, from the same place: a book that numbers
  // one diagram twice must not be measured as if it did not.
  flagDuplicateNumbers(positions, (p) => p.id);

  const withSolution = positions.filter((p) => p.solution);
  const legal = withSolution.filter((p) => p.solutionLegal);
  const repaired = positions.filter((p) => p.repairs.length);
  const problems = positions.filter((p) => p.problem);

  console.log('\n' + '='.repeat(58));
  console.log(`Dijagrama pronađeno:            ${positions.length}`);
  console.log(`  sa brojem (labelom):          ${positions.filter((p) => p.id !== null).length}`);
  console.log(`  sa rešenjem iz knjige:        ${withSolution.length}`);
  console.log(`  strana na potezu iz rešenja:  ${positions.filter((p) => p.sideSource === 'resenje').length}`);
  console.log(`  strana nepoznata:             ${positions.filter((p) => p.sideSource === 'nepoznato').length}`);
  console.log(`Potez iz knjige legalan:        ${legal.length} / ${withSolution.length}  (${pct(legal.length, withSolution.length)})`);
  console.log(`  popravljeno rokadom/e.p.:     ${repaired.length}`);
  console.log(`Za ljudsku proveru:             ${problems.length}`);
  if (anomalies.length) console.log(`Redovi koji nisu činili 8:      ${anomalies.length}`);
  if (glyphErrors.length) console.log(`Strane sa nepoznatim glifom:    ${glyphErrors.length}`);

  for (const p of problems.slice(0, 8)) {
    console.log(`   #${p.id ?? '?'} str.${p.page}: ${p.problem}`);
  }
  for (const e of glyphErrors.slice(0, 5)) console.log(`   ${e}`);

  // --- optional diff against the Python prototype ---------------------------
  if (args.baseline) {
    const base = JSON.parse(await readFile(args.baseline, 'utf8'));
    const byId = new Map(base.positions.map((b) => [Number(b.diagram_id), b]));
    let same = 0;
    let differ = 0;
    const examples = [];
    for (const p of positions) {
      const b = byId.get(p.id);
      if (!b) continue;
      if (b.fen.split(' ')[0] === p.placement) same += 1;
      else {
        differ += 1;
        if (examples.length < 5) examples.push({ id: p.id, node: p.placement, python: b.fen.split(' ')[0] });
      }
    }
    console.log('-'.repeat(58));
    console.log(`Poređenje sa Python izlazom: isto ${same}, različito ${differ}`);
    for (const e of examples) console.log(`   #${e.id}\n     node:   ${e.node}\n     python: ${e.python}`);
  }

  if (args.out) {
    await writeFile(
      args.out,
      JSON.stringify(
        {
          document: args.file,
          font: map.label,
          total: positions.length,
          positions: positions.map((p) => ({
            id: p.id,
            page: p.page,
            fen: p.fen,
            side_source: p.sideSource,
            solution_san: p.solution?.san ?? null,
            solution_legal: p.solutionLegal,
            themes_text: p.solution?.tail || null,
            repairs: p.repairs,
            problem: p.problem,
          })),
        },
        null,
        2
      ),
      'utf8'
    );
    console.log(`\nUpisano: ${args.out}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
