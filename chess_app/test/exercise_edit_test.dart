// exercise_edit_test.dart — the gate of phase 11, docs/PLAN-EXERCISE.md.
//
// Copy into chess_app/test/ and leave it there green, unchanged. Written
// 19.9.2026 by the lead, **red on master**: `ExerciseLineEdit`,
// `MakeExerciseSheet.edit` and `ExerciseEditorScreen` do not exist, and the
// Library opens an exercise in Analysis on its bare position.
//
// The server half has existed since phase 2a and is not touched: `GET` and
// `PUT /exercises/:id` (`chess_backend/test/exercise_authoring.test.js` —
// hand-made and scanned rows both), and the app's `ExerciseApiService.load` /
// `.update`, which nothing has called until now.
//
// It reads `docs/gates/exercise_line_cases.json`, the fixture both ends stand
// on. **One reader**: every change to a line goes through `ExerciseLine.read`
// — this phase writes no second rule about what an accepted move is.
//
// What the implementer must provide, exactly:
//
//   // lib/features/exercises/models/exercise_line_edit.dart — pure, no widgets
//   class ExerciseLineEdit {
//     ExerciseLineEdit({required String fen, required List<ExerciseStep> steps});
//     /// As `ExerciseLine.read` spells them. Empty when the line given does
//     /// not replay — [error] then says why.
//     List<ExerciseStep> get steps;
//     /// The last refusal, in the reader's own words; null after a success.
//     String? get error;
//     /// A move played on the editor's board: the first is the answer, every
//     /// further one an accepted alternative, as the board spells it. False —
//     /// with [error] set and [steps] unchanged — when the reader refuses it.
//     /// (Phase 16: this was `add(step, san)` beside `fenBefore(step)`, while
//     /// a solution could be a line.)
//     bool play(String san);
//     /// Takes an alternative back. Never `accept[0]`. False when [san] is
//     /// the main move or is not there.
//     bool remove(String san);
//   }
//
//   // lib/features/exercises/widgets/make_exercise_sheet.dart — added beside
//   // the constructor that exists, which keeps working unchanged
//   const MakeExerciseSheet.edit({
//     Key? key,
//     required ExerciseApiService api,
//     required Exercise exercise,
//     List<ExerciseStep>? steps,            // defaults to exercise.solution
//     required List<String> availableUserLabels,
//     ExerciseChecker checker = defaultExerciseChecker,
//   });
//   // In this mode: the title is „Edit exercise"; name, instruction and labels
//   // start as the exercise's; a game starts on its own goal, number, side and
//   // level; **the kind does not change** — a find exercise offers no „Win" /
//   // „Draw or better" chip and a game offers no „Find the move" — because a
//   // find exercise already sent is judged from this row, as one move; Save
//   // sends `PUT /exercises/:id` **without `fen`** and pops with the saved
//   // [Exercise]. What the sheet does not show (`thinkSeconds`) travels
//   // through untouched.
//   //
//   // In the mode that exists (making one), under a find line that reads: the
//   // sentence `kVariationHint`, exported from this file.
//
//   // lib/features/exercises/screens/exercise_editor_screen.dart
//   class ExerciseEditorScreen extends StatefulWidget {
//     const ExerciseEditorScreen({super.key, required this.api,
//         required this.exerciseId, this.availableUserLabels = const [],
//         this.checker = defaultExerciseChecker});
//   }
//   // Loads through `api.load`. A find exercise: the board
//   // (`ChessBoardWithOverlay`, as the solver draws it) on the exercise's
//   // position, the answer under `Key('exercise-editor-line')` in the sheet's
//   // own format („Qh5 (or Qf3)"), one `Key('exercise-editor-remove-$san')`
//   // per alternative, a refusal under `Key('exercise-editor-error')`, and
//   // `Key('exercise-editor-save')`, which opens `MakeExerciseSheet.edit` over
//   // the answer as it now stands. A move played on the board is
//   // `ExerciseLineEdit.play`. (Until phase 16 the line had steps, each with a
//   // chip to choose it.) A game exercise has no answer: the screen
//   // shows its board and the same Save. When the sheet pops with a saved
//   // exercise the screen pops with it too. What cannot be loaded says
//   // „The exercise could not be loaded." and offers „Try again".
//
//   // lib/features/library/screens/library_screen.dart
//   LibraryScreen gains `ExerciseApiService? exerciseApi` (a seam, like the
//   others). `_open` on an entry that `isExercise` and is not `fromTrainer`
//   pushes `ExerciseEditorScreen`; a saved edit reloads the list. Everything
//   else opens as it does today.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_line.dart';
import 'package:chess_app/features/exercises/models/exercise_line_edit.dart';
import 'package:chess_app/features/exercises/screens/exercise_editor_screen.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/landscape.dart' show loadRoboto;

