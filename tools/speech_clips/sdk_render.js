// sdk_render.js — a sentence through Azure's Speech SDK, with the time of
// every word it spoke.
//
// The REST endpoint `services/tts/azure.js` uses returns sound and nothing
// else; the SDK raises a `wordBoundary` event per word with its offset and
// duration in the audio it is writing, which is the one exact source of cut
// points for a word inside a sentence. Tool-only dependency: the server keeps
// its REST provider, and this file is never required by it.
'use strict';

const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const BACKEND = path.resolve(__dirname, '..', '..', 'chess_backend');
const backendRequire = createRequire(path.join(BACKEND, 'package.json'));
backendRequire('dotenv').config({ path: path.join(BACKEND, '.env') });

const sdk = require('microsoft-cognitiveservices-speech-sdk');

const TICKS_PER_MS = 10000; // the SDK counts in 100-nanosecond ticks

/// Renders [text] in [voice] to [outputPath] (RIFF, 22050 Hz, 16-bit, mono)
/// and resolves with the words it spoke: `[{ text, startMs, endMs }]`,
/// punctuation left out.
function renderWithWords({ text, voice, outputPath }) {
  const config = sdk.SpeechConfig.fromSubscription(
    (process.env.AZURE_SPEECH_KEY || '').trim(),
    (process.env.AZURE_SPEECH_REGION || '').trim().toLowerCase(),
  );
  config.speechSynthesisVoiceName = voice;
  config.speechSynthesisOutputFormat = sdk.SpeechSynthesisOutputFormat.Riff22050Hz16BitMonoPcm;
  config.setProperty(sdk.PropertyId.SpeechServiceResponse_RequestWordBoundary, 'true');

  const synth = new sdk.SpeechSynthesizer(config, null);
  const words = [];
  synth.wordBoundary = (_sender, e) => {
    if (e.boundaryType && e.boundaryType !== sdk.SpeechSynthesisBoundaryType.Word) return;
    words.push({
      text: e.text,
      startMs: e.audioOffset / TICKS_PER_MS,
      endMs: (e.audioOffset + e.duration) / TICKS_PER_MS,
    });
  };

  return new Promise((resolve, reject) => {
    synth.speakTextAsync(
      text,
      (result) => {
        synth.close();
        if (result.reason !== sdk.ResultReason.SynthesizingAudioCompleted) {
          reject(new Error(`synthesis ended with ${result.reason}: ${result.errorDetails || ''}`));
          return;
        }
        fs.mkdirSync(path.dirname(outputPath), { recursive: true });
        fs.writeFileSync(outputPath, Buffer.from(result.audioData));
        resolve(words);
      },
      (err) => {
        synth.close();
        reject(new Error(String(err)));
      },
    );
  });
}

module.exports = { renderWithWords };
