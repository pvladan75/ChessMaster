// spoken_moves.test.js — a move is said, not spelled, and both ends say it the
// same way.
//
// „Vidi da li se potezi navedeni u komentaru (recimo Bd5) izgovaraju dobro na
// drugim jezicima." They were not being said well by the film's voice in any
// language, English included. Measured with piper's own phonemiser, which is
// what the text is handed to:
//
//   en-US  Bd5 → „bee dee five"      de  Bd5 → „beh deh fünf"
//   es     Bd5 → „be de cinco"       it  Bd5 → „bi di cinque"
//   fr     Bd5 → „boulevard cinq"    and O-O → „oh oh" everywhere
//
// The French one is the argument in one line: espeak knows `Bd` as the
// abbreviation for *boulevard*.
//
// **The app had solved this already** — `speakable` in `chess_app/lib/core/
// services/speech_text.dart`, pinned by `chess_app/test/speech_text_test.dart`
// — and the server was the half that had never been taught. So the first test
// below is the important one: it holds the two ends to one wording, by asserting
// on the app's own expected strings, copied from that file.
const test = require('node:test');
const assert = require('node:assert/strict');

const { spokenMoves, languageOf } = require('../services/spokenMoves');
const tts = require('../services/tts');
const { narrateFilm } = require('../services/tutorialNarration');

test('the film says in English exactly what the app says', () => {
  // Every one of these is an expectation copied from
  // `chess_app/test/speech_text_test.dart`. A trainer who hears a tutorial read
  // aloud in the app and then watches the film must hear the same sentence, and
  // two vocabularies drifting apart is what this repository has paid for before.
  const app = {
    'd4': 'd four',
    'Kf2': 'king f two',
    'Rd3': 'rook d three',
    'Rxd3': 'rook takes d three',
    'exd5': 'pawn from e takes d five',
    'Nbd7': 'knight from b to d seven',
    'R1e2': 'rook from one to e two',
    'Qg3+': 'queen g three, check',
    'Qf1#': 'queen f one, mate',
    'e8=Q': 'e eight promotes to queen',
    'a1=N+': 'a one promotes to knight, check',
    'O-O': 'castles kingside',
    'O-O-O': 'castles queenside',
    '0-0-0': 'castles queenside',
    'Be a good sport.': 'Be a good sport.',
    'A rating of 2400 is high': 'A rating of 2400 is high',
    'It played e6.': 'It played e six.',
    'It held with Kf2.': 'It held with king f two.',
    'Found 3 of 12.': 'Found 3 of 12',
    'A rating of 2400.': 'A rating of 2400',
    '1.e4': '1.e four',
    'Correct. Try another move.': 'Correct. Try another move.',
    'Checking the tablebases…': 'Checking the tablebases,',
    'First line\n  second line': 'First line second line',
  };
  for (const [written, said] of Object.entries(app)) {
    assert.equal(spokenMoves(written, 'en_US-lessac-medium'), said, JSON.stringify(written));
  }
});

test('a move is expanded into the words of the voice speaking it', () => {
  assert.equal(spokenMoves('Bd5', 'en_US-lessac-medium'), 'bishop d five');
  assert.equal(spokenMoves('Bd5', 'de_DE-thorsten-medium'), 'Läufer d fünf');
  assert.equal(spokenMoves('Bd5', 'es_ES-davefx-medium'), 'alfil d cinco');
  assert.equal(spokenMoves('Bd5', 'it_IT-serena-medium'), 'alfiere d cinque');
  assert.equal(spokenMoves('Bd5', 'fr_FR-siwis-medium'), 'fou d cinq');

  // The file stays a bare letter — every voice knows its own letter names, and
  // spelling one out is what made the app's g-file come out as „dzh". The rank
  // is a word, because a digit before a full stop is read as an ordinal.
  assert.equal(spokenMoves('d5', 'de'), 'd fünf');
  assert.equal(spokenMoves('d5', 'fr'), 'd cinq');
});

test('the whole of the notation is read, not only the piece', () => {
  assert.equal(spokenMoves('Nxe5+', 'de'), 'Springer schlägt e fünf, Schach');
  assert.equal(spokenMoves('Qxf7#', 'es'), 'dama toma f siete, jaque mate');
  assert.equal(spokenMoves('exd5', 'fr'), 'pion de e prend d cinq');
  assert.equal(spokenMoves('e8=Q', 'it'), 'e otto promuove a donna');

  // A `+` came out as „plus" and a `#` as „hash"; castling as „oh oh".
  assert.equal(spokenMoves('O-O', 'de'), 'kurze Rochade');
  assert.equal(spokenMoves('0-0', 'it'), 'arrocco corto');
  assert.equal(spokenMoves('O-O-O', 'fr'), 'grand roque');
});

