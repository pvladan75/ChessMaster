// exercise_library_test.dart — the gate of phase 4, docs/PLAN-EXERCISE.md.
//
// Copy into chess_app/test/ and leave it there green, unchanged. Written
// 18.9.2026 by the lead, **red on master**: `LibraryEntry` has no `origin` or
// `task`, there is no `LibraryChip.exercises`, and none of the functions below
// exists.
//
// The owner's rule this phase makes literal: **a trainer does not send a
// position, they send an exercise** — a position plus a task. So the Library
// tells the two apart, an exercise is filtered by what it asks and where it
// came from, a bare position cannot be put in a homework, and a list of boards
// shows the boards.
//
// What the implementer must provide, exactly:
//
//   // lib/features/library/models/library_entry.dart — added
//   final String origin;                 // 'book' | 'manual' | 'mistakes'; 'book' when absent
//   final Map<String, dynamic>? task;    // as GET /library/positions sends it; null when absent
//   bool get isExercise;                 // kind == LibraryKind.scan
//
//   // lib/features/library/widgets/library_list.dart — changed
//   enum LibraryChip { all, tutorials, exercises, positions, analyses, recordings, puzzleSets }
//     exercises('Exercises', {LibraryKind.scan})
//     positions('Positions', {LibraryKind.position})      // no longer holds scans
//
//   // lib/features/library/models/exercise_filter.dart — new
//   enum ExerciseOrigin { book('From a book'), manual('Made by me'), mistakes('From mistakes') }
//   ExerciseOrigin exerciseOriginOf(LibraryEntry entry);
//   /// Null filters let everything through. Entries that are not exercises are
//   /// never removed by these filters — they are not what is being filtered.
//   List<LibraryEntry> filterExercises(List<LibraryEntry> entries,
//       {ExerciseAsk? ask, ExerciseOrigin? origin});
//
//   // lib/features/homework/models/homework_items_from_exercises.dart — new
//   /// What picking [chosen] adds to a homework: the find-the-move exercises
//   /// together as ONE `positions` item, then each game exercise as its own
//   /// `engine_game` item whose task is COPIED from the exercise. Anything
//   /// that is not an assignable exercise is left out.
//   List<HomeworkItem> homeworkItemsFromExercises(List<LibraryEntry> chosen);
//
//   // lib/features/library/widgets/board_preview_dialog.dart — new
//   class BoardPreviewDialog extends StatelessWidget {
//     const BoardPreviewDialog({super.key, required this.entry, this.onOpen});
//     final LibraryEntry entry;
//     final VoidCallback? onOpen;        // a TextButton labelled 'Open'; absent when null.
//                                        // Pressing it closes the dialog, then calls onOpen.
//   }
//   In `LibraryList`, tapping a row's `BoardThumbnail` opens this dialog with
//   `onOpen: () => widget.onOpen(entry)`; tapping the rest of the row opens
//   the entry, as today. Rows of kind scan and position draw a thumbnail; no
//   other kind does.
//
// `ExerciseAsk`, `exerciseAskOf`, `exerciseTaskWords`, `sideToMoveWords` are in
// `lib/features/exercises/models/exercise_task_words.dart` already. Use them;
// do not word a task anywhere else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/features/homework/models/homework.dart';
import 'package:chess_app/features/homework/models/homework_items_from_exercises.dart';
import 'package:chess_app/features/library/models/exercise_filter.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/widgets/board_preview_dialog.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

const _krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
const _kpk = '8/8/8/4k3/8/4K3/4P3/8 b - - 0 1';

Map<String, dynamic> _wire(String id,
        {String kind = 'scan',
        String title = 'An exercise',
        String fen = _krk,
        String? origin,
        Map<String, dynamic>? task,
        bool assignable = true}) =>
    {
      'kind': kind,
      'id': id,
      'title': title,
      'fen': fen,
      // As `listScanned` spells a row: a find exercise carries its solution, a
      // game carries none, and one that cannot be sent is marked for review —
      // a scan with *no* solution is not an exercise at all
      // (`exercise_shelves_test.dart`).
      if (kind == 'scan') 'hasSolution': task == null || task['type'] != 'game',
      // Every scan in this file is an exercise — a find with its answer or a
      // game — and since docs/PLAN-MATERIJAL.md phase 3 the server says so.
      if (kind == 'scan') 'isExercise': true,
      'assignable': assignable,
      'blockedReason': assignable ? null : 'is marked for review',
      if (origin != null) 'origin': origin,
      if (task != null) 'task': task,
    };

