import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/services/move_motif.dart' show sanOfUci;
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/core/models/review_grade.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';

class MistakeDrillScreen extends StatefulWidget {
  const MistakeDrillScreen({super.key});

  @override
  State<MistakeDrillScreen> createState() => _MistakeDrillScreenState();
}

class _MistakeDrillScreenState extends State<MistakeDrillScreen> {
  final ArchiveApiService _api = ArchiveApiService.instance;

  List<MistakeItem> _queue = [];
  MistakeItem? _current;
  int _completed = 0;
  bool _loading = true;

  final ChessBoardController _board = ChessBoardController();
  PlayerColor _orientation = PlayerColor.white;

  bool _revealed = false;
  bool _grading = false;
  String? _playerMoveUci;

  /// While the game of the mistake on the board is being fetched.
  bool _openingGame = false;

  MistakeRecurrence? _recurrence;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.fetchMistakesDue(limit: 20);
      final recurrence = await _api.fetchMistakeRecurrence();

      final validItems = items
          .where((i) => i.bestUci != null && i.bestUci!.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _queue = validItems;
        _recurrence = recurrence;
        _completed = 0;
        _loading = false;
        _next();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppFeedback.error(context, 'Error loading mistakes: $e');
    }
  }

  void _next() {
    if (_queue.isEmpty) {
      _current = null;
      return;
    }
    _current = _queue.removeAt(0);
    _revealed = false;
    _playerMoveUci = null;

    _board.loadFen(_current!.fenBefore);
    _orientation = _board.game.turn == chess_lib.Color.WHITE
        ? PlayerColor.white
        : PlayerColor.black;
  }

  /// Takes the mistake on the board out of the drill for good (22.9.2026:
  /// until then none could be). Its game stays in the archive.
  Future<void> _remove() async {
    final item = _current;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this mistake?'),
        content: const Text('It will not come back in the drill. The game it '
            'came from stays in your archive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove', style: TextStyle(color: ctx.colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _grading = true);
    final error = await _api.removeMistake(item.id);
    if (!mounted) return;
    setState(() {
      _grading = false;
      if (error == null && identical(_current, item)) _next();
    });
    if (error != null) AppFeedback.error(context, error);
  }

  Future<void> _grade(ReviewGrade grade) async {
    if (_current == null) return;
    setState(() => _grading = true);
    try {
      final res = await _api.gradeMistake(_current!.id, grade.name);
      if (!mounted) return;
      if (res.ok) {
        AppFeedback.success(context, res.description ?? 'Grade recorded');
        setState(() {
          _completed++;
          _next();
        });
      } else {
        AppFeedback.error(context, res.error ?? 'Server error');
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _grading = false);
    }
  }

  void _onMove(String fromStr, String toStr, String? promotion) {
    if (_revealed) return;

    // The board reports an ordinary move with no piece, or an empty one.
    final piece = (promotion == null || promotion.isEmpty) ? null : promotion;
    final moveUci = '$fromStr$toStr${piece ?? ""}';
    bool moved = false;
    try {
      if (piece != null) {
        _board.makeMoveWithPromotion(
            from: fromStr, to: toStr, pieceToPromoteTo: piece);
      } else {
        _board.makeMove(from: fromStr, to: toStr);
      }
      moved = true;
    } catch (_) {
      // makeMove throws or ignores invalid moves depending on flutter_chess_board version.
    }

    if (moved) {
      setState(() {
        _playerMoveUci = moveUci;
        _revealed = true;
      });
    }
  }

  /// The whole game of the mistake on the board, in Analysis, standing on the
  /// position the mistake was made in — D4 of `docs/PLAN-SKELET.md`: the
  /// archive's way to the tutorial is the Analysis door.
  Future<void> _openGameInAnalysis() async {
    final item = _current;
    if (item == null) return;
    setState(() => _openingGame = true);
    try {
      final game = await _api.fetchGameMoves(item.gameId);
      if (!mounted) return;
      await openGameInAnalysis(context, (
        startFen: game.startFen,
        uciMoves: game.uciMoves,
        cursorPly: item.ply,
        blackOrientation: (game.subjectColor ?? item.subjectColor) == 'b',
      ));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _openingGame = false);
    }
  }

  void _reveal() {
    setState(() {
      _revealed = true;
    });
  }

  String _endingName(String key) {
    if (key == 'KPRkpr') return 'Rook and pawn endgames';
    if (key == 'KPRkp') return 'Rook endgames with pawn advantage';
    if (key == 'KRkr') return 'Pure rook endgames';
    if (key == 'KPkp') return 'Pawn endgames';
    if (key == 'KPk') return 'King and pawn vs king';
    if (key == 'KQkq') return 'Queen endgames';
    if (key == 'KBNk') return 'Checkmate with bishop and knight';
    if (key == 'KBBk') return 'Checkmate with two bishops';
    if (key == 'KRk') return 'Checkmate with rook';
    if (key == 'KQk') return 'Checkmate with queen';
    if (key == 'KRNkrn') return 'Rook and knight';
    if (key == 'KRBkrb') return 'Rook and bishop';
    return 'Special endgames';
  }

  String _motifName(String key) {
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        title: const Text('My mistakes'),
        elevation: 0,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final item = _current;
    if (item == null) return _buildDone();

    return TrainerScreenLayout(
      board: (side) => BoardWithCoordinates(
        size: side,
        orientation: _orientation,
        builder: (size) => ChessBoardWithOverlay(
          controller: _board,
          boardOrientation: _orientation,
          boardSize: size,
          isAllowedToMove: !_revealed,
          isDrawingMode: false,
          drawingStartSquare: null,
          arrows: const [],
          engineArrows: const [],
          onMove: _onMove,
          onSquareTapForDrawing: (_) {},
        ),
      ),
      panel: _buildPanel(item),
      controls: _buildControls(item),
      // The grades are a label and a row of four buttons, a line more than
      // the endgame trainer's single row of controls.
      wideReserve: 150,
    );
  }

  /// The game it came from and how far along the drill is, the task, and
  /// once an answer is given the verdict (rules R1–R3 of
  /// `docs/PLAN-EKRANI.md`). The task is drawn and not spoken: the drill has
  /// no clips for it.
  Widget _buildPanel(MistakeItem item) {
    // From the side the board faces, which was set from the position before
    // the mistake: after an answer the board's own turn has moved on, and the
    // task would say the other side was to move.
    final toMove = _orientation == PlayerColor.white ? 'White' : 'Black';
    final verdict = _revealed ? _verdict(item) : null;

    return TrainerInfoPanel(
      // A new mistake is a new panel, so nothing of the last one's verdict
      // is carried across.
      key: ValueKey('mistake-panel-${item.id}'),
      taskText: '$toMove to move. Recall the better move.',
      chips: _chips(item),
      messageText: verdict?.lines,
      messageIcon: verdict?.icon,
      messageIsGood: verdict?.good ?? false,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton.icon(
              key: const Key('mistake-open-game'),
              onPressed: _openingGame ? null : _openGameInAnalysis,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open this game in Analysis'),
            ),
            TextButton.icon(
              key: const Key('mistake-remove'),
              onPressed: _grading ? null : _remove,
              icon: Icon(Icons.delete_outline,
                  size: 18, color: context.colors.danger),
              label: const Text('Remove from drill'),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _chips(MistakeItem item) {
    final played = item.playedAt;
    return [
      item.opponent != null ? 'vs ${item.opponent}' : 'Puzzle',
      '${played.day}.${played.month}.${played.year}.',
      if (item.opening != null) item.opening!,
      if (item.result != null) item.result!,
      if (item.subjectColor != null)
        item.subjectColor == 'w' ? 'White' : 'Black',
      '${_completed + 1}/${_completed + _queue.length + 1}',
    ];
  }

  /// A move of this mistake's position in SAN; the UCI string only for a move
  /// the position does not allow, which stored data can hold.
  String _san(MistakeItem item, String uci) =>
      sanOfUci(item.fenBefore, uci) ?? uci;

  bool _recalled(MistakeItem item) => _playerMoveUci == item.bestUci;

  ({List<String> lines, IconData icon, bool good}) _verdict(MistakeItem item) {
    final good = _recalled(item);
    final best = _san(item, item.bestUci!);
    final playedInGame = _san(item, item.playedUci);
    final tried = _playerMoveUci;
    // One short sentence a line: in one long sentence a move near the panel's
    // edge broke at its hyphen — „O-" on one line and „O" on the next
    // (rendered 3.10.2026 at 1536 x 792).
    final List<String> sentences;
    if (good) {
      sentences = ['Well done! You played the best move.'];
    } else if (tried == null) {
      sentences = [
        'The best move was $best.',
        'In the game you played $playedInGame.',
      ];
    } else {
      sentences = [
        'Incorrect.',
        'The best move was $best.',
        'You tried ${_san(item, tried)}.',
        'In the game you played $playedInGame.',
      ];
    }
    return (
      lines: [
        ...sentences,
        if (item.kind == 'engine') ...[
          'Loss: ${item.swingCp != null ? "${item.swingCp} cp" : "?"}',
          if (item.theme != null) 'Theme: ${item.theme}',
        ] else if (item.kind == 'tablebase')
          'Tablebase: ${_wdlString(item.wdlBefore)} -> ${_wdlString(item.wdlAfter)}',
      ],
      // Shapes, not colours: a tick, a cross, and an „i" for an answer that
      // was shown and not recalled.
      icon: good
          ? Icons.check_circle
          : (tried == null ? Icons.info_outline : Icons.cancel),
      good: good,
    );
  }

  String _wdlString(int? wdl) {
    if (wdl == null) return '?';
    if (wdl > 0) return 'Won';
    if (wdl < 0) return 'Lost';
    return 'Draw';
  }

  Widget _buildControls(MistakeItem item) {
    if (!_revealed) {
      return Center(
        child: FilledButton.icon(
          onPressed: _reveal,
          icon: const Icon(Icons.visibility),
          label: const Text('Show answer'),
        ),
      );
    }
    return _buildGradeButtons(item);
  }

  /// The grade the reader most likely wants is the one filled button — rule
  /// R4 for a row of four peer choices, read by the lead and one condition in
  /// one place: after a right answer „Good", after a wrong or a shown one
  /// „Again". The other three are outlined, in the order of the scale.
  ReviewGrade _likelyGrade(MistakeItem item) =>
      _recalled(item) ? ReviewGrade.good : ReviewGrade.again;

  Widget _buildGradeButtons(MistakeItem item) {
    final likely = _likelyGrade(item);

    return Column(
      children: [
        Text(
          'How well did you recall it?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final grade in ReviewGrade.values)
              if (grade == likely)
                FilledButton(
                  onPressed: _grading ? null : () => _grade(grade),
                  child: Text(grade.label),
                )
              else
                OutlinedButton(
                  onPressed: _grading ? null : () => _grade(grade),
                  child: Text(grade.label),
                ),
          ],
        ),
      ],
    );
  }

  /// The end of the drill: one main action, [FilledButton] for „Back", and
  /// „Refresh" outlined beside it.
  Widget _buildDone() {
    final nothingDue = _completed == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
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
                  nothingDue ? 'Nothing due.' : 'Done for today.',
                  style: AppText.headline,
                ),
                const SizedBox(height: 6),
                Text(
                  nothingDue
                      ? 'You played great and have no mistakes to practice.'
                      : 'You reviewed $_completed ${_completed == 1 ? 'mistake' : 'mistakes'}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_recurrence != null &&
              (_recurrence!.motifs.isNotEmpty ||
                  _recurrence!.endings.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Your frequent mistakes',
                style:
                    AppText.title.copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            if (_recurrence!.motifs.isNotEmpty) ...[
              Text('Tactics (motifs)',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              ..._recurrence!.motifs.map((m) => ListTile(
                    title: Text(_motifName(m.key), style: AppText.body),
                    trailing: Text(
                        '${m.count} ${m.count == 1 ? 'mistake' : 'mistakes'}',
                        style: AppText.bodyBold),
                  )),
            ],
            if (_recurrence!.endings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Endgames',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              ..._recurrence!.endings.map((m) => ListTile(
                    title: Text(_endingName(m.key), style: AppText.body),
                    trailing: Text(
                        '${m.count} ${m.count == 1 ? 'mistake' : 'mistakes'}',
                        style: AppText.bodyBold),
                  )),
            ],
          ]
        ],
      ),
    );
  }
}
