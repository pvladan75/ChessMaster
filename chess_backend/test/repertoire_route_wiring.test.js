const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

/// Two ways a route can be wired to nothing, both met on 2.9.2026 in the same
/// file, both invisible to every test there was.
///
///   * `/disagreements` referenced `viaFen`, `viaUci` and `exclude`, which it
///     never destructured — they belonged to `/drill/line`, one route down.
///     `typeof viaFen` on an undeclared name is legal and answers "undefined",
///     so two of the three failed *silently*; only the bare `exclude` threw,
///     and it threw on every single call to that route.
///   * `/drill/line` destructured all three and passed none of them on. So
///     "Vežbaj 0-0" changed the sentence above the board and nothing else: the
///     question still came back through whichever move the schedule preferred,
///     and "Druga linija" kept handing back the line it had just been refused.
///
/// The second is this codebase's recurring bug exactly — a step that skips,
/// reports success, and fails one layer away — so it gets a test that reads the
/// wiring rather than the behaviour.
const ROUTES = path.join(__dirname, '..', 'routes', 'repertoire.js');

/// Comments out. A comment that mentions a name is not a use of it, and this
/// file is heavily commented — the first run of this test reported `keys` and
/// `kept` as stray names because both are words in an English sentence above
/// the code. The same rule the narrative guard learned: strip first, then read.
function strip(code) {
  return code
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/^[ \t]*\/\/.*$/gm, ' ')
    .replace(/([^:])\/\/.*$/gm, '$1');
}

/// One handler body, read by **matching braces** from the arrow of its
/// callback.
///
/// Never by slicing a fixed number of characters: the guard that read 1600
/// characters from the start of a function ran into the next one, matched
/// there, and passed while the thing it guarded was gone.
function handlers(source) {
  const found = [];
  const pattern = /router\.(get|post|put|delete|patch)\(\s*'([^']+)'[^)]*?\(req, res\) => \{/g;
  let match = pattern.exec(source);
  while (match !== null) {
    let depth = 1;
    let at = match.index + match[0].length;
    while (at < source.length && depth > 0) {
      const ch = source[at];
      if (ch === '{') depth += 1;
      else if (ch === '}') depth -= 1;
      at += 1;
    }
    found.push({
      method: match[1],
      route: match[2],
      body: strip(source.slice(match.index + match[0].length, at - 1)),
    });
    match = pattern.exec(source);
  }
  return found;
}

/// The names a handler took out of `req.query` or `req.body`.
function destructured(body) {
  const names = [];
  const pattern = /const \{([^}]*)\} = req\.(query|body)/g;
  let match = pattern.exec(body);
  while (match !== null) {
    for (const part of match[1].split(',')) {
      const name = part.split(':')[0].trim();
      if (name !== '') names.push(name);
    }
    match = pattern.exec(body);
  }
  return names;
}

/// Every name a handler takes out of the request, by either route in: the
/// destructure, and `const exclude = ... req.query.exclude ...`.
///
/// The second half matters — the name that actually threw in the real bug was
/// declared that way, so a version of this test that only knew about
/// destructures watched it go past.
function requestNames(body) {
  return [
    ...destructured(body),
    ...[...body.matchAll(/const (\w+) = [^;]*req\.(?:query|body)/g)]
      .map((m) => m[1]),
  ];
}

/// How many times the body **uses** a name as a value.
///
/// A property key and a member access are not uses: `color: req.query.color`
/// writes the word twice and reads no variable at all, and counting those had
/// the first version of this test calling half the file broken.
function mentions(body, name) {
  const pattern = new RegExp(`(^|[^.\\w])${name}\\b(?!\\s*:)`, 'g');
  return (body.match(pattern) ?? []).length;
}

/// The same, with property keys counted — which is what the first test needs,
/// since `const { color } = req.query` and `color: color` are both writings of
/// a name that *is* being carried somewhere.
function occurrences(body, name) {
  const pattern = new RegExp(`(^|[^.\\w])${name}\\b`, 'g');
  return (body.match(pattern) ?? []).length;
}

test('every query parameter a handler reads is passed on', () => {
  const all = handlers(fs.readFileSync(ROUTES, 'utf8'));
  assert.ok(all.length > 20, 'nijedan handler nije pročitan — regex je promašio');

  const dead = [];
  for (const handler of all) {
    for (const name of destructured(handler.body)) {
      // Once for the destructure itself. A name that appears exactly once was
      // read out of the request and dropped on the floor.
      if (occurrences(handler.body, name) < 2) {
        dead.push(`${handler.method} ${handler.route}: ${name}`);
      }
    }
  }
  assert.deepEqual(dead, [], 'parametar se čita iz zahteva i nigde ne koristi');
});

test('no handler mentions a name it never took out of the request', () => {
  // The other half. `typeof x` on an undeclared name does not throw, so this
  // cannot be left to a runtime check: two of the three misplaced names would
  // have gone on answering "undefined" forever.
  const source = fs.readFileSync(ROUTES, 'utf8');
  const all = handlers(source);

  // Names that live at module scope are fair game inside any handler.
  const moduleScope = new Set(
    [...source.matchAll(/^(?:const|let|function) \{?\s*([\w,\s:]+?)\s*\}?\s*[=(]/gm)]
      .flatMap((m) => m[1].split(',').map((n) => n.split(':').pop().trim()))
      .filter((n) => n !== ''),
  );

  const stray = [];
  for (const handler of all) {
    const declared = new Set([
      ...destructured(handler.body),
      // Anything the body declares for itself.
      ...[...handler.body.matchAll(/(?:const|let) (\w+)\s*=/g)].map((m) => m[1]),
      ...[...handler.body.matchAll(/(?:const|let) \{([^}]*)\}\s*=/g)]
        .flatMap((m) => m[1].split(',').map((n) => n.split(':').pop().trim())),
      // A name a callback declares for itself, as in `.then(({ keys, ...rest })`.
      ...[...handler.body.matchAll(/\(\s*\{([^}]*)\}\s*\)\s*=>/g)]
        .flatMap((m) => m[1].split(',').map((n) => n.split(':').pop().trim())),
    ]);
    // Only the query-shaped names are checked, and only the ones some other
    // handler in this file does read out of a request: a general undeclared-name
    // hunt would need a parser, and this is the shape the bug actually takes —
    // a parameter that wandered one route away from where it was destructured.
    const known = new Set(all.flatMap((one) => requestNames(one.body)));
    for (const name of known) {
      if (declared.has(name) || moduleScope.has(name)) continue;
      if (mentions(handler.body, name) > 0) {
        stray.push(`${handler.method} ${handler.route}: ${name}`);
      }
    }
  }
  assert.deepEqual(stray, [],
    'handler koristi ime koje nije uzeo iz zahteva — pripada drugoj ruti');
});
