// One rule, one home: what `custom_puzzles.solution_san` means to a student is
// decided in `services/exercise.js` (`docs/PLAN-EXERCISE.md`, phase 1).
//
// Six files used to read the column for themselves, and each would have needed
// teaching when a row learned to hold a line and accepted alternatives. This
// fails when a file outside the list below names the column in its **code** —
// SQL included, since that is where a reader starts.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');

/// Who may name the column, and why. A writer stores and verifies the one move
/// a book printed; it does not decide what a student is judged against.
const ALLOWED = {
  'services/exercise.js': 'the reader',
  'routes/scans.js': 'writer: the scan pipeline stores and re-verifies the printed move',
  'services/scanIntake.js': 'writer: the same pipeline, the merge half',
  'services/homeworkFromArchive.js': 'writer: homework made from a student\'s mistakes',
  'routes/puzzles.js': 'a different table: endgame_puzzles has a column of the same name',
};

/// The code of a source file with its comments blanked and its strings kept —
/// the SQL lives in template literals, and SQL is what this looks for.
///
/// A small lexer rather than a regex over the text: `//` inside a string is
/// not a comment, and a comment that names the column (several do, to explain
/// themselves) is not a reader. A regex literal containing a quote would
/// confuse it; the failure mode is a false red on that file, which is loud.
function withoutComments(source) {
  let out = '';
  let i = 0;
  let quote = null;
  while (i < source.length) {
    const ch = source[i];
    const next = source[i + 1];
    if (quote) {
      out += ch;
      if (ch === '\\') { out += next ?? ''; i += 2; continue; }
      if (ch === quote) quote = null;
      i += 1;
    } else if (ch === '/' && next === '/') {
      while (i < source.length && source[i] !== '\n') i += 1;
    } else if (ch === '/' && next === '*') {
      const end = source.indexOf('*/', i + 2);
      i = end === -1 ? source.length : end + 2;
      out += ' ';
    } else {
      if (ch === '\'' || ch === '"' || ch === '`') quote = ch;
      out += ch;
      i += 1;
    }
  }
  return out;
}

function sources() {
  const found = [];
  for (const dir of ['routes', 'services']) {
    const walk = (at) => {
      for (const entry of fs.readdirSync(path.join(ROOT, at), { withFileTypes: true })) {
        const rel = `${at}/${entry.name}`;
        if (entry.isDirectory()) walk(rel);
        else if (entry.name.endsWith('.js')) found.push(rel);
      }
    };
    walk(dir);
  }
  return found;
}

test('the lexer blanks comments and keeps strings', () => {
  const code = withoutComments([
    'const a = `SELECT solution_san FROM t`; // solution_san in a comment',
    '/* solution_san in a block */ const b = \'http://x\';',
    '/// solution_san in a doc comment',
  ].join('\n'));
  assert.equal(code.match(/solution_san/g).length, 1);
  assert.match(code, /http:\/\/x/);
});

test('only the reader and the writers name solution_san in code', () => {
  const files = sources();
  // The walk is real: a guard over an empty list passes whatever is written.
  assert.ok(files.length > 40, `walked only ${files.length} files`);
  for (const allowed of Object.keys(ALLOWED)) {
    assert.ok(files.includes(allowed), `${allowed} is on the list but was not walked`);
  }

  const offenders = files
    .filter((rel) => !(rel in ALLOWED))
    .filter((rel) => /solution_san/.test(withoutComments(fs.readFileSync(path.join(ROOT, rel), 'utf8'))));
  assert.deepEqual(offenders, [],
    'these read custom_puzzles.solution_san themselves — use exerciseColumns() and exerciseOf()');
});

test('every consumer asks the one reader', () => {
  for (const rel of [
    'routes/assignments.js',
    'services/assignmentReview.js',
    'services/assignmentService.js',
    'services/homeworkSend.js',
    'services/homeworkTemplate.js',
    'services/positionLibrary.js',
  ]) {
    const code = withoutComments(fs.readFileSync(path.join(ROOT, rel), 'utf8'));
    assert.match(code, /exerciseColumns\(/, `${rel} selects the row without exerciseColumns()`);
    assert.match(code, /require\('\.\.?\/(services\/)?exercise'\)/, `${rel} does not import exercise.js`);
  }
});
