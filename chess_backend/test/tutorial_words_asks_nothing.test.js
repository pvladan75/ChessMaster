// Phase 5 of docs/PLAN-TUTORIJAL-VIDEO.md: the tutorial from a game asks
// nothing (D10), so the words the server asks a model for include no question.
// The prompt loses its question rules, a moment is requested without `asks` and
// `correct`, and a request from an app that still sends them is taken with
// both ignored — they are dropped, never written into the prompt.
//
// The requests are built here from the fixtures with the two fields removed, so
// each case is red on master for the reason it names and not for a fixture the
// harness had not yet rewritten.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { TEMPLATE, validateWordsRequest, buildPrompt } = require('../services/tutorialWords');

const FIXTURES = path.join(__dirname, '..', '..', 'chess_app', 'test', 'fixtures', 'game_tutorial');
const games = fs.readdirSync(FIXTURES)
  .filter((f) => /^g\d\d_[a-z-]+\.json$/.test(f))
  .sort()
  .map((f) => JSON.parse(fs.readFileSync(path.join(FIXTURES, f), 'utf8')));

const QUESTION = /question|correct answer/i;

function withoutAsking(request) {
  const copy = JSON.parse(JSON.stringify(request));
  for (const m of copy.moments) {
    delete m.asks;
    delete m.correct;
  }
  return copy;
}

test('ten games to hold the request to', () => {
  assert.equal(games.length, 10);
});

test('the template says nothing about a question or its answers', () => {
  const found = TEMPLATE.split('\n').filter((line) => QUESTION.test(line));
  assert.deepEqual(found, []);
});

for (const g of games) {
  test(`${g.game}: a request with no question is taken, and its prompt asks for none`, () => {
    const request = validateWordsRequest(withoutAsking(g.expected.wordsRequest));
    const found = buildPrompt(request).split('\n').filter((line) => QUESTION.test(line));
    assert.deepEqual(found, []);
  });
}

test('a request from an app that still says a moment asks is taken, and the prompt ignores it', () => {
  const request = withoutAsking(games[0].expected.wordsRequest);
  const quiet = buildPrompt(validateWordsRequest(request));
  for (const m of request.moments) {
    m.asks = true;
    m.correct = [m.best];
  }
  assert.equal(buildPrompt(validateWordsRequest(request)), quiet);
});
