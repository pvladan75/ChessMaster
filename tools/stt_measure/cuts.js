// A sentence cut where the board changed — phase 8b of docs/PLAN-PRIPREMA.md,
// measured on a real recording and written down as a fixture.
//
//   node tools/stt_measure/cuts.js --timeline <events.json | fixture.json>
//        --answer <Groq's raw answer.json> --tag <name> [--write <directory>]
//
// Prints how long before it was drawn each mark is on screen, and how long
// before it was played each move, with whole sentences and with the cut.
// With --write it also writes `<directory>/<tag>.json`: the timeline as it was
// recorded, the transcript as the server sends it (`wordsBySentence`), every
// letter and digit replaced by `w`, and what this sketch answers on it.
//
// **This is a measurement and a sketch, not the app's code**, as `beats.js`
// is for phase 5. The rule's home is
// chess_app/lib/features/tutorial_studio/services/recording_tutorial.dart;
// this reads the same rule a second time, from the plan, so that the app's
// gate has an answer it did not write itself. The two were compared on all
// five of the owner's recordings before either was believed.
//
// `chess.js` and the server's own sentence builder are borrowed from
// chess_backend. Nothing here is loaded by the server.

'use strict';

const fs = require('fs');
const path = require('path');

const backend = path.join(__dirname, '..', '..', 'chess_backend');
const { Chess } = require(path.join(backend, 'node_modules', 'chess.js'));
const { judgeSentences, sentencesFrom, wordsBySentence } = require(
    path.join(backend, 'services', 'transcript.js'));

const CAPTION_LETTERS = 4 * 42;
const MAX_EARLY_MS = 6000;
const MIN_PIECE_MS = 1000;

function arg(name, fallback) {
  const at = process.argv.indexOf(`--${name}`);
  return at === -1 ? fallback : process.argv[at + 1];
}

// ------------------------------------------------------------------ input

function readTimeline(file) {
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  return Array.isArray(json) ? json : json.events;
}

/// Groq's answer as the server's client hands it on (`services/stt/groq.js`).
function readAnswer(file) {
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  const ms = (seconds) => Math.round(Number(seconds) * 1000);
  return {
    durationMs: ms(raw.duration),
    words: raw.words.map((w) => ({ text: String(w.word ?? ''), startMs: ms(w.start), endMs: ms(w.end) })),
    segments: (raw.segments || []).map((s) => ({ text: String(s.text ?? ''), startMs: ms(s.start), endMs: ms(s.end) })),
  };
}

/// The words are somebody's; the times and the commas are the data.
const placeholder = (text) => text.replace(/[\p{L}\p{N}]/gu, 'w');

function transcriptOf(answer, language) {
  const judged = judgeSentences(sentencesFrom(answer, { language }), answer.durationMs);
  if (!judged.ok) throw new Error(judged.error);
  const words = wordsBySentence(judged.sentences, answer.words);
  if (!words) throw new Error('the words do not tally with the sentences');
  return judged.sentences.map((s, i) => ({
    startMs: s.startMs,
    endMs: s.endMs,
    text: placeholder(s.text),
    heard: placeholder(s.heard),
    words: words[i].map((w) => ({ ...w, text: placeholder(w.text) })),
  }));
}

// -------------------------------------------------------------- the board

const SETS_A_BOARD = new Set(['init', 'move', 'fen_change', 'lesson_loaded']);

function marksOf(data) {
  const arrows = (Array.isArray(data.arrows) ? data.arrows : [])
    .filter((a) => a && typeof a.from === 'string' && typeof a.to === 'string')
    .map((a) => `${a.color ?? a.colorCode ?? 'G'}${a.from}${a.to}`);
  const squares = (Array.isArray(data.squares) ? data.squares : [])
    .filter((s) => s && typeof s.square === 'string')
    .map((s) => `${s.color ?? s.colorCode ?? 'G'}${s.square}`);
  return { arrows, squares, key: `${[...arrows].sort().join(',')}|${[...squares].sort().join(',')}` };
}

const placementAndSide = (fen) => fen.trim().split(/\s+/).slice(0, 2).join(' ');

function moveBetween(from, to) {
  let game;
  try {
    game = new Chess(from);
  } catch (_) {
    return null;
  }
  for (const move of game.moves({ verbose: true })) {
    game.move(move);
    const reached = game.fen();
    game.undo();
    if (placementAndSide(reached) === placementAndSide(to)) return move.san;
  }
  return null;
}

/// R2: positions, each with the stretches of marks that stood on it.
function positionsOf(events, durationMs) {
  const positions = [];
  for (const event of events) {
    const setsBoard = SETS_A_BOARD.has(event.eventType);
    if (!setsBoard && event.eventType !== 'arrow_drawn') continue;
    const data = event.data || {};
    const stretch = { startMs: event.timestampMs, marks: marksOf(data) };
    if (setsBoard && typeof data.fen === 'string' && data.fen.trim() !== '') {
      positions.push({
        fen: data.fen,
        aroseMs: event.timestampMs,
        newBoard: event.eventType !== 'move',
        stretches: [stretch],
      });
    } else if (positions.length > 0) {
      positions[positions.length - 1].stretches.push(stretch);
    }
  }
  positions.forEach((p, i) => {
    const next = positions[i + 1];
    p.endMs = next ? next.aroseMs : Math.max(durationMs, p.aroseMs + 1);
    p.move = i === 0 || p.newBoard ? null : moveBetween(positions[i - 1].fen, p.fen);
    p.jump = i > 0 && p.move === null;
  });
  return positions;
}

