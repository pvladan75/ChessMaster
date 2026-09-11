/// Turns what the screen says into what a voice can say.
///
/// Written text and spoken text are not the same text, and chess is where they
/// come apart hardest: `Rd3` is read by every synthesiser as three characters,
/// which arrives as noise. The panel's sentences are already prose, so the work
/// here is narrow - find the moves inside them and spell them out the way a
/// person at the board would.
///
/// The tables are kept behind [SpeechVocabulary] rather than written into the
/// function. That was written when a second language was only planned; it
/// earned its keep when the app went English-only, because swapping the words
/// was the whole of the change. The rules of algebraic notation are the same in
/// every language; the names of the pieces are not.
library;

/// The words one language uses to read a move out loud.
class SpeechVocabulary {
  const SpeechVocabulary({
    required this.pieces,
    required this.files,
    required this.ranks,
    required this.pawn,
    required this.captures,
    required this.from,
    required this.to,
    required this.promotesTo,
    required this.check,
    required this.mate,
    required this.shortCastle,
    required this.longCastle,
  });

  /// Keyed by the letter used in English SAN, which is what the app stores.
  final Map<String, String> pieces;

  /// How a file is said.
  ///
  /// Instructions to a voice rather than spelling. For Serbian read by a
  /// Croatian voice they are the bare letters, which the voice already knows
  /// the names of - see the table below for why writing them out was worse.
  final Map<String, String> files;

  /// How a rank is said, as a word rather than a digit.
  ///
  /// The digit was left to the voice at first, on the reasoning that it reads
  /// numbers in its own language anyway. It does - but a digit followed by a
  /// full stop reads as an ordinal in more than one language, so a move at the
  /// end of a sentence came out as "e sixth" instead of "e six". A word cannot
  /// be read as an ordinal, which ends the question rather than working around
  /// it.
  final Map<String, String> ranks;

  final String pawn;
  final String captures;
  final String from;
  final String to;
  final String promotesTo;
  final String check;
  final String mate;
  final String shortCastle;
  final String longCastle;
}

const englishSpeech = SpeechVocabulary(
  pieces: {
    'K': 'king',
    'Q': 'queen',
    'R': 'rook',
    'B': 'bishop',
    'N': 'knight',
  },
  // One letter each, and nothing spelled out. A one-letter token is read from
  // the voice's own letter-name table, which in English gives exactly what a
  // player says: ay, bee, see, dee, ee, ef, gee, aitch.
  //
  // Spelling them out is what caused the trouble in the Serbian build - written
  // "ge", the g-file went through an English letter table and came out as "dzh"
  // - and writing them out here would reintroduce the same class of fault from
  // the other side.
  //
  // The map stays even though it is an identity, because it is the one place a
  // voice that reads bare letters by some other table gets its own spellings,
  // rather than a branch somewhere in the code.
  files: {
    'a': 'a',
    'b': 'b',
    'c': 'c',
    'd': 'd',
    'e': 'e',
    'f': 'f',
    'g': 'g',
    'h': 'h',
  },
  ranks: {
    '1': 'one',
    '2': 'two',
    '3': 'three',
    '4': 'four',
    '5': 'five',
    '6': 'six',
    '7': 'seven',
    '8': 'eight',
  },
  pawn: 'pawn',
  captures: 'takes',
  from: 'from',
  to: 'to',
  promotesTo: 'promotes to',
  check: 'check',
  mate: 'mate',
  shortCastle: 'castles kingside',
  longCastle: 'castles queenside',
);

// --- The six other languages a tutorial may be written in -------------------
//
// Phase 2 of `docs/PLAN-JEZIK-GLASA.md`. Ported word for word from
// `chess_backend/services/spokenMoves.js`, which was itself ported from this
// file — so this is the words coming home, not a third implementation. Both
// ends are judged by one file, `chess_backend/test/fixtures/
// spoken_moves_cases.json`; change a word here and it fails until the server
// says the same.

