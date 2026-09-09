// tts/piper.js — a neural voice that runs on the server and asks nobody's
// permission.
//
// Chosen on 9.9.2026, after Google Cloud turned out to be closed: Cloud does not
// accept an individual payments profile in Serbia, and the owner's is the same
// individual profile that already carries Play, AdSense and Pay. The tax dialog
// offered „Business" or „Government body" and nothing else, and ticking Business
// to get past a form you cannot edit afterwards is not a thing to do for a
// narration feature.
//
// Piper is the answer that needs none of it: no account, no card, no tax
// profile, no per-character bill, and nothing leaves the machine. It runs on the
// droplet's CPU at about real time.
//
// **176 voices across 57 languages**, read out of its own catalogue rather than
// remembered. It was chosen partly because it was the only engine here with a
// Serbian voice — and that voice was tried on 9.9.2026 and rejected by the
// owner, who described it as reading Serbian with an English model. So the
// installed set is English, German, Spanish, Italian and French, whose models
// are good, and Serbian is not offered at all rather than offered badly. The
// engine's own reason for being here stands without it: no account, no card, no
// bill, and nothing leaves the machine.
//
// **Licence.** The maintained distribution (`OHF-Voice/piper1-gpl`, installed
// with `pip install piper-tts`) is GPL-3.0. This server calls it as a separate
// program over a pipe — it links nothing, imports nothing and ships no part of
// it — which is the ordinary at-arm's-length use that does not reach into the
// caller's own licence. Worth knowing about rather than discovering later.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const logger = require('../logger');

const TIMEOUT_MS = 120000;

function python() {
  return process.env.PIPER_PYTHON || 'python';
}

function voicesDir() {
  return process.env.PIPER_VOICES_DIR || '';
}

/// Every `.onnx` in the voices directory that has its config beside it.
///
/// A model without its `.onnx.json` is half a download, and piper refuses it
/// with a stack trace; better to leave it out of the list than to offer a voice
/// that fails when a trainer picks it.
function modelFiles() {
  const dir = voicesDir();
  if (!dir || !fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter((name) => name.endsWith('.onnx'))
    .filter((name) => fs.existsSync(path.join(dir, `${name}.json`)))
    .map((name) => path.join(dir, name));
}

function available() {
  return modelFiles().length > 0;
}

/// `sr_RS-serbski_institut-medium` → `sr-RS`, so a voice sorts and groups the
/// way every other provider's does. The app's picker knows one shape only.
function languageOf(voiceId) {
  const [locale] = String(voiceId || '').split('-');
  const [lang, region] = String(locale).split('_');
  if (!lang) return '';
  return region ? `${lang}-${region}` : lang;
}

/// The quality piper was asked to build, which is also its size on disk and
/// roughly its cost in seconds: `low`, `medium`, `high`.
function tierOf(voiceId) {
  const parts = String(voiceId || '').split('-');
  return parts.length >= 3 ? parts[parts.length - 1] : 'medium';
}

async function voices() {
  return modelFiles()
    .map((file) => {
      const id = path.basename(file, '.onnx');
      return {
        id,
        name: id,
        language: languageOf(id),
        gender: '',
        tier: tierOf(id),
      };
    })
    .filter((voice) => voice.language)
    .sort((a, b) => a.language.localeCompare(b.language) || a.id.localeCompare(b.id));
}

function modelPathFor(voice) {
  const dir = voicesDir();
  const wanted = voice ? path.join(dir, `${voice}.onnx`) : '';
  if (wanted && fs.existsSync(wanted)) return wanted;
  // No voice asked for, or one this server does not have: the first model is a
  // better answer than a crash, and the app only ever sends an id this provider
  // itself listed.
  const [first] = modelFiles();
  if (!first) throw new Error('no piper voice is installed');
  if (voice) logger.warn({ voice }, '[TTS] unknown piper voice, using the first installed one');
  return first;
}

/**
 * Put piper's output files where the jobs asked for them.
 *
 * **The count is checked before anything is copied**, and that check is the
 * reason this is a named function with a test rather than three lines inside
 * the callback. Piper names its files by a timestamp, so they come back in the
 * order the sentences went in — but if it ever produced a different number,
 * mapping them by position would put one beat's sentence on another beat's
 * board. That is inaudible until somebody watches a finished film to the end,
 * which is the exact shape of fault this project keeps finding one layer late.
 */
function assignOutputs(files, jobs) {
  if (files.length !== jobs.length) {
    throw new Error(`piper wrote ${files.length} files for ${jobs.length} sentences`);
  }
  files.forEach((file, i) => fs.copyFileSync(file, jobs[i].outputPath));
}

async function synthesize({ text, voice, outputPath }) {
  await run(modelPathFor(voice), [text], (files) => assignOutputs(files, [{ outputPath }]));
  return outputPath;
}

/**
 * Many sentences, one model load.
 *
 * **This is why the provider has a batch method at all.** Loading a 61 MB model
 * costs about five seconds and speaking a sentence costs a fraction of one:
 * measured here, one sentence alone took 5.2 s and four together took 2.2 s. A
 * twenty-five beat tutorial synthesised a sentence at a time would spend two
 * minutes doing nothing but opening the same file.
 *
 * `jobs` is `[{ text, outputPath }]`. Piper names its output by a timestamp, so
 * the files come back in the order the sentences went in — and **the count is
 * checked before anything is copied**, because a batch that produced a
 * different number of files cannot be mapped back safely, and putting one
 * beat's sentence on another beat's board is exactly the silent fault this
 * project keeps finding.
 */
async function synthesizeBatch({ jobs, voice }) {
  if (jobs.length === 0) return;
  await run(modelPathFor(voice), jobs.map((job) => job.text), (files) => assignOutputs(files, jobs));
}

/// One piper process, its output collected from a directory of its own.
function run(model, texts, collect) {
  return new Promise((resolve, reject) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'piper-'));
    const proc = spawn(
      python(),
      ['-m', 'piper', '-m', model, '-d', dir, '--output-dir-naming', 'timestamp'],
      { timeout: TIMEOUT_MS },
    );

    let stderr = '';
    proc.stderr.on('data', (d) => { stderr += d.toString(); });
    proc.on('error', (err) => {
      cleanup(dir);
      reject(err);
    });
    proc.on('close', (code) => {
      try {
        if (code !== 0) throw new Error(`piper exited ${code}: ${stderr.slice(-300)}`);
        // Timestamps of equal length, so lexicographic order is the order they
        // were written, which is the order the sentences were fed in.
        const files = fs.readdirSync(dir)
          .filter((name) => name.endsWith('.wav'))
          .sort()
          .map((name) => path.join(dir, name));
        collect(files);
        resolve();
      } catch (err) {
        reject(err);
      } finally {
        cleanup(dir);
      }
    });

    // One sentence per line: piper reads stdin a line at a time, so a caption
    // carrying the trainer's own newline — a part that asks something puts its
    // task on the line under what was written — would otherwise become two
    // clips for one beat.
    for (const text of texts) {
      proc.stdin.write(`${String(text).replace(/\s+/g, ' ').trim()}\n`);
    }
    proc.stdin.end();
  });
}

function cleanup(dir) {
  try { fs.rmSync(dir, { recursive: true, force: true }); } catch { /* gone already */ }
}

module.exports = {
  available,
  voices,
  synthesize,
  synthesizeBatch,
  assignOutputs,
  languageOf,
  tierOf,
};
