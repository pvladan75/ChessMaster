// own_exercise_solve_screen.dart — solving one's own exercises alone
// (`docs/PLAN-MATERIJAL.md`, phase 1).
//
// Until this existed an exercise could be answered only as homework, so the
// trainer who made it, the student who scanned their own book and anybody
// training alone had no way to solve one. The board, the verdict and the lock
// after one move are the homework solver's (`CustomPuzzleSolverScreen`, over a
// `SolveTarget`); the answer goes to `POST /exercises/:id/attempt`, which
// judges it as homework is judged and logs it as an `own` attempt.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/models/solve_target.dart';
import 'package:chess_app/features/assignments/screens/custom_puzzle_solver_screen.dart';
import 'package:chess_app/models/user_session.dart';

import '../services/exercise_api_service.dart';
import 'exercise_editor_screen.dart';

/// A [SolveTarget] over the account's own exercises: answers go to [api], and
/// „Open" under a verdict leads to the exercise's own screen.
SolveTarget ownSolveTarget(ExerciseApiService api, {required String title}) =>
    SolveTarget(
      title: title,
      submit: (puzzleId, moveSan, msTaken) =>
          api.attempt(puzzleId, moveSan, msTaken: msTaken),
      onOpen: (context, position) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseEditorScreen(
            api: api,
            exerciseId: position.puzzleId,
          ),
        ),
      ),
    );

/// The side to move, read from a FEN's second field.
String sideToMoveOf(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  return fields.length > 1 && fields[1] == 'b' ? 'b' : 'w';
}

/// The queue from Practise's „My exercises": everything waiting, never-tried
/// first, or — with [retry] — only what failed last time.
class OwnExerciseSolveScreen extends StatefulWidget {
  const OwnExerciseSolveScreen({
    super.key,
    required this.session,
    this.retry = false,
    this.api,
  });

  final UserSession session;
  final bool retry;

  /// Seam for a test, which fakes the server behind it (rule 7).
  final ExerciseApiService? api;

  @override
  State<OwnExerciseSolveScreen> createState() => _OwnExerciseSolveScreenState();
}

class _OwnExerciseSolveScreenState extends State<OwnExerciseSolveScreen> {
  late final ExerciseApiService _api =
      widget.api ?? ExerciseApiService(authToken: widget.session.token);

  OwnExerciseQueue? _queue;
  bool _loading = true;

  String get _title => widget.retry ? 'Retry failed' : 'My exercises';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final queue = await _api.queue();
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    if (_loading || queue == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              // A server that could not be asked is not an empty queue.
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load your exercises.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: _load, child: const Text('Try again')),
                  ],
                ),
        ),
      );
    }
    final List<CustomPosition> positions =
        widget.retry ? queue.retry : queue.all;
    return CustomPuzzleSolverScreen(
      session: widget.session,
      target: ownSolveTarget(_api, title: _title),
      positions: positions,
      startIndex: 0,
    );
  }
}
