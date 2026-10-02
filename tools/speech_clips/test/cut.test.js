// node --test tools/speech_clips/test
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { wordCount, wordRangeMs, slicePcm, lockEntry, sameLock } = require('../cut.js');

test('a carrier is counted the way the Dart vocabulary counts it', () => {
  assert.equal(wordCount('Black plays bishop e5.'), 4);
  assert.equal(wordCount('Black plays bishop e5. Check.'), 5);
  assert.equal(wordCount('Black plays pawn e8, promotes to queen.'), 7);
  assert.equal(wordCount('  Mate in 3. '), 3);
});

const words = [
  { text: 'Black', startMs: 100, endMs: 400 },
  { text: 'plays', startMs: 450, endMs: 700 },
  { text: 'bishop', startMs: 760, endMs: 1100 },
  { text: 'e5', startMs: 1180, endMs: 1700 },
];
const voice = { startMs: 80, endMs: 1750 };

test('a word in the middle is cut at the midpoints to its neighbours', () => {
  assert.deepEqual(wordRangeMs(words, 3, 3, voice), { fromMs: 730, toMs: 1140 });
});

test('the first word starts where the voice starts and the last ends where it ends', () => {
  assert.deepEqual(wordRangeMs(words, 1, 2, voice), { fromMs: 80, toMs: 730 });
  assert.deepEqual(wordRangeMs(words, 4, 4, voice), { fromMs: 1140, toMs: 1750 });
});

test('a range outside the carrier is refused', () => {
  assert.throws(() => wordRangeMs(words, 0, 1, voice));
  assert.throws(() => wordRangeMs(words, 4, 5, voice));
  assert.throws(() => wordRangeMs(words, 3, 2, voice));
});

test('slicePcm takes whole frames between two times and clamps to the clip', () => {
  const info = { sampleRate: 1000, channels: 1 };
  const pcm = Buffer.alloc(2000); // one second
  assert.equal(slicePcm(pcm, info, 100, 350).length, 500);
  assert.equal(slicePcm(pcm, info, -50, 2000).length, 2000);
});

test('a lock entry changes with the carrier, the words and the voice, and with nothing else', () => {
  const token = { id: 'sq_e5', kind: 'cut', text: 'e5', carrier: 'Black plays bishop e5.', wordFrom: 4, wordTo: 4 };
  const a = lockEntry(token, 'en-US-AndrewNeural');
  assert.ok(sameLock(a, lockEntry({ ...token, text: 'E5' }, 'en-US-AndrewNeural')));
  assert.ok(!sameLock(a, lockEntry({ ...token, carrier: 'Black plays bishop e5' }, 'en-US-AndrewNeural')));
  assert.ok(!sameLock(a, lockEntry({ ...token, wordTo: 3 }, 'en-US-AndrewNeural')));
  assert.ok(!sameLock(a, lockEntry(token, 'en-US-AvaNeural')));
  assert.ok(!sameLock(undefined, a));
});
