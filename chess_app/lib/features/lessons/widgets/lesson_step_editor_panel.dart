import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess;

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/features/lessons/widgets/preview_assignment_api_service.dart';

class LessonStepEditorPanel extends StatefulWidget {
  final UserSession session;
  final LessonApiService api;
  final Map<String, dynamic> lesson;

  const LessonStepEditorPanel({
    super.key,
    required this.session,
    required this.api,
    required this.lesson,
  });

  @override
  State<LessonStepEditorPanel> createState() => _LessonStepEditorPanelState();
}

class _LessonStepEditorPanelState extends State<LessonStepEditorPanel> {
  late List<Map<String, dynamic>> _steps;
  int _selectedIndex = 0;
  bool _isSaving = false;

  late TextEditingController _instructionCtrl;
  final ChessBoardController _boardCtrl = ChessBoardController();

  /// Bumped when a kind change is refused, so the dropdown is rebuilt from the
  /// step instead of keeping the selection the trainer took back.
  ///
  /// `DropdownButtonFormField` is a form field: it holds the value the user
  /// picked in its own state, and a rebuild alone will not move it back. Without
  /// this the dropdown reads „Traži potez na tabli" over a step that is still
  /// a demonstration — the trainer believes they asked something and did not.
  int _kindEpoch = 0;

