import 'dart:collection';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_judge_panel_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/engine_analysis_dials.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Building a repertoire by being asked, not by being told.
///
/// The loop is the whole idea: the board shows a position, the student plays
/// what they would play, the judge says what it is worth, and the student
/// decides whether to keep it. Only then does the opponent's side of the
/// position open up, one wave at a time. Nobody is shown a line to memorise,
/// and the moves that end up stored are the student's own choices — which is
/// the difference between a repertoire somebody owns and one they were handed.
///
/// Three rules hold this together, and each of them is a decision rather than
/// an accident:
///
///   * **The first move kept in a position is the primary.** Alternates are
///     welcome, but one move has to be the answer, or the drill has nothing to
///     ask for. The database holds that rule, not this screen.
///   * **The opponent's replies stop at a share, not at a number the student
///     picks.** The server covers what 80% of games actually play, up to four
///     moves, and says how much is left outside. A position with no end is a
///     repertoire that never gets built.
///   * **The rejected attempts are kept too.** They are where the instinct is
///     wrong, and they are what the drill should ask about first.
class RepertoireBuildScreen extends StatefulWidget {
  const RepertoireBuildScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    this.minRating,
    this.api,
    this.judge,
    this.analyse,
  });

  final String name;

  /// 'w' or 'b' — the side being prepared. The board is turned this way and
  /// only these moves are ever asked for.
  final String color;

  final String rootFen;

  /// The rating band the opponent's replies are counted in. A child meets the
  /// moves of their own opponents, not a grandmaster's.
  final int? minRating;

  /// Injected in tests, which have neither a server nor a Lichess token.
  final RepertoireApiService? api;
  final OpeningJudgeService? judge;

  /// Runs the engine on one position and answers with the lines. The local
  /// Stockfish by default — injected in tests, which have no engine binary and
  /// must not wait ten seconds for one.
  final Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
      analyse;

  @override
  State<RepertoireBuildScreen> createState() => _RepertoireBuildScreenState();
}

