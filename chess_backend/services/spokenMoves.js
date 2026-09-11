// spokenMoves.js — a move written on the board's terms, said in the voice's.
//
// **This is the six-language sibling of `chess_app/lib/core/services/
// speech_text.dart`, and that file is the original.** The app has read moves
// aloud correctly since long before the film could speak; the server was the
// half that had never been taught. So the rules here are that file's rules —
// its pattern, its word order, its reasons — with the vocabulary in six
// languages instead of one, because the film's voice can be German, Spanish,
// Italian, French or (since Azure, 11.9.2026) Serbian. English is pinned to the
// app's own wording, verbatim, so a trainer who hears a tutorial in the app and
// then watches the film hears the same sentence twice. Change one of the two
// files and change the other.
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
// Serbian was added on 11.9.2026 with the Azure provider, and its words are the
// app's own from before the English pivot rather than a fresh translation.
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
/// **A file is a bare letter, unless the language says otherwise.** A
/// one-letter token is read from the voice's own letter-name table, which in
/// English is exactly what a player says: ay, bee, see, dee.
///
/// It is not what a Serbian voice does. Reported live on 11.9.2026 against an
/// Azure `sr-Latn-RS` voice: „Bc4" came out with the `c` almost inaudible,
/// because a lone consonant letter is a sound and not a word. The Serbian
/// vocabularies spell the consonants — be, ce, de, ef, ge, ha — which is what a
/// trainer at a board says.
///
/// **This is the same question that once had the opposite answer, and both
/// answers were right.** The app's Serbian build had „ge" read by an *English*
/// letter table and come out as „dzh", so the rule then became „never spell a
/// file". What that fault was really about is a voice reading a language that
/// is not its own; with a Serbian voice reading Serbian, spelling it is
/// correct. So the table belongs to the language, not to the code — `files` is
/// absent from the four vocabularies whose voices already say the letter
/// properly, and present where they do not.
const VOCABULARIES = {
  // Verbatim from `serbianSpeech` as it stood in `speech_text.dart` before the
  // English pivot deleted it — commit `ce012c0^`, and it was read aloud by
  // trainers for weeks before that. **Recovered rather than written**: this
  // repository has three cases on record of a second implementation being
  // written because nobody looked for the first, and one of them was better
  // than what replaced it.
  //
  // Here for Azure, which unlike piper and Google may offer a Serbian voice
  // (`sr-Latn-RS-…`); `languageOf` reads the `sr` off the front either way. The
  // ranks are words for the same reason as everywhere else, and the files stay
  // bare letters because that is what fixed „dž" for the g-file in the app's
  // own Serbian build.
  sr: {
    pieces: { K: 'kralj', Q: 'dama', R: 'top', B: 'lovac', N: 'skakač' },
    // The consonants are words and the vowels are themselves. „a" and „e" are
    // whole sounds a voice already says; „c" alone is not, which is what was
    // reported.
    files: {
      a: 'a', b: 'be', c: 'ce', d: 'de', e: 'e', f: 'ef', g: 'ge', h: 'ha',
    },
    ranks: ['jedan', 'dva', 'tri', 'četiri', 'pet', 'šest', 'sedam', 'osam'],
    pawn: 'pešak',
    captures: 'uzima',
    from: 'sa',
    to: 'na',
    promotesTo: 'postaje',
    check: 'šah',
    mate: 'mat',
    shortCastle: 'mala rokada',
    longCastle: 'velika rokada',
  },
  // The same words in the other script, for a voice whose locale is written in
  // it — Azure's `sr-RS` is Serbian (Cyrillic) and its `sr-Latn-RS` twin is the
  // Latin one. A caption is still the trainer's own text in whatever script
  // they wrote it; only what is *added* on the way to the voice is written to
  // match the voice's own.
  'sr-cyrl': {
    pieces: { K: 'краљ', Q: 'дама', R: 'топ', B: 'ловац', N: 'скакач' },
    files: {
      a: 'а', b: 'бе', c: 'це', d: 'де', e: 'е', f: 'еф', g: 'ге', h: 'ха',
    },
    ranks: ['један', 'два', 'три', 'четири', 'пет', 'шест', 'седам', 'осам'],
    pawn: 'пешак',
    captures: 'узима',
    from: 'са',
    to: 'на',
    promotesTo: 'постаје',
    check: 'шах',
    mate: 'мат',
    shortCastle: 'мала рокада',
    longCastle: 'велика рокада',
  },
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
///
/// Serbian is the one language here with two scripts, and the id is what says
/// which: `sr-Latn-RS-…` is the Latin one and a plain `sr-RS-…` is Azure's
/// Cyrillic. piper's `sr_RS-…` lands on Cyrillic by the same rule — its Serbian
/// model is not installed (it was tried and rejected on 9.9.2026), so nothing
/// turns on it today.
function languageOf(voiceOrTag) {
  const named = String(voiceOrTag || '').toLowerCase();
  const first = named.match(/^[a-z]+/);
  const key = first ? first[0] : '';
  if (key === 'sr') return named.includes('latn') ? 'sr' : 'sr-cyrl';
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

/// The letter itself where the voice says it properly, and the language's own
/// name for it where it does not.
function fileWordIn(v, letter) {
  return v.files ? v.files[letter] || letter : letter;
}

/// Reads one matched move out loud. The app's `_sayMove`, word for word.
function sayMove(match, v) {
  const [whole, piece, fromFile, fromRank, capture, file, rank, promotion, suffix] = match;
  if (whole === 'O-O' || whole === '0-0') return v.shortCastle;
  if (whole === 'O-O-O' || whole === '0-0-0') return v.longCastle;

  const rankWord = (digit) => v.ranks[Number(digit) - 1];
  const fileWord = (letter) => fileWordIn(v, letter);
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
  const origin = [fromFile ? fileWord(fromFile) : '', fromRank ? rankWord(fromRank) : '']
    .filter(Boolean).join(' ');
  if (origin) {
    words.push(!piece && capture ? v.from : `${v.from} ${origin}`);
    if (!piece && capture) words.push(origin);
  }

  if (capture) {
    words.push(v.captures);
  } else if (origin) {
    words.push(v.to);
  }

  words.push(`${fileWord(file)} ${rankWord(rank)}`);

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

/// A file named by its letter and joined to a word: „h-linija", „c-pešak",
/// „the h-file". Reported live on 11.9.2026: the hyphen was read as „minus" and
/// the lone „h" not at all. The app's `_fileNames`, rule for rule — a letter
/// standing alone („Rh-faktor" is left as it is), and only before a letter.
const FILE_WITH_HYPHEN = /(?<![\p{L}\p{N}])([a-h])-(?=\p{L})/gu;

function fileNames(text, v) {
  return text.replace(FILE_WITH_HYPHEN, (m, letter) => `${fileWordIn(v, letter)} `);
}

/// A full stop straight after a digit, where it would be read as an ordinal.
///
/// „Found 3 of 12." comes out as „twelfth" in more than one language. Where the
/// stop belongs to the number itself — „See 3. diagram" — it has to stay, and
/// the two are told apart by what follows: a stop that ends a sentence is
/// followed by a capital or by nothing at all.
///
/// The capitals include Cyrillic (U+0400–U+042F, which holds Ђ Ј Љ Њ Ћ Џ as
/// well as А–Я), since a tutorial may now be written in Serbian Cyrillic. The
/// app's `_noOrdinalStops` carries the same class, and
/// `test/fixtures/spoken_moves_cases.json` holds the two to it.
function noOrdinalStops(text) {
  return text.replace(/(\d)\.(\s+(?=[A-ZČĆŠĐŽÄÖÜÉÈÀÁÍÓÚÑ\u0400-\u042F])|$)/g, (m, digit, tail) => `${digit}${tail}`);
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
  return noOrdinalStops(fileNames(
    plainPunctuation(source).replace(MOVE, (...match) => sayMove(match, v)),
    v,
  ))
    .replace(/\s+/g, ' ')
    .trim();
}

/// What a voice says when a trainer asks to hear it.
///
/// **Every one of them carries a move**, because the notation is the whole
/// question: a voice that reads „Bc4" as „bee see four" is the wrong voice, and
/// that is inaudible in a sentence of prose. Short, because it is listened to
/// once per voice and a trainer auditioning six of them is waiting six times.
///
/// The move stays English SAN in every language, exactly as it does in a
/// tutorial: this app writes SAN and the PGN standard stores it.
const SAMPLES = {
  en: 'Play Bc4. This is how your video will sound.',
  sr: 'Odigraj Bc4. Ovako će zvučati tvoj video.',
  'sr-cyrl': 'Одиграј Bc4. Овако ће звучати твој видео.',
  de: 'Spiele Bc4. So wird dein Video klingen.',
  es: 'Juega Bc4. Así sonará tu vídeo.',
  it: 'Gioca Bc4. Ecco come suonerà il tuo video.',
  fr: 'Joue Bc4. Voilà comment ta vidéo va sonner.',
};

/// The sample sentence for [voice], already written out for the synthesiser.
///
/// Goes through `spokenMoves` like any other beat, so what a trainer hears is
/// the same treatment their tutorial will get — including the file letter that
/// started all this: „lovac ce četiri", not „lovac c četiri".
function sampleFor(voice) {
  const language = languageOf(voice);
  return spokenMoves(SAMPLES[language] || SAMPLES.en, voice);
}

module.exports = { spokenMoves, languageOf, sampleFor, VOCABULARIES, SAMPLES };