function marksAt(position, ms) {
  let found = position.stretches[0].marks;
  for (const s of position.stretches) if (s.startMs <= ms) found = s.marks;
  return found;
}

/// Every moment the board changed.
function changesOf(positions) {
  const changes = [];
  positions.forEach((p, i) => {
    p.stretches.forEach((s, j) => {
      const bare = s.marks.key === '|';
      if (j === 0) {
        if (i > 0) changes.push({ ms: s.startMs, board: true, bare, position: i, marks: s.marks });
      } else if (s.marks.key !== p.stretches[j - 1].marks.key) {
        changes.push({ ms: s.startMs, board: false, bare, position: i, marks: s.marks });
      }
    });
  });
  return changes;
}

// ---------------------------------------------------------------- the cut

const ENDS_CLAUSE = /[,;:]$/;

/// R1, as the plan says it. The fixtures hold no corrected sentence, so the
/// words of a sentence are its words as heard.
function piecesOf(sentence, changes, cut) {
  const whole = [{ text: sentence.text, startMs: sentence.startMs, endMs: sentence.endMs }];
  const words = sentence.words || [];
  if (!cut || words.length < 2) return whole;

  const cuts = [];
  let open = 0;
  let drawnAt = null;
  for (const change of changes) {
    if (change.ms >= sentence.endMs) continue;
    const said = words.reduce((found, w, i) => (w.startMs <= change.ms ? i : found), 0);
    let at = open;
    if (said > open) {
      let clause = open;
      for (let i = open + 1; i <= said; i++) {
        if (ENDS_CLAUSE.test(words[i - 1].text)) clause = i;
      }
      at = change.ms - words[clause].startMs <= MAX_EARLY_MS ? clause : said;
      let keeps = false;
      if (change.board && drawnAt !== null && words[at].startMs <= drawnAt) {
        at = said;
        keeps = words[at].startMs > drawnAt;
      }
      if (!keeps && words[at].startMs - words[open].startMs < MIN_PIECE_MS) at = open;
    }
    if (at > open) {
      cuts.push({ word: at, changeMs: change.ms });
      open = at;
    }
    drawnAt = change.bare ? null : change.ms;
  }
  if (cuts.length === 0) return whole;

  const pieces = [];
  let from = 0;
  for (let k = 0; k <= cuts.length; k++) {
    const last = k === cuts.length;
    const mine = words.slice(from, last ? words.length : cuts[k].word);
    const startMs = k === 0 ? sentence.startMs : mine[0].startMs;
    const endMs = last
      ? sentence.endMs
      : Math.min(mine[mine.length - 1].endMs, cuts[k].changeMs - 1);
    pieces.push({ text: mine.map((w) => w.text).join(' '), startMs, endMs: Math.max(endMs, startMs) });
    from += mine.length;
  }
  return pieces;
}

// -------------------------------------------------------------- the beats

const captionOf = (said) => said.map((s) => s.text.trim()).join(' ')
  .replace(/\s+/g, ' ').replace(/\{/g, '(').replace(/\}/g, ')');

function filmOf({ events, durationMs, sentences }, { cut }) {
  const positions = positionsOf(events, durationMs);
  const changes = changesOf(positions);
  const spoken = sentences
    .filter((s) => s.text.trim() !== '')
    .flatMap((s) => piecesOf(s, changes, cut));

  // R3.
  const byPosition = positions.map(() => []);
  for (const s of spoken) {
    let at = 0;
    positions.forEach((p, i) => { if (p.aroseMs <= s.endMs) at = i; });
    byPosition[at].push(s);
  }

  // R4 and R5.
  const beats = [];
  positions.forEach((p, i) => {
    const mine = byPosition[i];
    if (mine.length === 0) {
      const next = positions[i + 1];
      if (!(next && next.jump)) {
        beats.push({ position: i, marks: marksAt(p, p.endMs - 1), startMs: p.aroseMs, said: [] });
      }
      return;
    }
    let open = null;
    for (const s of mine) {
      const marks = marksAt(p, s.endMs < p.endMs ? s.endMs : p.endMs - 1);
      const letters = open ? captionOf(open.said).length + 1 + s.text.trim().length : 0;
      if (open && open.marks.key === marks.key && letters <= CAPTION_LETTERS) {
        open.said.push(s);
        open.marks = marks;
      } else {
        open = { position: i, marks, startMs: s.startMs, said: [s] };
        beats.push(open);
      }
    }
  });

  // R6.
  const parts = [];
  for (const beat of beats) {
    const lastPart = parts[parts.length - 1];
    const same = lastPart && lastPart[lastPart.length - 1].position === beat.position;
    if (!lastPart || (!same && positions[beat.position].jump)) parts.push([beat]);
    else lastPart.push(beat);
  }

  // R8.
  const markers = beats.map(() => 0);
  for (let i = 1; i < beats.length; i++) {
    const raw = beats[i].startMs;
    markers[i] = raw > markers[i - 1]
      ? raw
      : Math.max(positions[beats[i].position].aroseMs, markers[i - 1] + 1);
  }
  for (let i = beats.length - 1; i >= 1; i--) {
    const ceiling = i === beats.length - 1 ? durationMs - 1 : markers[i + 1] - 1;
    if (markers[i] > ceiling) markers[i] = ceiling;
  }
  beats.forEach((b, i) => { b.markerMs = markers[i]; });
  return { positions, changes, beats, parts };
}

