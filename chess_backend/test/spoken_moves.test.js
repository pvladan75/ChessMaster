// spoken_moves.test.js — a move is said, not spelled.
//
// „Vidi da li se potezi navedeni u komentaru (recimo Bd5) izgovaraju dobro na
// drugim jezicima." They were not being said well in any language, English
// included. Measured with piper's own phonemiser, which is what the text is
// handed to:
//
//   en-US  Bd5 → „bee dee five"      de  Bd5 → „beh deh fünf"
//   es     Bd5 → „be de cinco"       it  Bd5 → „bi di cinque"
//   fr     Bd5 → „boulevard cinq"    and O-O → „oh oh" everywhere
//
// The French one is the argument in one line: espeak knows `Bd` as the
// abbreviation for *boulevard*.
const test = require('node:test');
const assert = require('node:assert/strict');

const { spokenMoves, languageOf } = require('../services/spokenMoves');
const tts = require('../services/tts');
const { narrateFilm } = require('../services/tutorialNarration');

test('a move is expanded into the words of the voice speaking it', () => {
  assert.equal(spokenMoves('Bd5', 'en_US-lessac-medium'), 'bishop d 5');
  assert.equal(spokenMoves('Bd5', 'de_DE-thorsten-medium'), 'Läufer d 5');
  assert.equal(spokenMoves('Bd5', 'es_ES-davefx-medium'), 'alfil d 5');
  assert.equal(spokenMoves('Bd5', 'it_IT-serena-medium'), 'alfiere d 5');
  assert.equal(spokenMoves('Bd5', 'fr_FR-siwis-medium'), 'fou d 5');

  // The square is separated rather than translated: each voice then reads the
  // file as its own letter and the rank as its own number, which is the one
  // part of a move that already worked everywhere.
  assert.equal(spokenMoves('d5', 'en'), 'd 5');
});

test('the whole of the notation is read, not only the piece', () => {
  assert.equal(spokenMoves('Nxe5+', 'en'), 'knight takes e 5 check');
  assert.equal(spokenMoves('Qxf7#', 'en'), 'queen takes f 7 checkmate');
  assert.equal(spokenMoves('exd5', 'en'), 'e takes d 5');
  assert.equal(spokenMoves('e8=Q', 'en'), 'e 8 promotes to queen');
  assert.equal(spokenMoves('e8=Q#', 'en'), 'e 8 promotes to queen checkmate');
  assert.equal(spokenMoves('Rae1', 'en'), 'rook a e 1');
  assert.equal(spokenMoves('R1e2', 'en'), 'rook 1 e 2');

  // A `+` came out as „plus" and a `#` as „hash"; castling as „oh oh".
  assert.equal(spokenMoves('O-O', 'en'), 'castles kingside');
  assert.equal(spokenMoves('O-O-O', 'en'), 'castles queenside');
  assert.equal(spokenMoves('0-0', 'de'), 'kurze Rochade');
  assert.equal(spokenMoves('O-O-O+', 'fr'), 'grand roque échec');
});

test('a move inside a sentence is expanded and the sentence is not', () => {
  assert.equal(
    spokenMoves('Look at d5 — the square White wants.', 'en'),
    'Look at d 5 — the square White wants.',
  );
  assert.equal(
    spokenMoves('After Bd5! Black is lost.', 'en'),
    'After bishop d 5! Black is lost.',
  );
});

test('what is not notation is left for the voice to read as it always did', () => {
  // Everything this matches is rewritten inside a trainer's sentence, so the
  // pattern is strict on purpose. A from-file with no piece letter is only
  // legal in a capture, which is what keeps a word out of the net.
  for (const text of [
    'The bishop is strong.',
    'well-known',
    'Do not play be4 or ba5 here.',
    'Chapter 12 covers this.',
    'The score was 1-0.',
    'B',
    'd',
  ]) {
    assert.equal(spokenMoves(text, 'en'), text, `left alone: ${text}`);
  }

  // German notation is not read: this app writes English SAN and the PGN
  // standard stores it, so „Ld5" is a trainer's own spelling and stays theirs.
  assert.equal(spokenMoves('Ld5', 'de'), 'Ld5');
});

test('an unknown language is spoken in English rather than in notation', () => {
  // „bishop d 5" in the wrong accent is still a move; „boulevard cinq" is not.
  assert.equal(languageOf('sr_RS-serbski_institut-medium'), 'en');
  assert.equal(spokenMoves('Bd5', 'sr_RS-serbski_institut-medium'), 'bishop d 5');
  assert.equal(spokenMoves('Bd5', null), 'bishop d 5');
  assert.equal(spokenMoves('Bd5', ''), 'bishop d 5');
});

test('a voice id, a language tag and a bare language all name one language', () => {
  for (const named of ['de_DE-thorsten-medium', 'de-DE', 'de', 'DE']) {
    assert.equal(languageOf(named), 'de', named);
  }
});

test('nothing at all is nothing at all', () => {
  assert.equal(spokenMoves('', 'en'), '');
  assert.equal(spokenMoves(null, 'en'), '');
  assert.equal(spokenMoves(undefined, 'en'), '');
});

test('the voice is given the words and the film keeps the trainer\'s text', async () => {
  // The one thing that must not happen is the caption changing: the screen
  // shows what the trainer wrote and the voice says what a trainer would say.
  const events = [
    { timestampMs: 0, eventType: 'init', data: { fen: 'x', text: 'Play Bd5 here.' } },
    { timestampMs: 2000, eventType: 'move', data: { fen: 'y', text: 'Then O-O.' } },
  ];

  const originalAvailable = tts.narrationAvailable;
  const originalSpeak = tts.speakBeats;
  const spoken = [];
  tts.narrationAvailable = () => true;
  tts.speakBeats = async (texts) => {
    spoken.push(...texts);
    // No audio: `narrateFilm` then returns the silent film untouched, which is
    // all this test needs — it is about what the voice was asked to say.
    return texts.map(() => ({ clipSeconds: null }));
  };

  try {
    const film = await narrateFilm({
      events,
      voice: 'de_DE-thorsten-medium',
      exportsDir: 'unused',
      filename: 'unused',
    });
    assert.deepEqual(spoken, ['Play Läufer d 5 here.', 'Then kurze Rochade.']);
    assert.equal(film.events[0].data.text, 'Play Bd5 here.',
      'the caption on the film is the trainer\'s own text');
    assert.equal(film.events[1].data.text, 'Then O-O.');
  } finally {
    tts.narrationAvailable = originalAvailable;
    tts.speakBeats = originalSpeak;
  }
});
