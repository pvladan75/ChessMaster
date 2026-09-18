// exercise_make_test.dart — the gate of phase 2b, docs/PLAN-EXERCISE.md.
//
// Copy into chess_app/test/ and leave it there green, unchanged. Written
// 18.9.2026 by the lead, **red on master**: nothing under
// `lib/features/exercises/` exists, and `submitCustomAttempt` still takes one
// move.
//
// It reads `docs/gates/exercise_line_cases.json` — the same file the server's
// `exercise_line.test.js` and `exercise_authoring.test.js` read. The app
// writes a solution and the server judges by it, so both ends stand on one
// fixture (CLAUDE.md rules 12 and 13): what the app's reader accepts is what
// the server accepts, with the same reason when it refuses.
//
// What the implementer must provide, exactly:
//
//   // lib/features/exercises/models/exercise.dart
//   class ExerciseStep {
//     const ExerciseStep({required this.accept, this.reply});
//     final List<String> accept;     // accept[0] is the move the line goes on from
//     final String? reply;           // the opponent's answer; null on the last step
//     Map<String, dynamic> toJson(); // {'accept': [...], 'reply': reply}
//     static ExerciseStep? fromJson(Object? json);
//   }
//
//   class Exercise {                 // GET/POST/PUT /exercises answers this
//     final String id, fen, sideToMove, name, origin;
//     final String? instruction, blockedReason;
//     final List<String> themes;
//     final Map<String, dynamic> task;       // {'type': 'find'} or the game task
//     final List<ExerciseStep>? solution;    // null for a game
//     final bool assignable;
//     bool get isGame;                       // task['type'] == 'game'
//     static Exercise? fromJson(Map<String, dynamic> json);
//   }
//
//   class ExerciseDraft {            // what the sheet sends
//     const ExerciseDraft({required this.name, this.fen, this.instruction,
//         this.themes = const [], required this.task, this.solution});
//     Map<String, dynamic> toJson(); // omits 'fen' when null, 'solution' when null
//   }
//
//   // lib/features/exercises/models/exercise_line.dart
//   class ExerciseLineReading {
//     final List<ExerciseStep> steps;   // as the board spells them; empty when refused
//     final String? error;              // the reason, in the server's words
//     final bool droppedReply;          // fromTree: the main line ended on the opponent's move
//     final int ignoredReplies;         // fromTree: variations at the opponent's moves
//     bool get ok;
//   }
//   class ExerciseLine {
//     /// The server's `readSolution`, move for move and reason for reason.
//     static ExerciseLineReading read({required String fen, required List<ExerciseStep> steps});
//     /// The trainer's tree, flattened **from its root** — never from
//     /// `tree.current` — and read back through `read` before it is returned.
//     static ExerciseLineReading fromTree(MoveTree tree);
//   }
//
//   // lib/features/exercises/models/exercise_line_play.dart
//   class ExerciseLinePlay {            // the solver's state, no widgets
//     ExerciseLinePlay({required String fen});
//     String get fen;                   // the board to show now
//     List<String> get moves;           // the student's moves the server has accepted
//     bool get done;
//     List<String> attempt(String san); // what to send: [...moves, san]
//     void apply(String san, CustomAttemptResult result);
//   }
//
//   // lib/features/exercises/services/exercise_api_service.dart
//   class ExerciseSaveResult { final Exercise? exercise; final String? error; final int status; }
//   class ExerciseApiService {
//     ExerciseApiService({required String authToken, http.Client? client});
//     Future<ExerciseSaveResult> create(ExerciseDraft draft);              // POST /exercises
//     Future<ExerciseSaveResult> update(String id, ExerciseDraft draft);   // PUT  /exercises/:id
//     Future<Exercise?> load(String id);                                   // GET  /exercises/:id
//   }
//
// and, changed in place:
//
//   AssignmentApiService.submitCustomAttempt({required int assignmentId,
//       required String puzzleId, required List<String> moves, int? msTaken})
//   CustomAttemptResult gains: bool done, bool retry, String? reply,
//       String? continuesOn, int step  (absent on the wire reads as
//       done: correct, retry: false, reply/continuesOn: null, step: 0)

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_line.dart';
import 'package:chess_app/features/exercises/models/exercise_line_play.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/move_tree.dart';

