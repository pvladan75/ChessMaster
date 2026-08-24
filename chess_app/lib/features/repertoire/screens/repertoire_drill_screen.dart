import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
// `hide Color`: the board package re-exports the chess package, whose `Color`
// is a piece colour. Without this, `Color` in this file means black-or-white
// instead of a paint colour, and the error it produces names two files that
// look identical.
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Being asked what you decided to play, until you no longer have to think.
///
/// The questions come from the same schedule homework uses — SM-2, the one
/// algorithm, in `spacedRepetitionService` — but nobody is asked to grade
/// themselves here. The answer is objective, because it is the student's own
/// decision written down, so remembering it is a pass, needing to look is a
/// weaker pass, and playing something else is a miss even when it is perfectly
/// good chess. The drill asks about a decision, not about chess.
///
/// **It costs nothing.** No Lichess request is made at any point: the
/// opponent's replies come out of the book stored while the position was built.
/// Somebody who has spent their allowance, or never had a token at all, can
/// still practise everything they own.
///
/// **It is allowed to surprise.** The opponent's move is drawn by how often it
/// is really played, and the uncovered moves are in the draw. Landing in a
/// position nobody prepared is not a failure of the drill — it is the one thing
/// a book cannot do, and it opens the door back into building.
class RepertoireDrillScreen extends StatefulWidget {
  const RepertoireDrillScreen({
    super.key,
    required this.name,
    required this.color,
    this.minRating,
    this.api,
    this.onBuildHere,
  });

  final String name;

  /// 'w' or 'b' — the side whose decisions are being asked about.
  final String color;

  final int? minRating;
  final RepertoireApiService? api;

  /// Called with a position the student has not prepared, so the screen above
  /// can offer to build it instead of leaving them stuck.
  final void Function(String fen)? onBuildHere;

  @override
  State<RepertoireDrillScreen> createState() => _RepertoireDrillScreenState();
}

