// prep_narrative.test.js — the sentence over the report, and what it may not carry.
//
// The model is stubbed throughout. What is under test is not whether Gemini
// writes good Serbian; it is whether a bad answer can reach a player, and
// whether a name reaches Google.

const test = require('node:test');
const assert = require('node:assert/strict');

const { createPrepNarrative, factsFrom, buildPrompt } = require('../services/prepNarrative');

const REPORT = {
  subject: 'rival_handle',
  color: 'w',
  games: 4126,
  gamesWithoutNodes: 0,
  nodes: [
    {
      fenKey: 'k1', fen: 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      ply: 2, games: 121, score: 0.413,
      moves: [
        { san: 'c5', games: 92, score: 0.38, share: 0.76 },
        { san: 'e5', games: 29, score: 0.5, share: 0.24 },
      ],
      judgement: { verdict: 'mistake', eval: { lossCp: 60, better: 'd4' } },
    },
  ],
};

/// A model that says whatever it is told to, and records what it was asked.
function stubModel(...answers) {
  const prompts = [];
  const queue = [...answers];
  const generate = async (prompt) => {
    prompts.push(prompt);
    const next = queue.shift();
    if (next instanceof Error) throw next;
    return next;
  };
  return { generate, prompts };
}

test('a sentence that only restates the report is returned', async () => {
  const model = stubModel('U 92 od 121 partije bira c5, ali skor mu je 38%.');
  const { narrate } = createPrepNarrative({ generate: model.generate });

  const said = await narrate(REPORT);

  assert.equal(said.reason, null);
  assert.match(said.narrative, /92 od 121/);
});

test('the opponent\'s name never reaches the model', async () => {
  // The part of this feature that cannot be taken back. The model is describing
  // a playing style, not a person, and the name adds nothing to the prose.
  const model = stubModel('Bira ostre varijante.');
  const { narrate } = createPrepNarrative({ generate: model.generate });

  await narrate(REPORT);

  assert.equal(model.prompts.length, 1);
  assert.equal(
    model.prompts[0].includes('rival_handle'), false,
    'the handle was sent to a third party',
  );
});

test('the facts carry no identity at all', () => {
  const facts = factsFrom(REPORT);

  assert.equal('subject' in facts, false);
  assert.equal(JSON.stringify(facts).includes('rival_handle'), false);
  assert.equal(facts.games, 4126, 'the numbers still travel');
});

test('an invented number is refused, and one retry is asked for', async () => {
  const model = stubModel(
    'Skor mu je oko 40%.',                       // rounded — refused
    'U 92 od 121 partije bira isti potez.',      // corrected
  );
  const { narrate } = createPrepNarrative({ generate: model.generate });

  const said = await narrate(REPORT);

  assert.equal(said.reason, null, 'the second answer was clean');
  assert.equal(model.prompts.length, 2);
  assert.match(model.prompts[1], /ODBIJEN/, 'the retry says it was refused');
  assert.match(model.prompts[1], /40/, 'and names the number that got it refused');
});

test('a model that keeps inventing gets no third turn', async () => {
  // A loop that asks until something passes is a loop that eventually launders
  // a wrong number into an accepted one.
  const model = stubModel('Oko 40%.', 'Otprilike 45%.');
  const { narrate } = createPrepNarrative({ generate: model.generate });

  const said = await narrate(REPORT);

  assert.equal(said.narrative, null, 'fails closed');
  assert.equal(said.reason, 'invented-numbers');
  assert.deepEqual(said.invented, ['45']);
  assert.equal(model.prompts.length, 2, 'asked exactly twice');
});

test('with retry off, the first refusal is final', async () => {
  const model = stubModel('Oko 40%.');
  const { narrate } = createPrepNarrative({ generate: model.generate, retry: false });

  const said = await narrate(REPORT);

  assert.equal(said.narrative, null);
  assert.equal(model.prompts.length, 1);
});

test('a model outage returns a named reason, not a throw', async () => {
  // The report is the product. Decoration that fails must not take down the
  // thing it decorates — the same rule as every message in this codebase.
  const model = stubModel(new Error('GEMINI_API_KEY missing'));
  const { narrate } = createPrepNarrative({ generate: model.generate });

  const said = await narrate(REPORT);

  assert.equal(said.narrative, null);
  assert.equal(said.reason, 'model-unavailable');
});

test('an empty report is said to be empty rather than described', async () => {
  const model = stubModel('Protivnik nema slabosti.');
  const { narrate } = createPrepNarrative({ generate: model.generate });

  const said = await narrate({ ...REPORT, nodes: [] });

  assert.equal(said.narrative, null);
  assert.equal(said.reason, 'no-findings');
  assert.equal(model.prompts.length, 0, 'and the model is not asked at all');
});

test('the sentence sees a handful of positions, not the whole table', async () => {
  // A sentence about forty positions is a list, and the report is already a
  // better list than prose will ever be.
  const many = { ...REPORT, nodes: Array.from({ length: 40 }, (_, i) => ({
    ...REPORT.nodes[0], fenKey: `k${i}`, games: 100 + i,
  })) };

  const facts = factsFrom(many);
  assert.equal(facts.positions.length, 4);

  const model = stubModel('Bira ostre varijante.');
  const { narrate } = createPrepNarrative({ generate: model.generate });
  const said = await narrate(many);
  assert.equal(said.basedOn, 4);
});

test('the prompt shows the model the same object the guard checks', async () => {
  // One derivation of "the numbers". Two would eventually disagree, and the
  // disagreement would surface as the guard refusing sentences that were true.
  const facts = factsFrom(REPORT);
  const prompt = buildPrompt(facts);

  assert.ok(prompt.includes(JSON.stringify(facts, null, 2)));
});

test('the prompt demands percentages, because a child cannot read 0.38', async () => {
  // Found by running this against the real model: with the rule merely
  // permitted rather than required, it wrote „udeo 0.76" and
  // „prolaznost 0.38" — every number correct, and unreadable for the people
  // this app is for. The guard cannot catch prose that is true and useless.
  const prompt = buildPrompt(factsFrom(REPORT));

  assert.match(prompt, /uvek piši kao procenat/);
  assert.match(prompt, /41\.3%/, 'and shows the conversion rather than describing it');
});

test('a verdict travels as the word it is, so the sentence need not judge', async () => {
  const facts = factsFrom(REPORT);

  assert.equal(facts.positions[0].verdict, 'mistake');
  assert.equal(facts.positions[0].better, 'd4');
});
