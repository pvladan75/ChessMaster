const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

/// Every walk follows a reply that leads into the student's own work.
///
/// The rule, decided 4.9.2026 and true of every screen because every screen
/// reads its positions through one of these walks: **a move or a draft the
/// student authored or asked for is never hidden by the breadth.** A breadth
/// narrows what the *book* suggests; it was never meant to narrow what the
/// student already did.
///
/// `coveredReplies` can only apply that rule when it is given the boards and
/// what the student holds — `{ fens, kept }`. Without them it silently keeps
/// its old behaviour, which is the dangerous shape: the caller reads as if it
/// were filtering, and the omission looks like nothing at all. It had already
/// happened twice, in the two walks that decide what deleting a move would
/// strand, and "unreachable" is what the sweep deletes.
///
/// So this reads the sources rather than trusting a habit. A fifth call site
/// that forgets fails here.
const DIR = path.join(__dirname, '..', 'services');

/// The argument list of a call, by matching parentheses from the one that
/// opens it.
///
/// Never by slicing a fixed number of characters: a guard in this repository
/// once read 1600 characters from the start of a function, ran into the next
/// one, and went on matching after the check it guarded was deleted.
function argsAt(src, open) {
  let depth = 0;
  for (let i = open; i < src.length; i += 1) {
    if (src[i] === '(') depth += 1;
    else if (src[i] === ')') {
      depth -= 1;
      if (depth === 0) return src.slice(open + 1, i);
    }
  }
  throw new Error('unbalanced parentheses after position ' + open);
}

function callsIn(src) {
  const out = [];
  const needle = 'coveredReplies(';
  let at = src.indexOf(needle);
  while (at !== -1) {
    const before = src.slice(Math.max(0, at - 20), at);
    // The definition itself, not a call.
    if (!/function\s+$/.test(before)) {
      out.push(argsAt(src, at + needle.length - 1));
    }
    at = src.indexOf(needle, at + 1);
  }
  return out;
}

test('every coveredReplies call is given what the rescue needs', () => {
  const files = fs.readdirSync(DIR).filter((f) => f.endsWith('.js'));
  const seen = [];
  for (const file of files) {
    const src = fs.readFileSync(path.join(DIR, file), 'utf8');
    for (const args of callsIn(src)) {
      seen.push({ file, args });
      assert.match(args, /\bkept\b/,
        `${file}: poziv coveredReplies bez "kept" — širina bi sakrila `
        + 'igračev sopstveni potez');
      assert.match(args, /\bfens\b/,
        `${file}: poziv coveredReplies bez "fens" — bez table se ne može `
        + 'izračunati gde odgovor vodi');
    }
  }

  // The guard proves it read something. A rename that makes every call
  // invisible would otherwise pass with nothing checked — which is exactly how
  // a guard in this repository stopped guarding once already.
  assert.ok(seen.length >= 4,
    `ocekivana bar 4 poziva, nadjeno ${seen.length}`);
});
