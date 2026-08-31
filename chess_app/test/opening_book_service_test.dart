import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_picker.dart';

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

  test('an opening and its variation come out of the one name', () {
    // The ECO name is "Sicilian Defense: Najdorf Variation, English Attack" —
    // one string carrying two levels. The list of openings is built from the
    // first, and the rows inside one from the second.
    final entry = OpeningBookEntry(
        eco: 'B90',
        name: 'Sicilian Defense: Najdorf Variation, English Attack',
        pgn: '1. e4 c5');
    expect(entry.family, 'Sicilian Defense');
    expect(entry.variation, 'Najdorf Variation, English Attack');

    // The opening's own main line has nothing after the colon, and is named
    // rather than left blank: an empty row reads as a bug, and "the opening
    // itself" is a real choice.
    final plain =
        OpeningBookEntry(eco: 'B20', name: 'Sicilian Defense', pgn: '1. e4 c5');
    expect(plain.family, 'Sicilian Defense');
    expect(plain.variation, 'Osnovna linija');
  });

  test('every opening can be listed without typing anything', () async {
    // The half that was missing: the search field answers "what is this
    // called", and this answers "what is there". A picker that opens as an
    // empty box serves only somebody who already knows the name.
    await OpeningBookService.instance.ensureLoaded();
    final families = OpeningBookService.instance.families();

    expect(families.length, greaterThan(100));
    expect(families, contains('Sicilian Defense'));
    // Sorted, and each opening named once however many lines it has.
    final sorted = [...families]..sort();
    expect(families, sorted);
    expect(families.toSet().length, families.length);
  });

  test('the lines of one opening come back shortest first', () async {
    // Shortest first because the shortest line *is* the opening — the main line
    // somebody means when they name it. Alphabetical would open the list on
    // whatever begins with A.
    await OpeningBookService.instance.ensureLoaded();
    final lines = OpeningBookService.instance.variationsOf('Sicilian Defense');

    expect(lines.length, greaterThan(10));
    expect(lines.every((e) => e.family == 'Sicilian Defense'), isTrue);
    for (var i = 1; i < lines.length; i++) {
      expect(lines[i - 1].pgn.length <= lines[i].pgn.length, isTrue,
          reason: 'duže linije ne smeju da dođu pre kraćih');
    }
  });

  test('an opening nobody has is an empty list, not a failure', () async {
    await OpeningBookService.instance.ensureLoaded();
    expect(OpeningBookService.instance.variationsOf('Nepostojeće'), isEmpty);
  });

  /// The picker itself, in the same file as the service so the dataset is
  /// loaded once for both: parsing 3810 openings in an isolate is the slowest
  /// thing in this suite, and a second file would pay for it a second time.
  group('OpeningPicker', () {
    OpeningBookEntry? picked;

    /// Two things here are not decoration.
    ///
    /// The load goes through `runAsync`, because it spawns an isolate through
    /// `compute()` and a widget test's clock is fake — awaited inside the test
    /// zone the future simply never completes, and the test sits there until it
    /// times out. That is what happened.
    ///
    /// And frames rather than `pumpAndSettle`: the search field autofocuses, a
    /// focused text field blinks its cursor forever, and nothing ever settles.
    Future<void> pump(WidgetTester tester) async {
      picked = null;
      await tester.runAsync(() => OpeningBookService.instance.ensureLoaded());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: OpeningPicker(onPicked: (entry) => picked = entry),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('opens on the list of openings, with nothing typed',
        (tester) async {
      // What the owner asked for, and the half that was missing: it used to
      // open as an empty box that only answered somebody who already knew the
      // name of the thing they were looking up.
      await pump(tester);

      // The first opening in the book, alphabetically: the list is a
      // ListView.builder and only the visible rows exist, so an
      // assertion on a name three hundred rows down would be an
      // assertion about the scroll position.
      expect(find.text('Alekhine Defense'), findsWidgets);
      expect(find.textContaining('Ukucajte naziv'), findsNothing);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('an opening opens into its own variations', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Alekhine Defense').first);
      await tester.pump(const Duration(milliseconds: 50));

      // The opening's name is at the top once, and the rows below carry only
      // what tells them apart.
      // The book holds the plain name more than once for some openings, so
      // this is "there is at least one", not "there is exactly one".
      expect(find.text('Osnovna linija'), findsWidgets);
      expect(find.textContaining('Brooklyn'), findsWidgets);

      await tester.tap(find.byTooltip('Nazad na spisak otvaranja'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Osnovna linija'), findsNothing);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('picking a variation answers with the whole line',
        (tester) async {
      await pump(tester);

      await tester.tap(find.text('Alekhine Defense').first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Osnovna linija').first);
      await tester.pump(const Duration(milliseconds: 50));

      expect(picked, isNotNull);
      expect(picked!.family, 'Alekhine Defense');
      expect(picked!.pgn, contains('Nf6'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('typing cuts across the lists', (tester) async {
      // Somebody who types "Najdorf" means the Najdorf, not the Najdorf among
      // the lines of whatever they happened to be browsing.
      await pump(tester);

      await tester.tap(find.text('Alekhine Defense').first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'Najdorf');
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byTooltip('Nazad na spisak otvaranja'), findsNothing);
      expect(find.textContaining('Najdorf'), findsWidgets);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
