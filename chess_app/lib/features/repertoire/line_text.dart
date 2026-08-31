/// A line of SAN moves, numbered the way a book numbers it.
///
/// One copy of this, used by both repertoire screens. The build screen grew it
/// first and the drill screen needs exactly the same sentence — a second copy
/// would be two places for "where does this line start counting" to drift, and
/// the answer to that is already subtle enough: a repertoire may begin at move
/// four, and pretending the game started there is the confusion this text was
/// written to end.
///
/// [from] is the position the numbering is read out of, and is used only when
/// the moves do not reach back to the first move of the game. Pass null — or
/// the moves that led to the root, in [moves] — when the line does start at
/// move one.
///
/// A line that opens on Black's move says so once: `4...Nc6 5.Nf3`, rather than
/// a move hanging off nothing.
String numberedLine(List<String> moves, {String? from}) {
  if (moves.isEmpty) return '';

  var number = 1;
  var whiteToMove = true;
  if (from != null) {
    final parts = from.trim().split(RegExp(r'\s+'));
    whiteToMove = parts.length < 2 || parts[1] == 'w';
    number = parts.length >= 6 ? (int.tryParse(parts[5]) ?? 1) : 1;
  }

  final out = StringBuffer();
  for (final san in moves) {
    if (whiteToMove) {
      out.write('$number.$san ');
    } else {
      if (out.isEmpty) out.write('$number...');
      out.write('$san ');
      number += 1;
    }
    whiteToMove = !whiteToMove;
  }
  return out.toString().trimRight();
}
