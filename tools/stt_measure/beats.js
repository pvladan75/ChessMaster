// A recording cut into beats by the rules R1–R8 of docs/PLAN-PRIPREMA.md §3 —
// phase 5, the half that needs no vendor: it reads an answer already kept.
//
//   node tools/stt_measure/beats.js --timeline <events.json>
//        --answer <vendor answer.json> --sound <sound file> --tag <name>
//
// Writes, under `tools/stt_measure/out/` (which git ignores):
//
//   <tag>.beats.json   the parts and their beats, and the counts
//   <tag>.html         the same, to be read, heard and corrected by hand
//
// **This is a measurement and a sketch, not the app's code.** The conversion
// itself runs in the app (T5 of the plan); what is here exists so that the
// rules can be seen on a real recording before anything is built on them.
//
// `chess.js` is borrowed from the server's own `node_modules`. Nothing here is
// loaded by the server.

'use strict';

const fs = require('fs');
const path = require('path');
const { Chess } = require(
    path.join(__dirname, '..', '..', 'chess_backend', 'node_modules', 'chess.js'));

/// The caption's room: four lines (R4). The width of a line is the film's to
/// say; 42 letters is what a subtitle line usually holds, and is measured
/// against, not relied on.
const CAPTION_LETTERS = 4 * 42;

function arg(name, fallback) {
  const at = process.argv.indexOf(`--${name}`);
  return at === -1 ? fallback : process.argv[at + 1];
}

// ------------------------------------------------------------------ script

const LATIN = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', ђ: 'đ', е: 'e', ж: 'ž', з: 'z',
  и: 'i', ј: 'j', к: 'k', л: 'l', љ: 'lj', м: 'm', н: 'n', њ: 'nj', о: 'o',
  п: 'p', р: 'r', с: 's', т: 't', ћ: 'ć', у: 'u', ф: 'f', х: 'h', ц: 'c',
  ч: 'č', џ: 'dž', ш: 'š',
};

/// Serbian Cyrillic as Serbian Latin. One way only, and without loss: every
/// Cyrillic letter has one Latin spelling.
function latinOf(text) {
  let out = '';
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const lower = ch.toLowerCase();
    const to = LATIN[lower];
    if (to === undefined) {
      out += ch;
    } else if (ch === lower) {
      out += to;
    } else {
      // „Љубав" is „Ljubav", „ЉУБАВ" is „LJUBAV".
      const next = text[i + 1];
      const shout = next !== undefined && next !== next.toLowerCase();
      out += shout ? to.toUpperCase() : to[0].toUpperCase() + to.slice(1);
    }
  }
  return out;
}

// --------------------------------------------------------------- sentences

/// R1. What the vendor returned between two sentence ends, with the time of
/// its first and its last word. A number with a full stop — „1." — is also
/// how a vendor writes „prvi", which ends nothing.
function sentencesOf(answer) {
  const sentences = [];
  for (const phrase of answer.phrases || []) {
    let open = [];
    const close = () => {
      if (!open.length) return;
      sentences.push({
        text: open.map((w) => w.text).join(' '),
        startMs: open[0].offsetMilliseconds,
        endMs: open[open.length - 1].offsetMilliseconds +
            open[open.length - 1].durationMilliseconds,
        words: open.length,
        confidence: phrase.confidence,
      });
      open = [];
    };
    const words = phrase.words || [];
    words.forEach((word, i) => {
      open.push(word);
      if (!/[.?!]$/.test(word.text)) return;
      // „1. potez" is „prvi potez"; „lovac c 5. Ako želite" ends a sentence.
      // What tells them apart is what follows: a sentence begins with a
      // capital.
      const next = words[i + 1];
      const ordinal = /^\d+\.$/.test(word.text) && next !== undefined &&
          next.text[0] === next.text[0].toLowerCase();
      if (!ordinal) close();
    });
    close();
  }
  return sentences;
}

// ------------------------------------------------------------------ board

const placementOf = (fen) => fen.split(' ').slice(0, 2).join(' ');

