import 'package:chess/chess.dart' as chess;

/// Whether a FEN is not merely well written but a **possible game**.
///
/// `chess.Chess.validate_fen` checks the notation only: the number of squares,
/// the permitted letters, correct castling rights and en passant. It checks no
/// rule of the game — the word "king" does not appear in it once. A position
/// with no king therefore parses cleanly, passes as valid, reaches the engine,
/// and that is where the application falls over.
///
/// Found live 30.8.2026: a position is set up by hand with no king, imported
/// into the Studio, the engine is switched on — and the app crashes. The fault
/// is not in the engine but here: it was handed something that is not chess.
///
/// Returns `null` when all is well, or the reason when it is not.
///
/// Translated on 8.9.2026 with the English pivot. It had been missed by every
/// sweep, and the reason is worth keeping: its Serbian was written **without
/// diacritics** — "vise", "pesaka", "moze" — so `gate_english_ui`, which looks
/// for `čćžšđ`, could not see a single line of it.
String? fenIllegalReason(String fen) {
  final text = fen.trim();
  if (text.isEmpty) return 'No FEN given.';

  // A FEN is six fields, and a board on its own is the commonest thing people
  // paste — from a diagram tool, from a chat, from half of another FEN. Said
  // separately because „Malformed FEN." sends the reader to look at the board,
  // which is the one part that was right. Reported live 18.9.2026: „ne mogu da
  // ubacim pozicije, fen nije dobar", with no way to see what was wrong.
  final fieldCount = text.split(RegExp(r'\s+')).length;
  if (fieldCount < 6) {
    return 'A FEN has six fields and this one has $fieldCount. After the board '
        'come the side to move, castling, en passant and the two counters — '
        'for example „w - - 0 1".';
  }

  // The notation next, because everything below assumes it can be read.
  try {
    final check = chess.Chess.validate_fen(text);
    if (check['valid'] != true) return 'Malformed FEN.';
  } catch (_) {
    return 'Malformed FEN.';
  }

  final fields = text.split(RegExp(r'\s+'));
  final board = fields.first;

  // Three things `validate_fen` lets through and Stockfish 19 does not. SF19
  // answers them with „CRITICAL ERROR" and `std::exit(1)` — on Windows that
  // ends the engine's own process, on Android the engine runs inside the app's
  // process and it closes the app. Limits measured on the sf_19 binary.
  //
  // An en passant square sits behind a pawn that has just moved two squares,
  // so it is on the sixth rank when White is to move and on the third when
  // Black is.
  final ep = fields[3];
  if (ep != '-' && ep[1] != (fields[1] == 'w' ? '6' : '3')) {
    return 'The en passant square $ep cannot be right with '
        '${fields[1] == 'w' ? 'White' : 'Black'} to move.';
  }
  if ((int.tryParse(fields[4]) ?? 32768) > 32767) {
    return 'The halfmove counter is ${fields[4]}; the engine accepts at most '
        '32767.';
  }
  if ((int.tryParse(fields[5]) ?? 100001) > 100000) {
    return 'The move number is ${fields[5]}; the engine accepts at most '
        '100000.';
  }

  // Exactly one king of each colour. Neither none nor two — for the engine two
  // white kings are as impossible as none, they just break it somewhere else.
  final white = 'K'.allMatches(board).length;
  final black = 'k'.allMatches(board).length;
  if (white == 0 && black == 0) return 'There are no kings on the board.';
  if (white == 0) return 'The white king is missing.';
  if (black == 0) return 'The black king is missing.';
  if (white > 1) return 'There is more than one white king on the board.';
  if (black > 1) return 'There is more than one black king on the board.';

  // How much of what is on the board. Only the first FEN field is counted;
  // digits are empty squares and do not matter.
  int count(String letter) => letter.allMatches(board).length;

  for (final side in const [
    ('White', 'PNBRQK'),
    ('Black', 'pnbrqk'),
  ]) {
    final name = side.$1;
    final letters = side.$2;
    final pawns = count(letters[0]);
    final total = letters.split('').fold<int>(0, (n, c) => n + count(c));

    // Eight pawns is everything you start with; a ninth comes from nowhere.
    if (pawns > 8) return 'Too many pawns for $name: $pawns.';
    // Sixteen pieces is the whole army. More than that is not a game.
    if (total > 16) return 'Too many pieces for $name: $total.';

    // And the thing that ties those two numbers together: every piece beyond
    // the starting set must have come from a promotion, and a promotion spends
    // a pawn. So a spare queen and eight pawns cannot both be there — without
    // this, 8 pawns and 3 queens would pass, because neither number is on its
    // own too large.
    final spare = [
      (count(letters[4]) - 1), // queens
      (count(letters[3]) - 2), // rooks
      (count(letters[2]) - 2), // bishops
      (count(letters[1]) - 2), // knights
    ].map((n) => n > 0 ? n : 0).fold<int>(0, (a, b) => a + b);

    if (spare > 8 - pawns) {
      return '$name has too few pawns for that many promotions '
          '($pawns on the board, and $spare promotions would be needed).';
    }
  }

  // A pawn on the first or the last rank cannot arise in a game: it only ever
  // reaches the eighth rank in order to promote at once.
  final ranks = board.split('/');
  if (ranks.length == 8) {
    for (final r in [0, 7]) {
      if (ranks[r].contains('P') || ranks[r].contains('p')) {
        return 'A pawn cannot stand on the ${r == 0 ? 'eighth' : 'first'} rank.';
      }
    }
  }

  // The side that is *not* to move must not already be in check: that would
  // mean the previous move left a king under attack, which no game can produce.
  // The engine does not accept such a position.
  try {
    final game = chess.Chess.fromFEN(text);
    final toMove = game.turn;
    final opponent =
        toMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    if (game.king_attacked(opponent)) {
      return 'The side that is not to move is in check — no game can reach '
          'that position.';
    }
  } catch (_) {
    return 'The position cannot be read.';
  }

  return null;
}