/// The fixture lives beside the plan, one directory above the app.
Map<String, dynamic> _fixture() {
  final file = File('../docs/gates/exercise_line_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared fixture is missing: ${file.absolute.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<ExerciseStep> _steps(List<dynamic> raw) => [
      for (final entry in raw)
        ExerciseStep(
          accept: ((entry as Map)['accept'] as List).cast<String>(),
          reply: entry['reply'] as String?,
        ),
    ];

List<Map<String, dynamic>> _wire(List<ExerciseStep> steps) =>
    [for (final s in steps) s.toJson()];

/// The board after [sans] from [fen], as `chess.dart` spells it.
String _fenAfter(String fen, List<String> sans) {
  final game = chess.Chess.fromFEN(fen);
  for (final san in sans) {
    if (!game.move(san)) throw StateError('$san does not play');
  }
  return game.fen;
}

class _Recorder {
  final requests = <http.Request>[];
  Map<String, dynamic> bodyOf(int index) =>
      jsonDecode(requests[index].body) as Map<String, dynamic>;
}

void main() {
  final fixture = _fixture();
  final positions = (fixture['positions'] as Map).cast<String, String>();
  final solutions = (fixture['solutions'] as Map).cast<String, dynamic>();
  final scholar = positions['scholar']!;
  final scholarLine = solutions['scholarLine'] as Map<String, dynamic>;

  group('the reader agrees with the server', () {
    test('neither loop below can pass by being empty', () {
      expect((fixture['refused'] as List).length, greaterThanOrEqualTo(9));
      expect(solutions.length, greaterThanOrEqualTo(2));
    });

    test('every solution is read back as the board spells it', () {
      for (final entry in solutions.entries) {
        final s = entry.value as Map<String, dynamic>;
        final reading = ExerciseLine.read(
          fen: positions[s['position']]!,
          steps: _steps(s['steps'] as List),
        );
        expect(reading.ok, isTrue, reason: '${entry.key}: ${reading.error}');
        expect(_wire(reading.steps), s['normalised'], reason: entry.key);
      }
    });

    test('every line the server refuses is refused here, for its reason', () {
      for (final c in (fixture['refused'] as List).cast<Map<String, dynamic>>()) {
        final reading = ExerciseLine.read(
          fen: positions[c['position']]!,
          steps: _steps(c['steps'] as List),
        );
        expect(reading.ok, isFalse, reason: c['name'] as String);
        expect(reading.steps, isEmpty, reason: c['name'] as String);
        expect(reading.error, contains(c['why'] as String),
            reason: c['name'] as String);
      }
    });
  });

  group('the writer flattens the trainer\'s tree', () {
    MoveTree tree(String pgn) {
      final parsed = MoveTree.parsePgn(pgn, startingFen: scholar);
      if (parsed == null) throw StateError('the test\'s own PGN did not parse');
      return parsed;
    }

    test('a variation at the student\'s move is an accepted alternative', () {
      final reading =
          ExerciseLine.fromTree(tree('2. Qh5 (2. Qf3) 2... g6 3. Qxe5+'));
      expect(reading.ok, isTrue, reason: reading.error);
      expect(_wire(reading.steps), scholarLine['normalised']);
      expect(reading.droppedReply, isFalse);
      expect(reading.ignoredReplies, 0);
    });

    test('a variation at the opponent\'s move is not, and is counted', () {
      final reading = ExerciseLine.fromTree(
          tree('2. Qh5 g6 (2... Nc6 3. Qxf7#) 3. Qxe5+'));
      expect(reading.ok, isTrue, reason: reading.error);
      expect(_wire(reading.steps), [
        {
          'accept': ['Qh5'],
          'reply': 'g6'
        },
        {
          'accept': ['Qxe5+'],
          'reply': null
        },
      ]);
      expect(reading.ignoredReplies, 1);
    });

    test('a main line that ends on the opponent\'s move loses that move, '
        'and says so', () {
      final reading = ExerciseLine.fromTree(tree('2. Qh5 g6'));
      expect(reading.ok, isTrue, reason: reading.error);
      expect(_wire(reading.steps), [
        {
          'accept': ['Qh5'],
          'reply': null
        },
      ]);
      expect(reading.droppedReply, isTrue);
    });

    test('a tree with no moves is not a solution', () {
      final reading = ExerciseLine.fromTree(MoveTree(startingFen: scholar));
      expect(reading.ok, isFalse);
      expect(reading.error, contains('at least one move'));
    });

    test('the line starts at the root, wherever the trainer is standing', () {
      // The 6.9.2026 bug: `fen` from the current node, the line from the root.
      final t = tree('2. Qh5 (2. Qf3) 2... g6 3. Qxe5+');
      var node = t.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
      }
      t.current = node;
      final reading = ExerciseLine.fromTree(t);
      expect(_wire(reading.steps), scholarLine['normalised']);
    });
  });

  group('the solver plays a line one answer at a time', () {
    CustomAttemptResult answer(Map<String, dynamic> json) =>
        CustomAttemptResult.fromJson(json);

    test('an answer from before lines existed is a finished one-move verdict',
        () {
      final old = answer({'correct': true, 'reason': "the author's move"});
      expect(old.done, isTrue);
      expect(old.retry, isFalse);
      expect(old.reply, isNull);
      expect(old.continuesOn, isNull);
      final wrong = answer({'correct': false, 'reason': 'no'});
      expect(wrong.done, isFalse);
      expect(wrong.retry, isFalse);
    });

    test('a right move puts the reply on the board and is remembered', () {
      final play = ExerciseLinePlay(fen: scholar);
      expect(play.attempt('Qh5'), ['Qh5']);
      play.apply(
          'Qh5',
          answer({
            'correct': true,
            'done': false,
            'reply': 'g6',
            'continuesOn': null,
            'playedSan': 'Qh5',
          }));
      expect(play.fen, _fenAfter(scholar, ['Qh5', 'g6']));
      expect(play.moves, ['Qh5']);
      expect(play.done, isFalse);
      expect(play.attempt('Qxe5+'), ['Qh5', 'Qxe5+']);
    });

    test('after an accepted alternative the board goes on from the author\'s '
        'move, and the list keeps what was played', () {
      final play = ExerciseLinePlay(fen: scholar);
      play.apply(
          'Qf3',
          answer({
            'correct': true,
            'done': false,
            'reply': 'g6',
            'continuesOn': 'Qh5',
            'playedSan': 'Qf3',
          }));
      expect(play.fen, _fenAfter(scholar, ['Qh5', 'g6']),
          reason: 'g6 was written after Qh5; the board shows that line');
      expect(play.moves, ['Qf3'],
          reason: 'the server judges every move sent, and Qf3 is accepted');
    });

    test('a wrong move changes nothing, so it can be played again', () {
      final play = ExerciseLinePlay(fen: scholar);
      play.apply('Qh5',
          answer({'correct': true, 'done': false, 'reply': 'g6'}));
      final before = play.fen;
      play.apply('Qxh7',
          answer({'correct': false, 'done': false, 'retry': true, 'step': 1}));
      expect(play.fen, before);
      expect(play.moves, ['Qh5']);
      expect(play.done, isFalse);
      expect(play.attempt('Qxe5+'), ['Qh5', 'Qxe5+']);
    });

    test('the last right move finishes the line', () {
      final play = ExerciseLinePlay(fen: scholar);
      play.apply('Qh5',
          answer({'correct': true, 'done': false, 'reply': 'g6'}));
      play.apply('Qxe5+', answer({'correct': true, 'done': true}));
      expect(play.done, isTrue);
      expect(play.moves, ['Qh5', 'Qxe5+']);
      expect(play.fen, _fenAfter(scholar, ['Qh5', 'g6', 'Qxe5+']));
    });
  });

  group('the requests', () {
    final exerciseJson = {
      'exercise': {
        'id': 'ex_0123456789abcdef',
        'fen': scholar,
        'sideToMove': 'w',
        'name': 'Queen out early',
        'instruction': null,
        'themes': ['opening'],
        'origin': 'manual',
        'task': {'type': 'find'},
        'solution': scholarLine['normalised'],
        'needsReview': false,
        'assignable': true,
        'blockedReason': null,
      }
    };

    ExerciseDraft draft({String? fen}) => ExerciseDraft(
          name: 'Queen out early',
          fen: fen,
          themes: const ['opening'],
          task: const {'type': 'find'},
          solution: _steps(scholarLine['steps'] as List),
        );

    test('making an exercise posts the position, the task and the line',
        () async {
      final rec = _Recorder();
      final api = ExerciseApiService(
        authToken: 'tok',
        client: MockClient((r) async {
          rec.requests.add(r);
          return http.Response(jsonEncode(exerciseJson), 201);
        }),
      );
      final result = await api.create(draft(fen: scholar));

      expect(rec.requests.single.method, 'POST');
      expect(rec.requests.single.url.path, '/exercises');
      expect(rec.requests.single.headers['Authorization'], 'Bearer tok');
      final body = rec.bodyOf(0);
      expect(body['name'], 'Queen out early');
      expect(body['fen'], scholar);
      expect(body['task'], {'type': 'find'});
      expect(body['solution'], scholarLine['steps']);
      expect(body['themes'], ['opening']);

      expect(result.error, isNull);
      expect(result.exercise!.id, 'ex_0123456789abcdef');
      expect(result.exercise!.isGame, isFalse);
      expect(_wire(result.exercise!.solution!), scholarLine['normalised']);
    });

    test('an edit says nothing about the position', () async {
      final rec = _Recorder();
      final api = ExerciseApiService(
        authToken: 'tok',
        client: MockClient((r) async {
          rec.requests.add(r);
          return http.Response(jsonEncode(exerciseJson), 200);
        }),
      );
      await api.update('ex_0123456789abcdef', draft());
      expect(rec.requests.single.method, 'PUT');
      expect(rec.requests.single.url.path, '/exercises/ex_0123456789abcdef');
      expect(rec.bodyOf(0).containsKey('fen'), isFalse,
          reason: 'absence is a third answer: an exercise keeps its position');
    });

    test('a refusal comes back in the server\'s words, with its status',
        () async {
      final api = ExerciseApiService(
        authToken: 'tok',
        client: MockClient((r) async => http.Response(
            jsonEncode({'error': 'move 1: "Qh6" cannot be played here.'}),
            422)),
      );
      final result = await api.create(draft(fen: scholar));
      expect(result.exercise, isNull);
      expect(result.status, 422);
      expect(result.error, 'move 1: "Qh6" cannot be played here.');
    });

    test('a game exercise is read without a solution', () {
      final game = Exercise.fromJson({
        ...exerciseJson['exercise'] as Map<String, dynamic>,
        'task': {'type': 'game', 'side': 'w', 'goal': 'win', 'fen': scholar},
        'solution': null,
      });
      expect(game!.isGame, isTrue);
      expect(game.solution, isNull);
    });

    test('an answer is sent as every move so far, and read with its reply',
        () async {
      final rec = _Recorder();
      final api = AssignmentApiService(
        authToken: 'tok',
        client: MockClient((r) async {
          rec.requests.add(r);
          return http.Response(
              jsonEncode({
                'correct': true,
                'reason': "the author's move",
                'playedSan': 'Qxe5+',
                'done': false,
                'step': 1,
                'reply': 'Qe7',
                'continuesOn': null,
                'retry': false,
                'solutionSan': null,
              }),
              200);
        }),
      );
      final result = await api.submitCustomAttempt(
        assignmentId: 42,
        puzzleId: 'ex_0123456789abcdef',
        moves: const ['Qh5', 'Qxe5+'],
        msTaken: 900,
      );
      expect(rec.requests.single.url.path, '/assignments/42/custom-attempt');
      final body = rec.bodyOf(0);
      expect(body['moves'], ['Qh5', 'Qxe5+']);
      expect(body.containsKey('moveSan'), isFalse);
      expect(body['puzzleId'], 'ex_0123456789abcdef');

      expect(result!.correct, isTrue);
      expect(result.done, isFalse);
      expect(result.step, 1);
      expect(result.reply, 'Qe7');
      expect(result.retry, isFalse);
    });
  });
}
