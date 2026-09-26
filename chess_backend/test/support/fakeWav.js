// fakeWav.js — a wav file shaped like what a synthesiser hands back, for tests
// that need a clip on disk without a voice to make one.
//
// Lived inside narration_window.test.js until 26.9.2026, when a second file
// (api_usage_metering.test.js) needed the same clip; one home, imported twice.

const fs = require('fs');
const os = require('os');
const path = require('path');

const RATE = 22050;

/// A 16-bit mono wav of [seconds], with a tone from [from] to [to] and silence
/// around it — the shape a synthesiser hands back. Written to the system's
/// temp directory unless [file] names where; the path is returned.
function wavWith({ seconds, from, to, amplitude = 12000, rate = RATE, file = null }) {
  const frames = Math.round(seconds * rate);
  const data = Buffer.alloc(frames * 2);
  for (let i = 0; i < frames; i++) {
    const at = i / rate;
    const loud = at >= from && at < to;
    // Not digital silence outside the tone: a real clip's quiet part is around
    // −50 dB peak, and a scan for the first non-zero sample would answer 0 for
    // every clip ever made.
    const value = loud
      ? Math.round(amplitude * Math.sin(2 * Math.PI * 220 * at))
      : Math.round(60 * Math.sin(2 * Math.PI * 50 * at));
    data.writeInt16LE(value, i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(data.length, 40);

  const target = file
    || path.join(os.tmpdir(), `win_${process.pid}_${Math.random().toString(36).slice(2)}.wav`);
  fs.writeFileSync(target, Buffer.concat([header, data]));
  return target;
}

module.exports = { wavWith, RATE };
