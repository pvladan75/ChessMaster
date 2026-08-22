import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpeningBookService', () {
    // Loading spawns an isolate through compute() and parses 3810 openings,
    // replaying each line to index it by FEN. On its own that takes a couple of
    // seconds; when `flutter test` is running other files in parallel the same
    // work has been measured at twelve, which is past the default per-test
    // timeout. The test then failed here while the three below passed, because
    // by their turn the load had finished - a failure that came and went with
    // machine load and said nothing about the code.
    test('loads the bundled ECO dataset', () async {
      final service = OpeningBookService.instance;
      await service.ensureLoaded();
      expect(service.isLoaded, isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('search finds Najdorf lines by name', () async {
      final service = OpeningBookService.instance;
      await service.ensureLoaded();

      final results = service.search('najdorf');
      expect(results, isNotEmpty);
      expect(results.every((e) => e.name.toLowerCase().contains('najdorf')),
          isTrue);

      // The plain "Najdorf Variation" main line (shortest pgn) should rank first.
      expect(results.first.name, contains('Najdorf Variation'));
      expect(results.first.pgn,
          '1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6');
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

    test('lookupByFen returns null for an unnamed / arbitrary position',
        () async {
      final service = OpeningBookService.instance;
      await service.ensureLoaded();

      final entry = service.lookupByFen('8/8/8/8/8/8/8/K6k w - - 0 1');
      expect(entry, isNull);
    });
  });
}