/// A bare letter, for the languages whose voices already say the letter's
/// name properly. The reason is on [englishSpeech.files].
const _bareFiles = {
  'a': 'a',
  'b': 'b',
  'c': 'c',
  'd': 'd',
  'e': 'e',
  'f': 'f',
  'g': 'g',
  'h': 'h',
};

/// Serbian, Latin script.
///
/// `serbianSpeech` as it stood before the English pivot deleted it
/// (`ce012c0^`), with one change made live on 11.9.2026 against a real Serbian
/// voice: the consonant files are **words** — be, ce, de, ef, ge, ha — because
/// „Bc4" came back with the `c` almost inaudible. A lone consonant is a sound,
/// not a word. The vowels stay themselves. What the old „dzh" fault on
/// [englishSpeech.files] was really about is a voice reading a language that is
/// not its own; a Serbian voice reading Serbian spells correctly.
///
/// Whether that is also right for Croatian `Matej` on Windows, which reads
/// this table when a device has no Serbian voice, is the live check in the
/// plan — it was proved on Azure, and a device voice is a different ear.
const serbianLatinSpeech = SpeechVocabulary(
  pieces: {
    'K': 'kralj',
    'Q': 'dama',
    'R': 'top',
    'B': 'lovac',
    'N': 'skakač',
  },
  files: {
    'a': 'a',
    'b': 'be',
    'c': 'ce',
    'd': 'de',
    'e': 'e',
    'f': 'ef',
    'g': 'ge',
    'h': 'ha',
  },
  ranks: {
    '1': 'jedan',
    '2': 'dva',
    '3': 'tri',
    '4': 'četiri',
    '5': 'pet',
    '6': 'šest',
    '7': 'sedam',
    '8': 'osam',
  },
  pawn: 'pešak',
  captures: 'uzima',
  from: 'sa',
  to: 'na',
  promotesTo: 'postaje',
  check: 'šah',
  mate: 'mat',
  shortCastle: 'mala rokada',
  longCastle: 'velika rokada',
);

/// Serbian, Cyrillic script: the same words, written as a Cyrillic tutorial's
/// voice reads them. What the trainer wrote is untouched; only what is added on
/// the way to the voice is in the voice's script.
const serbianCyrillicSpeech = SpeechVocabulary(
  pieces: {
    'K': 'краљ',
    'Q': 'дама',
    'R': 'топ',
    'B': 'ловац',
    'N': 'скакач',
  },
  files: {
    'a': 'а',
    'b': 'бе',
    'c': 'це',
    'd': 'де',
    'e': 'е',
    'f': 'еф',
    'g': 'ге',
    'h': 'ха',
  },
  ranks: {
    '1': 'један',
    '2': 'два',
    '3': 'три',
    '4': 'четири',
    '5': 'пет',
    '6': 'шест',
    '7': 'седам',
    '8': 'осам',
  },
  pawn: 'пешак',
  captures: 'узима',
  from: 'са',
  to: 'на',
  promotesTo: 'постаје',
  check: 'шах',
  mate: 'мат',
  shortCastle: 'мала рокада',
  longCastle: 'велика рокада',
);

const germanSpeech = SpeechVocabulary(
  pieces: {
    'K': 'König',
    'Q': 'Dame',
    'R': 'Turm',
    'B': 'Läufer',
    'N': 'Springer',
  },
  files: _bareFiles,
  ranks: {
    '1': 'eins',
    '2': 'zwei',
    '3': 'drei',
    '4': 'vier',
    '5': 'fünf',
    '6': 'sechs',
    '7': 'sieben',
    '8': 'acht',
  },
  pawn: 'Bauer',
  captures: 'schlägt',
  from: 'von',
  to: 'nach',
  promotesTo: 'Umwandlung in',
  check: 'Schach',
  mate: 'schachmatt',
  shortCastle: 'kurze Rochade',
  longCastle: 'lange Rochade',
);

