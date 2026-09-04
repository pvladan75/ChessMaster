import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/stockfish_service.dart';

/// The engine is never handed something that is not chess.
///
/// Reported live 30.8.2026: a position set up by hand with no king, imported,
/// engine switched on — and the application went down. `fenIllegalReason` was
/// written the same day and put on the two doors that were known, the setup
/// dialog and the FEN paste box. It was not on the corridor they both lead to,
/// so every other way in still walked past it: a lesson position from the
/// server, a PGN, a puzzle with a broken FEN, and the auto-trigger that fires
/// when a screen becomes the top subscriber.
///
/// This test is about that corridor. It asks the service directly, because that
/// is the one place all of those meet.
void main() {
  const legal = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  // The reported board: White has everything except a king.
  const noWhiteKing = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1BNR w kq - 0 1';

  test('an impossible position is refused, with a reason', () async {
    final engine = StockfishService();
    String? refused;
    engine.onPositionRefused = (reason) => refused = reason;

    await engine.analyzePosition(noWhiteKing);

    expect(refused, isNotNull,
        reason: 'pozicija bez kralja mora da bude odbijena pre motora');
    expect(refused, contains('kralj'));
    engine.onPositionRefused = null;
  });

  test('a legal position is not refused', () async {
    final engine = StockfishService();
    var refusals = 0;
    engine.onPositionRefused = (_) => refusals++;

    // Not awaited to completion on purpose: this must not start a search in a
    // test. The guard runs before the debounce timer is even armed, so a
    // refusal — if there were one — would already have been counted.
    // ignore: unawaited_futures
    engine.analyzePosition(legal);

    expect(refusals, 0, reason: 'ispravna pozicija se ne odbija');
    engine.onPositionRefused = null;
    engine.stopAnalysis();
  });
}
