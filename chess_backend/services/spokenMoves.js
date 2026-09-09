// spokenMoves.js — a move written on the board's terms, said in the voice's.
//
// **This is the five-language sibling of `chess_app/lib/core/services/
// speech_text.dart`, and that file is the original.** The app has read moves
// aloud correctly since long before the film could speak; the server was the
// half that had never been taught. So the rules here are that file's rules —
// its pattern, its word order, its reasons — with the vocabulary in five
// languages instead of one, because the film's voice can be German, Spanish,
// Italian or French. English is pinned to the app's own wording, verbatim, so
// a trainer who hears a tutorial in the app and then watches the film hears the
// same sentence twice. Change one of the two files and change the other.
//
// The measurement that started it, taken with piper's own phonemiser on
// 9.9.2026 — which is what piper hands the text to:
//
//   en-US   Bd5 → „bee dee five"        O-O → „oh oh"
//   de      Bd5 → „beh deh fünf"        O-O → „oh oh"
//   es      Bd5 → „be de cinco"         O-O → „o o"
//   it      Bd5 → „bi di cinque"        O-O → „o o"
//   fr      Bd5 → „boulevard cinq"      O-O → „o o"
//
// The French one is the whole argument in one line: espeak knows `Bd` as the
// abbreviation for *boulevard*, so a bishop move became a street. A `+` came
// out as „plus" and a `#` as „hash". None of that is a bad model — the text is
// simply not language, and a phonemiser can only guess.
//
// **Only what is spoken changes.** The caption drawn on the film is the
// trainer's own text, so the screen still reads „Bd5" while the voice says
// „bishop d five", which is what a trainer at a board does. Nothing here is
// written back into an event, a lesson or a PGN.
//
// **The notation read is English SAN**, because that is what this app writes
// and what the PGN standard stores. A German trainer writing „Ld5" is not
// recognised and is left alone; a German *voice* reading „Bd5" says „Läufer d
// fünf". The language of the voice decides the words, not the language of the
// notation.

/// The words one language uses to read a move out loud.
///
/// Two of these carry a reason from the app's file rather than a preference.
///
/// **A rank is a word, not a digit.** The digit was left to the voice at first,
/// on the reasoning that it reads numbers in its own language anyway — and it
/// does, except that a digit followed by a full stop reads as an *ordinal* in
/// more than one language, so a move at the end of a sentence came out as „e
/// sixth". A word cannot be read as an ordinal, which ends the question rather
/// than working around it.
///
/// **A file is a bare letter.** A one-letter token is read from the voice's own
/// letter-name table, which is exactly what a player says. Spelling it out is
/// what caused the trouble in the app's Serbian build — written „ge", the
/// g-file went through an English table and came out as „dzh".
const VOCABULARIES = {
  // Verbatim from `englishSpeech` in speech_text.dart. Do not retune one side.
  en: {
    pieces: { K: 'king', Q: 'queen', R: 'rook', B: 'bishop', N: 'knight' },
    ranks: ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight'],
    pawn: 'pawn',
    captures: 'takes',
    from: 'from',
    to: 'to',
    promotesTo: 'promotes to',
    check: 'check',
    mate: 'mate',
    shortCastle: 'castles kingside',
    longCastle: 'castles queenside',
  },
  de: {
    pieces: { K: 'König', Q: 'Dame', R: 'Turm', B: 'Läufer', N: 'Springer' },
    ranks: ['eins', 'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben', 'acht'],
    pawn: 'Bauer',
    captures: 'schlägt',
    from: 'von',
    to: 'nach',
    promotesTo: 'Umwandlung in',
    check: 'Schach',
    mate: 'schachmatt',
    shortCastle: 'kurze Rochade',
    longCastle: 'lange Rochade',
  },
  es: {
    pieces: { K: 'rey', Q: 'dama', R: 'torre', B: 'alfil', N: 'caballo' },
    ranks: ['uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho'],
    pawn: 'peón',
    captures: 'toma',
    from: 'desde',
    to: 'a',
    promotesTo: 'corona',
    check: 'jaque',
    mate: 'jaque mate',
    shortCastle: 'enroque corto',
    longCastle: 'enroque largo',
  },
  it: {
    pieces: { K: 're', Q: 'donna', R: 'torre', B: 'alfiere', N: 'cavallo' },
    ranks: ['uno', 'due', 'tre', 'quattro', 'cinque', 'sei', 'sette', 'otto'],
    pawn: 'pedone',
    captures: 'prende',
    from: 'da',
    to: 'a',
    promotesTo: 'promuove a',
    check: 'scacco',
    mate: 'scacco matto',
    shortCastle: 'arrocco corto',
    longCastle: 'arrocco lungo',
  },
  fr: {
    pieces: { K: 'roi', Q: 'dame', R: 'tour', B: 'fou', N: 'cavalier' },
    ranks: ['un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit'],
    pawn: 'pion',
    captures: 'prend',
    from: 'de',
    to: 'à',
    promotesTo: 'promotion en',
    check: 'échec',
    mate: 'échec et mat',
    shortCastle: 'petit roque',
    longCastle: 'grand roque',
  },
};

