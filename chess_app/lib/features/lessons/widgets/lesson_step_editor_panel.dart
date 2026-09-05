import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess;

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
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

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Save current instruction
    final instr = _instructionCtrl.text.trim();
    _updateStep('instruction', instr.isEmpty ? null : instr);

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
          DropdownButtonFormField<String>(
            initialValue: kind,
            items: const [
              DropdownMenuItem(value: 'show', child: Text('Samo prikaži')),
              DropdownMenuItem(
                  value: 'ask_move', child: Text('Traži potez na tabli')),
              DropdownMenuItem(
                  value: 'ask_choice', child: Text('Traži odgovor iz liste')),
            ],
            onChanged: (val) {
              if (val != null) _updateStep('kind', val == 'show' ? null : val);
            },
            decoration: const InputDecoration(
              labelText: 'Tip zadatka',
              border: OutlineInputBorder(),
            ),
          ),
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
