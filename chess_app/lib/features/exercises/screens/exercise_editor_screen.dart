// exercise_editor_screen.dart — opening a saved exercise
// (`docs/PLAN-EXERCISE.md`, phase 11, `docs/briefs/
// BRIEF-EXERCISE-FAZA11-APP.md`).
//
// The server has had `GET`/`PUT /exercises/:id` since phase 2a and the app's
// `ExerciseApiService.load`/`.update` since 2b; nothing called them until this
// screen. It loads the exercise, lets the trainer add an alternative by
// **playing it on the board** at the chosen step — the board never plays the
// line forward, it is only for entering alternatives — and take one back, then
// opens `MakeExerciseSheet.edit` over the line as it now stands. The sheet
// does the actual saving; this screen only pops with what the sheet popped
// with, so the caller (the Library) knows a save happened.
//
// **Making one** (phase 14, `ExerciseEditorScreen.make`): the same screen opened
// on a position with no answer yet. A find exercise asks for one move, so there
// is nothing to play anywhere in advance — the first move played on this board
// is the answer, every further one an accepted alternative, „Start over" gives
// the answer back, and Save opens the same sheet over what was played.
import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

import '../models/exercise.dart';
import '../models/exercise_line_edit.dart';
import '../models/exercise_task_words.dart';
import '../services/exercise_api_service.dart';
import '../services/exercise_checker.dart';
import '../widgets/make_exercise_sheet.dart';

class ExerciseEditorScreen extends StatefulWidget {
  const ExerciseEditorScreen({
    super.key,
    required this.api,
    required String this.exerciseId,
    this.availableUserLabels = const [],
    this.checker = defaultExerciseChecker,
  }) : makingFen = null;

  /// A new find exercise on [fen], its move still to be played here.
  const ExerciseEditorScreen.make({
    super.key,
    required this.api,
    required String fen,
    this.availableUserLabels = const [],
    this.checker = defaultExerciseChecker,
  })  : exerciseId = null,
        makingFen = fen;

  final ExerciseApiService api;

  /// The saved exercise this screen opens, or null while one is being made.
  final String? exerciseId;

  /// The position of the exercise being made, or null for a saved one.
  final String? makingFen;

  bool get isMaking => makingFen != null;
  final List<String> availableUserLabels;
  final ExerciseChecker checker;

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  final ChessBoardController _board = ChessBoardController();

  Exercise? _exercise;

  /// Null for a game exercise — it has no line to edit, only its board.
  ExerciseLineEdit? _edit;

  bool _loading = true;
  bool _failed = false;

  /// The line as it stood the last time this screen agreed with the server —
  /// right after loading, and again after a save. [_dirty] compares [_edit]'s
  /// own steps against this rather than against nothing, so a save is not
  /// mistaken for a change still waiting to be made.
  List<ExerciseStep>? _baseline;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  /// Turned to the side the **student** plays. For a find exercise that is
  /// the side to move; for a game it is the task's own `side`, which the
  /// position does not decide — the same rule the Library's thumbnail reads.
  PlayerColor get _orientation {
    final making = widget.makingFen;
    if (making != null) {
      return making.split(' ')[1] == 'b'
          ? PlayerColor.black
          : PlayerColor.white;
    }
    final exercise = _exercise;
    if (exercise == null) return PlayerColor.white;
    final side = exercise.isGame ? exercise.task['side'] : exercise.sideToMove;
    return side == 'b' ? PlayerColor.black : PlayerColor.white;
  }

  /// A move played on the board that has not gone through a save yet.
  bool get _dirty {
    final edit = _edit;
    final baseline = _baseline;
    if (edit == null || baseline == null) return false;
    return !_sameSteps(edit.steps, baseline);
  }