/// R7. The move between two positions, from the positions themselves; null
/// where the second is not one legal move from the first — a jump (R6).
function moveBetween(fromFen, toFen) {
  let game;
  try {
    game = new Chess(fromFen);
  } catch (_) {
    return null;
  }
  for (const move of game.moves({ verbose: true })) {
    game.move(move);
    const reached = placementOf(game.fen());
    game.undo();
    if (reached === placementOf(toFen)) return move;
  }
  return null;
}

const marksKey = (marks) => JSON.stringify([
  marks.arrows.map((a) => `${a.from}${a.to}${a.color}`).sort(),
  marks.squares.map((s) => `${s.square}${s.color}`).sort(),
]);

/// R2. The timeline as positions, each with the stretches of marks that stood
/// on it. The marks are what the latest event said, whatever its kind (D14).
function positionsOf(events, endMs) {
  const positions = [];
  for (const event of events) {
    const data = event.data || {};
    const marks = {
      arrows: Array.isArray(data.arrows) ? data.arrows : [],
      squares: Array.isArray(data.squares) ? data.squares : [],
    };
    if (event.eventType === 'init' || event.eventType === 'move') {
      positions.push({
        fen: data.fen,
        startMs: event.timestampMs,
        kind: event.eventType,
        stretches: [{ startMs: event.timestampMs, marks }],
      });
    } else if (positions.length) {
      positions[positions.length - 1].stretches.push(
          { startMs: event.timestampMs, marks });
    }
  }
  positions.forEach((p, i) => {
    p.endMs = i + 1 < positions.length ? positions[i + 1].startMs : endMs;
    p.stretches.forEach((s, j) => {
      s.endMs = j + 1 < p.stretches.length ? p.stretches[j + 1].startMs : p.endMs;
    });
    const before = positions[i - 1];
    p.move = before && p.kind === 'move' ? moveBetween(before.fen, p.fen) : null;
    // A new board (`init`) and a position no legal move reaches are both a
    // jump; the first position of all is neither.
    p.jump = i > 0 && p.move === null;
  });
  return positions;
}

const overlap = (a0, a1, b0, b1) => Math.max(0, Math.min(a1, b1) - Math.max(a0, b0));

function marksAt(position, ms) {
  let found = position.stretches[0].marks;
  for (const s of position.stretches) if (s.startMs <= ms) found = s.marks;
  return found;
}

// ------------------------------------------------------------------ beats