/// The short check, for places that only want yes or no.
bool isFenLegal(String fen) => fenIllegalReason(fen) == null;

/// Fills in the fields a board-only FEN is missing, or null when there is
/// nothing to fill in or nothing to work with.
///
/// **Why this is offered and not applied.** A diagram has no memory: it cannot
/// say whether a king that is standing on e1 has ever moved, so castling is
/// *inferred* from where the king and rooks are — the most permissive reading a
/// position can have, and the one every diagram-to-FEN tool takes. That is a
/// guess, and a guess about the rules of the game being set for a student must
/// be made where they can see it. The caller writes the result into the field
/// the trainer is looking at; it is theirs to correct before they save.
///
/// Reported live on 18.9.2026: „ne mogu da ubacim pozicije, fen nije dobar",
/// with `rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR` — a board and
/// nothing else, which is what a diagram tool hands you.
String? completedFen(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.isEmpty || fields.first.isEmpty) return null;
  if (fields.length >= 6) return null;

  final ranks = fields.first.split('/');
  if (ranks.length != 8) return null;

  /// The piece on a square of the board field, or null.
  String? at(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]);
    if (file < 0 || file > 7 || rank < 1 || rank > 8) return null;
    final row = ranks[8 - rank];
    var index = 0;
    for (final ch in row.split('')) {
      final empty = int.tryParse(ch);
      if (empty != null) {
        if (file < index + empty) return null;
        index += empty;
      } else {
        if (file == index) return ch;
        index += 1;
      }
    }
    return null;
  }

  final side = fields.length >= 2 && (fields[1] == 'w' || fields[1] == 'b')
      ? fields[1]
      : 'w';

  final castling = StringBuffer();
  if (at('e1') == 'K') {
    if (at('h1') == 'R') castling.write('K');
    if (at('a1') == 'R') castling.write('Q');
  }
  if (at('e8') == 'k') {
    if (at('h8') == 'r') castling.write('k');
    if (at('a8') == 'r') castling.write('q');
  }

  final rest = [
    side,
    castling.isEmpty ? '-' : castling.toString(),
    '-',
    '0',
    '1',
  ];
  return '${fields.first} ${rest.join(' ')}';
}

/// [fen] with its side to move set to [side], or [fen] unchanged when it has
/// no side field to set.
///
/// **The en passant square is cleared with it**, and that is the whole reason
/// this is a function rather than a string splice: `e3` means „black may
/// capture there this move" and nothing else. Carried across a change of side
/// it asserts a capture that cannot happen, which is a position no game can
/// reach — the kind of thing `fenIllegalReason` would then refuse for a reason
/// the trainer never caused.
///
/// Asked for on 18.9.2026: „ako fen ima ko je na potezu, onda treba i dugme da
/// se postavi tako da odgovara tome, a ako promenim na drugu stranu, onda tako
/// treba da se prihvati" — the switch shows what the FEN says, and once it is
/// moved it is the one that decides.
String fenWithSideToMove(String fen, String side) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.length < 6) return fen;
  if (side != 'w' && side != 'b') return fen;
  if (fields[1] == side) return fen;
  fields[1] = side;
  fields[3] = '-';
  return fields.join(' ');
}
