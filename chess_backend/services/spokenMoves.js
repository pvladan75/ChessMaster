// spokenMoves.js — a move written on the board's terms, said in the voice's.
//
// „Bd5" is notation, not a word, and every voice spells it out. Measured with
// piper's own phonemiser on 9.9.2026, which is what piper hands the text to:
//
//   en-US   Bd5 → „bee dee five"        O-O → „oh oh"
//   de      Bd5 → „beh deh fünf"        O-O → „oh oh"
//   es      Bd5 → „be de cinco"         O-O → „o o"
//   it      Bd5 → „bi di cinque"        O-O → „o o"
//   fr      Bd5 → „boulevard cinq"      O-O → „o o"
//
// The French one is the whole argument in one line: espeak knows `Bd` as the
// abbreviation for *boulevard*, so a bishop move becomes a street. A `+` comes
// out as „plus" and a `#` as „hash". None of this is a bad model — the text is
// simply not language, and a phonemiser can only guess.
//
// **Only what is spoken changes.** The caption drawn on the film is the
// trainer's own text, so the screen still reads „Bd5" while the voice says
// „bishop d 5" — which is exactly what a trainer at a board does. Nothing here
// is written back into an event, a lesson or a PGN.
//
// **The notation read is English SAN**, because that is what this app writes
// and what the PGN standard stores. A German trainer writing „Ld5" is not
// recognised and is left alone; a German *voice* reading „Bd5" says „Läufer d
// 5". The language of the voice decides the words, not the language of the
// notation.
//
// **Squares are not translated**, only separated: „d5" is said as „d 5", so
// each voice reads the file as its own letter and the rank as its own number.
// That is the one part of a move that already works in every language.

/// What a move is called, per language.
///
/// The five here are the languages a voice is installed for (`deploy/
/// provision.sh`): English, German, Spanish, Italian, French. A language with
/// no entry falls back to English rather than to notation, because „bishop d 5"
/// in an English accent is still a move and „boulevard cinq" is not.
const VOCABULARIES = {
  en: {
    K: 'king', Q: 'queen', R: 'rook', B: 'bishop', N: 'knight',
    takes: 'takes',
    check: 'check',
    mate: 'checkmate',
    shortCastle: 'castles kingside',
    longCastle: 'castles queenside',
    promotes: 'promotes to',
  },
  de: {
    K: 'König', Q: 'Dame', R: 'Turm', B: 'Läufer', N: 'Springer',
    takes: 'schlägt',
    check: 'Schach',
    mate: 'schachmatt',
    shortCastle: 'kurze Rochade',
    longCastle: 'lange Rochade',
    promotes: 'Umwandlung in',
  },
  es: {
    K: 'rey', Q: 'dama', R: 'torre', B: 'alfil', N: 'caballo',
    takes: 'toma',
    check: 'jaque',
    mate: 'jaque mate',
    shortCastle: 'enroque corto',
    longCastle: 'enroque largo',
    promotes: 'corona',
  },
  it: {
    K: 're', Q: 'donna', R: 'torre', B: 'alfiere', N: 'cavallo',
    takes: 'prende',
    check: 'scacco',
    mate: 'scacco matto',
    shortCastle: 'arrocco corto',
    longCastle: 'arrocco lungo',
    promotes: 'promuove a',
  },
  fr: {
    K: 'roi', Q: 'dame', R: 'tour', B: 'fou', N: 'cavalier',
    takes: 'prend',
    check: 'échec',
    mate: 'échec et mat',
    shortCastle: 'petit roque',
    longCastle: 'grand roque',
    promotes: 'promotion en',
  },
};

/// „de_DE-thorsten-medium", „de-DE" and „de" all mean German.
///
/// The voice id is what the app sends, and it already carries the language —
/// so nothing new travels on the wire for this.
function languageOf(voiceOrTag) {
  const first = String(voiceOrTag || '').toLowerCase().match(/^[a-z]+/);
  const key = first ? first[0] : '';
  return VOCABULARIES[key] ? key : 'en';
}

/// A square as two things to read: the file, then the rank.
function square(file, rank) {
  return `${file} ${rank}`;
}

/// One token, expanded if it is a move and returned untouched if it is not.
///
/// The pattern is deliberately strict, because everything it matches is
/// rewritten inside a trainer's sentence:
///
/// - a token with **no piece letter and no `x`** must be a bare square (`d5`),
///   which is also how a trainer names a square in prose — and „look at d 5" is
///   what they would say out loud anyway;
/// - a from-file with no piece letter is only legal in a capture (`exd5`), so
///   it is required to carry the `x`. Without that rule a word like „be4"
///   would read as a move;
/// - a from-rank with no piece letter is not SAN at all.
///
/// Nothing that fails these is touched. A token this cannot read is left for
/// the voice to do what it always did.
function spokenToken(token, words) {
  if (/^(?:O-O-O|0-0-0)[+#]?$/.test(token)) {
    return withSuffix(words.longCastle, token.slice(-1), words);
  }
  if (/^(?:O-O|0-0)[+#]?$/.test(token)) {
    return withSuffix(words.shortCastle, token.slice(-1), words);
  }

  const move = /^([KQRBN])?([a-h])?([1-8])?(x?)([a-h])([1-8])(?:=([QRBN]))?([+#]?)$/.exec(token);
  if (!move) return null;
  const [, piece, fromFile, fromRank, takes, file, rank, promotion, suffix] = move;
  if (!piece && fromRank) return null;
  if (!piece && fromFile && !takes) return null;

  const said = [];
  if (piece) said.push(words[piece]);
  if (fromFile) said.push(fromFile);
  if (fromRank) said.push(fromRank);
  if (takes) said.push(words.takes);
  said.push(square(file, rank));
  if (promotion) said.push(words.promotes, words[promotion]);
  return withSuffix(said.join(' '), suffix, words);
}

function withSuffix(said, suffix, words) {
  if (suffix === '+') return `${said} ${words.check}`;
  if (suffix === '#') return `${said} ${words.mate}`;
  return said;
}

/// [text] with every move in it written out in the language of [voice].
///
/// Called on its way to the voice and nowhere else. A text with no notation in
/// it comes back character for character, which is the ordinary case: most
/// sentences a trainer writes name no move at all.
function spokenMoves(text, voice) {
  const source = String(text || '');
  if (!source) return source;
  const words = VOCABULARIES[languageOf(voice)];
  // Tokens are runs of the characters notation is made of. A hyphen is in
  // there for `O-O`, which also means „well-known" arrives as one token — and
  // one token that is not a move, which is the answer we want.
  return source.replace(/[A-Za-z0-9=+#-]+/g, (token) => {
    const said = spokenToken(token, words);
    return said === null ? token : said;
  });
}

module.exports = { spokenMoves, languageOf, VOCABULARIES };