const spanishSpeech = SpeechVocabulary(
  pieces: {
    'K': 'rey',
    'Q': 'dama',
    'R': 'torre',
    'B': 'alfil',
    'N': 'caballo',
  },
  files: _bareFiles,
  ranks: {
    '1': 'uno',
    '2': 'dos',
    '3': 'tres',
    '4': 'cuatro',
    '5': 'cinco',
    '6': 'seis',
    '7': 'siete',
    '8': 'ocho',
  },
  pawn: 'peón',
  captures: 'toma',
  from: 'desde',
  to: 'a',
  promotesTo: 'corona',
  check: 'jaque',
  mate: 'jaque mate',
  shortCastle: 'enroque corto',
  longCastle: 'enroque largo',
);

const italianSpeech = SpeechVocabulary(
  pieces: {
    'K': 're',
    'Q': 'donna',
    'R': 'torre',
    'B': 'alfiere',
    'N': 'cavallo',
  },
  files: _bareFiles,
  ranks: {
    '1': 'uno',
    '2': 'due',
    '3': 'tre',
    '4': 'quattro',
    '5': 'cinque',
    '6': 'sei',
    '7': 'sette',
    '8': 'otto',
  },
  pawn: 'pedone',
  captures: 'prende',
  from: 'da',
  to: 'a',
  promotesTo: 'promuove a',
  check: 'scacco',
  mate: 'scacco matto',
  shortCastle: 'arrocco corto',
  longCastle: 'arrocco lungo',
);

const frenchSpeech = SpeechVocabulary(
  pieces: {
    'K': 'roi',
    'Q': 'dame',
    'R': 'tour',
    'B': 'fou',
    'N': 'cavalier',
  },
  files: _bareFiles,
  ranks: {
    '1': 'un',
    '2': 'deux',
    '3': 'trois',
    '4': 'quatre',
    '5': 'cinq',
    '6': 'six',
    '7': 'sept',
    '8': 'huit',
  },
  pawn: 'pion',
  captures: 'prend',
  from: 'de',
  to: 'à',
  promotesTo: 'promotion en',
  check: 'échec',
  mate: 'échec et mat',
  shortCastle: 'petit roque',
  longCastle: 'grand roque',
);

/// A move in algebraic notation, wherever it sits inside a sentence.
///
/// Anchored on a destination square, because that is the one part every move
/// has. The optional pieces in front of it are the piece letter, the
/// disambiguating file or rank, and the capture sign; behind it, promotion and
/// check.
///
/// Nothing in Serbian prose can match this by accident: the pattern needs a
/// letter a-h followed by a digit, and words do not carry digits.
final _movePattern = RegExp(
  r'\b(?:O-O-O|0-0-0|O-O|0-0'
  r'|([KQRBN])?([a-h])?([1-8])?(x)?([a-h])([1-8])(?:=([QRBN]))?([+#])?)',
);

/// Reads one matched move out loud.
String _sayMove(Match m, SpeechVocabulary v) {
  final whole = m[0]!;
  if (whole == 'O-O' || whole == '0-0') return v.shortCastle;
  if (whole == 'O-O-O' || whole == '0-0-0') return v.longCastle;

  final piece = m[1];
  final fromFile = m[2];
  final fromRank = m[3];
  final capture = m[4] != null;
  final file = m[5]!;
  final rank = m[6]!;
  final promotion = m[7];
  final suffix = m[8];

  final words = <String>[];
  if (piece != null) {
    words.add(v.pieces[piece]!);
  } else if (capture) {
    // `exd5` - the pawn is named because "e takes d five" on its own sounds
    // like a piece whose name was swallowed.
    words.add(v.pawn);
  }

  // A disambiguated move is the one place where the square in front matters,
  // and running the two squares together ("knight b d seven") is exactly the
  // ambiguity the notation was disambiguating.
  final origin = [
    if (fromFile != null) v.files[fromFile]!,
    if (fromRank != null) v.ranks[fromRank]!,
  ].join(' ');
  if (origin.isNotEmpty) {
    words.add(piece == null && capture ? v.from : '${v.from} $origin');
    if (piece == null && capture) words.add(origin);
  }

  if (capture) {
    words.add(v.captures);
  } else if (origin.isNotEmpty) {
    words.add(v.to);
  }

  words.add('${v.files[file]!} ${v.ranks[rank]!}');

  if (promotion != null) {
    words.add('${v.promotesTo} ${v.pieces[promotion]!}');
  }
  if (suffix == '+') {
    words.add(', ${v.check}');
  } else if (suffix == '#') {
    words.add(', ${v.mate}');
  }

  // The comma before check is punctuation, not a word, so it must not arrive
  // with a space in front of it.
  return words.join(' ').replaceAll(' ,', ',');
}

