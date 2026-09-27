// English, measured without anybody speaking it — phase 5 of
// docs/PLAN-PRIPREMA.md. The owner teaches in Serbian and would not record a
// lesson in English, so the text in `english_lesson.txt` is spoken by the
// voice the app already has (Azure) and the sound is what a vendor is given.
//
//   node tools/stt_measure/english.js speak      makes out/english.wav
//   node tools/stt_measure/english.js score <vendor answer.json>
//
// **What this can and cannot say.** The true text is known to the letter, so
// the count is arithmetic. But a synthetic voice is steadier and clearer than
// a person at a desk: the number is the best a vendor does on chess English,
// not what it will do on a trainer's recording.

'use strict';

const fs = require('fs');
const path = require('path');

const VOICE = 'en-US-JennyNeural';
const out = (name) => path.join(__dirname, 'out', name);

function envFrom(file) {
  const env = {};
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return env;
}

const lesson = () =>
  fs.readFileSync(path.join(__dirname, 'english_lesson.txt'), 'utf8').trim();

async function speak() {
  const env = envFrom(path.join(__dirname, '..', '..', 'chess_backend', '.env'));
  const text = lesson().replace(/&/g, '&amp;').replace(/</g, '&lt;');
  const ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" ' +
      `xml:lang="en-US"><voice name="${VOICE}">${text}</voice></speak>`;
  const res = await fetch(
      `https://${env.AZURE_SPEECH_REGION}.tts.speech.microsoft.com/cognitiveservices/v1`, {
        method: 'POST',
        headers: {
          'Ocp-Apim-Subscription-Key': env.AZURE_SPEECH_KEY,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'riff-16khz-16bit-mono-pcm',
          'User-Agent': 'stt-measure',
        },
        body: ssml,
      });
  if (!res.ok) {
    console.log(`REFUSED ${res.status}: ${(await res.text()).slice(0, 300)}`);
    process.exit(1);
  }
  fs.mkdirSync(path.join(__dirname, 'out'), { recursive: true });
  const sound = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(out('english.wav'), sound);
  console.log(JSON.stringify({ voice: VOICE, letters: lesson().length,
    bytes: sound.length, seconds: (sound.length - 44) / 32000 }));
}

const NUMBERS = { one: '1', two: '2', three: '3', four: '4', five: '5',
  six: '6', seven: '7', eight: '8' };

/// Words as they are compared: lower case, no punctuation, a square as one
/// word however it was written — „e4", „E4", „e 4", „e four".
function wordsOf(text) {
  const raw = text.toLowerCase().replace(/[’']/g, "'")
      .replace(/[^a-z0-9' ]+/g, ' ').split(/\s+/).filter(Boolean)
      .map((w) => NUMBERS[w] || w);
  const words = [];
  for (let i = 0; i < raw.length; i++) {
    if (/^[a-h]$/.test(raw[i]) && /^[1-8]$/.test(raw[i + 1] || '')) {
      words.push(raw[i] + raw[i + 1]);
      i++;
    } else {
      words.push(raw[i]);
    }
  }
  return words;
}

/// The fewest single-word changes that turn what was heard into what was
/// said, and which words they were.
function differences(said, heard) {
  const n = said.length;
  const m = heard.length;
  const d = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = 0; i <= n; i++) d[i][0] = i;
  for (let j = 0; j <= m; j++) d[0][j] = j;
  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      d[i][j] = Math.min(
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + (said[i - 1] === heard[j - 1] ? 0 : 1));
    }
  }
  const wrong = [];
  let i = n;
  let j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && said[i - 1] === heard[j - 1] &&
        d[i][j] === d[i - 1][j - 1]) {
      i--;
      j--;
    } else if (i > 0 && j > 0 && d[i][j] === d[i - 1][j - 1] + 1) {
      wrong.push({ said: said[i - 1], heard: heard[j - 1] });
      i--;
      j--;
    } else if (i > 0 && d[i][j] === d[i - 1][j] + 1) {
      wrong.push({ said: said[i - 1], heard: null });
      i--;
    } else {
      wrong.push({ said: null, heard: heard[j - 1] });
      j--;
    }
  }
  return { changes: d[n][m], wrong: wrong.reverse() };
}

const CHESS = new Set(['italian', 'evans', 'gambit', 'pawn', 'knight', 'bishop',
  'queen', 'king', "king's", 'castles', 'kingside', 'check', 'checkmate',
  'tempo', 'centre', 'sacrifice', 'takes', 'taken', 'develops', 'square']);

function score(file) {
  const answer = JSON.parse(fs.readFileSync(file, 'utf8'));
  const said = wordsOf(lesson());
  const heard = wordsOf((answer.combinedPhrases || []).map((p) => p.text).join(' '));
  const { changes, wrong } = differences(said, heard);
  const isSquare = (w) => /^[a-h][1-8]$/.test(w);
  const lost = (test) => wrong.filter((w) => w.said && test(w.said)).length;
  const result = {
    wordsSaid: said.length,
    wordsHeard: heard.length,
    changesNeeded: changes,
    wordsRight: `${(100 * (1 - changes / said.length)).toFixed(1)}%`,
    squaresSaid: said.filter(isSquare).length,
    squaresWrong: lost(isSquare),
    chessWordsSaid: said.filter((w) => CHESS.has(w)).length,
    chessWordsWrong: lost((w) => CHESS.has(w)),
    wrong: wrong.map((w) => `${w.said ?? '(nothing)'} → ${w.heard ?? '(nothing)'}`),
  };
  console.log(JSON.stringify(result, null, 1));
}

if (process.argv[2] === 'speak') {
  speak().catch((e) => {
    console.error(`failed: ${e.message}`);
    process.exit(1);
  });
} else if (process.argv[2] === 'score' && process.argv[3]) {
  score(process.argv[3]);
} else {
  console.error('usage: node tools/stt_measure/english.js speak | score <answer.json>');
  process.exit(2);
}
