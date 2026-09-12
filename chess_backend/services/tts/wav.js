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

/// Loud enough to be the voice rather than the room. Measured: on the film of
/// 12.9.2026 the silence around a clip peaks at −50 dB and the speech at −3.6.
const SPEECH_FLOOR_DBFS = -40;

/// The window a peak is taken over. Short enough that a tenth of a second of
/// lead-in is visible, long enough that one stray sample cannot answer for it.
const SPEECH_BLOCK_MS = 20;

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

/// Where the speech is inside [file], in seconds from its start, or null when
/// the file cannot be read as 16-bit PCM or holds nothing above the floor.
///
/// **A synthesiser's clip is not all speech.** Azure returns its sentence with
/// about a tenth of a second of silence in front of it and eight tenths behind
/// it, measured on the owner's own film of 12.9.2026. Two things were being
/// paced by the file's length rather than by the voice inside it, and both were
/// reported the same day: the caption kept being written after the voice had
/// stopped, and the film then waited the breath on top of that tail — „posle
/// govora čekamo da se tekst ispiše, nekad i po 2 sekunde".
///
/// Peak per block rather than one sample: the quiet part of a clip is not
/// digital silence (−66 dB mean, −50 dB peak on that film), so a scan for the
/// first non-zero sample would report the very first block every time.
function speechWindow(file, { floorDbfs = SPEECH_FLOOR_DBFS, blockMs = SPEECH_BLOCK_MS } = {}) {
  const info = wavInfo(file);
  // PCM only, and 16-bit only. Everything this server writes or accepts is
  // both; anything else is read as „no answer" and the caller keeps using the
  // file's own length, which is what it did before this existed.
  if (!info || info.audioFormat !== 1 || info.bitsPerSample !== 16) return null;

  const frameBytes = 2 * Math.max(1, info.channels);
  const blockFrames = Math.max(1, Math.round((info.sampleRate * blockMs) / 1000));
  const floor = Math.pow(10, floorDbfs / 20) * 32768;

  let fd;
  try {
    fd = fs.openSync(file, 'r');
    const buf = Buffer.alloc(Math.min(info.dataBytes, blockFrames * frameBytes));
    const frames = Math.floor(info.dataBytes / frameBytes);
    let firstBlock = -1;
    let lastBlock = -1;

    for (let block = 0; block * blockFrames < frames; block++) {
      const at = info.dataOffset + block * blockFrames * frameBytes;
      const want = Math.min(buf.length, info.dataOffset + info.dataBytes - at);
      const got = fs.readSync(fd, buf, 0, want, at);
      if (got <= 0) break;
      let peak = 0;
      // The first channel is enough: everything here is mono, and a second
      // channel could only make a block louder, never quieter than the first.
      for (let at2 = 0; at2 + 2 <= got; at2 += frameBytes) {
        const sample = Math.abs(buf.readInt16LE(at2));
        if (sample > peak) peak = sample;
      }
      if (peak >= floor) {
        if (firstBlock < 0) firstBlock = block;
        lastBlock = block;
      }
    }
    if (firstBlock < 0) return null;

    const seconds = info.dataBytes / info.byteRate;
    const blockSeconds = blockFrames / info.sampleRate;
    return {
      startSeconds: Math.min(seconds, firstBlock * blockSeconds),
      endSeconds: Math.min(seconds, (lastBlock + 1) * blockSeconds),
      seconds,
    };
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

module.exports = {
  wavInfo,
  wavSeconds,
  speechWindow,
  SPEECH_FLOOR_DBFS,
  SPEECH_BLOCK_MS,
};
