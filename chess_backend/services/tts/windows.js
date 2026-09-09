// tts/windows.js — the voice that is already on the machine.
//
// `System.Speech.Synthesis` through PowerShell: no key, no account, no network,
// no per-character cost, and nothing about the trainer's text leaves the
// server. It sounds like 2010, and that is an honest trade for a first
// provider — the pipeline it drives is the same one a neural voice will use,
// and it can be listened to today rather than after somebody signs up for
// something.
//
// Windows only, by construction. On the droplet (Ubuntu) `available()` is false
// and narration is simply not offered, which is why every caller asks before it
// promises a trainer anything.
const { execFile } = require('child_process');
const os = require('os');

const TIMEOUT_MS = 30000;

function available() {
  return os.platform() === 'win32';
}

/// PowerShell's own string escape: a single quote is doubled.
///
/// The text is a trainer's sentence and reaches this file from a request body,
/// so it is not trusted. It is passed as an argument to a script that reads it
/// as data — `-Text` — rather than pasted into the script's body, and quoted
/// besides.
function psQuote(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

async function voices() {
  const script = `
    Add-Type -AssemblyName System.Speech
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $s.GetInstalledVoices() |
      Where-Object { $_.Enabled } |
      ForEach-Object { $_.VoiceInfo.Name + '|' + $_.VoiceInfo.Culture }
    $s.Dispose()
  `;
  const out = await run(script);
  return out
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [name, culture] = line.split('|');
      return { id: name, name, language: culture || '' };
    })
    // English only, and that is the owner's rule rather than a limitation of
    // this provider: nothing in this app is spoken in another language.
    .filter((voice) => voice.language.toLowerCase().startsWith('en'));
}

async function synthesize({ text, voice, outputPath }) {
  const selectVoice = voice
    ? `try { $s.SelectVoice(${psQuote(voice)}) } catch { }`
    : '';
  const script = `
    Add-Type -AssemblyName System.Speech
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    ${selectVoice}
    $s.SetOutputToWaveFile(${psQuote(outputPath)})
    $s.Speak(${psQuote(text)})
    $s.Dispose()
  `;
  await run(script);
  return outputPath;
}

function run(script) {
  return new Promise((resolve, reject) => {
    execFile(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      { timeout: TIMEOUT_MS, windowsHide: true },
      (err, stdout, stderr) => {
        // A synthesiser that hangs must not hang the export: the timeout above
        // kills it, and this arm turns that into one silent beat rather than a
        // request that never answers.
        if (err) return reject(new Error(stderr?.trim() || err.message));
        resolve(stdout || '');
      },
    );
  });
}

module.exports = { available, voices, synthesize };
