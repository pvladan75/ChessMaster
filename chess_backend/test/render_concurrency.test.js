// render_concurrency.test.js — two trainers rendering at the same moment.
//
// „Šta se dešava ako dva ili više korisnika pošalju zahtev za renderovanje u
// isto vreme?" They interleave: since the frame loop returns to the event loop
// between frames (`test/render_yields.test.js`), three concurrent renders on
// this machine took 6.8 s against 2.4 s for one, and all three finished
// together rather than one starving the others.
//
// What did not survive the question is the two places where concurrent renders
// wrote to one path.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const piper = require('../services/tts/piper');

test('a cache entry appears whole, or not at all', () => {
  // Two films can be rendered at once and they share the TTS cache, keyed by
  // the sentence and the voice — so two trainers narrating the same sentence at
  // the same moment both find it missing and both write it. A copy straight
  // onto the final path truncates a file the other render may be measuring or
  // feeding to ffmpeg, and a clip read half-written is a beat with the wrong
  // length: audio drifting out of step with the board for the rest of the film.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'publish-'));
  try {
    const source = path.join(dir, 'clip.wav');
    fs.writeFileSync(source, 'RIFF....the whole clip');
    const target = path.join(dir, 'cached.wav');

    // **The final path is never written to directly**, which is the whole of
    // the fix and the one thing a before-and-after assertion cannot see: a
    // straight copy also ends with the right bytes in the right place. So the
    // copy is watched.
    const realCopy = fs.copyFileSync;
    const copiedTo = [];
    fs.copyFileSync = (from, to) => {
      copiedTo.push(to);
      return realCopy(from, to);
    };
    try {
      piper.publish(source, target);
    } finally {
      fs.copyFileSync = realCopy;
    }
    assert.equal(fs.readFileSync(target, 'utf8'), 'RIFF....the whole clip');
    assert.ok(!copiedTo.includes(target),
      'the cache path is reached by a rename, never by a copy in progress');

    // The loser of the race leaves what the winner wrote alone: the cache key
    // *is* the content, so a target that already exists is the same audio
    // somebody else finished first.
    const other = path.join(dir, 'clip2.wav');
    fs.writeFileSync(other, 'RIFF....the whole clip');
    piper.publish(other, target);
    assert.equal(fs.readFileSync(target, 'utf8'), 'RIFF....the whole clip');

    // And nothing half-written is left lying in the cache directory, where the
    // next render would find it.
    assert.deepEqual(
      fs.readdirSync(dir).filter((name) => name.includes('.part')),
      [],
      'no temporary file survives',
    );
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('a source that is not there fails loudly rather than leaving a hole', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'publish-'));
  try {
    assert.throws(() => piper.publish(path.join(dir, 'missing.wav'), path.join(dir, 'out.wav')));
    assert.deepEqual(fs.readdirSync(dir), [], 'and leaves nothing behind');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
