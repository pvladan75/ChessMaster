// endgame_routes_auth.test.js
// Every endgame route is behind sign-in, and the app's requests name routes
// that exist.
//
// Found by the architecture audit on 16.9.2026 (`docs/audit/tests.md`, 8):
// `routes/puzzles.js` was named by no test, so removing `authenticateToken` from
// an endgame route left the backend suite green. The app half of the wire is
// `chess_app/test/endgame_wire_format_test.dart`; the paths listed here are the
// ones that test pins, so a rename on either end fails one of the two.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/puzzles');
const { authenticateToken } = require('../middleware/auth');

const ENDGAME_ROUTES = [
  ['get', '/puzzles/endgame/next'],
  ['get', '/puzzles/endgame/catalog'],
  ['get', '/puzzles/endgame/game/next'],
  ['get', '/puzzles/endgame/line'],
  ['get', '/puzzles/endgame/probe'],
  ['post', '/puzzles/endgame/play'],
];

function handlersOf(method, path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted — the app calls it`);
  return layer.route.stack.map((s) => s.handle);
}

for (const [method, path] of ENDGAME_ROUTES) {
  test(`${method.toUpperCase()} /api${path} is behind sign-in`, () => {
    assert.equal(handlersOf(method, path)[0], authenticateToken);
  });
}

test('no endgame route exists that this list does not know about', () => {
  // A new route added without a line here would be a route nobody checked.
  const mounted = router.stack
    .filter((l) => l.route && String(l.route.path).startsWith('/puzzles/endgame'))
    .map((l) => `${Object.keys(l.route.methods)[0]} ${l.route.path}`)
    .sort();
  const known = ENDGAME_ROUTES.map(([m, p]) => `${m} ${p}`).sort();
  assert.deepEqual(mounted, known);
});