Map<String, dynamic> _fixture() {
  final file = File('../docs/gates/exercise_line_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared fixture is missing: ${file.absolute.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<ExerciseStep> _steps(List<dynamic> raw) => [
      for (final entry in raw)
        ExerciseStep(accept: ((entry as Map)['accept'] as List).cast<String>())
    ];

List<Map<String, dynamic>> _wire(List<ExerciseStep> steps) =>
    [for (final s in steps) s.toJson()];

/// Answers `/exercises/:id` from [rows], by method, and keeps every request.
/// A `PUT` answers the row with the body's name, themes, task and solution —
/// what the server does — so a test that reads the answer back reads what was
/// sent, and asserts on the request all the same (CLAUDE.md rule 7).
class _Server {
  _Server(this.rows, {this.refuseWith, this.libraryItems = const []});

  final Map<String, Map<String, dynamic>> rows;
  final String? refuseWith;
  final List<Map<String, dynamic>> libraryItems;
  final requests = <http.Request>[];

  Iterable<http.Request> to(String path, String method) =>
      requests.where((r) => r.url.path == path && r.method == method);

  Map<String, dynamic> bodyOf(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/library/positions') {
          return http.Response(jsonEncode({'items': libraryItems}), 200);
        }
        if (path == '/lessons') return http.Response('[]', 200);
        if (path == '/lessons/labels') {
          return http.Response(jsonEncode(['endgame', 'opening']), 200);
        }
        if (!path.startsWith('/exercises/')) return http.Response('{}', 404);

        final id = path.substring('/exercises/'.length);
        final row = rows[id];
        if (row == null) {
          return http.Response(jsonEncode({'error': 'No such exercise.'}), 404);
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'exercise': row}), 200);
        }
        if (request.method == 'PUT') {
          if (refuseWith != null) {
            return http.Response(jsonEncode({'error': refuseWith}), 422);
          }
          final sent = jsonDecode(request.body) as Map<String, dynamic>;
          final saved = {
            ...row,
            'name': sent['name'],
            'instruction': sent['instruction'],
            'themes': sent['themes'],
            'solution': sent['solution'],
            'task': (sent['task'] as Map)['type'] == 'game'
                ? {...(sent['task'] as Map), 'fen': row['fen']}
                : sent['task']
          };
          rows[id] = saved.cast<String, dynamic>();
          return http.Response(jsonEncode({'exercise': saved}), 200);
        }
        return http.Response('{}', 405);
      });
}

const _kingAndRook = '4k3/8/8/8/8/8/8/4K2R b K - 0 1';

UserSession _session() => UserSession(
    token: 'tok',
    id: 1,
    email: 't@example.com',
    name: 'Trainer',
    role: 'trener');

ThemeData _theme() =>
    ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]);

