import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/pgn_parser.dart';

// A minimal but real shape of what Chess.com's game export API returns: a
// clock comment after every move, which forces the "N..." elided move-number
// convention for black. This is what analysis_studio_screen.dart's _importPgn
// hands to `chess.Chess().load_pgn` after fetching from
// ChessPlatformImportService.
const _chessComStylePgn = '''
[Event "Live Chess"]
[Site "Chess.com"]
[Date "2026.08.01"]
[White "Hikaru"]
[Black "only_strong_moves"]
[Result "1-0"]
[WhiteElo "3466"]
[BlackElo "2884"]

1. e4 {[%clk 0:02:59.9]} 1... e5 {[%clk 0:02:59.8]} 2. Nf3 {[%clk 0:02:58.5]} 2... Nc6 {[%clk 0:02:58.1]} 1-0
''';

void main() {
  test('the chess package cannot load a Chess.com-style PGN unmodified', () {
    // Documents the underlying bug being worked around: load_pgn's own
    // move-number regex only strips "12.", not "12...", leaving stray dots
    // that fail to parse as a move. If this ever starts passing, the `chess`
    // package has fixed it upstream and sanitizeForLoadPgn is no longer needed.
    final game = chess.Chess();
    expect(game.load_pgn(_chessComStylePgn), isFalse);
  });

  test('sanitizeForLoadPgn lets the same PGN load correctly', () {
    final sanitized = PgnParser.sanitizeForLoadPgn(_chessComStylePgn);
    final game = chess.Chess();

    expect(game.load_pgn(sanitized), isTrue);
    expect(game.getHistory().cast<String>(), ['e4', 'e5', 'Nf3', 'Nc6']);
    expect(game.header['White'], 'Hikaru');
    expect(game.header['Black'], 'only_strong_moves');
  });

  test('a PGN with plain move numbers is unaffected', () {
    const plain = '1. e4 e5 2. Nf3 Nc6';
    expect(PgnParser.sanitizeForLoadPgn(plain), plain);
  });

  test('header dates like "2026.08.01" are not mistaken for elided numbers', () {
    const withDate = '[Date "2026.08.01"]\n\n1. e4 e5';
    expect(PgnParser.sanitizeForLoadPgn(withDate), withDate);
  });
}