/// „de_DE-thorsten-medium", „de-DE" and „de" all mean German.
///
/// The voice id is what the app sends and it already carries the language, so
/// nothing new travels on the wire for this. A language with no vocabulary
/// falls back to English rather than to notation, because „bishop d five" in
/// the wrong accent is still a move and „boulevard cinq" is not.
function languageOf(voiceOrTag) {
  const first = String(voiceOrTag || '').toLowerCase().match(/^[a-z]+/);
  const key = first ? first[0] : '';
  return VOCABULARIES[key] ? key : 'en';
}

/// A move in algebraic notation, wherever it sits inside a sentence.
///
/// Anchored on a destination square, because that is the one part every move
/// has. Nothing in prose matches it by accident: the pattern needs a letter a–h
/// followed by a digit, and words do not carry digits.
const MOVE = new RegExp(
  '\\b(?:O-O-O|0-0-0|O-O|0-0'
  + '|([KQRBN])?([a-h])?([1-8])?(x)?([a-h])([1-8])(?:=([QRBN]))?([+#])?)',
  'g',
);

/// Reads one matched move out loud. The app's `_sayMove`, word for word.
function sayMove(match, v) {
  const [whole, piece, fromFile, fromRank, capture, file, rank, promotion, suffix] = match;
  if (whole === 'O-O' || whole === '0-0') return v.shortCastle;
  if (whole === 'O-O-O' || whole === '0-0-0') return v.longCastle;

  const rankWord = (digit) => v.ranks[Number(digit) - 1];
  const words = [];
  if (piece) {
    words.push(v.pieces[piece]);
  } else if (capture) {
    // `exd5` — the pawn is named because „e takes d five" on its own sounds
    // like a piece whose name was swallowed.
    words.push(v.pawn);
  }

  // A disambiguated move is the one place where the square in front matters,
  // and running the two squares together („knight b d seven") is exactly the
  // ambiguity the notation was disambiguating.
  const origin = [fromFile || '', fromRank ? rankWord(fromRank) : ''].filter(Boolean).join(' ');
  if (origin) {
    words.push(!piece && capture ? v.from : `${v.from} ${origin}`);
    if (!piece && capture) words.push(origin);
  }

  if (capture) {
    words.push(v.captures);
  } else if (origin) {
    words.push(v.to);
  }

  words.push(`${file} ${rankWord(rank)}`);

  if (promotion) words.push(`${v.promotesTo} ${v.pieces[promotion]}`);
  if (suffix === '+') words.push(`, ${v.check}`);
  else if (suffix === '#') words.push(`, ${v.mate}`);

  // The comma before check is punctuation, not a word, so it must not arrive
  // with a space in front of it.
  return words.join(' ').replace(/ ,/g, ',');
}

/// Typography a voice reads aloud as itself unless it goes.
///
/// Quotation marks are the loud one: several voices announce them, so a
/// sentence quoting a button name gets „quote" twice. The dashes become commas
/// rather than nothing, because they are doing a comma's work.
function plainPunctuation(text) {
  return text
    .replace(/[„”“"»«]/g, '')
    .replace(/\*\*/g, '')
    .replace(/…/g, ',')
    .replace(/ [—–] /g, ', ')
    .replace(/[—–]/g, ',');
}

/// A full stop straight after a digit, where it would be read as an ordinal.
///
/// „Found 3 of 12." comes out as „twelfth" in more than one language. Where the
/// stop belongs to the number itself — „See 3. diagram" — it has to stay, and
/// the two are told apart by what follows: a stop that ends a sentence is
/// followed by a capital or by nothing at all.
function noOrdinalStops(text) {
  return text.replace(/(\d)\.(\s+(?=[A-ZČĆŠĐŽÄÖÜÉÈÀÁÍÓÚÑ])|$)/g, (m, digit, tail) => `${digit}${tail}`);
}

/// [text] with every move in it written out in the language of [voice].
///
/// Called on its way to the voice and nowhere else. A text with no notation in
/// it comes back with only its typography tidied, which is the ordinary case:
/// most sentences a trainer writes name no move at all.
function spokenMoves(text, voice) {
  const source = String(text || '');
  if (!source) return source;
  const v = VOCABULARIES[languageOf(voice)];
  // Order matters: the moves go first, so that by the time the ordinal rule
  // runs there is no digit left in `e6.` for it to act on and the sentence
  // keeps its full stop. What is left for that rule is the numbers that really
  // are numbers — a rating, a count — where the stop has to go.
  return noOrdinalStops(
    plainPunctuation(source).replace(MOVE, (...match) => sayMove(match, v)),
  )
    .replace(/\s+/g, ' ')
    .trim();
}

module.exports = { spokenMoves, languageOf, VOCABULARIES };
