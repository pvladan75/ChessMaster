// Which shelf a scanned row stands on — `docs/PLAN-EXERCISE.md`, phase 10.
//
// The owner's live pass of 19.9.2026: the Exercises chip was a screen of
// scanned diagrams, and the homework picker listed a screen of rows it then
// refused — „has no solution, so an answer cannot be judged". A scan whose
// book printed no answer is a **position**: it gets its meaning by being put in
// an exercise, and until then it is neither on the Exercises shelf nor offered
// for a homework. A scan *with* its printed answer is a real find-the-move
// exercise and stays one.
//
// The rows here are spelled the way `GET /library/positions` spells them
// (`chess_backend/services/positionLibrary.js`, `listScanned`): every scan
// carries `hasSolution`. The older fixtures beside this file left it out, which
// is why no test could see the difference.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/homework/models/homework_items_from_exercises.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/library/widgets/position_picker_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';

const _krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';

LibraryEntry _scan(
  String id,
  String title, {
  required bool hasSolution,
  Map<String, dynamic>? task,
  bool needsReview = false,
  String? blockedReason,
}) =>
    LibraryEntry.fromJson({
      'kind': 'scan',
      'id': id,
      'title': title,
      'fen': _krk,
      'origin': 'book',
      'task': task ?? const {'type': 'find'},
      'hasSolution': hasSolution,
      // As `listScanned` says it since docs/PLAN-MATERIJAL.md phase 3: an
      // answer to judge, or a game its ending judges.
      'isExercise': hasSolution || task?['type'] == 'game',
      'needsReview': needsReview,
      'sourceTitle': 'TacticsCourse.pdf',
      'sourcePage': 8,
      'assignable': blockedReason == null,
      'blockedReason': blockedReason,
    });

final _answered = _scan('cust_1', 'With its answer', hasSolution: true);
final _bare = _scan('cust_2', 'A bare diagram',
    hasSolution: false,
    blockedReason: 'has no solution, so an answer cannot be judged');
final _game = _scan('cust_3', 'Win it',
    hasSolution: false,
    task: const {'type': 'game', 'fen': _krk, 'side': 'w', 'goal': 'win'});
final _toReview = _scan('cust_4', 'Unsure of this one',
    hasSolution: true,
    needsReview: true,
    blockedReason: 'is marked for review');
final _saved = LibraryEntry.fromJson(const {
  'kind': 'position',
  'id': '7',
  'title': 'Saved from the board',
  'fen': _krk,
  'assignable': false,
});

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(body: child),
    );

void main() {
  group('what an exercise is', () {
    test('a scan with an answer, or a game; never a scan with nothing to judge',
        () {
      expect(_answered.isExercise, isTrue);
      expect(_game.isExercise, isTrue,
          reason: 'a game has no stored solution and is judged by its ending');
      expect(_toReview.isExercise, isTrue,
          reason: 'it cannot be sent yet, and it is still an exercise');
      expect(_bare.isExercise, isFalse);
      expect(_saved.isExercise, isFalse);
    });

    test('each row stands on one shelf, and a bare scan stands with positions',
        () {
      for (final e in [_answered, _game, _toReview]) {
        expect(LibraryChip.exercises.shows(e), isTrue, reason: e.title);
        expect(LibraryChip.positions.shows(e), isFalse, reason: e.title);
      }
      for (final e in [_bare, _saved]) {
        expect(LibraryChip.exercises.shows(e), isFalse, reason: e.title);
        expect(LibraryChip.positions.shows(e), isTrue, reason: e.title);
      }
      expect(LibraryChip.all.shows(_bare), isTrue);
    });

    test('a bare scan adds nothing to a homework', () {
      expect(homeworkItemsFromExercises([_bare]), isEmpty);
      expect(homeworkItemsFromExercises([_answered]), hasLength(1));
    });
  });

  group('the Library', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(LibraryList(
        entries: [_answered, _bare, _game, _toReview, _saved],
        onOpen: (_) {},
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('the Exercises chip lists exercises, and only them',
        (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Exercises'));
      await tester.pumpAndSettle();

      expect(find.text('With its answer'), findsOneWidget);
      expect(find.text('Win it'), findsOneWidget);
      expect(find.text('Unsure of this one'), findsOneWidget);
      expect(find.text('A bare diagram'), findsNothing);
      expect(find.text('Saved from the board'), findsNothing);
    });

    testWidgets(
        'the Positions chip holds the bare scan, and its row claims no task',
        (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Positions'));
      await tester.pumpAndSettle();

      expect(find.text('A bare diagram'), findsOneWidget);
      expect(find.text('Saved from the board'), findsOneWidget);
      expect(find.text('With its answer'), findsNothing);

      final row = find.byKey(const ValueKey('library-row-scan-cust_2'));
      expect(row, findsOneWidget);
      expect(
          find.descendant(of: row, matching: find.textContaining('Find the')),
          findsNothing,
          reason: 'nothing is asked of a diagram with no answer');
      expect(
          find.descendant(
              of: row, matching: find.textContaining('TacticsCourse.pdf')),
          findsOneWidget,
          reason: 'where it came from is still what it is recognised by');
    });
  });

  group('the homework picker', () {
    Future<void> pump(WidgetTester tester, PickerPurpose purpose) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => PositionPickerDialog(
          service: PositionLibraryService(authToken: 't'),
          purpose: purpose,
          loader: ({kind, search}) async =>
              [_answered, _bare, _game, _toReview, _saved],
        ),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'lists what can be an item of a homework, not what it would refuse',
        (tester) async {
      await pump(tester, PickerPurpose.homework);

      expect(find.text('With its answer'), findsOneWidget);
      expect(find.text('Win it'), findsOneWidget);
      expect(find.text('A bare diagram'), findsNothing);
      expect(find.textContaining('has no solution'), findsNothing);
      expect(find.text('Saved from the board'), findsNothing);

      // An exercise the trainer marked as unsure is theirs to fix, so it
      // stays, greyed, with the reason.
      expect(find.text('Unsure of this one'), findsOneWidget);
      expect(find.text('is marked for review'), findsOneWidget);
    });
  });
}
