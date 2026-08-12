import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpeningBookService', () {
    test('loads the bundled ECO dataset', () async {
      final service = OpeningBookService.instance;
      await service.ensureLoaded();
      expect(service.isLoaded, isTrue);
    });

    test('search finds Najdorf lines by name', () async {
      final service = OpeningBookService.instance;
      await service.ensureLoaded();

      final results = service.search('najdorf');
      expect(results, isNotEmpty);
      expect(results.every((e) => e.name.toLowerCase().contains('najdorf')), isTrue);

      // The plain "Najdorf Variation" main line (shortest pgn) should rank first.
      expect(results.first.name, contains('Najdorf Variation'));
      expect(results.first.pgn, '1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6');
    });

    test('lookupByFen finds the exact Najdorf position', () async {
      final service = OpeningBookService.instance;
      await service.ensureLoaded();

      final game = chess.Chess();
      game.load_pgn('1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6');
      final entry = service.lookupByFen(game.fen);

      expect(entry, isNotNull);
      expect(entry!.name, contains('Najdorf'));
    });

    test('lookupByFen returns null for an unnamed / arbitrary position', () async {
      final service = OpeningBookService.instance;
      await service.ensureLoaded();

      final entry = service.lookupByFen('8/8/8/8/8/8/8/K6k w - - 0 1');
      expect(entry, isNull);
    });
  });
}