  static bool _sameSteps(List<ExerciseStep> a, List<ExerciseStep> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].accept.length != b[i].accept.length) return false;
      for (var j = 0; j < a[i].accept.length; j++) {
        if (a[i].accept[j] != b[i].accept[j]) return false;
      }
    }
    return true;
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard the unsaved change?'),
        content: const Text(
          'A move played on the board has not been saved. Leaving now '
          'throws it away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const Key('exercise-editor-discard'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard and leave'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _load() async {
    final making = widget.makingFen;
    if (making != null) {
      // Nothing to fetch: the position is the caller's and the answer is
      // about to be played. The baseline is the empty answer, so a move
      // played and not saved is asked about before leaving, as in an edit.
      final edit = ExerciseLineEdit.empty(fen: making);
      _board.loadFen(making);
      setState(() {
        _loading = false;
        _edit = edit;
        _baseline = edit.steps;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final exercise = await widget.api.load(widget.exerciseId!);
    if (!mounted) return;
    if (exercise == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    final edit = exercise.isGame
        ? null
        : ExerciseLineEdit(
            fen: exercise.fen,
            steps: exercise.solution ?? const [],
          );
    // Set before the board is (re)built, the way the solver's own `_load`
    // does it — the controller keeps its state whether or not anything is
    // listening yet.
    _board.loadFen(exercise.fen);
    setState(() {
      _loading = false;
      _exercise = exercise;
      _edit = edit;
      _baseline = edit?.steps;
    });
  }

  /// Turns the move just played into SAN on a fresh copy of the position, the
  /// way `custom_puzzle_solver_screen.dart`'s `_sanFor` does — asked *before*
  /// the move exists on the board, since `move_to_san` throws afterwards.
  static String? _sanFor(String fen, String from, String to, String promotion) {
    try {
      final game = chess.Chess.fromFEN(fen);
      if (!game.move({
        'from': from,
        'to': to,
        'promotion': promotion.isEmpty ? 'q' : promotion,
      })) {
        return null;
      }
      final made = game.history.last.move;
      game.undo_move();
      return game.move_to_san(made);
    } catch (_) {
      return null;
    }
  }

  /// The board is for entering the answer and its alternatives; it never
  /// plays on, so it always goes back to the exercise's position — whether
  /// the move just played was accepted or refused.
  void _onMove(String from, String to, String promotion) {
    final edit = _edit;
    final fen = widget.makingFen ?? _exercise?.fen;
    if (edit == null || fen == null) return;
    final san = _sanFor(fen, from, to, promotion);
    if (san != null) edit.play(san);
    _board.loadFen(fen);
    setState(() {});
  }

  Future<void> _openSaveSheet() async {
    final exercise = _exercise;
    final making = widget.makingFen;
    if (exercise == null && making == null) return;
    final saved = await showDialog<Exercise>(
      context: context,
      builder: (_) => exercise != null
          ? MakeExerciseSheet.edit(
              api: widget.api,
              exercise: exercise,
              steps: _edit?.steps,
              availableUserLabels: widget.availableUserLabels,
              checker: widget.checker,
            )
          : MakeExerciseSheet.withAnswer(
              api: widget.api,
              fen: making!,
              steps: _edit!.steps,
              availableUserLabels: widget.availableUserLabels,
              checker: widget.checker,
            ),
    );
    if (saved == null || !mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(saved);
      return;
    }
    // Nothing to pop back to (this screen is the root, as in a test that
    // opens it on its own): show what was just saved instead of nothing.
    final edit = saved.isGame
        ? null
        : ExerciseLineEdit(fen: saved.fen, steps: saved.solution ?? const []);
    _board.loadFen(saved.fen);
    setState(() {
      _exercise = saved;
      _edit = edit;
      _baseline = edit?.steps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: context.colors.canvas,
        appBar: AppBar(
          toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
          title: Text(_exercise?.name ??
              (widget.isMaking ? 'New exercise' : 'Exercise')),
        ),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_failed || (_exercise == null && !widget.isMaking)) {
      final colors = context.colors;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: colors.textMuted),
              const SizedBox(height: AppSpacing.md),
              const Text('The exercise could not be loaded.'),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return LandscapeBoardLayout.applies(context)
        ? LandscapeBoardLayout(
            board: _boardView,
            panels: _panels(),
            footer: _footer(),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final heightBased = (constraints.maxHeight - 280).clamp(
                200.0,
                520.0,
              );
              final widthBased = (constraints.maxWidth - 24).clamp(
                180.0,
                520.0,
              );
              final boardSize =
                  heightBased < widthBased ? heightBased : widthBased;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _panels(),
                    const SizedBox(height: 10),
                    Center(child: _boardView(boardSize)),
                    const SizedBox(height: AppSpacing.md),
                    ..._footer(),
                  ],
                ),
              );
            },
          );
  }

  Widget _boardView(double boardSize) {
    final edit = _edit;
    return BoardWithCoordinates(
      size: boardSize,
      orientation: _orientation,
      builder: (size) => ChessBoardWithOverlay(
        controller: _board,
        boardOrientation: _orientation,
        boardSize: size,
        isAllowedToMove: edit != null,
        isDrawingMode: false,
        drawingStartSquare: null,
        arrows: const [],
        engineArrows: const [],
        onMove: _onMove,
        onSquareTapForDrawing: (_) {},
      ),
    );
  }

  Widget _panels() {
    final exercise = _exercise;
    final edit = _edit;
    final colors = context.colors;
    if (exercise == null) return _makingPanels(edit!, colors);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            exerciseTaskWords(exercise.task),
            style: AppText.bodyLargeBold,
          ),
          if (edit != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              exerciseSolutionText(edit.steps),
              key: const Key('exercise-editor-line'),
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            if (edit.steps.isNotEmpty &&
                edit.steps.first.accept.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              _alternatives(edit),
            ],
          ],
        ],
      ),
    );
  }

  /// While the exercise is being made: what to do, then what was played —
  /// the answer, and the alternatives, each removable.
  Widget _makingPanels(ExerciseLineEdit edit, AppColorTokens colors) {
    final accept = edit.steps.isEmpty ? const <String>[] : edit.steps[0].accept;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(exerciseTaskWords(const {'type': 'find'}),
              style: AppText.bodyLargeBold),
          const SizedBox(height: AppSpacing.sm),
          if (accept.isEmpty)
            Text(
              'Play the move the student should find.',
              key: const Key('exercise-editor-making-hint'),
              style: AppText.body.copyWith(color: colors.textSecondary),
            )
          else ...[
            Text(
              exerciseSolutionText(edit.steps),
              key: const Key('exercise-editor-line'),
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            _alternatives(
              edit,
              trailing: TextButton.icon(
                key: const Key('exercise-editor-start-over'),
                onPressed: () => setState(edit.clear),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Start over'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The accepted alternatives, each removable.
  Widget _alternatives(ExerciseLineEdit edit, {Widget? trailing}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final san in edit.steps.first.accept.skip(1))
          ActionChip(
            key: Key('exercise-editor-remove-$san'),
            avatar: const Icon(Icons.close, size: 16),
            label: Text(san),
            onPressed: () => setState(() => edit.remove(san)),
          ),
        if (trailing != null) trailing,
      ],
    );
  }

  List<Widget> _footer() {
    final edit = _edit;
    final colors = context.colors;
    return [
      if (edit != null) ...[
        Text(
          // While making, „a variation" is the wrong word: there is no tree
          // here, only moves played one after another from one position.
          widget.isMaking
              ? 'Every other move you play here is accepted as well.'
              : kVariationHint,
          style: AppText.body.copyWith(color: colors.textMuted),
        ),
        if (edit.error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            edit.error!,
            key: const Key('exercise-editor-error'),
            style: AppText.body.copyWith(color: colors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
      SizedBox(
        width: double.infinity,
        // A `FilledButton`, not an `ElevatedButton`: the sheet this opens has
        // its own "Save" `ElevatedButton`, and the two stack while the sheet
        // is a dialog over this screen rather than replacing it — a widget
        // type apart keeps `find.widgetWithText(ElevatedButton, 'Save')'
        // pointed at the sheet's own button alone.
        child: FilledButton(
          key: const Key('exercise-editor-save'),
          // Nothing to save until the move has been played.
          onPressed: widget.isMaking && (edit?.steps.isEmpty ?? true)
              ? null
              : _openSaveSheet,
          child: const Text('Save'),
        ),
      ),
    ];
  }
}
