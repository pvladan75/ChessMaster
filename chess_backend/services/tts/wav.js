// wav.js — what a wav holds, read from its own header.
//
// Not from ffprobe: that is a second process per beat, and a dependency on a
// binary being present for a number that is sixteen bytes into the file. Not
// from the synthesiser's own report either — the file is the thing that gets
// concatenated, so the file is what has to be measured.
//
// Two readers of it: the synthesised narration's clips, and a trainer's own
// recording (`services/narrationUpload.js`), which is judged by the server from
// its own header rather than from what the app says about it.
const fs = require('fs');

/// The format and where the audio is, or null when [file] is not a readable
/// RIFF/WAVE file with a `fmt ` and a `data` chunk.
///
/// Walks the chunk list rather than assuming the canonical 44-byte header:
/// Windows' synthesiser writes a `LIST`/`INFO` chunk before the data, and a
/// reader that trusted the offset would report the length of the metadata.
///
/// `dataBytes` is what is **in the file**, never more: a header that claims
/// more than arrived — an upload cut short — is read as what arrived, which is
/// the only honest length to judge.
function wavInfo(file) {
  let fd;
  try {
    fd = fs.openSync(file, 'r');
    const head = Buffer.alloc(12);
    if (fs.readSync(fd, head, 0, 12, 0) < 12) return null;
    if (head.toString('ascii', 0, 4) !== 'RIFF' || head.toString('ascii', 8, 12) !== 'WAVE') {
      return null;
    }

    const size = fs.fstatSync(fd).size;
    let at = 12;
    let format = null;
    const header = Buffer.alloc(8);

    while (at + 8 <= size) {
      if (fs.readSync(fd, header, 0, 8, at) < 8) break;
      const id = header.toString('ascii', 0, 4);
      const length = header.readUInt32LE(4);

      if (id === 'fmt ') {
        const fmt = Buffer.alloc(Math.min(length, 16));
        fs.readSync(fd, fmt, 0, fmt.length, at + 8);
        if (fmt.length >= 16) {
          format = {
            audioFormat: fmt.readUInt16LE(0),
            channels: fmt.readUInt16LE(2),
            sampleRate: fmt.readUInt32LE(4),
            byteRate: fmt.readUInt32LE(8),
            bitsPerSample: fmt.readUInt16LE(14),
          };
        }
      } else if (id === 'data') {
        if (!format || !format.byteRate) return null;
        const dataOffset = at + 8;
        // A streamed wav can carry 0xFFFFFFFF for a length nobody knew yet.
        const dataBytes = length === 0xFFFFFFFF
          ? size - dataOffset
          : Math.min(length, size - dataOffset);
        if (dataBytes <= 0) return null;
        return { ...format, dataOffset, dataBytes };
      }

      // Chunks are word-aligned; an odd length is followed by a pad byte.
      at += 8 + length + (length % 2);
    }
    return null;
  } catch {
    return null;
  } finally {
    if (fd !== undefined) try { fs.closeSync(fd); } catch { /* already gone */ }
  }
}

/// Seconds of audio in a RIFF/WAVE file, or 0 when it cannot be read.
function wavSeconds(file) {
  const info = wavInfo(file);
  return info ? info.dataBytes / info.byteRate : 0;
}

module.exports = { wavInfo, wavSeconds };
