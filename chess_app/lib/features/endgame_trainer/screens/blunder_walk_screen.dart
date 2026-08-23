import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/endgame_info_panel.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

import '../services/holding_pattern.dart';

// The service re-exports the game model, as it does the drill step.
import '../services/endgame_api_service.dart';

/// Walks a real game from where it first went wrong, stopping at every mistake.
///
/// A separate screen from the trainer because it is a different object. The
/// trainer asks one question of one board; this walks a game — a line of moves,
/// a cursor over it, and several exercises in sequence — and folding the two
/// together would put two unrelated modes in one file.
///
/// Two rules shape it, and both came from watching the trainer being used:
///
/// The board is never turned automatically. Mistakes alternate between the
/// players in real games — three in six moves, black then white then black, in
/// the game the tests use — so turning it at each stop would spin it under the
/// reader. The flip button is there for whoever wants it.
///
/// And the continuation is played on the board rather than listed under it.
/// After a right answer the board stays where it is and the game plays forward
/// from there, a move at a time, stopping at the next mistake. A row of move
/// buttons would say the same thing in notation, which is the one form a child
/// working on a board does not need it in - and the first version of this
/// screen did exactly that.
///
/// Touching the navigation takes the playback over. From then on the moves are
/// stepped by hand, still no further than the next mistake: an unanswered one
/// is a wall, and the strip is handed only the positions up to it, so it stops
/// there without knowing why.
class BlunderWalkScreen extends StatefulWidget {
  const BlunderWalkScreen({
    super.key,
    required this.session,
    this.minBlunders,
    this.maxBlunders,
    this.minElo,
    this.maxElo,
    this.material,
    this.api,
  });

  final UserSession session;
  final int? minBlunders;
  final int? maxBlunders;
  final int? minElo;
  final int? maxElo;
  final String? material;

  /// Injected in tests, which have no server.
  final EndgameApiService? api;

  @override
  State<BlunderWalkScreen> createState() => _BlunderWalkScreenState();
}

