import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/pgn_parser.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import '../services/review_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Works through the positions that are due for review.
///
/// The shape is recall-then-grade, the same as any spaced-repetition trainer:
/// the position appears, the student tries to remember the idea, then reveals it
/// and says how it went. Grading before revealing would let someone tap "Lako"
/// through a whole session and quietly destroy their own schedule, so the grade
/// buttons stay hidden until the answer is shown.
class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  late final ReviewApiService _api;
  final ChessBoardController _board = ChessBoardController();

  List<ReviewItem> _queue = const [];
  ReviewStats _stats = const ReviewStats();
  int _index = 0;
  bool _loading = true;
  bool _revealed = false;
  bool _grading = false;
  int _completed = 0;

  List<String> _fens = const [];
  List<String> _moves = const [];
  int _moveIndex = 0;
  PlayerColor _orientation = PlayerColor.white;

  ReviewItem? get _current => _index < _queue.length ? _queue[_index] : null;

  @override
  void initState() {
    super.initState();
    _api = ReviewApiService(authToken: widget.session.token);
    _load();
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _api.fetchDue();
    if (!mounted) return;

    setState(() {
      _queue = result.items;
      _stats = result.stats;
      _index = 0;
      _loading = false;
    });
    if (_queue.isNotEmpty) _showCurrent();
  }

  void _showCurrent() {
    final item = _current;
    if (item == null) return;

    // Same guard as the lesson viewer: PgnParser replays from the standard
    // starting position, so a line is only trusted when its first position is
    // the step's own. Otherwise the position is shown without a continuation.
    List<String> fens = const [];
    List<String> moves = const [];
    final pgn = item.step.pgn;
    if (pgn != null && pgn.trim().isNotEmpty) {
      try {
        final parsed = PgnParser.parse(pgn);
        if (parsed != null &&
            parsed.fens.isNotEmpty &&
            _sameFen(parsed.fens.first, item.step.fen)) {
          fens = parsed.fens;
          moves = parsed.movesSan;
        }
      } catch (_) {
        // Fall through to the still position.
      }
    }

    setState(() {
      _fens = fens;
      _moves = moves;
      _moveIndex = 0;
      _revealed = false;
      _orientation = _sideToMove(item.step.fen);
    });
    _board.loadFen(item.step.fen);
  }

  static bool _sameFen(String a, String b) {
    final left = a.trim().split(' ');
    final right = b.trim().split(' ');
    if (left.isEmpty || right.isEmpty) return false;
    return left.take(4).join(' ') == right.take(4).join(' ');
  }

  static PlayerColor _sideToMove(String fen) {
    try {
      return chess.Chess.fromFEN(fen).turn == chess.Color.WHITE
          ? PlayerColor.white
          : PlayerColor.black;
    } catch (_) {
      return PlayerColor.white;
    }
  }

  void _reveal() {
    setState(() => _revealed = true);
    if (_fens.isNotEmpty) _seek(_fens.length - 1);
  }

  void _seek(int index) {
    if (_fens.isEmpty) return;
    final clamped = index.clamp(0, _fens.length - 1);
    setState(() => _moveIndex = clamped);
    _board.loadFen(_fens[clamped]);
  }

  Future<void> _grade(ReviewGrade grade) async {
    final item = _current;
    if (item == null || _grading) return;

    setState(() => _grading = true);
    final description = await _api.grade(
      lessonId: item.lessonId,
      position: item.position,
      grade: grade,
    );

    if (!mounted) return;

    if (description == null) {
      setState(() => _grading = false);
      AppFeedback.show(
        context,
        () => const SnackBar(
            content: Text('Ocena nije sačuvana — proverite vezu.')),
      );
      return;
    }

    AppFeedback.show(
      context,
      () => SnackBar(
          content: Text('${grade.label} — sledeće ponavljanje $description'),
          duration: const Duration(milliseconds: 1400)),
    );

    setState(() {
      _grading = false;
      _completed++;
      _index++;
    });

    if (_current != null) {
      _showCurrent();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Ponavljanje'),
        bottom: _queue.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _completed / _queue.length,
                  minHeight: 4,
                  backgroundColor: context.colors.surfaceRaised,
                ),
              ),
      ),
      // Arrow keys drive the same cursor the strip's buttons do — but only once
      // the continuation is showing. Walking the line before that is being told
      // the answer by the keyboard, which is the one thing this screen must not
      // do: the whole exercise is recalling the move before seeing it.
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        onChanged: () {},
        enabled: _revealed && _moves.isNotEmpty,
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_current == null) return _buildDone();

    return LayoutBuilder(
      builder: (context, constraints) {
        final heightBased = (constraints.maxHeight - 260).clamp(200.0, 520.0);
        final widthBased = (constraints.maxWidth - 24).clamp(180.0, 520.0);
        final boardSize = heightBased < widthBased ? heightBased : widthBased;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildPrompt(),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: ChessBoardWithOverlay(
                    controller: _board,
                    boardOrientation: _orientation,
                    boardSize: boardSize,
                    isAllowedToMove: false,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: const [],
                    engineArrows: const [],
                    onMove: (_, __, ___) {},
                    onSquareTapForDrawing: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_revealed && _moves.isNotEmpty) _buildMoveControls(),
              const SizedBox(height: 8),
              _revealed ? _buildGradeButtons() : _buildRevealButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrompt() {
    final item = _current!;
    // Read from the position, not from [_orientation]: the board starts facing
    // the side to move but can now be flipped by hand, and a flipped board must
    // not change who the prompt says is on move.
    final toMove =
        _sideToMove(item.step.fen) == PlayerColor.white ? 'Beli' : 'Crni';

    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.lessonTitle,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_completed + 1}/${_queue.length}',
                  style: TextStyle(
                      fontSize: 13, color: context.colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.isNew
                  ? 'Nova pozicija — pogledajte je i ocenite koliko vam je jasna.'
                  : '$toMove na potezu. Setite se ideje, pa proverite.',
              style: TextStyle(
                  fontSize: 12.5, color: context.colors.textSecondary),
            ),
            if (item.step.title.isNotEmpty && _revealed) ...[
              const SizedBox(height: 6),
              Text(item.step.title, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRevealButton() {
    return ElevatedButton.icon(
      onPressed: _reveal,
      icon: const Icon(Icons.visibility),
      label: Text(_moves.isEmpty ? 'Prikaži opis' : 'Prikaži nastavak'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
    );
  }

  /// The one cursor this screen is walked by — the strip's buttons and the
  /// arrow keys read it from here rather than each building their own.
  MoveCursor _moveCursor() => LinearMoveCursor(
        fens: _fens,
        movesSan: _moves,
        index: _moveIndex,
        onSeek: _seek,
      );

  Widget _buildMoveControls() {
    return MoveNavigationControls(
      cursor: _moveCursor(),
      centerLabel: '$_moveIndex/${_moves.length}',
      onFlipBoard: () => setState(() {
        _orientation = _orientation == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;
      }),
    );
  }

  Widget _buildGradeButtons() {
    // Colour runs from "forgot" to "knew it cold" so the row reads at a glance.
    final colors = {
      ReviewGrade.again: context.colors.danger,
      ReviewGrade.hard: context.colors.warning,
      ReviewGrade.good: context.colors.accent,
      ReviewGrade.easy: context.colors.success,
    };

    return Column(
      children: [
        Text(
          'Koliko ste se setili?',
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final grade in ReviewGrade.values)
              ElevatedButton(
                onPressed: _grading ? null : () => _grade(grade),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors[grade],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: Text(grade.label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDone() {
    final nothingDue = _completed == 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              nothingDue ? Icons.check_circle_outline : Icons.task_alt,
              size: 56,
              color: context.colors.success,
            ),
            const SizedBox(height: 14),
            Text(
              nothingDue ? 'Ništa nije na redu.' : 'Gotovo za danas.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              nothingDue
                  ? _stats.total == 0
                      ? 'Kada prođete kroz zadatu lekciju, pozicije iz nje počinju da se '
                          'vraćaju na ponavljanje.'
                      : 'Sve pozicije su ponovljene. Vratite se kasnije.'
                  : 'Ponovili ste $_completed ${_completed == 1 ? 'poziciju' : 'pozicija'}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            if (_stats.total > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Ukupno u ponavljanju: ${_stats.total} · savladano: ${_stats.mature}',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Osveži'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Nazad'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
