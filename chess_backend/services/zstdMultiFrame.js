// zstdMultiFrame.js
// Reads a zstd file that contains more than one frame.
//
// Why this exists: the Lichess puzzle dump is compressed with `pzstd`, which
// writes a skippable header frame followed by many independent 32 MiB frames.
// Node's `zlib.createZstdDecompress()` decodes the first frame and then throws
// "Unknown frame descriptor" at the start of the second — it does not walk
// across frame boundaries, and it rejects skippable frames rather than skipping
// them. So the frame boundaries are located here, and each frame is handed to
// the decoder on its own.
//
// Frame layout per RFC 8878: magic, a variable-length header, a chain of blocks
// whose 3-byte headers carry their own sizes, then an optional checksum.

const fs = require('fs');
const zlib = require('zlib');

// Node grew a zstd codec only in v22.15.0 (and v23.8.0). Older runtimes leave
// these undefined, and the failure otherwise surfaces mid-import as
// "zlib.zstdDecompressSync is not a function", which reads like a typo.
if (typeof zlib.zstdDecompressSync !== 'function') {
  throw new Error(`zstd support requires Node >= 22.15.0 (running ${process.version})`);
}

const ZSTD_MAGIC = 0xfd2fb528;
const SKIPPABLE_MIN = 0x184d2a50;
const SKIPPABLE_MAX = 0x184d2a5f;

const FCS_FIELD_SIZE = [0, 2, 4, 8]; // by Frame_Content_Size_flag, when not single-segment
const DID_FIELD_SIZE = [0, 1, 2, 4]; // by Dictionary_ID_flag

/// Total byte length of the frame starting at `offset`.
///
/// Returns null when the buffer does not yet hold the whole frame, so the caller
/// knows to read more rather than mis-parsing a truncated one.
function frameLength(buf, offset) {
  if (offset + 4 > buf.length) return null;

  const magic = buf.readUInt32LE(offset);

  if (magic >= SKIPPABLE_MIN && magic <= SKIPPABLE_MAX) {
    if (offset + 8 > buf.length) return null;
    return { length: 8 + buf.readUInt32LE(offset + 4), skippable: true };
  }
  if (magic !== ZSTD_MAGIC) {
    throw new Error(`Not a zstd frame at offset ${offset} (magic 0x${magic.toString(16)})`);
  }

  let cursor = offset + 4;
  if (cursor >= buf.length) return null;

  const descriptor = buf[cursor];
  cursor += 1;

  const fcsFlag = descriptor >> 6;
  const singleSegment = (descriptor & 0x20) !== 0;
  const hasChecksum = (descriptor & 0x04) !== 0;
  const didFlag = descriptor & 0x03;

  if (!singleSegment) cursor += 1; // Window_Descriptor
  cursor += DID_FIELD_SIZE[didFlag];
  // A single-segment frame always carries a content size, one byte when the flag is 0.
  cursor += singleSegment && fcsFlag === 0 ? 1 : FCS_FIELD_SIZE[fcsFlag];

  // Walk the block chain; each header states how far the next one is.
  for (;;) {
    if (cursor + 3 > buf.length) return null;

    const header = buf[cursor] | (buf[cursor + 1] << 8) | (buf[cursor + 2] << 16);
    const isLast = (header & 1) !== 0;
    const blockType = (header >> 1) & 0x3;
    const blockSize = header >> 3;
    cursor += 3;

    // An RLE block stores a single byte and repeats it Block_Size times.
    cursor += blockType === 1 ? 1 : blockSize;

    if (isLast) break;
  }

  if (hasChecksum) cursor += 4;
  if (cursor > buf.length) return null;

  return { length: cursor - offset, skippable: false };
}

/// Yields the decompressed contents of each frame in order.
///
/// Memory stays bounded by one compressed frame plus its output, rather than the
/// whole file, which matters when the input is 300 MB and expands past a
/// gigabyte.
async function* decompressFrames(filePath, { chunkSize = 4 * 1024 * 1024 } = {}) {
  const handle = await fs.promises.open(filePath, 'r');
  try {
    let buffer = Buffer.alloc(0);
    let fileOffset = 0;
    let eof = false;

    for (;;) {
      let parsed = null;
      try {
        parsed = buffer.length > 0 ? frameLength(buffer, 0) : null;
      } catch (err) {
        if (eof && buffer.length === 0) break;
        throw err;
      }

      const needsMore = parsed === null || parsed.length > buffer.length;
      if (needsMore) {
        if (eof) {
          if (buffer.length === 0) break;
          throw new Error(`Truncated zstd frame: ${buffer.length} bytes left over`);
        }

        const chunk = Buffer.alloc(chunkSize);
        const { bytesRead } = await handle.read(chunk, 0, chunkSize, fileOffset);
        fileOffset += bytesRead;
        if (bytesRead === 0) {
          eof = true;
        } else {
          buffer = Buffer.concat([buffer, chunk.subarray(0, bytesRead)]);
        }
        continue;
      }

      const frame = buffer.subarray(0, parsed.length);
      buffer = buffer.subarray(parsed.length);

      if (!parsed.skippable) {
        yield zlib.zstdDecompressSync(frame);
      }
    }
  } finally {
    await handle.close();
  }
}

/// Yields decompressed text lines across every frame.
///
/// Line splitting happens here rather than per frame because a record can
/// straddle a frame boundary — the compressor cuts on byte counts, not newlines.
async function* readLines(filePath, options) {
  let remainder = '';

  for await (const chunk of decompressFrames(filePath, options)) {
    const text = remainder + chunk.toString('utf8');
    const lines = text.split('\n');
    remainder = lines.pop();
    for (const line of lines) {
      yield line.endsWith('\r') ? line.slice(0, -1) : line;
    }
  }

  if (remainder.length > 0) yield remainder;
}

module.exports = { frameLength, decompressFrames, readLines };