class _RepertoireBuildScreenState extends State<RepertoireBuildScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();
  late final OpeningJudgeService _judge =
      widget.judge ?? OpeningJudgeService.instance;

  /// Positions still to be answered, oldest first — the waves the student asked
  /// for. A queue and not a stack: going wide before deep is what keeps the
  /// common replies covered before the rare ones.
  final Queue<String> _queue = Queue<String>();

  /// Every position that has already been queued, so a transposition does not
  /// come round twice. Keyed the way the server keys them: no move counters.
  final Set<String> _seen = {};

  String? _current;
  List<RepertoireMove> _kept = const [];

  String? _proposalUci;
  String? _proposalSan;
  OpeningJudgement? _verdict;
  String? _verdictReason;

  /// The book, once the student has said they do not know. Opening it is
  /// allowed and is written down — a position answered by looking is not the
  /// same as one answered by thinking, and the drill should know the
  /// difference.
  OpponentReplies? _book;
  bool _lookedUp = false;

  /// How many questions this session has cost the student's Lichess allowance.
  /// On screen, because it is their allowance and they should not have to guess.
  int _asked = 0;

  bool _busy = false;
  String? _note;

  /// The engine's opinion, when it has been asked for one.
  ///
  /// Asked for by hand and answered once, rather than left running: this screen
  /// is a conversation about one position at a time, and an engine that streams
  /// in the background would be turning a phone warm to answer a question
  /// nobody asked yet. It costs no Lichess allowance at all — it is the local
  /// engine, and its depth and number of lines are the reader's to set.
  List<AnalysisLine> _lines = const [];
  bool _thinking = false;

  /// The position the lines belong to.
  ///
  /// Not bookkeeping — the whole difference between an opinion and a wrong one.
  /// A deep search takes seconds, the reader can walk on while it runs, and the
  /// answer then arrives for a board nobody is looking at. It was on screen:
  /// the engine offered `Bxb2` in a position with no capture on b2, because
  /// that move was legal one position earlier. Every answer here is checked
  /// against the position it was asked for, the same way the endgame trainer
  /// keeps its readout's FEN and the analysis board keeps its judged node.
  String? _linesFen;

  bool get _forWhite => widget.color == 'w';

  @override
  void initState() {
    super.initState();
    _enqueue(widget.rootFen);
    _advance();
  }

  String _keyOf(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    return parts.length >= 4 ? parts.sublist(0, 4).join(' ') : fen;
  }

  void _enqueue(String fen) {
    final key = _keyOf(fen);
    if (_seen.contains(key)) return;
    _seen.add(key);
    _queue.add(fen);
  }

  /// Moves to the next position in the queue, or to the "nothing left" state.
  Future<void> _advance() async {
    setState(() {
      _proposalUci = null;
      _proposalSan = null;
      _verdict = null;
      _verdictReason = null;
      _book = null;
      _lookedUp = false;
      _lines = const [];
      _linesFen = null;
      _thinking = false;
      _current = _queue.isEmpty ? null : _queue.removeFirst();
      _kept = const [];
    });
    final fen = _current;
    if (fen == null) return;
    _boardController.loadFen(fen);
    await _loadKept();
  }

  Future<void> _loadKept() async {
    final fen = _current;
    if (fen == null) return;
    final moves = await _api.movesAt(color: widget.color, fen: fen);
    if (!mounted) return;
    setState(() => _kept = moves);
  }

  /// The student's own move, offered to the judge at once.
  ///
  /// Judged automatically rather than on a button, because in this mode that is
  /// the point of playing the move at all. The counter above says what it cost.
  Future<void> _onMove(String from, String to, String promotion) async {
    final fen = _current;
    if (fen == null || _busy || _proposalUci != null) return;

    final board = chess.Chess.fromFEN(fen);
    final isPromotion = _isPromotion(board, from, to);
    // The piece the reader picked on the board. A repertoire line is stored as
    // UCI, and 'e8q' and 'e8n' are different lines.
    final piece = promotion.isEmpty ? 'q' : promotion;
    final ok = board.move({
      'from': from,
      'to': to,
      if (isPromotion) 'promotion': piece,
    });
    if (ok == false) {
      // An illegal drag must never leave the board showing a position nobody
      // asked about.
      _boardController.loadFen(fen);
      return;
    }
    final san = board.getHistory().last.toString();
    final uci = isPromotion ? '$from$to$piece' : '$from$to';

    setState(() {
      _busy = true;
      _proposalUci = uci;
      _proposalSan = san;
      _verdict = null;
      _verdictReason = null;
    });

    final lookup = await _judge.judge(fen, uci, minRating: widget.minRating);
    if (!mounted) return;
    if (_current != fen) return;
    setState(() {
      _busy = false;
      _asked += 1;
      _verdict = lookup.judgement;
      _verdictReason = lookup.reason;
    });

    // And now the book, without being asked for it.
    //
    // The rule is about *when*, not whether: hidden while the student is still
    // deciding, free the moment they have committed. Choosing between
    // candidates is the work, and a verdict on one move says whether that move
    // is sound — not whether something better was sitting next to it. There is
    // nothing left to spoil once the move has been played.
    await _loadBook(marksLookedUp: false);
  }

  /// The moves played from the position in front of the student, and how those
  /// games went. Fetched once per position; the counter says what it cost.
  Future<void> _loadBook({required bool marksLookedUp}) async {
    final fen = _current;
    if (fen == null || _book != null) return;
    // Without a token there is no book to fetch, and the verdict panel already
    // says why. A second sentence about the same missing token is noise.
    if (!_judge.hasPersonalToken) return;
    setState(() => _busy = true);
    final lookup = await _judge.replies(fen, minRating: widget.minRating);
    if (!mounted) return;
    // The book that arrives is the book for the board it was asked about.
    if (_current != fen) return;
    setState(() {
      _busy = false;
      _asked += 1;
      _book = lookup.replies;
      if (marksLookedUp) _lookedUp = true;
      if (!lookup.isAvailable) {
        _note = 'Knjiga nije dostupna (${lookup.reason}).';
      }
    });
  }

  bool _isPromotion(chess.Chess board, String from, String to) {
    final piece = board.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;
    final rank = to.substring(1);
    return rank == '8' || rank == '1';
  }

  Future<void> _keep() async {
    final fen = _current;
    final uci = _proposalUci;
    final san = _proposalSan;
    if (fen == null || uci == null || san == null) return;

    setState(() => _busy = true);
    final verdict = _verdict?.verdict.name;
    final saved = await _api.keepMove(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
      verdict: verdict,
    );
    await _api.recordAttempt(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
      verdict: verdict,
      kept: true,
      lookedUp: _lookedUp,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = saved ? null : 'Potez nije sačuvan — server nije odgovorio.';
    });
    if (saved) await _loadKept();
    _clearProposal();
  }

  Future<void> _discard() async {
    final fen = _current;
    final uci = _proposalUci;
    if (fen == null || uci == null) return;
    // Written down even though it was thrown away. This is the row the drill
    // will read: it is where the first instinct was wrong.
    await _api.recordAttempt(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: _proposalSan,
      verdict: _verdict?.verdict.name,
      kept: false,
      lookedUp: _lookedUp,
    );
    _clearProposal();
  }

  void _clearProposal() {
    final fen = _current;
    setState(() {
      _proposalUci = null;
      _proposalSan = null;
      _verdict = null;
      _verdictReason = null;
    });
    if (fen != null) _boardController.loadFen(fen);
  }

  /// Opens the book for the position in front of the student.
  Future<void> _showBook() => _loadBook(marksLookedUp: true);

  /// What the engine makes of this position, at the reader's depth and with as
  /// many lines as they asked for.
  /// This board's analysis dials — see [EngineAnalysisDials]. Up to 50 plies
  /// here: on a repertoire position it is worth waiting for, and the old
  /// ceiling of 28 was a leftover from when this number also decided how long
  /// the engine thought before playing a move.
  int _analysisDepth = AppSettingsService.instance.analysisDepth;
  int _analysisLines = AppSettingsService.instance.analysisLines;

  /// One arrow per engine line, carrying that line's evaluation.
  ///
  /// Only for the position on the board: lines from the previous one would
  /// point at pieces that have moved.
  List<EngineArrow> _engineArrows() {
    if (_linesFen != _current) return const [];
    final arrows = <EngineArrow>[];
    for (var i = 0; i < _lines.length && i < _analysisLines; i++) {
      final line = _lines[i];
      if (line.fromSquare.isEmpty || line.toSquare.isEmpty) continue;
      arrows.add(EngineArrow(
        from: line.fromSquare,
        to: line.toSquare,
        evalText: line.evaluation,
        rank: i + 1,
      ));
    }
    return arrows;
  }

  /// A dial moved: remember it and ask again about this position.
  Future<void> _applyAnalysisDials({int? depth, int? lines}) async {
    setState(() {
      if (depth != null) _analysisDepth = depth;
      if (lines != null) _analysisLines = lines;
    });
    if (depth != null) {
      await AppSettingsService.instance.setAnalysisDepth(depth);
    }
    if (lines != null) {
      await AppSettingsService.instance.setAnalysisLines(lines);
    }
    if (!mounted) return;
    // Asked again at once. Leaving the old lines up under a new depth reads as
    // an engine that stopped working — which is exactly how it was reported.
    await _askEngine();
  }

  Future<void> _askEngine() async {
    final fen = _current;
    if (fen == null || _thinking) return;

    setState(() {
      _thinking = true;
      _lines = const [];
      _linesFen = null;
    });

    final run = widget.analyse ??
        (String f, int depth, int multiPV) async {
          final engine = StockfishService();
          await engine.initEngine();
          return engine.analyzePositionSync(
            f,
            depth: depth,
            multiPV: multiPV,
            // A deep search takes a while, and a panel that says nothing until
            // it finishes is indistinguishable from an engine that is not
            // answering. The lines are shown as they come and simply get
            // better; the depth beside each one says how much to trust it.
            timeout: Duration(seconds: 5 + depth),
            onProgress: (partial) {
              if (!mounted || _current != f) return;
              setState(() {
                _lines = partial;
                _linesFen = f;
              });
            },
          );
        };

    List<AnalysisLine> lines;
    try {
      lines = await run(fen, _analysisDepth, _analysisLines);
    } catch (e) {
      lines = const [];
    }
    if (!mounted) return;

    // Asked about one position, answered about that one. A reader who moved on
    // while the engine was thinking gets no opinion rather than the wrong one.
    if (_current != fen) return;

    setState(() {
      _thinking = false;
      _lines = lines;
      _linesFen = fen;
      // Silence from the engine is said out loud rather than looking like a
      // position it had no opinion about.
      _note = lines.isEmpty ? 'Motor nije odgovorio na vreme.' : null;
    });
  }

  /// Plays the engine's move as the reader's own proposal, so it goes through
  /// the same judging and the same decision as a move played by hand. A
  /// suggestion is not a decision.
  void _playLine(AnalysisLine line) {
    if (line.fromSquare.isEmpty || line.toSquare.isEmpty) return;
    // The engine's LAN carries the promotion as a fifth character when there is
    // one — `d7d8q`. Read from there rather than defaulted, because an engine
    // that says `d8n` means it.
    final lan = line.bestMoveLan;
    final promotion = lan.length > 4 ? lan[4].toLowerCase() : '';
    _onMove(line.fromSquare, line.toSquare, promotion);
  }

  /// Opens the opponent's side of every move kept here, then moves on.
  Future<void> _openReplies() async {
    final kept = _kept;
    if (_current == null || kept.isEmpty) return;

    setState(() => _busy = true);
    var added = 0;
    var coveredSum = 0.0;
    var tailMoves = 0;
    var counted = 0;

    for (final move in kept) {
      final after = _fenAfter(_current!, move.uci);
      if (after == null) continue;
      final lookup = await _judge.replies(after, minRating: widget.minRating);
      if (!mounted) return;
      _asked += 1;
      final replies = lookup.replies;
      if (replies == null) continue;
      counted += 1;
      coveredSum += replies.coveredShare;
      tailMoves += replies.tailMoves;
      for (final reply in replies.replies) {
        final next = _fenAfter(after, reply.uci);
        if (next != null) {
          final before = _queue.length;
          _enqueue(next);
          if (_queue.length > before) added += 1;
        }
      }
    }

    final covered = counted == 0 ? 0 : (coveredSum / counted * 100).round();
    setState(() {
      _busy = false;
      _note = counted == 0
          ? 'Nijedan odgovor nije stigao — pozicija ostaje nepokrivena.'
          : 'Dodato $added ${added == 1 ? "pozicija" : "pozicija"}. '
              'Pokriveno $covered% onoga što ćete sresti; '
              'van toga još $tailMoves ${tailMoves == 1 ? "potez" : "poteza"}.';
    });
    await _advance();
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

  Future<void> _makePrimary(RepertoireMove move) async {
    final fen = _current;
    if (fen == null) return;
    await _api.makePrimary(color: widget.color, fen: fen, uci: move.uci);
    await _loadKept();
  }

  Future<void> _remove(RepertoireMove move) async {
    final fen = _current;
    if (fen == null) return;
    await _api.removeMove(color: widget.color, fen: fen, uci: move.uci);
    await _loadKept();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text(widget.name),
        elevation: 0,
        actions: [
          const BoardCoordinatesButton(),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                // Their allowance, so the number is theirs to see.
                'upita: $_asked',
                style: AppText.micro.copyWith(color: context.colors.textMuted),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_current == null) return _buildDone();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Minus the padding below, not the raw width: BoardWithCoordinates
        // takes `size` as the whole thing, gutter included, so handing it the
        // outer width overflows by exactly the padding — 24 px, invisible in a
        // release build.
        final boardSize = (constraints.maxWidth - 24).clamp(200.0, 420.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: BoardWithCoordinates(
                  size: boardSize,
                  orientation:
                      _forWhite ? PlayerColor.white : PlayerColor.black,
                  builder: (inner) => ChessBoardWithOverlay(
                    controller: _boardController,
                    boardOrientation:
                        _forWhite ? PlayerColor.white : PlayerColor.black,
                    boardSize: inner,
                    isAllowedToMove: !_busy && _proposalUci == null,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: const [],
                    // The engine's answer, on the board rather than only in a
                    // list underneath it: one arrow per line, its evaluation
                    // written beside it. Reading a move as "Nxd4" and finding
                    // it on the board is work a beginner should not have to do
                    // to see what the engine means.
                    engineArrows: _engineArrows(),
                    onMove: _onMove,
                    onSquareTapForDrawing: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildQuestion(context),
              const SizedBox(height: AppSpacing.sm),
              if (_proposalSan != null) _buildVerdict(context),
              if (_kept.isNotEmpty) _buildKept(context),
              // Open once the engine has been asked about *this* position —
              // including when it came back with nothing, because that is
              // exactly when the reader wants the depth dial and another go.
              if (_thinking || _linesFen == _current) _buildEngine(context),
              if (_book != null) _buildBook(context),
              if (_note != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_note!,
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted)),
              ],
              const SizedBox(height: AppSpacing.md),
              _buildControls(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final left = _queue.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _forWhite ? 'Šta igrate belim?' : 'Šta igrate crnim?',
          style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          left == 0 ? 'Poslednja pozicija u ovom talasu.' : 'Još $left u redu.',
          style: AppText.caption.copyWith(color: context.colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildVerdict(BuildContext context) {
    // The same panel the analysis board uses, so a verdict is worded in one
    // place and cannot come to mean two different things.
    return OpeningJudgePanelWidget(
      hasToken: _judge.hasPersonalToken,
      moveSan: _proposalSan,
      isLoading: _busy,
      judgement: _verdict,
      reason: _verdictReason,
    );
  }

  /// The moves kept here, and which of them is the main one.
  ///
  /// Rows rather than chips, and a line that says what the star means: the
  /// choice was always there — tapping a chip promoted it — but nothing on
  /// screen said so, and a control nobody can see is a control that does not
  /// exist. The main move is what the drill will ask for; the rest are yours
  /// and are accepted, with a word saying which one you settled on.
  Widget _buildKept(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vaši potezi ovde',
              style: AppText.bodyBold.copyWith(color: context.colors.accent)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _kept.length == 1
                ? 'Zvezdica je glavni potez — to će drill tražiti od vas.'
                : 'Zvezdica je glavni potez — to će drill tražiti od vas. '
                    'Dodirnite drugi potez da on postane glavni.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final move in _kept)
            InkWell(
              onTap: move.isPrimary || _busy ? null : () => _makePrimary(move),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      move.isPrimary ? Icons.star : Icons.star_border,
                      size: 18,
                      color: move.isPrimary
                          ? context.colors.accent
                          : context.colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(move.san,
                        style:
                            (move.isPrimary ? AppText.bodyBold : AppText.body)
                                .copyWith(color: context.colors.textPrimary)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        move.isPrimary ? 'glavni' : 'dodirnite za glavni',
                        style: AppText.micro
                            .copyWith(color: context.colors.textMuted),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ukloni',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _busy ? null : () => _remove(move),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// What is played here, as a list to choose from.
  ///
  /// Popularity alone cannot answer "is there a better move", so every row
  /// carries the score from the side to move as well — how those games ended,
  /// which is history and not an evaluation, and it says so. Kept moves wear
  /// their star here too, and the move just proposed is marked, so the
  /// comparison is with the thing actually being decided.
  Widget _buildBook(BuildContext context) {
    final book = _book!;
    final moves = book.all.isNotEmpty ? book.all : book.replies;
    final kept = {for (final move in _kept) move.uci};

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Šta se ovde igra',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
              Text('${book.total} partija',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Drugi procenat je koliko su te partije donele strani na potezu — '
            'kako je prošlo, ne koliko je dobro.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 6),
          if (moves.isEmpty)
            Text('Nijedna partija iz baze ne prolazi kroz ovu poziciju.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted))
          else
            for (final reply in moves)
              _bookRow(context, reply, kept.contains(reply.uci)),
          if (_proposalUci != null &&
              moves.isNotEmpty &&
              !moves.any((m) => m.uci == _proposalUci))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$_proposalSan nije među ovim potezima — ovde se retko igra.',
                style: AppText.caption.copyWith(color: context.colors.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bookRow(BuildContext context, OpponentReply reply, bool isKept) {
    final mine = reply.uci == _proposalUci;
    final score = reply.scoreFor(white_: _forWhite);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: isKept
                ? Icon(Icons.star, size: 14, color: context.colors.accent)
                : (mine
                    ? Icon(Icons.arrow_right,
                        size: 16, color: context.colors.textPrimary)
                    : const SizedBox.shrink()),
          ),
          SizedBox(
            width: 64,
            child: Text(
              reply.san,
              style: (mine ? AppText.bodyBold : AppText.body).copyWith(
                color: mine
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('${(reply.share * 100).round()}%',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          Expanded(
            child: Text(
              '${score.round()}% za ${_forWhite ? "belog" : "crnog"}',
              style:
                  AppText.caption.copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    // Wrap and not Row: four Serbian labels do not fit a 360 dp phone, and a
    // release build clips the overflow without drawing a stripe.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (_proposalSan != null) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _keep,
            icon: const Icon(Icons.playlist_add, size: 18),
            label: Text('Uzmi $_proposalSan'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _discard,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Odbaci'),
          ),
        ] else ...[
          OutlinedButton.icon(
            // Before deciding, this is a confession and is written down as one.
            // After a move is played the same list arrives by itself and costs
            // the student nothing in the schedule.
            onPressed: _busy || _book != null ? null : _showBook,
            icon: const Icon(Icons.menu_book, size: 18),
            label: const Text('Ne znam'),
          ),
          OutlinedButton.icon(
            onPressed: _busy || _thinking ? null : _askEngine,
            icon: const Icon(Icons.psychology_outlined, size: 18),
            label: const Text('Pitaj motor'),
          ),
          FilledButton.icon(
            onPressed: _busy || _kept.isEmpty ? null : _openReplies,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Dalje'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _advance,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Preskoči'),
          ),
        ],
      ],
    );
  }

  /// The engine's lines, and the two dials that decide what it answers.
  ///
  /// Depth and the number of lines sit here rather than in Settings because
  /// this is where the question is asked — and they *are* the settings, the
  /// same ones the analysis board uses, so changing them here changes them
  /// everywhere rather than making a second copy nobody can find.
  Widget _buildEngine(BuildContext context) {
    final settings = AppSettingsService.instance;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined,
                  size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Motor',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
              if (_thinking)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.colors.accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Lokalni motor — ne troši Lichess kvotu. Ocena je iz ugla belog.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 6),
          EngineAnalysisDials(
            depth: _analysisDepth,
            lines: _analysisLines,
            enabled: !_thinking,
            onRestart: _askEngine,
            onDepthChanged: (value) => _applyAnalysisDials(depth: value),
            onLinesChanged: (value) => _applyAnalysisDials(lines: value),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final line in (_linesFen == _current ? _lines : const []))
            InkWell(
              onTap:
                  _busy || _proposalUci != null ? null : () => _playLine(line),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(line.evaluation,
                          style: AppText.bodyBold
                              .copyWith(color: context.colors.textPrimary)),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(line.bestMoveSan,
                          style: AppText.body
                              .copyWith(color: context.colors.textPrimary)),
                    ),
                    Expanded(
                      child: Text(
                        line.continuationSan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                    ),
                    if (line.depth > 0)
                      Text('d${line.depth}',
                          style: AppText.micro
                              .copyWith(color: context.colors.textMuted)),
                  ],
                ),
              ),
            ),
          if (_lines.isNotEmpty &&
              _linesFen == _current &&
              _proposalUci == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Dodirnite liniju da odigrate njen prvi potez.',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ),
        ],
      ),
    );
  }

  Widget _engineDial(
    BuildContext context, {
    required String label,
    required int value,
    required List<int> values,
    required Future<void> Function(int) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: AppText.micro.copyWith(color: context.colors.textMuted)),
        DropdownButton<int>(
          value: values.contains(value) ? value : values.first,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: AppText.caption.copyWith(color: context.colors.textPrimary),
          items: [
            for (final option in values)
              DropdownMenuItem(value: option, child: Text('$option')),
          ],
          onChanged: _thinking
              ? null
              : (picked) {
                  if (picked != null) onChanged(picked);
                },
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nema više pozicija u redu.',
              style: AppText.bodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Sve što ste izabrali je sačuvano. Sledeći talas se otvara kad se '
              'vratite na neku od pozicija i uzmete još odgovora.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            // What the last wave covered, said here too. Emptying the queue is
            // exactly when the number matters most, and it used to vanish with
            // the position it was written under.
            if (_note != null) ...[
              const SizedBox(height: 10),
              Text(
                _note!,
                style: AppText.caption.copyWith(color: context.colors.accent),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
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
