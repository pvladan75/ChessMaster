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

  Widget host(
    List<LibraryEntry> entries, {
    List<Widget> Function(LibraryEntry)? actionsFor,
    List<LibraryChip> chips = LibraryChip.values,
    bool originChips = false,
    List<String> labels = const [],
    bool shrinkWrap = false,
  }) =>
      MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: Scaffold(
          body: LibraryList(
            entries: entries,
            onOpen: opened.add,
            actionsFor: actionsFor,
            chips: chips,
            originChips: originChips,
            labels: labels,
            shrinkWrap: shrinkWrap,
          ),
        ),
      );

  // The list's own rows: the label panel's expansion tile is a ListTile too.
  List<String> titlesShown(WidgetTester tester) => tester
      .widgetList<ListTile>(find.descendant(
          of: find.byType(ListView), matching: find.byType(ListTile)))
      .map((t) => (t.title as Text).data!)
      .toList();

  testWidgets('seven chips, in order, and All shows every kind',
      (tester) async {
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((c) => (c.label as Text).data)
        .toList();
    // Until 18.9.2026 this was six, with „Positions" holding both a saved
    // board and a book's diagram. Superseded the same day
    // (`docs/PLAN-EXERCISE.md`, decision 2, as amended when phase 4 was
    // briefed): a trainer does not send a position, they send an exercise,
    // so a scan is told apart as its own chip.
    expect(chips, [
      'All',
      'Tutorials',
      'Exercises',
      'Positions',
      'Analyses',
      'Recordings',
      'Puzzle sets',
    ]);
    expect(titlesShown(tester).length, 6);
  });

  testWidgets('Exercises and Positions are told apart, not shared',
      (tester) async {
    // Superseded 18.9.2026, same decision as above: a scan is an exercise,
    // not a position — it moved to its own chip and Positions narrowed to a
    // bare board.
    await tester.pumpWidget(host(_six));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Exercises'));
    await tester.pumpAndSettle();
    expect(titlesShown(tester), ['Diagram 41']);
    expect(find.textContaining('Mat u 333'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Positions'));
    await tester.pumpAndSettle();
    expect(titlesShown(tester), ['Rook ending, 1.Kf2']);
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
    expect(find.byType(ChoiceChip), findsNWidgets(7));
  });

  // Phase 3b of docs/PLAN-REORGANIZACIJA.md — the room's left column reads
  // this widget too. It needs four things the Library screen did not: a subset
  // of the chips (only what can go on a board), a split by who keeps the row,
  // the label filter the room already had, and a height of its own inside a
  // column that scrolls.
  group('phase 3b — the room\'s column', () {
    // `docs/PLAN-EXERCISE.md` phase 4 added `exercises` here: without it a
    // scan is unreachable from the room's board (CLAUDE.md rule 10), now
    // that „Positions" no longer holds one.
    const board = [
      LibraryChip.all,
      LibraryChip.tutorials,
      LibraryChip.exercises,
      LibraryChip.positions
    ];

    testWidgets('a subset of chips draws only those, and All shows their union',
        (tester) async {
      await tester.pumpWidget(host(_six, chips: board));
      await tester.pumpAndSettle();
      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((c) => (c.label as Text).data)
          .toList();
      expect(chips, ['All', 'Tutorials', 'Exercises', 'Positions']);
      // Not the six: an analysis or a recording is not on this column's All.
      expect(titlesShown(tester),
          ['Sicilian: the Najdorf', 'Rook ending, 1.Kf2', 'Diagram 41']);
    });

    final mine = _entry(LibraryKind.tutorial, 'Moj tutorijal', parts: 2);
    final theirs = LibraryEntry(
      kind: LibraryKind.tutorial,
      id: 'theirs',
      title: 'Trenerov tutorijal',
      fen: '',
      assignable: false,
      partsCount: 3,
      fromTrainer: true,
    );

    testWidgets('Mine and From trainer split the list by who keeps it',
        (tester) async {
      await tester.pumpWidget(host([mine, theirs], originChips: true));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Moj tutorijal', 'Trenerov tutorijal']);

      await tester.tap(find.widgetWithText(FilterChip, 'From trainer'));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Trenerov tutorijal']);

      await tester.tap(find.widgetWithText(FilterChip, 'Mine'));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Moj tutorijal']);

      // Tapping the chosen one again is „everyone" — there is no third chip
      // for that, the kind row's All already has the word.
      await tester.tap(find.widgetWithText(FilterChip, 'Mine'));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Moj tutorijal', 'Trenerov tutorijal']);
    });

    testWidgets('without originChips the two chips are not drawn',
        (tester) async {
      await tester.pumpWidget(host([mine, theirs]));
      await tester.pumpAndSettle();
      expect(find.text('Mine'), findsNothing);
      expect(find.text('From trainer'), findsNothing);
    });

    final endgame = LibraryEntry(
      kind: LibraryKind.position,
      id: 'p1',
      title: 'Lucena',
      fen: '',
      assignable: false,
      themes: const ['endgame', 'rook'],
    );
    final opening = LibraryEntry(
      kind: LibraryKind.position,
      id: 'p2',
      title: 'Najdorf, 6.Bg5',
      fen: '',
      assignable: false,
      themes: const ['opening'],
    );

    testWidgets('the labels filter by the themes a row carries',
        (tester) async {
      await tester.pumpWidget(host([endgame, opening],
          labels: const ['endgame', 'opening', 'rook']));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Lucena', 'Najdorf, 6.Bg5']);

      await tester.tap(find.text('Label Filter Matrix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('endgame'));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Lucena']);

      // A long press excludes; ALL (AND) wants every included label.
      await tester.longPress(find.text('endgame'));
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Najdorf, 6.Bg5']);
    });

    testWidgets('no labels, no panel', (tester) async {
      await tester.pumpWidget(host([endgame, opening]));
      await tester.pumpAndSettle();
      expect(find.text('Label Filter Matrix'), findsNothing);
    });

    testWidgets('search matches a label as well as the title', (tester) async {
      await tester.pumpWidget(host([endgame, opening]));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, LibraryList.searchHint), 'rook');
      await tester.pumpAndSettle();
      expect(titlesShown(tester), ['Lucena']);
    });

    testWidgets('inside a scrolling column it takes its own height',
        (tester) async {
      // The room's column is a SingleChildScrollView; a list that asks for
      // all the height there is gets none, and throws.
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 400),
                  LibraryList(
                    entries: _six,
                    onOpen: opened.add,
                    chips: board,
                    shrinkWrap: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ListTile), findsNWidgets(3));
    });
  });
}