class _BlunderWalkScreenState extends State<BlunderWalkScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final EndgameApiService _api =
      widget.api ?? EndgameApiService(authToken: widget.session.token);

  BlunderWalk? _walk;
  PlayerColor _orientation = PlayerColor.white;
  bool _loading = true;
  String? _error;
  String? _feedback;
  bool _feedbackIsGood = false;

  /// Positions from the opening board to the wall, one per ply plus the start.
  /// Rebuilt whenever the wall moves, which is the only time it changes.
  List<String> _fens = const [];

  /// Plays the continuation forward after an answer. Slow enough to follow a
  /// rook across the board and fast enough not to be waited on.
  static const _playbackStep = Duration(milliseconds: 850);

  /// How long the mistake stays drawn on the board when a stop is reached.
  ///
  /// Long enough to look at, short enough that it is gone before the reader
  /// starts trying moves - an arrow left standing while they think would sit on
  /// top of the squares they are trying to read.
  static const _arrowLinger = Duration(seconds: 4);

  /// The punishment, once it has been asked for: the position after the
  /// mistake and the tables' best play from there, one board per ply.
  ///
  /// Kept apart from the walk's own line rather than folded into it. The game
  /// went one way and this is the way it did not go, and a reader who has just
  /// watched them mixed together has no way to tell which was which.
  List<String>? _refutation;
  int _refutationAt = 0;
  bool _fetchingRefutation = false;

  /// The move that lost the result, drawn from where it started to where it
  /// went. "White played Ng4" is a sentence to decode; the arrow is the same
  /// thing already decoded, which on a board is the form that costs nothing.
  List<ChessArrow> _arrows = const [];
  Timer? _arrowTimer;

  /// How much of it plays by itself.
  ///
  /// Between two mistakes the gap is usually a move or three and watching it is
  /// the point. After the last one the rest of the game is opened, and that is
  /// another matter: the median tail is eleven moves but a quarter run past
  /// twenty and the longest is a hundred and fifty-five, which at this speed is
  /// two minutes of watching a decided game. So the playback stops here and the
  /// rest stays open to walk through at whatever pace the reader likes.
  static const _maxPlayback = 12;

  Timer? _playback;

  @override
  void dispose() {
    _playback?.cancel();
    _arrowTimer?.cancel();
    // Leaving is one of the three things that stop a sentence. A voice still
    // explaining a position on a screen nobody is looking at is the surest way
    // to make someone switch the whole feature off.
    SpeechService.instance.stop();
    super.dispose();
  }

  /// Points at the mistake standing on this board, for a few seconds.
  void _markMistake(GameBlunder blunder) {
    _arrowTimer?.cancel();
    if (blunder.playedUci.length < 4) return;
    setState(() {
      _arrows = [
        ChessArrow(
          from: blunder.playedUci.substring(0, 2),
          to: blunder.playedUci.substring(2, 4),
          colorCode: 'R',
        ),
      ];
    });
    _arrowTimer = Timer(_arrowLinger, () {
      if (mounted) setState(() => _arrows = const []);
    });
  }

  void _clearMarks() {
    _arrowTimer?.cancel();
    _arrowTimer = null;
    if (_arrows.isNotEmpty) setState(() => _arrows = const []);
  }

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _error = null;
      _feedback = null;
      _leaveRefutation();
    });

    final result = await _api.fetchNextGame(
      minBlunders: widget.minBlunders,
      maxBlunders: widget.maxBlunders,
      minElo: widget.minElo,
      maxElo: widget.maxElo,
      material: widget.material,
      excludeId: _walk?.game.id,
      includeOnline: AppSettingsService.instance.endgameIncludeOnline,
    );
    if (!mounted) return;

    if (result.game == null || !result.game!.isPlayable) {
      setState(() {
        _loading = false;
        _error = result.outcome == EndgameFetchOutcome.noneMatch
            ? 'Nema partije koja odgovara traženim uslovima.'
            : 'Trenutno nije moguće dobaviti partiju.';
      });
      return;
    }

    _stopPlayback();
    _kept.clear();
    final walk = BlunderWalk(result.game!);
    setState(() {
      _walk = walk;
      _loading = false;
      // The side that has to find something, once, at the start. After that it
      // stays where the reader put it.
      _orientation = _sideToMove(walk.game.startFen) == 'white'
          ? PlayerColor.white
          : PlayerColor.black;
      _feedbackIsGood = false;
      _feedback = null;
    });
    _rebuildLine();
    final first = walk.pending;
    if (first != null) _markMistake(first);
  }

  String _sideToMove(String fen) {
    final parts = fen.split(' ');
    return parts.length < 2 || parts[1] == 'w' ? 'white' : 'black';
  }

  /// Replays the game up to the wall and caches every position on the way.
  void _rebuildLine() {
    final walk = _walk;
    if (walk == null) return;
    final board = chess.Chess.fromFEN(walk.game.startFen);
    final fens = <String>[board.fen];
    for (var ply = 0; ply < walk.frontier; ply++) {
      if (board.move(walk.game.moves[ply]) == false) break;
      fens.add(board.fen);
    }
    setState(() => _fens = fens);
    _showCurrent();
  }

  void _showCurrent() {
    final walk = _walk;
    if (walk == null || _fens.isEmpty) return;
    _boardController.loadFen(_fens[walk.cursor.clamp(0, _fens.length - 1)]);
  }

  void _seek(int index) {
    final walk = _walk;
    if (walk == null) return;
    // Reaching for the strip is how the reader says they would rather do this
    // themselves - including doing without the rest of the sentence.
    _stopPlayback();
    SpeechService.instance.stop();
    _clearMarks();
    setState(() {
      // Reaching for the game is leaving the punishment, and "Na grešku" is
      // offered while one is open.
      _leaveRefutation();
      walk.seek(index);
      _feedback = null;
    });
    _showCurrent();
    final here = walk.pending;
    if (here != null) _markMistake(here);
  }

  void _stopPlayback() {
    _playback?.cancel();
    _playback = null;
  }

  /// Plays out how the mistake would have been punished.
  Future<void> _showRefutation(GameBlunder blunder) async {
    final board = chess.Chess.fromFEN(blunder.fen);
    if (board.move(blunder.played) == false) return;

    setState(() => _fetchingRefutation = true);
    final moves = await _api.fetchBestLine(fen: board.fen);
    if (!mounted) return;

    if (moves == null || moves.isEmpty) {
      setState(() {
        _fetchingRefutation = false;
        _feedbackIsGood = false;
        _feedback = 'Kaznu trenutno nije moguće izvesti — tablica ne odgovara.';
      });
      return;
    }

    final fens = <String>[board.fen];
    for (final san in moves) {
      if (board.move(san) == false) break;
      fens.add(board.fen);
    }

    _stopPlayback();
    _clearMarks();
    setState(() {
      _fetchingRefutation = false;
      _refutation = fens;
      _refutationAt = 0;
      _feedbackIsGood = false;
      // The move goes at the end, after a noun, rather than inside the verb
      // phrase. "Ovako se Qxb2 kažnjava" reads passably and hears badly: spoken
      // out, the notation lands in the middle of a construction the listener is
      // still waiting to have finished.
      _feedback = 'Ovako se kažnjava potez ${blunder.played}.';
    });
    _boardController.loadFen(fens.first);

    _playback = Timer.periodic(_playbackStep, (timer) {
      if (!mounted || _refutation == null) {
        _stopPlayback();
        return;
      }
      // Let the sentence finish first. A board that moves under a verdict
      // still being read leaves the listener hearing about a position that is
      // no longer on the screen.
      if (SpeechService.instance.isSpeaking) return;
      if (_refutationAt + 1 >= _refutation!.length) {
        _stopPlayback();
        return;
      }
      setState(() => _refutationAt++);
      _boardController.loadFen(_refutation![_refutationAt]);
    });
  }

  /// Whether the stop standing here has already been kept.
  final Set<int> _kept = {};
  bool _keeping = false;

  /// Keeps this position, with what the screen knows written into it.
  Future<void> _keepForLater(GameBlunder blunder) async {
    final walk = _walk;
    if (walk == null || _keeping || _kept.contains(blunder.ply)) return;
    setState(() => _keeping = true);

    final who = blunder.side == 'white' ? 'Beli' : 'Crni';
    final lost = blunder.lostAWin ? 'ispustio dobitak' : 'izgubio remi';
    final lesson = holdingLesson(
      fen: blunder.fen,
      holdingUci: blunder.shouldPlayUci,
      playedUci: blunder.playedUci,
    );

    final ok = await _api.keepForLater(
      fen: blunder.fen,
      title: '${blunder.material ?? 'Završnica'} — nejasno',
      description: [
        '$who je odigrao ${blunder.played} i $lost.',
        'Držalo je: ${blunder.shouldPlay.join(', ')}.',
        lesson,
        walk.game.label,
      ].whereType<String>().join(' '),
    );
    if (!mounted) return;
    setState(() {
      _keeping = false;
      if (ok) _kept.add(blunder.ply);
      _feedbackIsGood = ok;
      _feedback = ok
          ? 'Zapamćeno u „Moje pozicije", oznaka „Nejasno".'
          : 'Poziciju trenutno nije moguće sačuvati.';
    });
  }

  /// Puts the game back where it was before the punishment was shown.
  void _closeRefutation() {
    _stopPlayback();
    setState(() {
      _leaveRefutation();
      _feedback = null;
    });
    _showCurrent();
  }

  /// Forgets the punishment line, wherever we are leaving it from.
  ///
  /// Written once and called from all three exits, because the one that forgot
  /// it locked the board: loading the next game reset the walk, the cursor, the
  /// kept marks and the feedback, and left `_refutation` standing. The board is
  /// only live while there is no punishment on it, so the new game opened
  /// unplayable, with no move strip and a "Nazad na partiju" button belonging
  /// to a position two games back.
  ///
  /// Call inside a setState.
  void _leaveRefutation() {
    _refutation = null;
    _refutationAt = 0;
    _fetchingRefutation = false;
  }

  /// Walks the game forward, one move at a time, as far as it is worth doing
  /// by itself.
  void _playForward() {
    _stopPlayback();
    var played = 0;
    _playback = Timer.periodic(_playbackStep, (timer) {
      final walk = _walk;
      if (!mounted || walk == null || !walk.canGoForward) {
        _stopPlayback();
        return;
      }
      if (SpeechService.instance.isSpeaking) return;
      setState(walk.forward);
      _showCurrent();
      played++;
      if (!walk.canGoForward || played >= _maxPlayback) {
        _stopPlayback();
        _arrive();
      }
    });
  }

  /// What the screen says once the board has stopped moving.
  ///
  /// The verdict on the previous move is cleared here rather than left to age.
  /// A "correct" still sitting under a fresh question reads as an answer to
  /// that question, which is the one thing it is not.
  void _arrive() {
    final walk = _walk;
    if (walk == null) return;
    final here = walk.pending;
    if (here != null) {
      setState(() => _feedback = null);
      _markMistake(here);
      return;
    }
    if (walk.isFinished) {
      setState(() {
        _feedbackIsGood = true;
        _feedback = 'Kraj partije — nema više poteza. Nađeno '
            '${walk.solvedCount} od ${walk.totalCount}.';
      });
    }
  }

  /// A move from the reader, which answers whatever was being said.
  Future<void> _onMove(String from, String to) async {
    SpeechService.instance.stop();
    final walk = _walk;
    final blunder = walk?.pending;
    if (walk == null || blunder == null) return;
    // Only at the wall, and only on the board the wall stands on.
    if (walk.cursor != blunder.ply) return;

    final board = chess.Chess.fromFEN(blunder.fen);
    final piece = board.get(from);
    final isPromotion = piece != null &&
        piece.type == chess.PieceType.PAWN &&
        (to.endsWith('8') || to.endsWith('1'));
    const promotion = 'q';
    if (board.move({'from': from, 'to': to, 'promotion': promotion}) == false) {
      return;
    }
    final san = board.getHistory().last.toString();
    final uci = isPromotion ? '$from$to$promotion' : '$from$to';

    final verdict = walk.submit(uci, san: san);
    if (!verdict.correct) {
      setState(() {
        _feedbackIsGood = false;
        _feedback = blunder.lostAWin
            ? '$san takođe ispušta dobitak. Probajte drugi potez.'
            : '$san ne drži remi. Probajte drugi potez.';
      });
      _showCurrent();
      return;
    }

    _afterStop(blunder, found: san);
  }

  void _reveal() {
    final walk = _walk;
    final blunder = walk?.pending;
    if (walk == null || blunder == null) return;
    walk.reveal();
    _afterStop(blunder, found: null);
  }

  /// Says how it went, then lets the game play on from where the board is.
  ///
  /// The board is not moved to the next mistake. Jumping there would skip the
  /// part worth seeing - what the players actually did with the position - and
  /// it is the part this whole screen exists to show.
  void _afterStop(GameBlunder blunder, {String? found}) {
    final walk = _walk!;

    final verdict = found == null
        ? 'Držalo je: ${blunder.shouldPlay.join(', ')}.'
        : (blunder.shouldPlay.length == 1
            ? 'Tačno — $found je bio jedini potez.'
            : 'Tačno. Držalo je i: '
                '${blunder.shouldPlay.where((m) => m != found).join(', ')}.');

    // What the moves that hold had in common, when they had anything. Said
    // now rather than while the position was open, where it would have been a
    // hint rather than a lesson.
    final lesson = holdingLesson(
      fen: blunder.fen,
      holdingUci: blunder.shouldPlayUci,
      playedUci: blunder.playedUci,
    );
    final taught = lesson == null ? verdict : '$verdict $lesson';

    // The last answer opens the game to its end rather than to the next stop,
    // so it is worth saying which of the two just happened - and if there is
    // nothing left to open, saying that instead.
    final last = walk.answeredCount == walk.totalCount;
    final movesLeft = walk.game.moves.length - walk.cursor;
    // The arrow pointed at a mistake that is now behind us.
    _clearMarks();
    setState(() {
      _feedbackIsGood = found != null;
      if (!last) {
        _feedback = '$taught Partija se nastavlja onako kako je odigrana.';
      } else if (movesLeft <= 0) {
        _feedback = '$taught To je bila poslednja greška i poslednji potez — '
            'kraj partije.';
      } else {
        _feedback = '$taught To je bila poslednja greška — ostatak partije je '
            'otključan, prođite kroz njega trakom.';
      }
    });
    // The wall has moved, so the line the strip walks is longer now.
    _rebuildLine();
    _playForward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('Greške iz partija')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    final walk = _walk;
    if (walk == null) return const SizedBox.shrink();

    final wide = Breakpoints.isWide(context);
    final panel = EndgameInfoPanel(
      title: _taskText(walk),
      subtitle: _hintText(walk),
      chips: _chips(walk),
      message: _feedback,
      messageIsGood: _feedbackIsGood,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: EndgameBoardLayout(
            wide: wide,
            constraints: constraints,
            panel: panel,
            // The strip and the buttons under the board; on a phone the panel
            // as well.
            reserveHeight: wide ? 190 : 320,
            builder: (boardSize) {
              return Column(
                children: [
                  Center(
                    child: BoardWithCoordinates(
                      size: boardSize,
                      orientation: _orientation,
                      builder: (inner) => ChessBoardWithOverlay(
                        controller: _boardController,
                        boardOrientation: _orientation,
                        boardSize: inner,
                        isAllowedToMove: _refutation == null &&
                            walk.pending != null &&
                            walk.cursor == walk.pending!.ply,
                        isDrawingMode: false,
                        drawingStartSquare: null,
                        arrows: _arrows,
                        engineArrows: const [],
                        onMove: _onMove,
                        onSquareTapForDrawing: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_refutation == null)
                    MoveNavigationControls(
                      cursor: LinearMoveCursor(
                        fens: _fens,
                        index: walk.cursor,
                        onSeek: _seek,
                      ),
                      // No chips. Naming the moves under the board says in
                      // notation what the board is already saying in pieces, and
                      // it is the form a child working on a board needs least.
                      showMoveChips: false,
                      centerLabel: 'Potez ${walk.cursor} od ${walk.frontier}',
                      onFlipBoard: () => setState(() {
                        _orientation = _orientation == PlayerColor.white
                            ? PlayerColor.black
                            : PlayerColor.white;
                      }),
                    ),
                  if (!wide) ...[
                    const SizedBox(height: 8),
                    panel,
                  ],
                  const SizedBox(height: 10),
                  _buildControls(walk),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// The heading is always something to do, never a description of where you
  /// happen to be standing.
  String _taskText(BlunderWalk walk) {
    if (_refutation != null) return 'Kazna se odigrava sama';
    final here = walk.pending;
    if (here != null) {
      final who = here.side == 'white' ? 'Beli' : 'Crni';
      return here.lostAWin
          ? '$who je ovde odigrao ${here.played} i ispustio dobitak'
          : '$who je ovde odigrao ${here.played} i izgubio remi';
    }
    if (walk.nextStop != null) return 'Idite napred do sledeće greške';
    return walk.isFinished
        ? 'Partija je prošla — nađeno ${walk.solvedCount} od ${walk.totalCount}'
        : 'Sve greške su rešene — ostatak partije je otključan';
  }

  /// And the instruction under it names the thing to press or the thing to do
  /// on the board, because "you are between two mistakes" is a fact and not an
  /// instruction.
  String? _hintText(BlunderWalk walk) {
    // Reported from the desktop build, and the second time the same lesson has
    // had to be learned here: the reader could not pick up a piece and thought
    // the board had frozen. It had not - a punishment is being shown and there
    // is nothing to play - but nothing on the screen said so, and a mode you
    // are in without knowing it is indistinguishable from a bug.
    if (_refutation != null) {
      return 'Tabla se ovde ne igra — gledate kako se greška kažnjava. '
          'Dugme „Nazad na partiju" vraća na šetnju.';
    }
    final here = walk.pending;
    if (here != null) {
      return here.lostAWin
          ? 'Odigrajte na tabli potez koji zadržava dobitak.'
          : 'Odigrajte na tabli potez koji drži remi.';
    }
    final next = walk.nextStop;
    if (next != null) {
      final away = next.ply - walk.cursor;
      // And why the board does not answer here. A piece that lifts and falls
      // back with nothing said reads as a broken board rather than as a locked
      // one, which is how this got reported.
      return 'Tabla se igra samo na grešci. Još $away ${_moveWord(away)} '
          'napred — strelicom ispod table ili dugmetom „Na grešku".';
    }
    return walk.isFinished
        ? null
        : 'Prođite ostatak partije trakom ispod table.';
  }

  /// One potez, two to four poteza, and the same again past twenty.
  String _moveWord(int n) =>
      (n % 10 == 1 && n % 100 != 11) ? 'potez' : 'poteza';

  List<String> _chips(BlunderWalk walk) {
    final blunder = walk.pending;
    return [
      walk.game.label,
      'Greške: ${walk.answeredCount}/${walk.totalCount}',
      if (blunder?.material != null) blunder!.material!,
    ];
  }

  Widget _buildControls(BlunderWalk walk) {
    final blunder = walk.pending;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Jumps to the next unanswered stop. This used to be written against
        // `pending`, which is the mistake *at* the cursor - so the condition
        // could never hold and the button never appeared.
        if (blunder == null && walk.nextStop != null)
          FilledButton.icon(
            onPressed: () => _seek(walk.nextStop!.ply),
            icon: const Icon(Icons.error_outline),
            label: const Text('Na grešku'),
          ),
        if (blunder != null)
          TextButton.icon(
            onPressed: _reveal,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Pokaži'),
          ),
        // Offered once the stop is behind us: before that it is the solution.
        if (_refutation == null && blunder == null && walk.atCursor != null)
          OutlinedButton.icon(
            onPressed: _fetchingRefutation
                ? null
                : () => _showRefutation(walk.atCursor!),
            icon: const Icon(Icons.gavel),
            label: const Text('Zašto je loše'),
          ),
        if (_refutation != null)
          FilledButton.icon(
            onPressed: _closeRefutation,
            icon: const Icon(Icons.close),
            label: const Text('Nazad na partiju'),
          ),
        // Wherever there is a mistake on this board, answered or not.
        if (_refutation == null && walk.atCursor != null)
          TextButton.icon(
            onPressed: _keeping || _kept.contains(walk.atCursor!.ply)
                ? null
                : () => _keepForLater(walk.atCursor!),
            icon: Icon(_kept.contains(walk.atCursor!.ply)
                ? Icons.bookmark_added_outlined
                : Icons.bookmark_add_outlined),
            label: Text(_kept.contains(walk.atCursor!.ply)
                ? 'Zapamćeno'
                : 'Zapamti za kasnije'),
          ),
        FilledButton.icon(
          onPressed: _loadNext,
          icon: const Icon(Icons.arrow_forward),
          label: Text(walk.isFinished ? 'Sledeća partija' : 'Preskoči'),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadNext,
                child: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
      );
}
