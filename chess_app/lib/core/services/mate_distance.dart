/// The distance to mate a tablebase gives, as a reader counts it.
///
/// The tablebase (`dtm`, Lichess's explorer shape, passed on unchanged by our
/// server) counts in **plies**, and on a move from the **opponent's** side
/// after it: negative when the opponent is being mated, positive when the
/// opponent mates. A reader counts in moves, from the side that is about to
/// play. Both of the app's tablebase lists — Analysis's panel and the endgame
/// trainer's findings — read it through here, so the two never disagree on
/// what „mate in 21" means.
///
/// Measured on the real answers in
/// `chess_backend/test/fixtures/tablebase_best.json`: a position with `dtm`
/// 55 is mate in 28; its best move carries `dtm` -54, and is mate in 28 too.
/// A mating move carries no `dtm` at all, only `checkmate`.
library;

/// The side to move's own distance, from a position's `dtm`: positive, it
/// mates in that many of its own moves; negative, it is mated in that many of
/// the opponent's. Null when no source knew it, and for zero, which the
/// tablebase also writes on a drawing move.
int? mateInFromPosition(int? dtm) {
  if (dtm == null || dtm == 0) return null;
  return dtm > 0 ? (dtm + 1) ~/ 2 : -((-dtm + 1) ~/ 2);
}

/// The same, for the side that plays a move whose answer is [dtm] (the
/// opponent's, after it) — one ply more than the opponent's own distance.
int? mateInAfterMove(int? dtm, {bool checkmate = false}) {
  if (checkmate) return 1;
  if (dtm == null || dtm == 0) return null;
  return mateInFromPosition(dtm < 0 ? -dtm + 1 : -(dtm + 1));
}

/// „mate in 21" or „mated in 20", for a signed count from the two above.
String? mateLabel(int? mateIn) {
  if (mateIn == null) return null;
  return mateIn > 0 ? 'mate in $mateIn' : 'mated in ${-mateIn}';
}
