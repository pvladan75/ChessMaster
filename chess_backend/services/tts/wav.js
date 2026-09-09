// wav.js — how long a wav is, read from its own header.
//
// Not from ffprobe: that is a second process per beat, and a dependency on a
// binary being present for a number that is sixteen bytes into the file. Not
// from the synthesiser's own report either — the file is the thing that gets
// concatenated, so the file is what has to be measured.
const fs = require('fs');

/// Seconds of audio in a RIFF/WAVE file, or 0 when it cannot be read.
///
/// Walks the chunk list rather than assuming the canonical 44-byte header:
/// Windows' synthesiser writes a `LIST`/`INFO` chunk before the data, and a
/// reader that trusted the offset would report the length of the metadata.
function wavSeconds(file) {
  let fd;
  try {
    fd = fs.openSync(file, 'r');
    const head = Buffer.alloc(12);
    if (fs.readSync(fd, head, 0, 12, 0) < 12) return 0;
    if (head.toString('ascii', 0, 4) !== 'RIFF' || head.toString('ascii', 8, 12) !== 'WAVE') {
      return 0;
    }

    const size = fs.fstatSync(fd).size;
    let at = 12;
    let byteRate = 0;
    let dataBytes = 0;
    const header = Buffer.alloc(8);

    while (at + 8 <= size) {
      if (fs.readSync(fd, header, 0, 8, at) < 8) break;
      const id = header.toString('ascii', 0, 4);
      const length = header.readUInt32LE(4);

      if (id === 'fmt ') {
        const fmt = Buffer.alloc(Math.min(length, 16));
        fs.readSync(fd, fmt, 0, fmt.length, at + 8);
        if (fmt.length >= 16) byteRate = fmt.readUInt32LE(8);
      } else if (id === 'data') {
        // A streamed wav can carry 0xFFFFFFFF for a length nobody knew yet.
        dataBytes = length === 0xFFFFFFFF ? size - (at + 8) : Math.min(length, size - (at + 8));
        break;
      }

      // Chunks are word-aligned; an odd length is followed by a pad byte.
      at += 8 + length + (length % 2);
    }

    if (!byteRate || !dataBytes) return 0;
    return dataBytes / byteRate;
  } catch {
    return 0;
  } finally {
    if (fd !== undefined) try { fs.closeSync(fd); } catch { /* already gone */ }
  }
}

module.exports = { wavSeconds };