test('a move inside a sentence is expanded and the sentence is not', () => {
  assert.equal(
    spokenMoves('Look at d5, the square White wants.', 'en'),
    'Look at d five, the square White wants.',
  );
  assert.equal(
    spokenMoves('Nach Bd5 steht Weiß besser.', 'de'),
    'Nach Läufer d fünf steht Weiß besser.',
  );
});

test('an unknown language is spoken in English rather than in notation', () => {
  // „bishop d five" in the wrong accent is still a move; „boulevard cinq" is not.
  //
  // Serbian stood here as the example of a language with no vocabulary until
  // 11.9.2026, when Azure brought one — see the two tests below. The claim is
  // unchanged and needed a language that really has none.
  assert.equal(languageOf('pl_PL-darkman-medium'), 'en');
  assert.equal(spokenMoves('Bd5', 'pl_PL-darkman-medium'), 'bishop d five');
  assert.equal(spokenMoves('Bd5', null), 'bishop d five');
  assert.equal(spokenMoves('Bd5', ''), 'bishop d five');
});

test('the film says in Serbian what the app said before the English pivot', () => {
  // The Serbian words are `serbianSpeech` as it stood in `speech_text.dart`
  // before the pivot deleted it (`ce012c0^`), not a fresh translation: trainers
  // listened to those exact words for weeks. The inputs are the English test's
  // inputs above, so the two vocabularies are held to one set of rules.
  const app = {
    'd4': 'd četiri',
    'Kf2': 'kralj f dva',
    'Rd3': 'top d tri',
    'Rxd3': 'top uzima d tri',
    'exd5': 'pešak sa e uzima d pet',
    'Nbd7': 'skakač sa b na d sedam',
    'R1e2': 'top sa jedan na e dva',
    'Qg3+': 'dama g tri, šah',
    'Qf1#': 'dama f jedan, mat',
    'e8=Q': 'e osam postaje dama',
    'a1=N+': 'a jedan postaje skakač, šah',
    'O-O': 'mala rokada',
    'O-O-O': 'velika rokada',
    '0-0-0': 'velika rokada',
    // The owner's own example when he asked for this.
    'Bd5': 'lovac d pet',
  };
  for (const [written, said] of Object.entries(app)) {
    assert.equal(spokenMoves(written, 'sr-Latn-RS-NicholasNeural'), said, JSON.stringify(written));
  }

  // A move inside a Serbian sentence, and the sentence untouched around it. The
  // piece keeps its dictionary form — „odigraj lovac d pet" rather than
  // „lovca" — which is what the app has always said and what a trainer already
  // knows the sound of. Grammar is a change to both files or to neither.
  assert.equal(
    spokenMoves('Odigraj Bd5, pa O-O.', 'sr-Latn-RS-SophieNeural'),
    'Odigraj lovac d pet, pa mala rokada.',
  );

  // The ordinal rule reads Serbian capitals too, so a sentence that ends on a
  // real number still loses its full stop while one that ends on a move keeps
  // it.
  assert.equal(spokenMoves('Pronađeno 3 od 12.', 'sr'), 'Pronađeno 3 od 12');
  assert.equal(spokenMoves('Odigrao je e6.', 'sr'), 'Odigrao je e šest.');
});

test('both spellings of a Serbian voice name find the Serbian words', () => {
  // Azure writes the locale with its script in the middle (`sr-Latn-RS-…`) and
  // piper writes `sr_RS-…`; the language is read off the front, so neither
  // needs a rule of its own.
  for (const named of ['sr-Latn-RS-NicholasNeural', 'sr_RS-serbski_institut-medium', 'sr-RS', 'sr']) {
    assert.equal(languageOf(named), 'sr', named);
  }
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

  // `narrateFilm` asks for the *reason* it cannot narrate rather than for a
  // boolean, so that „no voices installed" and „the engine will not start" can
  // be two sentences. Null is „nothing is in the way".
  const originalBlockedBy = tts.narrationBlockedBy;
  const originalSpeak = tts.speakBeats;
  const spoken = [];
  tts.narrationBlockedBy = async () => null;
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
    assert.deepEqual(spoken, ['Play Läufer d fünf here.', 'Then kurze Rochade.']);
    assert.equal(film.events[0].data.text, 'Play Bd5 here.',
      'the caption on the film is the trainer\'s own text');
    assert.equal(film.events[1].data.text, 'Then O-O.');
  } finally {
    tts.narrationBlockedBy = originalBlockedBy;
    tts.speakBeats = originalSpeak;
  }
});