void main() {
  final fixture = _fixture();
  final positions = (fixture['positions'] as Map).cast<String, String>();
  final solutions = (fixture['solutions'] as Map).cast<String, dynamic>();
  final scholar = positions['scholar']!;
  final backRank = positions['backRank']!;
  final scholarFirst =
      _steps((solutions['scholarFirst'] as Map)['normalised'] as List);
  final backRankMate =
      _steps((solutions['backRankMate'] as Map)['normalised'] as List);

  Map<String, dynamic> findRow({String origin = 'manual'}) => {
        'id': 'ex_find',
        'fen': scholar,
        'sideToMove': 'w',
        'name': 'Queen out early',
        'instruction': 'Punish the early queen.',
        'themes': ['opening'],
        'origin': origin,
        'task': {'type': 'find'},
        'solution': _wire(scholarFirst),
        'needsReview': false,
        'assignable': true,
        'blockedReason': null
      };

  Map<String, dynamic> gameRow() => {
        'id': 'ex_game',
        'fen': _kingAndRook,
        'sideToMove': 'b',
        'name': 'Hold the ending',
        'instruction': null,
        'themes': <String>[],
        'origin': 'manual',
        'task': {
          'type': 'game',
          'fen': _kingAndRook,
          'side': 'b',
          'goal': 'hold',
          'surviveMoves': 7,
          'level': 'tesko',
          'thinkSeconds': 3,
          'plyCap': 300
        },
        'solution': null,
        'needsReview': false,
        'assignable': true,
        'blockedReason': null
      };

  setUpAll(loadRoboto);

  // -------------------------------------------------------------------------
  group('ExerciseLineEdit', () {
    test('reads the line it is given the way the one reader does', () {
      final raw = _steps((solutions['backRankMate'] as Map)['steps'] as List);
      final edit = ExerciseLineEdit(fen: backRank, steps: raw);
      expect(edit.error, isNull);
      expect(_wire(edit.steps), _wire(backRankMate),
          reason: 'spelled by the board: Rd8 is Rd8#');
    });

    test('an answer the board cannot play is no answer, and says why', () {
      final edit = ExerciseLineEdit(fen: scholar, steps: const [
        ExerciseStep(accept: ['Qh6'])
      ]);
      expect(edit.steps, isEmpty);
      expect(edit.error, contains('"Qh6" cannot be played here'));
    });

    test('a move is accepted as well, after the others, as the board spells it',
        () {
      final edit = ExerciseLineEdit(fen: backRank, steps: backRankMate);
      expect(edit.play('Re8'), isTrue);
      expect(edit.error, isNull);
      expect(edit.steps.single.accept, ['Rd8#', 'Re8#']);
    });

    test('a row that still holds a line is no answer, and says what is asked',
        () {
      final edit = ExerciseLineEdit(fen: scholar, steps: const [
        ExerciseStep(accept: ['Qh5']),
        ExerciseStep(accept: ['Qxe5+']),
      ]);
      expect(edit.steps, isEmpty);
      expect(edit.error, ExerciseLine.oneMove);
    });

    test('what the reader refuses is refused in its words and changes nothing',
        () {
      final edit = ExerciseLineEdit(fen: scholar, steps: scholarFirst);
      final before = _wire(edit.steps);

      expect(edit.play('Qh6'), isFalse);
      expect(edit.error, contains('"Qh6" cannot be played here'));
      expect(_wire(edit.steps), before);

      expect(edit.play('Qf3'), isFalse);
      expect(edit.error, contains('The same move is accepted twice'));
      expect(_wire(edit.steps), before);

      // A success clears the refusal that stood before it.
      expect(edit.play('Nf3'), isTrue);
      expect(edit.error, isNull);
    });

    test('the answer accepts no more than the server does', () {
      final edit = ExerciseLineEdit(fen: scholar, steps: scholarFirst);
      for (final san in ['Nf3', 'Nc3', 'Bc4', 'd4', 'd3', 'a3']) {
        expect(edit.play(san), isTrue, reason: san);
      }
      expect(edit.steps.single.accept, hasLength(8));
      expect(edit.play('h3'), isFalse);
      expect(edit.error, contains('More than 8 accepted moves'));
      expect(edit.steps.single.accept, hasLength(8));
    });

    // Until 21.9.2026 this case said „the main move cannot" be taken back.
    // Superseded openly on the owner's word (TODO-provera 196.3): it can, and
    // the first alternative becomes the answer.
    test('an alternative can be taken back, and so can the main move', () {
      final edit = ExerciseLineEdit(fen: scholar, steps: scholarFirst);
      expect(edit.remove('Qg4'), isFalse, reason: 'not there');
      expect(edit.steps.single.accept, ['Qh5', 'Qf3']);
      expect(edit.remove('Qf3'), isTrue);
      expect(edit.steps.single.accept, ['Qh5']);
      expect(edit.play('Qf3'), isTrue);
      expect(edit.remove('Qh5'), isTrue);
      expect(edit.steps.single.accept, ['Qf3']);
    });
  });

  // -------------------------------------------------------------------------
  group('the sheet, editing', () {
    /// Opens the sheet the way its callers do — through `showDialog` — and
    /// hands back a reader of what it popped with (null while it is open).
    Future<Exercise? Function()> openSheet(
        WidgetTester tester, _Server server, Exercise exercise,
        {List<ExerciseStep>? steps, Size size = const Size(360, 640)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Exercise? popped;
      await tester.pumpWidget(MaterialApp(
          theme: _theme(),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () async {
                        popped = await showDialog<Exercise>(
                            context: context,
                            builder: (_) => MakeExerciseSheet.edit(
                                    api: ExerciseApiService(
                                        authToken: 'tok',
                                        client: server.client()),
                                    exercise: exercise,
                                    steps: steps,
                                    availableUserLabels: const [
                                      'endgame',
                                      'opening'
                                    ]));
                      },
                      child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(MakeExerciseSheet), findsOneWidget);
      return () => popped;
    }

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'opens on what the exercise already says, at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final server = _Server({'ex_find': findRow()});
        final exercise = Exercise.fromJson(findRow())!;
        await openSheet(tester, server, exercise, size: size);
        expect(tester.takeException(), isNull);

        expect(find.text('Edit exercise'), findsOneWidget);
        expect(find.text('Make exercise'), findsNothing);
        expect(
            tester
                .widget<TextField>(find.byKey(const Key('exercise-name-field')))
                .controller!
                .text,
            'Queen out early');
        expect(
            tester
                .widget<TextField>(
                    find.byKey(const Key('exercise-instruction-field')))
                .controller!
                .text,
            'Punish the early queen.');
        expect(find.textContaining('or Qf3'), findsOneWidget);

        // The kind does not change under a homework already sent.
        expect(find.byKey(const Key('exercise-ask-find')), findsOneWidget);
        expect(find.byKey(const Key('exercise-ask-win')), findsNothing);
        expect(find.byKey(const Key('exercise-ask-hold')), findsNothing);

        // Nothing was typed and Save is already on: the name is there.
        final save = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save'));
        expect(save.onPressed, isNotNull);
      });
    }

    testWidgets('saves over the exercise: PUT, no position, the steps given',
        (tester) async {
      final server = _Server({'ex_find': findRow()});
      final exercise = Exercise.fromJson(findRow())!;
      final edit = ExerciseLineEdit(fen: scholar, steps: scholarFirst)
        ..play('Nf3');

      final popped =
          await openSheet(tester, server, exercise, steps: edit.steps);

      await tester.enterText(
          find.byKey(const Key('exercise-name-field')), 'Queen out, punished');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(server.to('/exercises', 'POST'), isEmpty,
          reason: 'an edit never makes a second exercise');
      final put = server.to('/exercises/ex_find', 'PUT').toList();
      expect(put, hasLength(1));
      final body = server.bodyOf(put.single);
      expect(body.containsKey('fen'), isFalse,
          reason: 'an edit says nothing about the position');
      expect(body['name'], 'Queen out, punished');
      expect(body['instruction'], 'Punish the early queen.');
      expect(body['themes'], ['opening'],
          reason: 'labels nobody touched are still the exercise\'s');
      expect(body['task'], {'type': 'find'});
      expect(body['solution'], _wire(edit.steps));
      expect((body['solution'] as List).first['accept'], ['Qh5', 'Qf3', 'Nf3']);

      expect(find.byType(MakeExerciseSheet), findsNothing,
          reason: 'the sheet closed');
      expect(popped()?.id, 'ex_find');
      expect(popped()?.name, 'Queen out, punished');
    });

    testWidgets('a refusal stays in the sheet, in the server\'s words',
        (tester) async {
      final server = _Server({'ex_find': findRow()},
          refuseWith: 'move 1: "Qh6" cannot be played here.');
      final exercise = Exercise.fromJson(findRow())!;
      await openSheet(tester, server, exercise);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(MakeExerciseSheet), findsOneWidget);
      expect(find.text('move 1: "Qh6" cannot be played here.'), findsOneWidget);
    });

    testWidgets('a game opens on its own answers and sends them back whole',
        (tester) async {
      final server = _Server({'ex_game': gameRow()});
      final exercise = Exercise.fromJson(gameRow())!;
      await openSheet(tester, server, exercise);
      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('exercise-ask-find')), findsNothing);
      expect(
          tester
              .widget<ChoiceChip>(find.byKey(const Key('exercise-ask-hold')))
              .selected,
          isTrue);
      expect(
          tester
              .widget<ChoiceChip>(
                  find.byKey(const Key('exercise-length-forMoves')))
              .selected,
          isTrue);
      expect(
          tester
              .widget<TextField>(
                  find.byKey(const Key('exercise-for-moves-field')))
              .controller!
              .text,
          '7');
      expect(
          tester
              .widget<ChoiceChip>(find.byKey(const Key('exercise-side-b')))
              .selected,
          isTrue);
      expect(
          tester
              .widget<ChoiceChip>(find.byKey(const Key('exercise-level-tesko')))
              .selected,
          isTrue);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      final body = server.bodyOf(server.to('/exercises/ex_game', 'PUT').single);
      expect(body.containsKey('fen'), isFalse);
      expect(body.containsKey('solution'), isFalse,
          reason: 'a game has no line, and says nothing about one');
      final task = (body['task'] as Map).cast<String, dynamic>();
      expect(task['type'], 'game');
      expect(task['side'], 'b');
      expect(task['goal'], 'hold');
      expect(task['surviveMoves'], 7);
      expect(task['level'], 'tesko');
      expect(task['thinkSeconds'], 3,
          reason: 'what the sheet does not show is not lost by an edit');
    });

    testWidgets('making one says how an alternative is given', (tester) async {
      final tree = MoveTree.parsePgn('2. Qh5 (2. Qf3) 2... g6 3. Qxe5+',
          startingFen: scholar)!;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: _theme(),
          home: Scaffold(
              body: MakeExerciseSheet(
                  api: ExerciseApiService(
                      authToken: 'tok',
                      client:
                          MockClient((r) async => http.Response('{}', 500))),
                  moveTree: tree,
                  availableUserLabels: const []))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(kVariationHint, contains('variation'));
      expect(find.text(kVariationHint), findsOneWidget);

      // A game has no line, so nothing to say about variations.
      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      expect(find.text(kVariationHint), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('the editor screen', () {
    Future<_Server> pumpEditor(
        WidgetTester tester, Map<String, Map<String, dynamic>> rows, String id,
        {Size size = const Size(360, 640)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final server = _Server(rows);
      await tester.pumpWidget(MaterialApp(
          theme: _theme(),
          home: ExerciseEditorScreen(
              api:
                  ExerciseApiService(authToken: 'tok', client: server.client()),
              exerciseId: id,
              availableUserLabels: const ['endgame', 'opening'])));
      await tester.pumpAndSettle();
      return server;
    }

    String lineText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('exercise-editor-line')))
        .data!;

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'shows the exercise it was asked for, at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final server = await pumpEditor(
            tester, {'ex_find': findRow()}, 'ex_find',
            size: size);
        expect(tester.takeException(), isNull);
        expect(server.to('/exercises/ex_find', 'GET'), hasLength(1));
        expect(find.text('Queen out early'), findsWidgets);
        expect(lineText(tester), 'Qh5 (or Qf3)');
        expect(find.byType(ChessBoardWithOverlay), findsOneWidget);
        expect(find.byKey(const Key('exercise-editor-save')), findsOneWidget);
      });
    }

    testWidgets('a move played on the board is accepted as well — and saved',
        (tester) async {
      final server =
          await pumpEditor(tester, {'ex_find': findRow()}, 'ex_find');

      // 1.Nf3, on the board — played on the controller first, as the real
      // board does before it reports a move, so „goes back" has something to
      // go back from.
      final board = tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
      board.controller.makeMove(from: 'g1', to: 'f3');
      expect(
          MoveTree.samePosition(board.controller.getFen(), scholar), isFalse);
      board.onMove('g1', 'f3', '');
      await tester.pumpAndSettle();
      expect(lineText(tester), 'Qh5 (or Qf3, Nf3)');
      // Since 21.9.2026 the move is shown for [kExerciseAnswerHold] before the
      // board goes back (TODO-provera 196.3); the rule below is unchanged, it
      // just holds once the move has been seen.
      await tester.pump(kExerciseAnswerHold);
      await tester.pump();
      expect(
          MoveTree.samePosition(
              tester
                  .widget<ChessBoardWithOverlay>(
                      find.byType(ChessBoardWithOverlay))
                  .controller
                  .getFen(),
              scholar),
          isTrue,
          reason: 'the board never plays on: it goes back to the position');

      // Twice is refused, in the reader's words, and the answer stays.
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .onMove('g1', 'f3', '');
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const Key('exercise-editor-error')))
              .data,
          contains('The same move is accepted twice'));
      expect(lineText(tester), 'Qh5 (or Qf3, Nf3)');

      // One taken back.
      await tester
          .ensureVisible(find.byKey(const Key('exercise-editor-remove-Qf3')));
      await tester.tap(find.byKey(const Key('exercise-editor-remove-Qf3')));
      await tester.pumpAndSettle();
      expect(lineText(tester), 'Qh5 (or Nf3)');
      // Until 21.9.2026: „the main move is not an alternative", with no ×.
      // Superseded openly (TODO-provera 196.3) — the answer has its ×, named
      // as the answer in words.
      expect(
          find.byKey(const Key('exercise-editor-remove-Qh5')), findsOneWidget);
      expect(find.text('Qh5 · answer'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing,
          reason: 'one move: there are no steps to choose between');

      await tester.ensureVisible(find.byKey(const Key('exercise-editor-save')));
      await tester.tap(find.byKey(const Key('exercise-editor-save')));
      await tester.pumpAndSettle();
      expect(find.byType(MakeExerciseSheet), findsOneWidget);
      expect(find.text('Edit exercise'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      final body = server.bodyOf(server.to('/exercises/ex_find', 'PUT').single);
      expect(body['solution'], [
        {
          'accept': ['Qh5', 'Nf3']
        }
      ]);
      expect(body.containsKey('fen'), isFalse);
    });

    testWidgets('a move the position does not allow changes nothing',
        (tester) async {
      await pumpEditor(tester, {'ex_find': findRow()}, 'ex_find');
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .onMove('d1', 'h6', '');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(lineText(tester), 'Qh5 (or Qf3)');
    });

    testWidgets('a game has no line: its board, and the same sheet',
        (tester) async {
      final server =
          await pumpEditor(tester, {'ex_game': gameRow()}, 'ex_game');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('exercise-editor-line')), findsNothing);

      await tester.tap(find.byKey(const Key('exercise-editor-save')));
      await tester.pumpAndSettle();
      expect(find.text('Edit exercise'), findsOneWidget);
      expect(find.byKey(const Key('exercise-ask-find')), findsNothing);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(server.to('/exercises/ex_game', 'PUT'), hasLength(1));
    });

    testWidgets('what cannot be loaded says so, and can be asked again',
        (tester) async {
      final rows = <String, Map<String, dynamic>>{};
      final server = await pumpEditor(tester, rows, 'ex_find');
      expect(find.text('The exercise could not be loaded.'), findsOneWidget);
      expect(find.byKey(const Key('exercise-editor-save')), findsNothing);

      rows['ex_find'] = findRow();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(server.to('/exercises/ex_find', 'GET'), hasLength(2));
      expect(lineText(tester), 'Qh5 (or Qf3)');
    });
  });

  // -------------------------------------------------------------------------
  group('the door in the Library', () {
    Map<String, dynamic> item(String id, String title,
            {bool hasSolution = true,
            bool fromTrainer = false,
            String origin = 'manual'}) =>
        {
          'kind': 'scan',
          'id': id,
          'title': title,
          'fen': scholar,
          'assignable': hasSolution,
          'hasSolution': hasSolution,
          'isExercise': hasSolution,
          'fromTrainer': fromTrainer,
          'origin': origin,
          'task': {'type': 'find'}
        };

    Future<_Server> pumpLibrary(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final server = _Server({
        'ex_find': findRow(),
        'cust_book': {...findRow(origin: 'book'), 'id': 'cust_book'}
      }, libraryItems: [
        item('ex_find', 'Queen out early'),
        item('cust_book', 'From the book', origin: 'book'),
        item('cust_theirs', 'My trainer made this', fromTrainer: true)
      ]);
      final client = server.client();
      await tester.pumpWidget(MaterialApp(
          theme: _theme(),
          home: LibraryScreen(
              session: _session(),
              lessonApi: LessonApiService(authToken: 'tok', client: client),
              positionLibrary:
                  PositionLibraryService(authToken: 'tok', client: client),
              exerciseApi:
                  ExerciseApiService(authToken: 'tok', client: client))));
      await tester.pumpAndSettle();
      return server;
    }

    for (final id in ['ex_find', 'cust_book']) {
      testWidgets('tapping my own exercise ($id) opens it, not Analysis',
          (tester) async {
        final server = await pumpLibrary(tester);
        await tester.tap(find.descendant(
            of: find.byKey(ValueKey('library-row-scan-$id')),
            matching: find.byType(ListTile)));
        await tester.pumpAndSettle();

        expect(find.byType(ExerciseEditorScreen), findsOneWidget);
        expect(server.to('/exercises/$id', 'GET'), hasLength(1),
            reason: 'the editor asked for this exercise, by its id');
      });
    }

    testWidgets('a saved edit is read back into the list', (tester) async {
      final server = await pumpLibrary(tester);
      final listsBefore = server.to('/library/positions', 'GET').length;

      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('library-row-scan-ex_find')),
          matching: find.byType(ListTile)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('exercise-editor-save')));
      await tester.tap(find.byKey(const Key('exercise-editor-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(server.to('/exercises/ex_find', 'PUT'), hasLength(1));
      expect(find.byType(ExerciseEditorScreen), findsNothing,
          reason: 'saved, and back in the Library');
      expect(server.to('/library/positions', 'GET').length, listsBefore + 1);
    });

    testWidgets("my trainer's exercise is not mine to open for editing",
        (tester) async {
      final server = await pumpLibrary(tester);
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('library-row-scan-cust_theirs')),
          matching: find.byType(ListTile)));
      await tester.pump();
      // Whatever that tap does today (it asks the router for Analysis, which a
      // bare MaterialApp does not have) is not this gate's business; that it
      // does not open the editor, or ask for the exercise, is.
      tester.takeException();
      expect(find.byType(ExerciseEditorScreen), findsNothing);
      expect(server.to('/exercises/cust_theirs', 'GET'), isEmpty);
    });
  });
}
