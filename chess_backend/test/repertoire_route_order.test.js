const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

/// `router.delete('/:id', ...)` matches **one** path segment, so every other
/// one-segment route of the same method has to be registered before it or
/// Express hands it the id handler instead.
///
/// This cost a working `DELETE /repertoire/comment` for as long as it took to
/// notice: the route was registered a hundred lines below `/:id`, so deleting a
/// comment answered "Repertoar nije imenovan brojem" — a 400 with a sentence
/// about something else entirely, which is the hardest kind of failure to read.
///
/// `/node/move` and its neighbours are two segments and are safe wherever they
/// stand. This test is about the one-segment ones, and it is written as a rule
/// rather than a list so a route added next year is covered without anybody
/// remembering this.
const SOURCE = path.join(__dirname, '..', 'routes', 'repertoire.js');

/// Every registration in file order: `{ method, route }`.
///
/// Read with a regular expression over the file rather than by mounting the
/// router, because mounting it pulls in the database pool and the auth
/// middleware — and what is being asserted here is the *order lines appear in*,
/// which is exactly what the text says.
function registrations(source) {
  const found = [];
  const pattern = /router\.(get|post|put|delete|patch)\(\s*'([^']+)'/g;
  let match = pattern.exec(source);
  while (match !== null) {
    found.push({ method: match[1], route: match[2] });
    match = pattern.exec(source);
  }
  return found;
}

function segments(route) {
  return route.split('/').filter((part) => part !== '').length;
}

test('one-segment routes are registered before the :id catch-all', () => {
  const source = fs.readFileSync(SOURCE, 'utf8');
  const all = registrations(source);
  assert.ok(all.length > 20, 'nijedna ruta nije pročitana — regex je promašio');

  for (const [index, entry] of all.entries()) {
    if (!entry.route.startsWith('/:')) continue;
    // Everything of the same method after a one-segment parameter route, that
    // is itself one fixed segment, is unreachable.
    const shadowed = all.slice(index + 1).filter(
      (later) => later.method === entry.method
        && segments(later.route) === 1
        && !later.route.startsWith('/:'),
    );
    assert.deepEqual(
      shadowed.map((one) => `${one.method} ${one.route}`),
      [],
      `ruta ispod '${entry.method} ${entry.route}' se nikada ne poziva`,
    );
  }
});

test('the routes this bug was found on are still above it', () => {
  // The general rule above is the guard; these three are the ones that were
  // actually broken, named so a failure says which feature stopped working.
  const all = registrations(fs.readFileSync(SOURCE, 'utf8'));
  const at = (method, route) =>
    all.findIndex((one) => one.method === method && one.route === route);

  const catchAll = at('delete', '/:id');
  assert.ok(catchAll > 0, "DELETE '/:id' nije pronađena");
  for (const route of ['/comment', '/color', '/imported']) {
    const where = at('delete', route);
    assert.ok(where >= 0, `DELETE '${route}' nije pronađena`);
    assert.ok(where < catchAll, `DELETE '${route}' je ispod '/:id'`);
  }
});