function beatsOf(events, answer, { rule = 'end', graceMs = 0 } = {}) {
  const sentences = sentencesOf(answer);
  const endMs = Math.max(answer.durationMilliseconds || 0,
      events.length ? events[events.length - 1].timestampMs : 0);
  const positions = positionsOf(events, endMs);

  // R3, as the owner decided it on 27.9.2026 after seeing his own recordings
  // cut: **a sentence belongs to the position standing when it ends.** He
  // names a move and then plays it, so „the position that stood for most of
  // it" — the rule as first written, kept here as `most` to be measured
  // against — put a sentence on the position before the move it names.
  // `graceMs` looks that much past the sentence's end, for a move played a
  // moment after the last word.
  let straddling = 0;
  for (const s of sentences) {
    let best = -1;
    let bestMs = -1;
    let touched = 0;
    let atEnd = -1;
    positions.forEach((p, i) => {
      const ms = overlap(s.startMs, s.endMs, p.startMs, p.endMs);
      if (ms > 0) touched++;
      if (ms > 0 && ms >= bestMs) {
        best = i;
        bestMs = ms;
      }
      if (p.startMs <= s.endMs + graceMs) atEnd = i;
    });
    if (best === -1) best = positions.length - 1;
    if (atEnd === -1) atEnd = 0;
    s.position = rule === 'most' ? best : atEnd;
    s.positionsTouched = touched;
    if (touched > 1) straddling++;
  }

  // R4 and R5, position by position.
  const beats = [];
  positions.forEach((p, i) => {
    const mine = sentences.filter((s) => s.position === i);
    if (!mine.length) {
      // R5. Seen, because the line has to be — unless the board left it by a
      // jump, which makes it a position passed through on the way.
      const next = positions[i + 1];
      p.passedThrough = Boolean(next && next.jump);
      if (!p.passedThrough) {
        beats.push({ position: i, sentences: [], startMs: p.startMs,
          marks: marksAt(p, p.endMs - 1), wordless: true });
      }
      return;
    }
    let open = null;
    for (const s of mine) {
      const marks = marksAt(p, Math.min(s.endMs, p.endMs - 1));
      const letters = open
        ? open.sentences.reduce((n, x) => n + x.text.length + 1, 0) + s.text.length
        : 0;
      if (open && marksKey(open.marks) === marksKey(marks) &&
          letters <= CAPTION_LETTERS) {
        open.sentences.push(s);
        open.marks = marks;
      } else {
        open = { position: i, sentences: [s], startMs: s.startMs, marks,
          wordless: false };
        beats.push(open);
      }
    }
  });

  // R6. A part ends where the board jumps.
  const parts = [];
  let part = null;
  for (const beat of beats) {
    const p = positions[beat.position];
    const firstOfPosition = !part ||
        part.beats[part.beats.length - 1].position !== beat.position;
    let jumped = false;
    if (part && firstOfPosition) {
      const from = part.beats[part.beats.length - 1].position;
      for (let k = from + 1; k <= beat.position; k++) {
        if (positions[k].jump) jumped = true;
      }
    }
    if (!part || jumped) {
      part = { beats: [] };
      parts.push(part);
    }
    part.beats.push(beat);
    beat.san = p.move ? p.move.san : null;
  }

  const spoken = beats.filter((b) => !b.wordless);
  const perPosition = {};
  for (const b of beats) perPosition[b.position] = (perPosition[b.position] || 0) + 1;
  const passed = positions.filter((p) => p.passedThrough);
  const counts = {
    audioSeconds: endMs / 1000,
    sentences: sentences.length,
    positions: positions.length,
    jumps: positions.filter((p) => p.jump).length,
    parts: parts.length,
    beats: beats.length,
    wordlessBeats: beats.length - spoken.length,
    mostBeatsOnOnePosition: Math.max(0, ...Object.values(perPosition)),
    positionsWithSeveralBeats:
        Object.values(perPosition).filter((n) => n > 1).length,
    sentencesThatStraddleAMove: straddling,
    longestCaptionLetters: Math.max(0, ...spoken.map(
        (b) => b.sentences.reduce((n, s) => n + s.text.length + 1, -1))),
    captionRoomLetters: CAPTION_LETTERS,
    positionsPassedThrough: passed.length,
    longestPassedThroughSeconds:
        Math.max(0, ...passed.map((p) => (p.endMs - p.startMs) / 1000)),
    shortestSpokenPositionSeconds: Math.min(...spoken.map(
        (b) => (positions[b.position].endMs - positions[b.position].startMs) / 1000)),
  };
  return { parts, positions, sentences, counts };
}

// ------------------------------------------------------------------- page

const GLYPH = {
  K: '♔', Q: '♕', R: '♖', B: '♗', N: '♘', P: '♙',
  k: '♚', q: '♛', r: '♜', b: '♝', n: '♞', p: '♟',
};
const COLOUR = { G: '#2e8b57', R: '#c0392b', B: '#2a6fb0', Y: '#b8860b',
  O: '#d2691e', P: '#7d3c98' };
const COLOUR_NAME = { G: 'green', R: 'red', B: 'blue', Y: 'yellow',
  O: 'orange', P: 'purple' };

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function centre(square, size) {
  const file = square.charCodeAt(0) - 97;
  const rank = Number(square[1]);
  return [(file + 0.5) * size, (8 - rank + 0.5) * size];
}

