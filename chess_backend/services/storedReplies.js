// storedReplies.js — which rows of `opening_replies` are this book's.
//
// `opening_replies` keeps what the opponent plays in a position, so the drill,
// the tree and the panel beside the board never have to ask anybody. Until
// 15.9.2026 its rows came from the Lichess explorer, one set per rating band —
// `min_rating` 0, 1600, 2000 — and `docs/PLAN-OTVARANJA-LOKALNO.md` replaced
// that with one local book and no bands.
//
// Two constants, and every reader and the one writer use both:
//
// **One band.** Every row is written at `BOOK_BAND` and every reader asks for
// it, whatever a caller sends. The app still sends a rating on some routes;
// reading it here would split one book into a copy per number, each filled by
// whoever happened to build at that number.
//
// **A source.** Rows written before this change say nothing about where they
// came from, and they are the Lichess band rows. A reader that asked only for
// the band would take the old band-0 rows as the book's own and mix two
// sources invisibly, so readers ask for `BOOK_SOURCE` too, and the old rows are
// rewritten from the book at start-up (`refreshStoredReplies`) rather than
// deleted — they are a real student's tree, and deleting them would empty it
// until every position had been opened again. The next swap of book is then a
// change of this string, and visible.

const BOOK_BAND = 0;
const BOOK_SOURCE = 'book';

module.exports = { BOOK_BAND, BOOK_SOURCE };
