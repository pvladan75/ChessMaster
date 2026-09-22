// The delete routes of 22.9.2026 are where the app will look for them, and in
// an order that lets each be reached.
//
// `DELETE /notifications/read` and `DELETE /notifications/:id` share a shape:
// registered the other way round, „read" is taken for an id and „Clear read"
// answers 400 for ever. Express matches in registration order, so the order
// is the rule.
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const social = require('../routes/social');
const userGames = require('../routes/userGames');
const mistakeDrill = require('../routes/mistakeDrill');

/// Paths of a router's DELETE routes, in the order express will try them.
function deletes(router) {
  return router.stack
    .filter((l) => l.route && l.route.methods.delete)
    .map((l) => l.route.path);
}

test('„Clear read" is tried before a single notification', () => {
  const paths = deletes(social);
  const clear = paths.indexOf('/notifications/read');
  const one = paths.indexOf('/notifications/:id');
  assert.ok(clear >= 0, 'no DELETE /notifications/read');
  assert.ok(one >= 0, 'no DELETE /notifications/:id');
  assert.ok(clear < one, '/notifications/read would be answered as an id');
});

test("a player's games and one mistake can be deleted", () => {
  assert.ok(deletes(userGames).includes('/subjects/:subject'), 'no DELETE /games/subjects/:subject');
  assert.ok(deletes(mistakeDrill).includes('/:id'), 'no DELETE /games/mistakes/:id');
});
