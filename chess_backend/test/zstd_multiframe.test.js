// zstd_multiframe.test.js
// Pins the frame-boundary parser.
//
// This exists because Node's own zstd stream stops at the end of the first frame
// and throws on the second, which is silent-data-loss shaped: a naive reader
// gets the first 32 MiB of the puzzle dump and no error until it hits the
// boundary. These tests build real multi-frame buffers and check the whole file
// comes back.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const zlib = require('zlib');

const { frameLength, decompressFrames, readLines } = require('../services/zstdMultiFrame');

/// Builds the skippable frame `pzstd` writes ahead of the real data.
function skippableFrame(contentLength = 4) {
  const frame = Buffer.alloc(8 + contentLength);
  frame.writeUInt32LE(0x184d2a50, 0);
  frame.writeUInt32LE(contentLength, 4);
  return frame;
}

function writeTempFile(buffer) {
  const file = path.join(os.tmpdir(), `zstd-test-${Date.now()}-${Math.random().toString(36).slice(2)}.zst`);
  fs.writeFileSync(file, buffer);
  return file;
}

test('frameLength measures a real compressed frame exactly', () => {
  const frame = zlib.zstdCompressSync(Buffer.from('hello frame'));
  // Trailing bytes must not change the answer — that is the whole point.
  const withTrailer = Buffer.concat([frame, Buffer.from([1, 2, 3, 4])]);

  const parsed = frameLength(withTrailer, 0);
  assert.equal(parsed.skippable, false);
  assert.equal(parsed.length, frame.length);
});

test('frameLength recognises and measures a skippable frame', () => {
  const parsed = frameLength(skippableFrame(4), 0);
  assert.equal(parsed.skippable, true);
  assert.equal(parsed.length, 12);
});

test('frameLength asks for more data instead of guessing at a truncated frame', () => {
  const frame = zlib.zstdCompressSync(Buffer.from('a'.repeat(5000)));
  assert.equal(frameLength(frame.subarray(0, 6), 0), null);
  assert.equal(frameLength(Buffer.alloc(2), 0), null);
});

test('frameLength rejects bytes that are not a frame at all', () => {
  assert.throws(() => frameLength(Buffer.from([0, 1, 2, 3, 4, 5, 6, 7]), 0), /Not a zstd frame/);
});

test('every frame is decompressed, not just the first', async () => {
  // The exact shape of the puzzle dump: a skippable header then several frames.
  const parts = ['first frame\n', 'second frame\n', 'third frame\n'];
  const file = writeTempFile(
    Buffer.concat([skippableFrame(), ...parts.map((p) => zlib.zstdCompressSync(Buffer.from(p)))])
  );

  try {
    const chunks = [];
    for await (const chunk of decompressFrames(file)) chunks.push(chunk.toString());

    assert.equal(chunks.length, 3, 'must yield one output per data frame, skipping the header');
    assert.equal(chunks.join(''), parts.join(''));
  } finally {
    fs.unlinkSync(file);
  }
});

test('a record split across a frame boundary is rejoined', async () => {
  // The compressor cuts on byte counts, so a CSV row can straddle two frames.
  const file = writeTempFile(
    Buffer.concat([
      skippableFrame(),
      zlib.zstdCompressSync(Buffer.from('id,rating\n00008,19')),
      zlib.zstdCompressSync(Buffer.from('39\n0000D,1559\n')),
    ])
  );

  try {
    const lines = [];
    for await (const line of readLines(file)) lines.push(line);

    // Splitting per frame would produce "00008,19" and "39" as separate rows.
    assert.deepEqual(lines, ['id,rating', '00008,1939', '0000D,1559']);
  } finally {
    fs.unlinkSync(file);
  }
});

test('a final line without a trailing newline is still emitted', async () => {
  const file = writeTempFile(
    Buffer.concat([zlib.zstdCompressSync(Buffer.from('only,line\nlast,row'))])
  );

  try {
    const lines = [];
    for await (const line of readLines(file)) lines.push(line);
    assert.deepEqual(lines, ['only,line', 'last,row']);
  } finally {
    fs.unlinkSync(file);
  }
});

test('a truncated file fails loudly rather than returning partial data', async () => {
  const frame = zlib.zstdCompressSync(Buffer.from('x'.repeat(100000)));
  const file = writeTempFile(frame.subarray(0, frame.length - 20));

  try {
    await assert.rejects(async () => {
      for await (const _ of decompressFrames(file)) { /* drain */ }
    }, /Truncated zstd frame/);
  } finally {
    fs.unlinkSync(file);
  }
});