function boardSvg(fen, marks, move) {
  const size = 30;
  const out = [`<svg class="board" viewBox="0 0 ${size * 8} ${size * 8}" ` +
      `role="img" aria-label="Position">`];
  const rows = fen.split(' ')[0].split('/');
  for (let r = 0; r < 8; r++) {
    for (let f = 0; f < 8; f++) {
      const dark = (r + f) % 2 === 1;
      const name = String.fromCharCode(97 + f) + (8 - r);
      const last = move && (move.from === name || move.to === name);
      out.push(`<rect x="${f * size}" y="${r * size}" width="${size}" ` +
          `height="${size}" class="${dark ? 'dark' : 'light'}${last ? ' last' : ''}"/>`);
    }
  }
  rows.forEach((row, r) => {
    let f = 0;
    for (const ch of row) {
      if (/\d/.test(ch)) {
        f += Number(ch);
        continue;
      }
      out.push(`<text x="${(f + 0.5) * size}" y="${(r + 0.5) * size + 8}" ` +
          `class="piece">${GLYPH[ch]}</text>`);
      f++;
    }
  });
  for (const s of marks.squares) {
    const [x, y] = centre(s.square, size);
    out.push(`<rect x="${x - size / 2 + 2}" y="${y - size / 2 + 2}" ` +
        `width="${size - 4}" height="${size - 4}" class="mark" ` +
        `stroke="${COLOUR[s.color] || '#333'}"/>`);
  }
  for (const a of marks.arrows) {
    const [x1, y1] = centre(a.from, size);
    const [x2, y2] = centre(a.to, size);
    const angle = Math.atan2(y2 - y1, x2 - x1);
    const tipX = x2 - Math.cos(angle) * 6;
    const tipY = y2 - Math.sin(angle) * 6;
    const head = [0.5, -0.5].map((side) =>
      `${tipX - Math.cos(angle + side) * 11},${tipY - Math.sin(angle + side) * 11}`);
    const colour = COLOUR[a.color] || '#333';
    out.push(`<line x1="${x1}" y1="${y1}" x2="${tipX}" y2="${tipY}" ` +
        `class="arrow" stroke="${colour}"/>`);
    out.push(`<polygon points="${x2},${y2} ${head.join(' ')}" fill="${colour}"/>`);
  }
  out.push('</svg>');
  return out.join('');
}

