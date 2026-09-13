// When the model cannot be asked, a move's comment is the app's own findings
// put together. The app writes each finding as a sentence and joins them with
// a space — a comment is read aloud in an imported tutorial, and a „ | "
// between clauses is something a voice reads out.
const test = require('node:test');
const assert = require('node:assert/strict');

const { generateFallbackMoveComment } = require('../geminiService');

test('the findings are joined as sentences, never with a bar', () => {
  const out = generateFallbackMoveComment({
    tacticalFindings: [
      { description: 'The white bishop on b5 pins the black knight on c6 to the king on e8.' },
    ],
    positionalFindings: [
      { description: 'White has the bishop pair.' },
      { description: '   ' },
      null,
    ],
  });

  assert.equal(
    out.comment,
    'The white bishop on b5 pins the black knight on c6 to the king on e8. White has the bishop pair.',
  );
  assert.ok(!out.comment.includes('|'));
});

test('a quiet move still says how the evaluation moved', () => {
  const out = generateFallbackMoveComment({ evalBefore: 0.2, evalAfter: -0.4 });
  assert.equal(out.comment, 'Evaluation moves from +0.20 to -0.40.');
});
