import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/core/speech/move_words.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

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
    this.attemptApi,
    this.speech,
  });

  final UserSession session;
  final int? minBlunders;
  final int? maxBlunders;
  final int? minElo;
  final int? maxElo;
  final String? material;

  /// Injected in tests, which have no server.
  final EndgameApiService? api;

  /// Injected in tests — fake the client, assert the request (rule 7) — for
  /// the attempt log this screen writes to per stop
  /// (docs/PLAN-NAPREDAK-VEZBI.md §4).
  final PuzzleAttemptApi? attemptApi;

  /// Injected in tests. The app's one `SpeechService` otherwise.
  final SpeechService? speech;

  @override
  State<BlunderWalkScreen> createState() => _BlunderWalkScreenState();
}

class _BlunderWalkScreenState extends State<BlunderWalkScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final PuzzleAttemptApi _attemptApi =
      widget.attemptApi ?? PuzzleAttemptApi(authToken: widget.session.token);

  late final EndgameApiService _api =
      widget.api ?? EndgameApiService(authToken: widget.session.token);

  BlunderWalk? _walk;
  PlayerColor _orientation = PlayerColor.white;
  bool _loading = true;
  String? _error;
  List<SpokenLine> _feedback = const [];

  /// A sentence that is only drawn, with no row in the table: never said.
  String? _note;
  bool _feedbackIsGood = false;

  /// Bumped whenever a new game opens, so its first task is said even when its
  /// words are the last game's.
  int _panelSerial = 0;

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

  /// The mistake the open punishment is for, which its task line names.
  GameBlunder? _refutationOf;

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
    _stopSpeech();
    super.dispose();
  }

  SpeechService get _speech => widget.speech ?? SpeechService.instance;

  /// Cuts the voice off, for what the reader does. Guarded: a voice that
  /// throws must never stop a move or the screen's own teardown.
  void _stopSpeech() {
    try {
      unawaited(_speech.stop().catchError((Object _) {}));
    } catch (_) {}
  }

  /// Says [line], forced: the same verdict twice in a row is two verdicts.
  void _say(SpokenLine line) {
    if (!mounted) return;
    try {
      unawaited(_speech.speakLine(line, force: true).catchError((Object _) {}));
    } catch (_) {}
  }

  /// Draws and says the verdict: the panel draws each line's text and the
  /// voice plays the same line. [note] is drawn under it and never said.
  void _tell(List<SpokenLine> lines, {required bool good, String? note}) {
    setState(() {
      _feedback = lines;
      _note = note;
      _feedbackIsGood = good;
    });
    lines.forEach(_say);
  }

  /// Forgets the verdict, and what was last said, so the same sentence is said
  /// again when it comes round. Call inside a `setState`.
  void _clearFeedback() {
    _feedback = const [];
    _note = null;
    try {
      _speech.forget();
    } catch (_) {}
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

  /// Writes one stop's outcome to the attempt log — found unaided, revealed
  /// with "Show", or walked past unanswered (docs/PLAN-NAPREDAK-VEZBI.md §4).
  /// Fired, not awaited: recording must never hold up the board.
  void _recordStop(GameBlunder blunder,
      {required bool found, bool skipped = false}) {
    final gameId = _walk?.game.id;
    if (gameId == null) return;
    // The id is opaque on the wire: a game named 'bg_test' in a fixture is
    // recorded like a game named '42'.
    unawaited(_attemptApi.record(
      source: PuzzleSource.blunderGame,
      puzzleId: PuzzleSource.blunderGameId(gameId, blunder.ply),
      solved: found,
      hinted: !found && !skipped,
      skipped: skipped,
    ));
  }

  Future<void> _loadNext() async {
    // Leaving a stop that is still standing, unanswered, is a skip.
    final pending = _walk?.pending;
    if (pending != null) {
      _recordStop(pending, found: false, skipped: true);
    }

    // Moving on is the reader saying they are done with the last sentence.
    _stopSpeech();
    setState(() {
      _loading = true;
      _error = null;
      _clearFeedback();
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
            ? 'No game matches the requested criteria.'
            : 'Currently unable to fetch a game.';
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
      _clearFeedback();
      _panelSerial++;
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
    _stopSpeech();
    _clearMarks();
    setState(() {
      // Reaching for the game is leaving the punishment, and "Na grešku" is
      // offered while one is open.
      _leaveRefutation();
      walk.seek(index);
      _clearFeedback();
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
      setState(() => _fetchingRefutation = false);
      // The tablebase is what answers, and it did not.
      _tell([
        SpokenLine([SpeechVocabulary.tablebaseSilent])
      ], good: false);
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
      _refutationOf = blunder;
      _refutationAt = 0;
      _feedbackIsGood = false;
      // The task line says what is playing ('Watch the refutation of king d5.');
      // there is no verdict under it.
      _clearFeedback();
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
      if (_speech.isSpeaking) return;
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

    final who = blunder.side == 'white' ? 'White' : 'Black';
    final lost = blunder.lostAWin ? 'let the win go' : 'lost the draw';

    final ok = await _api.keepForLater(
      fen: blunder.fen,
      title: '${blunder.material ?? 'Endgame'} — unclear',
      description: [
        '$who played ${blunder.played} and $lost.',
        'Holding moves were: ${blunder.shouldPlay.join(', ')}.',
        walk.game.label,
      ].whereType<String>().join(' '),
    );
    if (!mounted) return;
    setState(() {
      _keeping = false;
      if (ok) _kept.add(blunder.ply);
    });
    // Said as a message and not as a line of the panel: saving is not part of
    // the lesson, and the message cannot take the screen down.
    if (ok) {
      AppFeedback.success(context, EndgameApiService.keptMessage);
    } else {
      AppFeedback.error(context, 'Currently unable to save position.');
    }
  }

  /// Puts the game back where it was before the punishment was shown.
  void _closeRefutation() {
    _stopPlayback();
    setState(() {
      _leaveRefutation();
      _clearFeedback();
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
    _refutationOf = null;
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
      if (_speech.isSpeaking) return;
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
      setState(_clearFeedback);
      _markMistake(here);
      return;
    }
    if (walk.isFinished) {
      // The task line is the end ('Game finished. Found 3 of 5.'); the verdict
      // under it is cleared so the two do not say it twice.
      setState(() {
        _feedbackIsGood = true;
        _feedback = const [];
        _note = null;
      });
    }
  }

  /// A move from the reader, which answers whatever was being said.
  Future<void> _onMove(String from, String to, String promotion) async {
    _stopSpeech();
    final walk = _walk;
    final blunder = walk?.pending;
    if (walk == null || blunder == null) return;
    // Only at the wall, and only on the board the wall stands on.
    if (walk.cursor != blunder.ply) return;

    final board = chess.Chess.fromFEN(blunder.fen);
    // Asked of the position rather than of the destination square: a rook
    // reaching the eighth rank is not a promotion, and a pawn taking on it is.
    final isPromotion = isPromotionMove(board, from, to);
    final piece = promotion.isEmpty ? 'q' : promotion;
    if (board.move({'from': from, 'to': to, 'promotion': piece}) == false) {
      return;
    }
    final san = board.getHistory().last.toString();
    final uci = isPromotion ? '$from$to$piece' : '$from$to';

    final verdict = walk.submit(uci, san: san);
    if (!verdict.correct) {
      // The move, said as a move, and what it costs.
      final facts = MoveWords.factsOf(blunder.fen, from, to,
          promotion: isPromotion ? piece : null);
      _tell(
        facts == null
            ? const []
            : [
                SpokenLine([
                  ...MoveWords.bare(facts),
                  blunder.lostAWin
                      ? SpeechVocabulary.alsoLetsWinGo
                      : SpeechVocabulary.doesNotHoldDraw,
                ])
              ],
        good: false,
      );
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
    _recordStop(blunder, found: found != null);

    // The last answer opens the game to its end rather than to the next stop,
    // so it is worth saying which of the two just happened - and if there is
    // nothing left to open, saying that instead.
    final last = walk.answeredCount == walk.totalCount;
    // The cursor stands on the mistake, which is itself a move of the game: one
    // move left is that one, and after it there is nothing. (It read `<= 0`,
    // which no game can reach - the branch was dead.)
    final movesLeft = walk.game.moves.length - walk.cursor;
    // The arrow pointed at a mistake that is now behind us.
    _clearMarks();
    // One line: the verdict and where the game goes from here. A reveal has
    // no „Correct" to say, and the holding moves it names are a list of
    // notation the table has no words for - drawn, not said.
    _tell(
      [
        SpokenLine([
          if (found != null) SpeechVocabulary.correct,
          last && movesLeft <= 1
              ? SpeechVocabulary.lastMistakeGameOver
              : SpeechVocabulary.gameContinues,
        ])
      ],
      good: found != null,
      note: found == null
          ? 'Holding moves were: ${blunder.shouldPlay.join(', ')}.'
          : null,
    );
    // The wall has moved, so the line the strip walks is longer now.
    _rebuildLine();
    _playForward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        title: const Text('Game mistakes'),
        actions: const [BoardViewMenu()],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    final walk = _walk;
    if (walk == null) return const SizedBox.shrink();

    final wide = Breakpoints.isWide(context);
    final task = _task(walk);
    final panel = TrainerInfoPanel(
      key: ValueKey('panel-$_panelSerial'),
      task: task,
      detail: _detail(walk),
      chips: _chips(walk),
      message: _feedback,
      note: _note,
      messageIsGood: _feedbackIsGood,
      // 'The game continues as played.' as a task only repeats the verdict that
      // was just said.
      autoSpeak: !(walk.pending == null &&
          walk.nextStop == null &&
          !walk.isFinished &&
          _refutation == null),
      speech: widget.speech,
    );

    final cursor = LinearMoveCursor(
      fens: _fens,
      index: walk.cursor,
      onSeek: _seek,
    );
    Widget board(double boardSize) => BoardWithCoordinates(
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
        );
    // Not while a punishment is playing: there is no line to walk there.
    final strip = _refutation != null
        ? null
        : MoveNavigationControls(
            cursor: cursor,
            // No chips. Naming the moves under the board says in notation what
            // the board is already saying in pieces, and it is the form a child
            // working on a board needs least.
            centerLabel: 'Move ${walk.cursor} of ${walk.frontier}',
            onFlipBoard: () => setState(() {
              _orientation = _orientation == PlayerColor.white
                  ? PlayerColor.black
                  : PlayerColor.white;
            }),
          );

    // Arrow keys drive the same cursor the strip's buttons do. A game is walked
    // more than it is clicked through, and a desktop that can only be walked
    // with the mouse reads as a phone in a window.
    Widget keys(Widget child) => MoveKeyboardShortcuts(
          cursor: cursor,
          onChanged: () {},
          // Not while a punishment is playing: there is no line to walk there,
          // and the strip is hidden for the same reason.
          enabled: _refutation == null,
          child: child,
        );

    if (LandscapeBoardLayout.applies(context)) {
      return keys(LandscapeBoardLayout(
        board: board,
        panels: panel,
        footer: [
          if (strip != null) strip,
          const SizedBox(height: AppSpacing.xs),
          _buildControls(walk),
        ],
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TrainerBoardLayout(
            wide: wide,
            constraints: constraints,
            panel: panel,
            // The strip and the buttons under the board; on a phone the panel
            // as well.
            reserveHeight: wide ? 190 : 320,
            builder: (boardSize) {
              return keys(
                Column(
                  children: [
                    Center(child: board(boardSize)),
                    const SizedBox(height: AppSpacing.sm),
                    if (strip != null) strip,
                    if (!wide) ...[
                      const SizedBox(height: AppSpacing.sm),
                      panel,
                    ],
                    const SizedBox(height: 10),
                    _buildControls(walk),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The heading is always something to do, never a description of where you
  /// happen to be standing. Said and drawn from the same line (D4).
  SpokenLine _task(BlunderWalk walk) {
    final watching = _refutationOf;
    if (_refutation != null && watching != null) {
      final facts = _factsOfPlayed(watching);
      return SpokenLine([
        SpeechVocabulary.watchRefutationOf,
        if (facts != null) ...MoveWords.bare(facts),
      ]);
    }
    final here = walk.pending;
    if (here != null) {
      // The move is said as a move, read off the position it was played in.
      final facts = _factsOfPlayed(here);
      return SpokenLine([
        SpeechVocabulary.playedHere(here.side == 'white' ? 'white' : 'black'),
        if (facts != null) ...MoveWords.bare(facts),
        here.lostAWin
            ? SpeechVocabulary.hereLetWinGo
            : SpeechVocabulary.hereLostDraw,
      ]);
    }
    if (walk.nextStop != null) return SpokenLine([SpeechVocabulary.goForward]);
    if (walk.isFinished) {
      return SpokenLine([
        SpeechVocabulary.gameFinishedFound,
        SpeechVocabulary.numberInside(walk.solvedCount.clamp(0, 99)),
        SpeechVocabulary.ofToken,
        SpeechVocabulary.number(walk.totalCount.clamp(0, 99)),
      ]);
    }
    // Every mistake answered and the game not yet at its end: the rest of it
    // is open to walk. The table has no row of its own for this, and the line
    // that says where the game goes from here is the closest.
    return SpokenLine([SpeechVocabulary.gameContinues]);
  }

  /// What to do on the board, under the task — only at a mistake.
  SpokenLine? _detail(BlunderWalk walk) {
    final here = walk.pending;
    if (_refutation != null || here == null) return null;
    return SpokenLine([
      here.lostAWin
          ? SpeechVocabulary.playMoveHoldsWin
          : SpeechVocabulary.playMoveHoldsDraw,
    ]);
  }

  /// The mistake's move as facts, from its coordinates, falling back on its
  /// notation. Null when neither can be read in its position.
  MoveFacts? _factsOfPlayed(GameBlunder blunder) {
    final uci = blunder.playedUci;
    try {
      if (uci.length >= 4) {
        final facts = MoveWords.factsOf(
            blunder.fen, uci.substring(0, 2), uci.substring(2, 4),
            promotion: uci.length > 4 ? uci[4].toLowerCase() : null);
        if (facts != null) return facts;
      }
    } catch (_) {}
    return MoveWords.factsOfSan(blunder.fen, blunder.played);
  }

  List<String> _chips(BlunderWalk walk) {
    final blunder = walk.pending;
    return [
      walk.game.label,
      'Mistakes: ${walk.answeredCount}/${walk.totalCount}',
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
            label: const Text('To mistake'),
          ),
        if (blunder != null)
          TextButton.icon(
            onPressed: _reveal,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Show'),
          ),
        // Offered once the stop is behind us: before that it is the solution.
        if (_refutation == null && blunder == null && walk.atCursor != null)
          OutlinedButton.icon(
            onPressed: _fetchingRefutation
                ? null
                : () => _showRefutation(walk.atCursor!),
            icon: const Icon(Icons.gavel),
            label: const Text('Why it is bad'),
          ),
        if (_refutation != null)
          FilledButton.icon(
            onPressed: _closeRefutation,
            icon: const Icon(Icons.close),
            label: const Text('Back to game'),
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
                ? 'Saved'
                : 'Save for later'),
          ),
        FilledButton.icon(
          onPressed: _loadNext,
          icon: const Icon(Icons.arrow_forward),
          label: Text(walk.isFinished ? 'Next game' : 'Skip'),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _loadNext,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}
