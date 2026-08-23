/// Turns what the screen says into what a voice can say.
///
/// Written text and spoken text are not the same text, and chess is where they
/// come apart hardest: `Rd3` is read by every synthesiser as three characters,
/// which arrives as noise. The panel's sentences are already Serbian prose, so
/// the work here is narrow - find the moves inside them and spell them out the
/// way a person at the board would.
///
/// The tables are kept behind [SpeechVocabulary] rather than written into the
/// function, because a second language is planned and the only thing that
/// changes is the words. The rules of algebraic notation are the same in every
/// language; the names of the pieces are not.
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

  /// How a file is said. Spoken as the name of the letter, not the letter:
  /// `d3` is "de tri", and a voice given "d 3" says something else.
  ///
  /// These are instructions to a voice, not spelling, and one of them looks
  /// wrong on paper for that reason. See the table below.
  final Map<String, String> files;

  /// How a rank is said, as a word rather than a digit.
  ///
  /// The digit was left to the voice at first, on the reasoning that it reads
  /// numbers in its own language anyway. It does - but a digit followed by a
  /// full stop is how Serbian writes an ordinal, so a move at the end of a
  /// sentence came out as "e šesti" instead of "e šest". A word cannot be read
  /// as an ordinal, which ends the question rather than working around it.
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

const serbianSpeech = SpeechVocabulary(
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
    // Not "ge", which is what it is called and what was here first: Microsoft
    // Matej, the Croatian voice, reads that two-letter token by an English
    // letter name, so the g-file came out closer to "dž" than to the g in
    // "gitara". "gje" is not how anyone spells it - it is what makes this voice
    // put a hard g in front of the e, chosen by ear against five other
    // spellings. A different voice may need a different one, which is why the
    // table is a table.
    'g': 'gje',
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
    // `exd5` - the pawn is named because "e uzima de pet" on its own sounds
    // like a piece whose name was swallowed.
    words.add(v.pawn);
  }

  // A disambiguated move is the one place where the square in front matters,
  // and running the two squares together ("skakač be de sedam") is exactly the
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
/// sentence quoting a button name gets "navodnik" twice. The dashes become
/// commas rather than nothing, because they are doing a comma's work.
/// A full stop straight after a digit is how Serbian writes an ordinal, and
/// that is a problem in one direction only.
///
/// Where it really is an ordinal - "greška je napravljena u 8. potezu" - the
/// stop must stay, or the voice says "u osam potezu". Where it is the end of a
/// sentence that happens to finish on a number - "Nađeno 3 od 12." - the same
/// two characters make the voice say "dvanaesti".
///
/// The two are told apart by what follows, which in Serbian is reliable: an
/// ordinal is followed by the rest of its sentence in lower case, while a new
/// sentence starts with a capital. So the stop goes only at the end of the
/// text or before a capital letter.
///
/// Moves need none of this - their rank is already a word by the time this
/// runs - and "1.e4" is untouched either way, having no space after the stop.
String _noOrdinalStops(String text) => text.replaceAllMapped(
      RegExp(r'(\d)\.(\s+(?=[A-ZČĆŠŽĐ])|$)'),
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
String speakable(String? text, {SpeechVocabulary vocabulary = serbianSpeech}) {
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
