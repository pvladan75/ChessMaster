// One list of everything a user keeps — the widget alone.
//
// Phase 3a of docs/PLAN-REORGANIZACIJA.md (S3). The gate of the phase's app
// half: copied into chess_app/test/ by the implementer and left there green.
// Written 17.9.2026 against the seam in
// lib/features/library/widgets/library_list.dart, which draws nothing yet, so
// every test here is red on master for the right reason.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/theme/app_colors.dart';

LibraryEntry _entry(LibraryKind kind, String title,
        {int? parts, bool video = false, String? book, int? page}) =>
    LibraryEntry(
      kind: kind,
      id: '${kind.name}-$title',
      title: title,
      fen: kind == LibraryKind.recording ? '' : '8/8/8/8/8/8/8/K6k w - - 0 1',
      assignable: false,
      partsCount: parts,
      hasVideo: video,
      sourceTitle: book,
      sourcePage: page,
      createdAt: DateTime(2026, 9, 12, 18, 30),
    );

final _six = <LibraryEntry>[
  _entry(LibraryKind.tutorial, 'Sicilian: the Najdorf', parts: 6, video: true),
  _entry(LibraryKind.position, 'Rook ending, 1.Kf2'),
  _entry(LibraryKind.scan, 'Diagram 41', book: 'Mat u 333', page: 41),
  _entry(LibraryKind.analysis, 'Game vs. Ana'),
  _entry(LibraryKind.recording, 'Endgames, part 1'),
  _entry(LibraryKind.puzzleSet, 'Blunders, game 3'),
];

void main() {
  final opened = <LibraryEntry>[];
  setUp(opened.clear);

  Widget host(List<LibraryEntry> entries,
          {List<Widget> Function(LibraryEntry)? actionsFor}) =>
      MaterialApp(
        theme:
            ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
        home: Scaffold(
          body: LibraryList(
            entries: entries,
            onOpen: opened.add,
            actionsFor: actionsFor,
          ),
        ),
      );

  List<String> titlesShown(WidgetTester tester) => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => (t.title as Text).data!)
      .toList();

  testWidgets('six chips, in order, and All shows every kind', (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((c) => (c.label as Text).data)
        .toList();
    expect(chips, [
      'All',
      'Tutorials',
      'Positions',
      'Analyses',
      'Recordings',
      'Puzzle sets',
    ]);
    expect(titlesShown(tester).length, 6);
  });

  testWidgets('Positions holds a saved board and a book\'s diagram alike',
      (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Positions'));
    await tester.pumpAndSettle();
    expect(titlesShown(tester), ['Rook ending, 1.Kf2', 'Diagram 41']);
    // The source rides on the row, so the two are told apart there.
    expect(find.textContaining('Mat u 333'), findsOneWidget);
  });

  testWidgets('each other chip shows its one kind', (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    for (final (chip, title) in [
      ('Tutorials', 'Sicilian: the Najdorf'),
      ('Analyses', 'Game vs. Ana'),
      ('Recordings', 'Endgames, part 1'),
      ('Puzzle sets', 'Blunders, game 3'),
    ]) {
      await tester.tap(find.widgetWithText(ChoiceChip, chip));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), [title], reason: chip);
    }
  });

  testWidgets('a tutorial row says how many parts it has', (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    expect(find.textContaining('6 parts'), findsOneWidget);
  });

  testWidgets('search narrows by title, across kinds', (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, LibraryList.searchHint), 'end');
    await tester.pumpAndSettle();
    expect(titlesShown(tester), ['Rook ending, 1.Kf2', 'Endgames, part 1']);
  });

  testWidgets('tapping a row opens that entry and nothing else',
      (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Game vs. Ana'));
    await tester.pumpAndSettle();
    expect(opened.map((e) => e.title).toList(), ['Game vs. Ana']);
  });

  testWidgets('the row draws the actions it was given, and none otherwise',
      (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send to student'), findsNothing);

    await tester.pumpWidget(host(_six, actionsFor: (e) {
      if (e.kind != LibraryKind.tutorial) return const [];
      return [
        IconButton(
          icon: const Icon(Icons.send_outlined),
          tooltip: 'Send to student',
          onPressed: () {},
        ),
      ];
    }));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send to student'), findsOneWidget);
  });

  testWidgets('an empty library says so', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.text(LibraryList.empty), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('fits a 360 dp phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ChoiceChip), findsNWidgets(6));
  });
}