class _RepertoireDrillScreenState extends State<RepertoireDrillScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();

  String? _fen;
  DrillStats _stats =
      const DrillStats(positions: 0, due: 0, known: 0, fresh: 0);
  bool _loading = true;
  bool _busy = false;

  /// Set once the student has asked to be shown the answer. The next answer is
  /// then graded as recognised rather than remembered.
  RepertoireMove? _revealed;

  DrillAnswer? _answer;
  String? _playedSan;

  /// What the opponent replied, once it has been played on the board.
  String? _replySan;

  /// Where the line stands after that reply — the next question, if the
  /// student prepared one. Kept as a field rather than recomputed: the board is
  /// the one place that knows, and asking it twice invites the two to disagree.
  String? _lineFen;
  bool _replyCovered = true;

  bool get _forWhite => widget.color == 'w';
  PlayerColor get _orientation =>
      _forWhite ? PlayerColor.white : PlayerColor.black;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _answer = null;
      _playedSan = null;
      _replySan = null;
      _replyCovered = true;
      _revealed = null;
      _lineFen = null;
    });
    final next = await _api.nextDrill(color: widget.color);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _stats = next.stats;
      _fen = next.item?.fen;
    });
    final fen = _fen;
    if (fen != null) _boardController.loadFen(fen);
  }

  /// Continues the line from a position the drill walked into, rather than
  /// jumping somewhere else. Landing in an unprepared position is the point of
  /// the uncovered replies, so it stays on the board and offers the way out.
  void _continueAt(String fen) {
    setState(() {
      _fen = fen;
      _answer = null;
      _playedSan = null;
      _replySan = null;
      _replyCovered = true;
      _revealed = null;
      _lineFen = null;
    });
    _boardController.loadFen(fen);
  }

  Future<void> _onMove(String from, String to) async {
    final fen = _fen;
    if (fen == null || _busy || _answer != null) return;

    final board = chess.Chess.fromFEN(fen);
    final promotion = _isPromotion(board, from, to);
    final ok = board.move({
      'from': from,
      'to': to,
      if (promotion) 'promotion': 'q',
    });
    if (ok == false) {
      _boardController.loadFen(fen);
      return;
    }
    final san = board.getHistory().last.toString();
    final uci = promotion ? '$from${to}q' : '$from$to';

    setState(() {
      _busy = true;
      _playedSan = san;
    });

    final graded = await _api.answerDrill(
      color: widget.color,
      fen: fen,
      uci: uci,
      revealed: _revealed != null,
      minRating: widget.minRating,
    );
    if (!mounted) return;

    if (graded == null) {
      setState(() {
        _busy = false;
        _playedSan = null;
      });
      _boardController.loadFen(fen);
      return;
    }

    // The board shows the line as it should have gone: the student's own move
    // when it was one of theirs, and their primary when it was not — carrying
    // on from a move they were just told is wrong would rehearse the mistake.
    final shown = graded.outcome == 'unknown' && graded.primary != null
        ? graded.primary!.uci
        : uci;
    final afterOwn = _fenAfter(fen, shown) ?? fen;
    var boardFen = afterOwn;
    String? replySan;
    if (graded.reply != null) {
      final replyBoard = chess.Chess.fromFEN(afterOwn);
      final played = replyBoard.move({
        'from': graded.reply!.substring(0, 2),
        'to': graded.reply!.substring(2, 4),
        if (graded.reply!.length > 4)
          'promotion': graded.reply!.substring(4, 5),
      });
      if (played != false) {
        replySan = replyBoard.getHistory().last.toString();
        boardFen = replyBoard.fen;
      }
    }

    setState(() {
      _busy = false;
      _answer = graded;
      _replySan = replySan;
      _replyCovered = graded.replyCovered;
      _lineFen = boardFen;
    });
    _boardController.loadFen(boardFen);
  }

  bool _isPromotion(chess.Chess board, String from, String to) {
    final piece = board.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;
    final rank = to.substring(1);
    return rank == '8' || rank == '1';
  }

  String? _fenAfter(String fen, String uci) {
    final board = chess.Chess.fromFEN(fen);
    final ok = board.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      if (uci.length > 4) 'promotion': uci.substring(4, 5),
    });
    return ok == false ? null : board.fen;
  }

  Future<void> _reveal() async {
    final fen = _fen;
    if (fen == null) return;
    setState(() => _busy = true);
    final move = await _api.revealDrill(color: widget.color, fen: fen);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _revealed = move;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text('Vežbanje — ${widget.name}'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'na redu: ${_stats.due} · novo: ${_stats.fresh}',
                style: AppText.micro.copyWith(color: context.colors.textMuted),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_fen == null) return _buildEmpty(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = (constraints.maxWidth - 24).clamp(200.0, 420.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: BoardWithCoordinates(
                  size: boardSize,
                  orientation: _orientation,
                  builder: (inner) => ChessBoardWithOverlay(
                    controller: _boardController,
                    boardOrientation: _orientation,
                    boardSize: inner,
                    isAllowedToMove: !_busy && _answer == null,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: const [],
                    engineArrows: const [],
                    onMove: _onMove,
                    onSquareTapForDrawing: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildPrompt(context),
              const SizedBox(height: 10),
              _buildControls(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrompt(BuildContext context) {
    final graded = _answer;
    if (graded == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_forWhite ? 'Šta igrate belim?' : 'Šta igrate crnim?',
              style: AppText.bodyBold),
          const SizedBox(height: 2),
          Text(
            _revealed == null
                ? 'Odigrajte potez koji ste izabrali za ovu poziciju.'
                : 'Vaš potez je ${_revealed!.san}. Odigrajte ga.',
            style: AppText.caption.copyWith(
              color: _revealed == null
                  ? context.colors.textMuted
                  : context.colors.warning,
            ),
          ),
        ],
      );
    }

    final ({Color color, IconData icon, String title, String detail}) face =
        switch (graded.outcome) {
      'primary' => (
          color: context.colors.success,
          icon: Icons.check_circle_outline,
          title: 'Tačno — ${_playedSan ?? ''}',
          detail: _whenBack(graded),
        ),
      'alternate' => (
          color: context.colors.info,
          icon: Icons.alt_route,
          title: 'I to je vaše — ${_playedSan ?? ''}',
          detail: graded.primary == null
              ? _whenBack(graded)
              : 'Glavni potez vam je ${graded.primary!.san}. ${_whenBack(graded)}',
        ),
      'unprepared' => (
          color: context.colors.textMuted,
          icon: Icons.help_outline,
          title: 'Ovu poziciju niste pokrili',
          detail: 'Ovde nema vašeg poteza, pa nema ni ocene. '
              'Otvorite izgradnju i odlučite šta igrate.',
        ),
      _ => (
          color: context.colors.danger,
          icon: Icons.close,
          title: 'Nije to — ${_playedSan ?? ''}',
          detail: graded.primary == null
              ? _whenBack(graded)
              : 'Vaš potez je ${graded.primary!.san}. ${_whenBack(graded)}',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(face.icon, size: 18, color: face.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(face.title,
                  style: AppText.bodyBold.copyWith(color: face.color)),
            ),
          ],
        ),
        if (face.detail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(face.detail,
              style:
                  AppText.caption.copyWith(color: context.colors.textPrimary)),
        ],
        if (_replySan != null) ...[
          const SizedBox(height: 6),
          Text(
            _replyCovered
                ? 'Protivnik je odgovorio $_replySan.'
                : 'Protivnik je odgovorio $_replySan — to niste pokrili.',
            style: AppText.caption.copyWith(
              color: _replyCovered
                  ? context.colors.textMuted
                  : context.colors.warning,
            ),
          ),
        ],
      ],
    );
  }

  /// When the position comes back, in words rather than in a number of days.
  String _whenBack(DrillAnswer graded) {
    final days = graded.intervalDays;
    if (days == null) return '';
    if (days == 0) return 'Vraća se za koji minut.';
    if (days == 1) return 'Vraća se sutra.';
    if (days < 7) return 'Vraća se za $days dana.';
    if (days < 30) {
      final weeks = (days / 7).round();
      return weeks == 1
          ? 'Vraća se za nedelju dana.'
          : 'Vraća se za $weeks nedelje.';
    }
    final months = (days / 30).round();
    return months == 1
        ? 'Vraća se za mesec dana.'
        : 'Vraća se za $months meseca.';
  }

  Widget _buildControls(BuildContext context) {
    final graded = _answer;
    // Wrap and not Row: three Serbian labels outgrow a 360 dp phone, and a
    // release build clips what does not fit without a word.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (graded == null) ...[
          OutlinedButton.icon(
            onPressed: _busy || _revealed != null ? null : _reveal,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Pokaži'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _loadNext,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Preskoči'),
          ),
        ] else ...[
          if (!graded.isPrepared && widget.onBuildHere != null)
            FilledButton.icon(
              onPressed: () => widget.onBuildHere!(_fen!),
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Izgradi ovu poziciju'),
            ),
          if (_lineFen != null && graded.isPrepared)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _continueAt(_lineFen!),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Nastavi liniju'),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _loadNext,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Sledeća'),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    // Two different empty states, and only one of them is good news.
    final nothingBuilt = _stats.positions == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(nothingBuilt ? Icons.menu_book_outlined : Icons.done_all,
                size: 40),
            const SizedBox(height: 12),
            Text(
              nothingBuilt
                  ? 'Još nema šta da se vežba.'
                  : 'Ništa nije na redu.',
              style: AppText.bodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              nothingBuilt
                  ? 'Prvo izgradite nekoliko pozicija — vežba pita ono što ste '
                      'vi izabrali.'
                  : 'Sve što ste izgradili vraća se na red kad dođe vreme. '
                      'Do sada znate ${_stats.known} od ${_stats.positions} '
                      'pozicija.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Nazad'),
            ),
          ],
        ),
      ),
    );
  }
}