// --------------------------------------------------------- the measurement

/// For each change of the board, how long before it happened it is on
/// screen: its own moment less the marker of the first beat on its position
/// that shows it. Null where no beat ever does.
function earliness(film) {
  const rows = [];
  for (const change of film.changes) {
    const onPosition = film.beats.filter((b) => b.position === change.position);
    let shown;
    if (change.board) {
      if (onPosition.length === 0) continue; // passed through (R5)
      shown = onPosition[0];
    } else if (change.bare) {
      continue; // marks taken off: nothing to show
    } else {
      const has = (beat, mark, of) => beat.marks[of].includes(mark);
      shown = onPosition.find((b) => change.marks.arrows.every((a) => has(b, a, 'arrows'))
        && change.marks.squares.every((s) => has(b, s, 'squares')));
    }
    rows.push({ ms: change.ms, board: change.board, early: shown ? change.ms - shown.markerMs : null });
  }
  return rows;
}

function summary(rows) {
  const shown = rows.filter((r) => r.early !== null).map((r) => r.early).sort((a, b) => a - b);
  return {
    counted: rows.length,
    dropped: rows.length - shown.length,
    medianMs: shown.length ? shown[Math.floor(shown.length / 2)] : null,
    maxMs: shown.length ? shown[shown.length - 1] : null,
    over3s: shown.filter((e) => e > 3000).length,
    over6s: shown.filter((e) => e > 6000).length,
  };
}

// ------------------------------------------------------------------- main

function main() {
  const tag = arg('tag');
  const timeline = arg('timeline');
  const answerFile = arg('answer');
  if (!tag || !timeline || !answerFile) {
    console.error('usage: node cuts.js --timeline <file> --answer <file> --tag <name> [--write <dir>]');
    process.exit(2);
  }
  const language = arg('language', 'sr-Latn');
  const events = readTimeline(timeline);
  const answer = readAnswer(answerFile);
  const recording = { events, durationMs: answer.durationMs, sentences: transcriptOf(answer, language) };

  const whole = filmOf(recording, { cut: false });
  const cut = filmOf(recording, { cut: true });
  const measured = {};
  for (const [name, film] of [['whole', whole], ['cut', cut]]) {
    const rows = earliness(film);
    measured[name] = {
      beats: film.beats.length,
      marks: summary(rows.filter((r) => !r.board)),
      moves: summary(rows.filter((r) => r.board)),
    };
  }
  console.log(JSON.stringify({ tag, sentences: recording.sentences.length, measured }, null, 1));

  const to = arg('write');
  if (!to) return;
  const fixture = {
    about: `The owner's recording „${tag}": its real timeline, and its transcript as the server `
      + 'sends it since phase 8b of docs/PLAN-PRIPREMA.md — the sentences built from Groq\'s real '
      + 'answer, each with its words and their times (services/transcript.js), every letter and '
      + 'digit replaced by „w": the times and the commas are the recording\'s, the words are not '
      + 'kept. `sketch` is what tools/stt_measure/cuts.js answers on it, a second reading of the '
      + 'rule that the app\'s core is held to. Written by that tool, never by hand.',
    durationMs: recording.durationMs,
    events,
    transcript: { language, sentences: recording.sentences },
    sketch: {
      parts: cut.parts.length,
      beatsPerPart: cut.parts.map((p) => p.length),
      wordlessBeats: cut.beats.filter((b) => b.said.length === 0).length,
      beats: cut.beats.map((b) => ({
        fen: cut.positions[b.position].fen,
        caption: captionOf(b.said),
        marks: b.marks.key,
        markerMs: b.markerMs,
      })),
      wholeSentences: { beats: whole.beats.length },
      measured,
    },
  };
  fs.mkdirSync(to, { recursive: true });
  const file = path.join(to, `${tag}.json`);
  fs.writeFileSync(file, `${JSON.stringify(fixture, null, 1)}\n`);
  console.log(`wrote ${file}`);
}

if (require.main === module) main();

module.exports = { earliness, filmOf, readAnswer, readTimeline, summary, transcriptOf };
