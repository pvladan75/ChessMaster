// exercise_make_test.dart — the gate of phase 2b, docs/PLAN-EXERCISE.md, as
// phase 16 left it: a find exercise asks for one move, and the machinery that
// played a line — `ExerciseLinePlay`, the replies, the list of moves on the
// attempt's wire — is gone, with the tests that stood on it.
//
// It reads `docs/gates/exercise_line_cases.json` — the same file the server's
// `exercise_line.test.js` and `exercise_authoring.test.js` read. The app
// writes a solution and the server judges by it, so both ends stand on one
// fixture (CLAUDE.md rules 12 and 13): what the app's reader accepts is what
// the server accepts, with the same reason when it refuses.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_line.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';

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
        ExerciseStep(accept: ((entry as Map)['accept'] as List).cast<String>()),
    ];

List<Map<String, dynamic>> _wire(List<ExerciseStep> steps) =>
    [for (final s in steps) s.toJson()];

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
  final scholarFirst = solutions['scholarFirst'] as Map<String, dynamic>;

  group('the reader agrees with the server', () {
    test('neither loop below can pass by being empty', () {
      final refused = (fixture['refused'] as List).cast<Map>();
      expect(refused.length, greaterThanOrEqualTo(6));
      expect(refused.any((c) => (c['steps'] as List).length > 1), isTrue,
          reason: 'a solution refused for its length alone');
      expect(solutions.length, greaterThanOrEqualTo(3));
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

    test('every solution the server refuses is refused here, for its reason',
        () {
      for (final c
          in (fixture['refused'] as List).cast<Map<String, dynamic>>()) {
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

  // The group about the writer flattening the trainer's tree stood here
  // until phase 14 (20.9.2026): a find exercise is one move now, so the
  // writer reads the root's first move and its variations and nothing after.
  // Its cases — the alternative, what is not used and is said so, the empty
  // tree, the root wherever the trainer stands — are in
  // `exercise_one_move_test.dart`, on the same fixture.

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
        'solution': scholarFirst['normalised'],
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
          solution: _steps(scholarFirst['steps'] as List),
        );

    test('making an exercise posts the position, the task and the answer',
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
      expect(body['solution'], scholarFirst['steps']);
      expect(body['themes'], ['opening']);

      expect(result.error, isNull);
      expect(result.exercise!.id, 'ex_0123456789abcdef');
      expect(result.exercise!.isGame, isFalse);
      expect(_wire(result.exercise!.solution!), scholarFirst['normalised']);
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
            jsonEncode({'error': '"Qh6" cannot be played here.'}), 422)),
      );
      final result = await api.create(draft(fen: scholar));
      expect(result.exercise, isNull);
      expect(result.status, 422);
      expect(result.error, '"Qh6" cannot be played here.');
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

    test('an answer is sent as one move, and read with the solution', () async {
      final rec = _Recorder();
      final api = AssignmentApiService(
        authToken: 'tok',
        client: MockClient((r) async {
          rec.requests.add(r);
          return http.Response(
              jsonEncode({
                'correct': true,
                'reason': 'another correct move',
                'playedSan': 'Qf3',
                'solutionSan': 'Qh5',
              }),
              200);
        }),
      );
      final result = await api.submitCustomAttempt(
        assignmentId: 42,
        puzzleId: 'ex_0123456789abcdef',
        moveSan: 'Qf3',
        msTaken: 900,
      );
      expect(rec.requests.single.url.path, '/assignments/42/custom-attempt');
      // The whole body: a list of moves no longer travels.
      expect(rec.bodyOf(0), {
        'puzzleId': 'ex_0123456789abcdef',
        'moveSan': 'Qf3',
        'msTaken': 900,
      });

      expect(result!.correct, isTrue);
      expect(result.reason, 'another correct move');
      expect(result.playedSan, 'Qf3');
      expect(result.solutionSan, 'Qh5');
    });
  });
}