/// Typography that is read aloud as itself unless it goes.
///
/// Quotation marks are the loud one: several voices announce them, so a
/// sentence quoting a button name gets "quote" twice. The dashes become commas
/// rather than nothing, because they are doing a comma's work. The Serbian
/// quotation marks are still stripped, because a trainer pasting a line out of
/// an older document is exactly where they turn up.
///
/// A full stop straight after a digit is the remaining trap, and it is a
/// problem in one direction only. At the end of a sentence that happens to
/// finish on a number - "Found 3 of 12." - several voices read the digits as an
/// ordinal and say "twelfth". Where the stop belongs to the number itself -
/// "See 3. diagram" - it has to stay.
///
/// The two are told apart by what follows: a stop that ends a sentence is
/// followed by a capital or by nothing at all, while one that belongs to the
/// number is followed by the rest of its clause in lower case. So the stop goes
/// only at the end of the text or before a capital letter.
///
/// The rule was written for Serbian, where "u 8. potezu" is how an ordinal is
/// spelled and getting it wrong made the voice say "u osam potezu". English
/// writes "move 8" and rarely trips that half, so what mostly survives here is
/// the end-of-sentence case, which is real in both.
///
/// Moves need none of this - their rank is already a word by the time this
/// runs - and "1.e4" is untouched either way, having no space after the stop.
///
/// A capital is any the seven tutorial languages start a sentence with: the
/// Latin diacritics („Pronađeno 3 od 12. Šta sada?") and the whole Cyrillic
/// capital block, U+0400 to U+042F, which holds Ђ Ј Љ Њ Ћ Џ as well as А to Я.
/// `spokenMoves.js` carries the same class, and the shared fixture holds the
/// two to it.
String _noOrdinalStops(String text) => text.replaceAllMapped(
      RegExp(
          r'(\d)\.(\s+(?=[A-Z\u010C\u0106\u0160\u0110\u017DÄÖÜÉÈÀÁÍÓÚÑ\u0400-\u042F])|$)'),
      (m) => '${m[1]}${m[2]}',
    );

String _plainPunctuation(String text) {
  return text
      .replaceAll('„', '')
      .replaceAll('”', '')
      .replaceAll('“', '')
      .replaceAll('"', '')
      .replaceAll('»', '')
      .replaceAll('«', '')
      .replaceAll('**', '')
      .replaceAll('…', ',')
      .replaceAll(' — ', ', ')
      .replaceAll(' – ', ', ')
      .replaceAll('—', ',')
      .replaceAll('–', ',');
}

/// What the voice should be handed, given what the screen shows.
///
/// Returns an empty string when there is nothing worth saying, so the caller
/// can treat "nothing to speak" and "spoke nothing" as one case.
String speakable(String? text, {SpeechVocabulary vocabulary = englishSpeech}) {
  if (text == null) return '';
  // Order matters: the moves go first, so that by the time the ordinal rule
  // runs there is no digit left in `e6.` for it to act on and the sentence
  // keeps its full stop. What is left for that rule is the numbers that really
  // are numbers - a rating, a count - where the stop has to go.
  final spoken = _noOrdinalStops(_plainPunctuation(text)
          .replaceAllMapped(_movePattern, (m) => _sayMove(m, vocabulary)))
      // Runs of whitespace, including the newlines the panel wraps at, are one
      // pause rather than several.
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return spoken;
}