  @override
  void initState() {
    super.initState();
    _steps = ((widget.lesson['position_list'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _instructionCtrl = TextEditingController();
    _loadStep();
  }

  @override
  void dispose() {
    _instructionCtrl.dispose();
    _boardCtrl.dispose();
    super.dispose();
  }

  void _loadStep() {
    if (_steps.isEmpty || _selectedIndex >= _steps.length) return;
    final step = _steps[_selectedIndex];
    _instructionCtrl.text = step['instruction']?.toString() ?? '';
    final fen = step['fen']?.toString() ?? '8/8/8/8/8/8/8/8 w - - 0 1';
    _boardCtrl.loadFen(fen);
  }

  void _updateStep(String key, dynamic value) {
    if (_steps.isEmpty || _selectedIndex >= _steps.length) return;
    setState(() {
      if (value == null) {
        _steps[_selectedIndex].remove(key);
      } else {
        _steps[_selectedIndex][key] = value;
      }
    });
  }

  /// Whether [step] carries a line the child can walk.
  ///
  /// Read through `LessonStepLine`, which is the one reader of a step's line in
  /// this app and the same read the student's screen performs. A second opinion
  /// about what a PGN contains is how this codebase ended up with two parsers.
  static bool _hasLine(Map<String, dynamic> step) {
    final pgn = step['pgn']?.toString() ?? '';
    if (pgn.trim().isEmpty) return false;
    final read = LessonStepLine.read(
      fen: step['fen']?.toString() ?? '',
      pgn: pgn,
    );
    return read.line.movesSan.isNotEmpty;
  }

  /// True for a step that would hand the child its own answer.
  static bool _leaksAnswer(Map<String, dynamic> step) =>
      step['kind']?.toString() == 'ask_move' && _hasLine(step);

  /// The kind the trainer picked, and the one question worth asking about it.
  ///
  /// A step's `pgn` is not redacted on its way to the child — the line *is* the
  /// lesson — and `LessonViewerScreen` draws the move strip for every kind. So a
  /// question whose line runs on from the very position being asked about shows
  /// the answer to anyone who presses „Sledeći potez".
  ///
  /// Asked rather than done: deleting a trainer's line and their words inside it
  /// because they touched a dropdown is not a repair, it is a loss they did not
  /// agree to. Refusing outright is no better — it leaves them with a position
  /// they cannot ask about and no way forward. The demonstration belongs in the
  /// step *before* the question, which the viewer joins without reloading the
  /// board.
  Future<void> _chooseKind(String? value) async {
    if (value == null || _steps.isEmpty || _selectedIndex >= _steps.length) {
      return;
    }

    if (value == 'ask_move' && _hasLine(_steps[_selectedIndex])) {
      final drop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dete bi videlo odgovor'),
          content: const Text(
            'Ovaj korak nosi liniju, a dete može da je prolista dugmetom '
            '„Sledeći potez" pre nego što odgovori. Demonstracija ide u korak '
            'ispred pitanja — pitanje ostaje samo pozicija.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Ukloni liniju i postavi pitanje'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (drop != true) {
        setState(() => _kindEpoch += 1);
        return;
      }
      _updateStep('pgn', null);
    }

    _updateStep('kind', value == 'show' ? null : value);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Save current instruction
    final instr = _instructionCtrl.text.trim();
    _updateStep('instruction', instr.isEmpty ? null : instr);

    // The one refusal this editor makes, and it is not a copy of one of the
    // server's: the server stores `pgn` as opaque text and has no PGN reader,
    // so it cannot make this one, and giving it one would be a second parser
    // disagreeing with this app's. The combination was reachable for as long as
    // this panel has existed, so a lesson opened today may already be in it —
    // and the quiet version of this bug is a child who stops getting anything
    // wrong.
    final leaking = _steps.where(_leaksAnswer).toList();
    if (leaking.isNotEmpty) {
      final names = leaking
          .map((s) => '„${s['title']?.toString() ?? 'Korak'}"')
          .join(', ');
      setState(() => _isSaving = false);
      AppFeedback.show(
        context,
        () => SnackBar(
          content: Text('Nije sačuvano. $names nosi liniju u kojoj je odgovor '
              '— ukloni liniju ili promeni tip zadatka.'),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }

    final err = await widget.api.update(
      id: widget.lesson['id'],
      title: widget.lesson['title'],
      description: widget.lesson['description'],
      tags: (widget.lesson['tags'] as List?)?.map((e) => e.toString()).toList(),
      fen: widget.lesson['fen'],
      pgn: widget.lesson['pgn'],
      positionList: _steps,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (err != null) {
      AppFeedback.show(
          context,
          () => SnackBar(
                content: Text(err),
                backgroundColor: context.colors.danger,
              ));
    } else {
      AppFeedback.show(
          context,
          () => SnackBar(
                content: const Text('Korak je sačuvan.'),
                backgroundColor: context.colors.success,
              ));
    }
  }

  void _preview() {
    // Save instruction to map before previewing
    final instr = _instructionCtrl.text.trim();
    _updateStep('instruction', instr.isEmpty ? null : instr);

    final detail = AssignmentDetail(
      assignment: Assignment(
        id: widget.lesson['id'] ?? 0,
        title: widget.lesson['title'] ?? '',
      ),
      items: List.generate(
          _steps.length,
          (i) => AssignmentItem(
                puzzleId: null,
                position: i,
                attemptedAt: i < _selectedIndex ? DateTime.now() : null,
              )),
      steps: _steps.map((m) => LessonStep.fromJson(m)).toList(),
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonViewerScreen(
        session: widget.session,
        detail: detail,
        api: PreviewAssignmentApiService(),
      ),
    ));
  }

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

  /// Shown on a step that already asks for a move and already carries a line.
  ///
  /// Those exist: the combination was reachable for as long as this panel has
  /// been, so the fix cannot only be a question asked at the moment the kind is
  /// chosen. A trainer opening an old lesson has to be told which step is
  /// showing children its own answer, and be able to fix it where they are
  /// standing.
  Widget _buildAnswerLeakWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dete bi videlo odgovor',
              style: AppText.bodyBold.copyWith(color: context.colors.danger)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ovo pitanje nosi liniju koju dete može da prolista dugmetom '
            '„Sledeći potez" pre nego što odgovori. Dok je tu, korak se ne čuva.',
            style: AppText.body.copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => _updateStep('pgn', null),
              child: const Text('Ukloni liniju'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicesEditor(Map<String, dynamic> step) {
    final choicesList = (step['choices'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('Ponuđeni odgovori', style: AppText.bodyBold),
        RadioGroup<int>(
          groupValue: choicesList.indexWhere((c) => c['correct'] == true),
          onChanged: (val) {
            if (val == null) return;
            final newChoices = List<Map<String, dynamic>>.from(
                choicesList.map((c) => Map<String, dynamic>.from(c as Map)));
            for (int j = 0; j < newChoices.length; j++) {
              newChoices[j]['correct'] = (j == val);
            }
            _updateStep('choices', newChoices);
          },
          child: Column(
            children: [
              for (int i = 0; i < choicesList.length; i++)
                Row(
                  children: [
                    Radio<int>(value: i),
                    Expanded(
                      child: TextFormField(
                        initialValue: choicesList[i]['text'],
                        onChanged: (val) {
                          final newChoices = List<Map<String, dynamic>>.from(
                              choicesList.map(
                                  (c) => Map<String, dynamic>.from(c as Map)));
                          newChoices[i]['text'] = val;
                          _updateStep('choices', newChoices);
                        },
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: context.colors.danger),
                      onPressed: () {
                        final newChoices = List<Map<String, dynamic>>.from(
                            choicesList.map(
                                (c) => Map<String, dynamic>.from(c as Map)));
                        newChoices.removeAt(i);
                        _updateStep('choices', newChoices);
                      },
                    )
                  ],
                ),
            ],
          ),
        ),
        if (choicesList.length < 4)
          TextButton(
            onPressed: () {
              final newChoices = List<Map<String, dynamic>>.from(
                  choicesList.map((c) => Map<String, dynamic>.from(c as Map)));
              newChoices.add({'text': '', 'correct': newChoices.isEmpty});
              _updateStep('choices', newChoices);
            },
            child: const Text('Dodaj odgovor'),
          ),
      ],
    );
  }

  Widget _buildEditor() {
    if (_steps.isEmpty) return const Text('Nema koraka.');
    final step = _steps[_selectedIndex];
    final kind = step['kind']?.toString() ?? 'show';

    final isBlackToMove = (step['fen']?.toString() ?? '').contains(' b ');
    final orientation = isBlackToMove ? PlayerColor.black : PlayerColor.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_leaksAnswer(step)) _buildAnswerLeakWarning(),
          TextField(
            key: const Key('step-instruction'),
            controller: _instructionCtrl,
            decoration: const InputDecoration(
              labelText: 'Zadatak za učenika',
              hintText: 'npr. Beli je na potezu — nađi dobitak figure',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
          // The subtree's key changes with the step, with the kind, and every
          // time a change is taken back — see [_kindEpoch] — which tears the
          // field down and builds it from the step again. Without that it goes
          // on showing a kind the step does not have. The field's own key stays
          // put, because it is the handle the tests reach it by.
          KeyedSubtree(
              key: ValueKey('kind-$_selectedIndex-$kind-$_kindEpoch'),
              child: DropdownButtonFormField<String>(
                key: const Key('step-kind'),
                initialValue: kind,
                items: const [
                  DropdownMenuItem(value: 'show', child: Text('Samo prikaži')),
                  DropdownMenuItem(
                      value: 'ask_move', child: Text('Traži potez na tabli')),
                  DropdownMenuItem(
                      value: 'ask_choice',
                      child: Text('Traži odgovor iz liste')),
                ],
                onChanged: _chooseKind,
                decoration: const InputDecoration(
                  labelText: 'Tip zadatka',
                  border: OutlineInputBorder(),
                ),
              )),
          if (kind == 'ask_choice') _buildChoicesEditor(step),
          const SizedBox(height: AppSpacing.md),
          if (kind == 'ask_move') ...[
            Text('Odigraj tačan potez na tabli', style: AppText.bodyBold),
            if (step['solutionSan'] != null)
              Text('Tačan potez: ${step['solutionSan']}',
                  style: AppText.body.copyWith(color: context.colors.success)),
            const SizedBox(height: AppSpacing.sm),
          ],
          Center(
            child: BoardWithCoordinates(
              size: 300,
              orientation: orientation,
              builder: (size) => ChessBoardWithOverlay(
                controller: _boardCtrl,
                boardOrientation: orientation,
                boardSize: size,
                isAllowedToMove: kind == 'ask_move',
                isDrawingMode: false,
                drawingStartSquare: null,
                arrows: const [],
                squares: const [],
                engineArrows: const [],
                onMove: (from, to, promotion) {
                  if (kind == 'ask_move') {
                    final fen = step['fen']?.toString() ?? '';
                    final san = _sanFor(fen, from, to, promotion);
                    if (san != null) {
                      _updateStep('solutionSan', san);
                    }
                    _boardCtrl.loadFen(fen); // Revert board to step fen
                  }
                },
                onSquareTapForDrawing: (_) {},
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: const Text('Sačuvaj korak'),
              ),
              OutlinedButton(
                onPressed: _preview,
                child: const Text('Pregled'),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: ListView.builder(
            itemCount: _steps.length,
            itemBuilder: (context, i) {
              return ListTile(
                title: Text(_steps[i]['title']?.toString() ?? 'Korak ${i + 1}'),
                selected: i == _selectedIndex,
                onTap: () {
                  // Save current instruction before switching
                  final instr = _instructionCtrl.text.trim();
                  _updateStep('instruction', instr.isEmpty ? null : instr);
                  setState(() => _selectedIndex = i);
                  _loadStep();
                },
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildEditor()),
      ],
    );
  }
}