LibraryEntry _entry(String id,
        {String kind = 'scan',
        String title = 'An exercise',
        String fen = _krk,
        String? origin,
        Map<String, dynamic>? task,
        bool assignable = true}) =>
    LibraryEntry.fromJson(_wire(id,
        kind: kind,
        title: title,
        fen: fen,
        origin: origin,
        task: task,
        assignable: assignable));

const _win = {'type': 'game', 'fen': _krk, 'side': 'w', 'goal': 'win'};
const _hold = {
  'type': 'game',
  'fen': _kpk,
  'side': 'b',
  'goal': 'hold',
  'surviveMoves': 4,
  'level': 'tesko',
  'thinkSeconds': null,
  'plyCap': 200,
};

void main() {
  group('an entry says what it is', () {
    test('origin and task are read, and their absence means a scanned find',
        () {
      final old = _entry('cust_1');
      expect(old.origin, 'book');
      expect(old.task, isNull);
      expect(old.isExercise, isTrue);
      expect(exerciseAskOf(old.task), ExerciseAsk.find);

      final made = _entry('ex_1', origin: 'manual', task: _hold);
      expect(made.origin, 'manual');
      expect(exerciseAskOf(made.task), ExerciseAsk.hold);
      expect(
          exerciseTaskWords(made.task), 'Draw or better as Black, for 4 moves');

      expect(_entry('7', kind: 'position').isExercise, isFalse);
    });

    test('the origin is one of three, and an unknown one is a book', () {
      expect(exerciseOriginOf(_entry('a', origin: 'manual')),
          ExerciseOrigin.manual);
      expect(exerciseOriginOf(_entry('b', origin: 'mistakes')),
          ExerciseOrigin.mistakes);
      expect(exerciseOriginOf(_entry('c')), ExerciseOrigin.book);
      expect(exerciseOriginOf(_entry('d', origin: 'elsewhere')),
          ExerciseOrigin.book);
      expect(ExerciseOrigin.values.map((o) => o.label).toSet().length, 3);
    });
  });

  group('the chips', () {
    test('an exercise and a position are different shelves', () {
      expect(LibraryChip.values.map((c) => c.label).toList(), [
        'All',
        'Tutorials',
        'Exercises',
        'Positions',
        'Analyses',
        'Recordings',
        // „Puzzle sets" until 23.9.2026 — gone with the sets
        // (docs/PLAN-MATERIJAL.md, phase 4).
      ]);
      final exercise = _entry('cust_1');
      final position = _entry('7', kind: 'position');
      expect(LibraryChip.exercises.shows(exercise), isTrue);
      expect(LibraryChip.exercises.shows(position), isFalse);
      expect(LibraryChip.positions.shows(position), isTrue);
      expect(LibraryChip.positions.shows(exercise), isFalse,
          reason: 'a scan was a „position" until the two were told apart');
    });
  });

  group('the two filters', () {
    final entries = [
      _entry('find_book'),
      _entry('find_made', origin: 'manual', task: const {'type': 'find'}),
      _entry('win_made', origin: 'manual', task: _win),
      _entry('hold_mistake', origin: 'mistakes', task: _hold),
      _entry('a_position', kind: 'position'),
    ];
    List<String> ids(List<LibraryEntry> list) => [for (final e in list) e.id];

    test('no filter lets everything through', () {
      expect(ids(filterExercises(entries)), ids(entries));
    });

    test('by what is asked', () {
      expect(ids(filterExercises(entries, ask: ExerciseAsk.find)),
          ['find_book', 'find_made', 'a_position']);
      expect(ids(filterExercises(entries, ask: ExerciseAsk.win)),
          ['win_made', 'a_position']);
      expect(ids(filterExercises(entries, ask: ExerciseAsk.hold)),
          ['hold_mistake', 'a_position']);
    });

    test('by where it came from, and both at once', () {
      expect(ids(filterExercises(entries, origin: ExerciseOrigin.manual)),
          ['find_made', 'win_made', 'a_position']);
      expect(
          ids(filterExercises(entries,
              ask: ExerciseAsk.find, origin: ExerciseOrigin.manual)),
          ['find_made', 'a_position']);
    });
  });

  group('what a pick adds to a homework', () {
    test('find exercises travel together, each game on its own, in order', () {
      final items = homeworkItemsFromExercises([
        _entry('f1'),
        _entry('g1', origin: 'manual', task: _win),
        _entry('f2', origin: 'manual', task: const {'type': 'find'}),
        _entry('g2', origin: 'manual', task: _hold),
      ]);
      expect(items.map((i) => i.kind).toList(), [
        HomeworkItemKind.positions,
        HomeworkItemKind.engineGame,
        HomeworkItemKind.engineGame,
      ]);
      expect(items[0].task, {
        'puzzleIds': ['f1', 'f2']
      });
      expect(items.every((i) => i.itemKey == null), isTrue,
          reason: 'new items have no key until the server mints one');
      expect(items.every((i) => i.gate == false), isTrue);
    });

    test(
        'a game\'s task is copied whole, with its position, and is a task the '
        'server reads', () {
      final item = homeworkItemsFromExercises(
          [_entry('g2', origin: 'manual', task: _hold)]).single;
      expect(item.task['fen'], _kpk);
      expect(item.task['side'], 'b');
      expect(item.task['goal'], 'hold');
      expect(item.task['surviveMoves'], 4);
      expect(item.task['level'], 'tesko');
      expect(item.task.containsKey('type'), isFalse,
          reason:
              '`type` is the exercise\'s word, not the engine-game task\'s');
      // Copied, not shared: editing the item must not edit the entry.
      item.task['goal'] = 'win';
      expect(_hold['goal'], 'hold');
    });

    test('a bare position, or an exercise that cannot be set, adds nothing',
        () {
      expect(
        homeworkItemsFromExercises([
          _entry('7', kind: 'position'),
          _entry('broken', assignable: false),
        ]),
        isEmpty,
      );
    });
  });

  group('the board without opening a board', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets(
        'a row of a position or an exercise draws its board, and a '
        'tutorial\'s does not', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(LibraryList(
        entries: [
          _entry('cust_1', title: 'From the book'),
          _entry('7', kind: 'position', title: 'Saved'),
          _entry('3', kind: 'tutorial', title: 'A tutorial', fen: ''),
        ],
        onOpen: (_) {},
      )));
      await tester.pumpAndSettle();

      Finder boardIn(String rowKey) => find.descendant(
            of: find.byKey(ValueKey(rowKey)),
            matching: find.byType(BoardThumbnail),
          );
      expect(boardIn('library-row-scan-cust_1'), findsOneWidget);
      expect(boardIn('library-row-position-7'), findsOneWidget);
      expect(boardIn('library-row-tutorial-3'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row of an exercise says what it asks', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(LibraryList(
        entries: [
          _entry('g2', origin: 'manual', task: _hold, title: 'Hold it')
        ],
        onOpen: (_) {},
      )));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('library-row-scan-g2')),
          matching: find.textContaining('Draw or better as Black'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the board previews it; tapping the row opens it',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final opened = <String>[];
      await tester.pumpWidget(wrap(LibraryList(
        entries: [
          _entry('g2', origin: 'manual', task: _hold, title: 'Hold it')
        ],
        onOpen: (e) => opened.add(e.id),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BoardThumbnail));
      await tester.pumpAndSettle();
      expect(find.byType(BoardPreviewDialog), findsOneWidget);
      expect(opened, isEmpty, reason: 'a preview is not an opening');

      await tester.tap(find.widgetWithText(TextButton, 'Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BoardPreviewDialog), findsNothing);
      expect(opened, ['g2']);
    });

    testWidgets(
        'the preview says the name, the task and who is to move — in '
        'words', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(BoardPreviewDialog(
        entry: _entry('g2',
            origin: 'manual', task: _hold, title: 'Hold it', fen: _kpk),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Hold it'), findsOneWidget);
      expect(find.text('Draw or better as Black, for 4 moves'), findsOneWidget);
      expect(find.text('Black to move'), findsOneWidget);
      // Bigger than a row's thumbnail, and still inside a 360-wide phone.
      final board = tester.getSize(find.byType(BoardThumbnail));
      expect(board.width, greaterThanOrEqualTo(240));
      expect(board.width, lessThanOrEqualTo(360));
      expect(find.widgetWithText(TextButton, 'Open'), findsNothing,
          reason: 'no `onOpen`, no button: a widget draws what it was given');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bare position\'s preview names no task', (tester) async {
      await tester.pumpWidget(wrap(BoardPreviewDialog(
        entry: _entry('7', kind: 'position', title: 'Saved'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('White to move'), findsOneWidget);
      expect(find.textContaining('Find the move'), findsNothing);
    });
  });
}
