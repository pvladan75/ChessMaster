import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';

void main() {
  group('SyzygyTablebaseService (live Lichess API)', () {
    test('KQ vs KR: reports a white win with the check as the top move', () async {
      const fen = '7r/8/4k3/8/3K4/8/8/3Q4 w - - 0 1';
      final result = await SyzygyTablebaseService.instance.lookup(fen);

      expect(result, isNotNull);
      expect(result!.category, SyzygyCategory.win);
      expect(result.dtz, 29);
      expect(result.moves, isNotEmpty);

      // Best move for White should be the checking queen move (lowest DTZ
      // among moves that leave Black losing).
      final best = result.moves.first;
      expect(best.san, 'Qg4+');
      expect(best.category, SyzygyCategory.loss); // API reports it from Black's (mover-after) perspective
    });
  });
}