const clock = (ms) => {
  const s = Math.floor(ms / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
};

function marksInWords(marks) {
  const said = [
    ...marks.arrows.map((a) =>
      `arrow ${a.from}→${a.to} (${COLOUR_NAME[a.color] || a.color})`),
    ...marks.squares.map((s) =>
      `square ${s.square} (${COLOUR_NAME[s.color] || s.color})`),
  ];
  return said.length ? said.join(', ') : 'no marks';
}

function pageOf(tag, title, sound, result, vendor) {
  const { parts, positions, counts } = result;
  let n = 0;
  const body = parts.map((part, pi) => {
    const beats = part.beats.map((beat) => {
      const p = positions[beat.position];
      const moveNo = p.fen.split(' ')[5];
      const black = p.fen.split(' ')[1] === 'w';
      const made = beat.san
        ? `${black ? `${Number(moveNo) - 1}…` : `${moveNo}.`} ${beat.san}`
        : (beat.position === 0 ? 'Starting position' : 'A position set on the board');
      const sentences = beat.wordless
        ? '<p class="wordless">Nothing was said here. The move is shown, ' +
          'without a sentence.</p>'
        : beat.sentences.map((s) => {
          n++;
          const latin = latinOf(s.text);
          const weak = s.confidence < 0.6;
          return `<div class="sentence${weak ? ' weak' : ''}" data-start="${s.startMs}" ` +
              `data-end="${s.endMs}">
<div class="row">
<button class="play" type="button" aria-label="Play this sentence">▶ ${clock(s.startMs)}–${clock(s.endMs)}</button>
<span class="heard">heard${weak ? ' — the vendor was unsure' : ''}: ${esc(latin)}</span>
</div>
<textarea rows="2" data-heard="${esc(latin)}" aria-label="Sentence ${n}">${esc(latin)}</textarea>
</div>`;
        }).join('\n');
      return `<section class="beat${beat.wordless ? ' quiet' : ''}">
<div class="left">${boardSvg(p.fen, beat.marks, p.move)}
<p class="made">${esc(made)}</p>
<p class="marks">${esc(marksInWords(beat.marks))}</p></div>
<div class="right"><p class="when">from ${clock(beat.startMs)}</p>${sentences}</div>
</section>`;
    }).join('\n');
    return `<h2>Part ${pi + 1} <span>${part.beats.length} ` +
        `${part.beats.length === 1 ? 'beat' : 'beats'}</span></h2>\n${beats}`;
  }).join('\n');

  const rows = [
    ['Length', `${counts.audioSeconds.toFixed(0)} s`],
    ['Sentences heard', counts.sentences],
    ['Positions on the board', counts.positions],
    ['Parts', counts.parts],
    ['Beats', `${counts.beats}, of them ${counts.wordlessBeats} without a sentence`],
    ['Most beats on one position', counts.mostBeatsOnOnePosition],
    ['Sentences said across a move', counts.sentencesThatStraddleAMove],
    ['Longest caption', `${counts.longestCaptionLetters} letters ` +
        `(room for ${counts.captionRoomLetters})`],
    ['Positions only passed through', counts.positionsPassedThrough],
  ].map(([k, v]) => `<tr><th>${k}</th><td>${v}</td></tr>`).join('');

  return `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} — transcript against the board</title>
<style>
:root { --ink:#1d2329; --soft:#5b6670; --line:#d5dae0; --paper:#fbfaf7;
  --card:#ffffff; --accent:#1f5f8b; --warn:#8a5a00; --warnbg:#fff6df; }
* { box-sizing: border-box; }
body { margin:0; background:var(--paper); color:var(--ink);
  font:16px/1.5 "Segoe UI", system-ui, sans-serif; }
main { max-width: 980px; margin: 0 auto; padding: 24px 16px 120px; }
h1 { font-size: 26px; margin: 0 0 4px; }
.lead { color: var(--soft); margin: 0 0 16px; }
h2 { font-size: 18px; margin: 32px 0 8px; padding-top: 12px;
  border-top: 2px solid var(--ink); }
h2 span { font-weight: 400; color: var(--soft); font-size: 14px; margin-left: 8px; }
table { border-collapse: collapse; margin: 8px 0 8px; font-size: 14px; }
th { text-align: left; font-weight: 400; color: var(--soft); padding: 2px 16px 2px 0; }
td { font-weight: 600; }
.beat { display: flex; gap: 16px; background: var(--card);
  border: 1px solid var(--line); border-radius: 8px; padding: 12px;
  margin: 10px 0; }
.beat.quiet { background: transparent; border-style: dashed; }
.left { width: 200px; flex: none; }
.right { flex: 1; min-width: 0; }
.board { width: 200px; height: 200px; display: block; border: 1px solid #555; }
.light { fill: #efe6d2; } .dark { fill: #a9875f; }
.last { stroke: #111; stroke-width: 2; stroke-dasharray: 4 3; }
.piece { font-size: 24px; text-anchor: middle; fill: #111; }
.mark { fill: none; stroke-width: 3; }
.arrow { stroke-width: 4; stroke-linecap: round; opacity: .9; }
.made { margin: 6px 0 0; font-weight: 600; }
.marks, .when { margin: 0; font-size: 13px; color: var(--soft); }
.sentence { margin: 8px 0 12px; }
.row { display: flex; gap: 8px; align-items: baseline; flex-wrap: wrap; }
.heard { font-size: 13px; color: var(--soft); }
.sentence.weak .heard { color: var(--warn); }
.sentence.weak textarea { background: var(--warnbg); border-color: var(--warn); }
.play { font: inherit; font-size: 13px; padding: 2px 8px; border: 1px solid var(--accent);
  border-radius: 4px; background: #fff; color: var(--accent); cursor: pointer; }
.play.on { background: var(--accent); color: #fff; }
textarea { width: 100%; font: inherit; padding: 6px 8px; border: 1px solid var(--line);
  border-radius: 6px; resize: vertical; margin-top: 4px; }
textarea.changed { border-color: var(--accent); border-width: 2px; }
.wordless { margin: 8px 0; color: var(--soft); font-style: italic; }
.bar { position: fixed; left: 0; right: 0; bottom: 0; background: var(--card);
  border-top: 1px solid var(--line); padding: 8px 16px; }
.bar div { max-width: 980px; margin: 0 auto; display: flex; gap: 12px;
  align-items: center; flex-wrap: wrap; }
.bar audio { flex: 1; min-width: 200px; height: 36px; }
.bar button { font: inherit; padding: 6px 14px; border-radius: 6px;
  border: 1px solid var(--ink); background: var(--ink); color: #fff; cursor: pointer; }
#state { font-size: 13px; color: var(--soft); }
@media (max-width: 640px) { .beat { flex-direction: column; } }
</style></head><body><main>
<h1>${esc(title)}</h1>
<p class="lead">What ${esc(vendor)} heard, laid against the board as the rules of the
plan cut it. Each box is one beat of the future tutorial: a position, the marks
standing on it, and what is said over it. Press ▶ to hear a sentence, and
write over it what you actually said.</p>
<table>${rows}</table>
${body}
</main>
<div class="bar"><div>
<audio id="sound" controls preload="metadata" src="${esc(sound)}"></audio>
<span id="state">0 of ${n} sentences changed</span>
<button id="save" type="button">Save corrections</button>
</div></div>
<script>
const sound = document.getElementById('sound');
let stopAt = null, playing = null;
sound.addEventListener('timeupdate', () => {
  if (stopAt !== null && sound.currentTime * 1000 >= stopAt) {
    sound.pause(); stopAt = null;
    if (playing) playing.classList.remove('on');
  }
});
for (const box of document.querySelectorAll('.sentence')) {
  const button = box.querySelector('.play');
  button.addEventListener('click', () => {
    if (playing) playing.classList.remove('on');
    playing = button; button.classList.add('on');
    // A little before and after: a vendor's first and last word are tight.
    sound.currentTime = Math.max(0, (Number(box.dataset.start) - 300) / 1000);
    stopAt = Number(box.dataset.end) + 300;
    sound.play();
  });
  const area = box.querySelector('textarea');
  area.addEventListener('input', () => {
    area.classList.toggle('changed', area.value !== area.dataset.heard);
    const all = document.querySelectorAll('textarea.changed').length;
    document.getElementById('state').textContent =
        all + ' of ${n} sentences changed';
  });
}
document.getElementById('save').addEventListener('click', () => {
  const out = [...document.querySelectorAll('.sentence')].map((box) => {
    const area = box.querySelector('textarea');
    return { startMs: Number(box.dataset.start), endMs: Number(box.dataset.end),
      heard: area.dataset.heard, said: area.value };
  });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(new Blob(
      [JSON.stringify({ recording: ${JSON.stringify(tag)}, sentences: out }, null, 1)],
      { type: 'application/json' }));
  link.download = ${JSON.stringify(tag)} + '.corrected.json';
  link.click();
});
</script></body></html>
`;
}

// -------------------------------------------------------------------- main

function main() {
  const timeline = arg('timeline');
  const answerFile = arg('answer');
  const tag = arg('tag');
  if (!timeline || !answerFile || !tag) {
    console.error('usage: node tools/stt_measure/beats.js --timeline <file> ' +
        '--answer <file> --tag <name> [--sound <file>] [--title <text>] ' +
        '[--vendor <name>] [--rule end|most] [--grace <ms>]');
    process.exit(2);
  }
  const events = JSON.parse(fs.readFileSync(timeline, 'utf8'));
  const answer = JSON.parse(fs.readFileSync(answerFile, 'utf8'));
  const result = beatsOf(events, answer,
      { rule: arg('rule', 'end'), graceMs: Number(arg('grace', '0')) });

  const outDir = path.join(__dirname, 'out');
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, `${tag}.beats.json`), JSON.stringify({
    counts: result.counts,
    parts: result.parts.map((part) => part.beats.map((b) => ({
      position: b.position,
      fen: result.positions[b.position].fen,
      move: b.san,
      startMs: b.startMs,
      marks: b.marks,
      sentences: b.sentences.map((s) => latinOf(s.text)),
    }))),
  }, null, 1));
  const sound = arg('sound');
  fs.writeFileSync(path.join(outDir, `${tag}.html`), pageOf(
      tag, arg('title', tag),
      sound ? `file:///${path.resolve(sound).replace(/\\/g, '/')}` : '',
      result, arg('vendor', 'the vendor')));
  console.log(JSON.stringify(result.counts, null, 1));
}

if (require.main === module) main();

module.exports = { latinOf, sentencesOf, moveBetween, positionsOf, beatsOf };
