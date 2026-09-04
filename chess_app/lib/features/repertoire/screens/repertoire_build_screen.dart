import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/core/services/eval_parsing.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_judge_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/repertoire/line_text.dart';
import 'package:chess_app/features/repertoire/widgets/fork_repertoire_dialog.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_comment_panel.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_gate_picker.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_position_ask.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/repertoire/widgets/breadth_dialog.dart';
import 'package:chess_app/features/repertoire/widgets/unconfirmed_banner.dart';
import 'package:chess_app/features/repertoire/widgets/opening_banner.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/core/services/serbian_plural.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/speakable_info.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/engine_analysis_dials.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

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
/// How deep the picture is asked for, in plies, from where the board is.
///
/// Sixteen is the old default and the floor. Past that it follows the reader:
/// the line they are actually on, plus four moves of room, so a move taken here
/// lands inside the drawing instead of one ply past its edge. Capped at the
/// forty the server allows — more is a 400, and a picture nobody can read was
/// never the goal.
///
/// Top-level and pure so the rule can be tested as a rule. The screen that uses
/// it is the same screen the owner was standing on at move seven when the tree
/// stopped at move eight.
int treeDepthFor(int plyHere) {
  final wanted = plyHere + 8;
  if (wanted < 16) return 16;
  if (wanted > 40) return 40;
  return wanted;
}

class RepertoireBuildScreen extends StatefulWidget {
  const RepertoireBuildScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    this.rootPath = const [],
    this.minRating,
    this.gateUci,
    this.api,
    this.judge,
    this.analyse,
    this.onDrillHere,
    this.openingLookup,
    this.id,
    this.breadth,
  });

  final String name;
  final int? id;

  /// How wide the walk reads, from this repertoire's own row: `main`,
  /// `standard` or `broad`.
  ///
  /// Carried rather than left to the server's default, which is what made the
  /// setting inert: the dialog wrote `main` to the row and every read on this
  /// screen went on asking at 80%, so the picture and the queue disagreed with
  /// the choice the reader had just made. Null keeps the server's default,
  /// which is what a screen opened without a row (a jump into some position)
  /// should get.
  final String? breadth;

  /// 'w' or 'b' — the side being prepared. The board is turned this way and
  /// only these moves are ever asked for.
  final String color;

  final String rootFen;

  /// How the banner above the board finds an opening's name, injected for the
  /// same reason [api] and [analyse] are: the real `OpeningBookService` loads
  /// through `compute()`, and `compute()` never completes inside
  /// `testWidgets`. Without this the banner is unreachable from a test — which
  /// is how it shipped keyed on a counter that reset it on every walk
  /// advance, blanking the name at exactly the depth the rule exists for.
  final OpeningBookEntry? Function(String fen)? openingLookup;

  /// The moves that led to [rootFen], in SAN.
  ///
  /// A repertoire may start anywhere, so without this the breadcrumb would
  /// begin mid-air: a Smith-Morra repertoire whose root is move four would read
  /// as though the game started there. Empty for a repertoire built from a
  /// pasted position, where there is no line to tell.
  final List<String> rootPath;

  /// The rating band the opponent's replies are counted in. A child meets the
  /// moves of their own opponents, not a grandmaster's.
  final int? minRating;

  /// The move this repertoire goes through at its root — its **gate**.
  ///
  /// Two repertoires can start from the same position and mean two different
  /// openings: after 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5, one plays 4.b4 and the other
  /// 4.0-0. The moves stay in one graph — a position reached both ways is one
  /// position — and this narrows the **view** to one of them, so the tree, the
  /// queue and the drill are about one opening.
  ///
  /// Null is every repertoire with no twin, and behaves exactly as before.
  final String? gateUci;

  /// Injected in tests, which have neither a server nor a Lichess token.
  final RepertoireApiService? api;
  final OpeningJudgeService? judge;

  /// Called with the position in front of the student, so the screen above can
  /// open the drill over that branch alone.
  ///
  /// A callback rather than a push from here, the same way the drill screen
  /// hands a position back to be built: the two screens stay strangers, and
  /// whoever opened them decides what happens between them.
  final void Function(String fen)? onDrillHere;

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

  /// Positions still to be answered, most-reached first — and, the point of the
  /// type, the way each one was reached.
  ///
  /// The queue used to hold bare FENs, which is why this screen could never say
  /// where the student was: a board with no history and a count of an invisible
  /// list. The path costs one list per position and turns "Još 14 u redu" into
  /// a line the reader can find themselves in.
  ///
  /// A list rather than a queue, because the order is not arrival order. New
  /// positions used to be appended, so a main line opened halfway through a
  /// session waited behind every sideline enqueued before it — and the same
  /// walk, resumed tomorrow, came back in a different order, since the server
  /// sorts by `reach`. Two orders for one walk is the worse half of that: the
  /// student learns the shape of a session rather than the shape of the tree.
  final List<_Pending> _queue = [];

  /// Every position that has already been queued, so a transposition does not
  /// come round twice. Keyed the way the server keys them: no move counters.
  final Set<String> _seen = {};

  /// The repertoire as a picture, and the same thing converted for the tree
  /// widget. Beside the board rather than on another screen: it was a screen
  /// for one day, which is one day of it being useless — seeing what you were
  /// building meant leaving the board and coming back.
  ///
  /// Costs no Lichess allowance, like everything that reads what was built, so
  /// it can be re-read whenever the store changes.
  RepertoireTree? _tree;
  AnalysisNode? _treeRoot;

  /// Whether the drawing includes the branches that were cut. Off by default:
  /// a cut stops the walk, and a card that stays behind only widens a picture
  /// that is read to find the holes.
  bool _showCut = false;

  String? _lastMoveFrom;
  String? _lastMoveTo;

  String? _draftToReplaceFen;
  String? _draftToReplaceUci;

  /// One search, not two.
  ///
  /// This was a second copy of `findNodeByFen` with the same body, and a copied
  /// comparison is where the two drift: the panel's learned to compare by
  /// `fenKeyOf` and this one would have gone on comparing whole FENs, so the
  /// tree would highlight the right card while the same question answered here
  /// said the position was not in the drawing at all.
  /// What each drawn card is, by node id, rebuilt with the drawing itself.
  Map<String, MoveTreeNodeLook> _looks = {};

  AnalysisNode? _findNode(String fen, AnalysisNode? root) =>
      root == null ? null : findNodeByFen(root, fen);

  _Pending? _node;

  /// The position on the board. A getter so the FEN reads the same everywhere
  /// it did before the queue learned to carry paths.
  String? get _current => _node?.fen;

  /// The walk this screen resumed from, kept for the header. Null until the
  /// server has answered, and after a server that did not.
  RepertoireFrontier? _frontier;

  /// The width in force, starting from the row and changed by the spine dialog.
  late String? _breadth = widget.breadth;
  bool _resuming = true;

  List<RepertoireMove> _kept = const [];

  String? _proposalUci;
  String? _proposalSan;
  OpeningJudgement? _verdict;
  String? _verdictReason;

  /// What is played in the position **on the board**, out of the stored book.
  ///
  /// Always on screen, whoever is to move. Building a repertoire is a decision
  /// made from the statistics, the evaluation and the builder's own will — not
  /// a guess that gets marked — so there is nothing here to hide until somebody
  /// admits they do not know. It costs no Lichess request: `opening_replies`
  /// holds whatever anybody's session already paid for.
  StoredBook? _here;

  /// The position that list belongs to. A list drawn for the previous board
  /// names moves that cannot be played on this one.
  String? _hereFor;

  /// What the opponent answers the student's own move with.
  ///
  /// These were fetched and thrown away: `Dalje` spent a Lichess request on
  /// them, counted what they covered, and moved on without ever putting them in
  /// front of the person who paid for them. They are the whole reason the next
  /// wave looks the way it does, so they are now shown — on the board, from the
  /// position they are answers to, with how often each is played.
  OpponentReplies? _answers;

  /// The position the answers belong to: after the student's primary move.
  /// Kept for the same reason `_linesFen` is — an answer drawn on the wrong
  /// board is worse than no answer.
  String? _answersFen;
  String? _answersSan;

  /// The branches cut in this session: "I am not preparing this."
  ///
  /// Kept here as well as on the server so the header can say how many there
  /// are without asking for the whole walk again. The walk is read once, on the
  /// way in; re-reading it after every cut would be a request per press to
  /// change one number.
  final List<_Pending> _cutHere = [];

  /// What the opponent plays after the student's main move here, out of the
  /// stored book — no Lichess request. Beside the board rather than behind a
  /// button, because it is the thing that decides what the next wave looks
  /// like.
  StoredBook? _stored;

  /// The position the stored book belongs to: after the move being looked at.
  /// Kept for the same reason the engine keeps its own — a list drawn for the
  /// previous board names moves that cannot be played on this one.
  String? _storedFor;

  /// Set when somebody tapped one of *their own* moves in the tree: the board
  /// is standing after it, looking at what comes back.
  ///
  /// The position after my move has the opponent to move, so this screen has no
  /// question to ask about it — which is why a tap used to be bounced back to
  /// the position the move was chosen from, and looked from the outside like a
  /// card that does nothing. What somebody means by tapping their own move is
  /// "show me what comes back", and that answer is already stored and free.
  ///
  /// [_node] stays where it was: the queue and the question belong to the
  /// position the move was played *from*, and only the board moves on. That is
  /// the same arrangement the wave's answers use, and it carries the same
  /// obligation — nothing belonging to [_node] may be drawn while it holds.
  ({String uci, String san, String fen})? _standingAfter;

  /// True while the board is one move further on than [_node] — the wave's
  /// answers, or a tap on one of the student's own moves.
  ///
  /// One getter rather than two conditions repeated down the build method: a
  /// panel that forgot the second one would be a verdict, a book or an engine
  /// line drawn for a board that is not showing, which is a bug this screen has
  /// met more than once.
  bool get _afterMyMove => _answers != null || _standingAfter != null;

  /// The opponent's moves prepared by hand in this session, past the cut.
  ///
  /// Kept so the row can say it is done without asking the server again — the
  /// walk already knows, and this screen only needs to stop offering a button
  /// that has been pressed.
  final Set<String> _preparedUcis = {};

  /// Whether the tail is showing. Folded away by default: ten moves at one per
  /// cent each under every position would bury the answers that matter.
  bool _showTail = false;

  /// The last branch cut, and the only one the undo button offers back.
  ///
  /// One step is enough here and more would be a second list to keep straight:
  /// cutting is a considered answer to a position on the board, not a stream of
  /// keystrokes, and the ones before it are on the server where the whole list
  /// can be shown when there is a screen for it.
  _Pending? _lastCut;

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

  /// What the engine has already said about the positions in this repertoire,
  /// keyed the way the store keys them.
  ///
  /// Read once beside the picture, never per card. It is information and not a
  /// verdict: the judgement on this screen belongs to the opening judge, which
  /// answers "is this sound, judged by the games real people played" — the
  /// better question for a repertoire. Two judges on one card is how a screen
  /// starts contradicting itself in front of a child.
  Map<String, RepertoireNote> _notes = const {};

  /// What the student wrote about these positions, keyed the same way.
  ///
  /// Read beside the notes and for the same reason — one call for the whole
  /// colour rather than one per card — but with the opposite lifetime. An
  /// evaluation is recomputed by anything that can run an engine; a sentence
  /// somebody typed at a board is the only thing here nothing can bring back.
  Map<String, RepertoireComment> _comments = const {};

  /// A comment is being written to the server. The text stays on screen while
  /// it goes: what was typed is not in question, only whether it arrived.
  bool _savingComment = false;

  /// The model has been asked about the position and has not answered yet.
  bool _asking = false;

  /// The whole-line pass: how many positions it has done, and of how many.
  ///
  /// It costs no Lichess allowance at all — only time and a warm phone — which
  /// is exactly why the price has to be on the button before it is pressed and
  /// the progress has to be visible while it runs.

  /// Set by the stop button. Read between positions rather than mid-search: a
  /// search already running is finished and stored, because throwing away an
  /// answer that has been paid for helps nobody.

  bool get _forWhite => widget.color == 'w';

  @override
  void initState() {
    super.initState();
    _resume();
  }

  /// Picks the walk back up where it was, rather than starting again.
  ///
  /// The queue is not stored anywhere and never was — the server rebuilds it
  /// from the moves already kept and the books already fetched, which costs no
  /// Lichess request at all. That is what makes closing this screen safe: come
  /// back tomorrow, or on the other machine, and the same positions are
  /// waiting, in the same order.
  ///
  /// A server that does not answer falls back to the root. It has to be the
  /// root and not an empty screen: "we could not find out" must never be shown
  /// as "there is nothing left to do".
  /// Re-reads the walk, and only moves the board when there is nothing on it.
  ///
  /// [keepBoard] is for the actions that happen *at* a position — a spine grown
  /// from here, a branch cut behind you. They change the queue and the numbers,
  /// and moving the board on top of that leaves the reader hunting for where
  /// they were.
  Future<void> _resume({bool keepBoard = false}) async {
    final walk = await _api.frontier(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
      gateUci: widget.gateUci,
      breadth: _breadth,
    );
    if (!mounted) return;
    if (walk == null) {
      _enqueue(widget.rootFen, const [], reach: 1);
      setState(() {
        _resuming = false;
        _note = 'Nije moglo da se pročita dokle ste stigli — počinjete od '
            'početne pozicije repertoara.';
      });
    } else {
      for (final node in walk.open) {
        _enqueue(node.fen, node.path, kind: node.kind, reach: node.reach);
      }
      setState(() {
        _frontier = walk;
        _resuming = false;
      });
    }
    if (!keepBoard || _node == null) await _advance();
    // Read after the queue rather than beside it: the walk decides what is on
    // the board, and a picture that arrives first would highlight a position
    // nobody is standing on yet.
    await _loadTree();
    if (keepBoard) await _loadKept();
  }

  int _treeDepth() => treeDepthFor(_node?.path.length ?? 0);

  /// Re-reads the picture. Called after anything that changes the store, and
  /// never on a plain advance: the tree only moves when the moves do.
  Future<void> _loadTree() async {
    // Both at once, and both free: one reads what was decided, the other what
    // the engine was asked. Neither spends a Lichess request.
    final drawing = _api.repertoireTree(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
      gateUci: widget.gateUci,
      breadth: _breadth,
      maxPly: _treeDepth(),
      // Deep enough to contain the reader.
      //
      // The default is sixteen plies — eight moves — and it was never sent, so
      // the picture stopped at move eight however deep the work had gone.
      // Standing on move seven, as the owner was on 4.9.2026, the move being
      // decided is the last one the drawing can hold and everything taken after
      // it falls off the edge: „aplikacija ne upisuje taj potez u stablo
      // odmah". It was written; the picture just could not reach it.
      //
      // Four moves of headroom past where the board is, never less than the old
      // default and never past what the server allows. The panel already says
      // when it was cut short, so this makes that sentence rarer rather than
      // hiding it.
    );
    final stored = _api.notes(color: widget.color);
    // The third free read: what the student wrote. Beside the other two rather
    // than per position, or a tree of a hundred cards is a hundred requests.
    final written = _api.comments(color: widget.color);
    final tree = await drawing;
    final notes = await stored;
    final comments = await written;
    if (!mounted || tree == null) return;
    setState(() {
      _tree = tree;
      _notes = notes;
      _comments = comments;
      _looks = {};
      _treeRoot = repertoireTreeToNodes(tree, showCut: _showCut, looks: _looks);
    });
  }

  /// Draws the cut branches, or stops drawing them. The tree is rebuilt from
  /// the answer already in hand — no request, and nothing is re-read to change
  /// what is on screen.
  void _toggleCut() {
    final tree = _tree;
    if (tree == null) return;
    setState(() {
      _showCut = !_showCut;
      // Rebuilt together, always. The looks are keyed by node id and the ids
      // are minted by this call, so a map kept from the previous drawing would
      // colour nothing and quietly draw every card as an ordinary one.
      _looks = {};
      _treeRoot = repertoireTreeToNodes(tree, showCut: _showCut, looks: _looks);
    });
  }

  /// What the engine said about the position on the board, if anything.
  RepertoireNote? get _noteHere {
    final fen = _current;
    return fen == null ? null : _notes[_keyOf(fen)];
  }

  /// The position the comment is about: the one **on the board**.
  ///
  /// Not the one the question is about. Standing after your own move to see
  /// what comes back, what you would write a note about is the board in front
  /// of you — and the store keys by position, so both are perfectly good places
  /// to have written one.
  String? get _commentFen => _standingAfter?.fen ?? _current;

  /// What the student wrote about the position on the board, if anything.
  RepertoireComment? get _commentHere {
    final fen = _commentFen;
    return fen == null ? null : _comments[_keyOf(fen)];
  }

  /// Opens the editor on the position the board is standing on, and stores what
  /// comes back.
  ///
  /// [prefill] is how the model's answer arrives: as text in the box, to be
  /// read and edited, never as a comment already saved. What a model wrote is
  /// not the student's note until the student has said it is.
  Future<void> _editComment({String? prefill}) async {
    final fen = _commentFen;
    if (fen == null) return;
    final existing = _commentHere?.body ?? '';
    final typed = await showRepertoireCommentEditor(
      context,
      initial: prefill ?? existing,
      line: _lineText(),
      wide: Breakpoints.isWide(context),
    );
    // Closed without saving. An empty string is "clear it" and is a different
    // answer, which is why this is a null check and not an isEmpty one.
    if (typed == null || !mounted) return;
    await _saveComment(fen, typed);
  }

  /// Writes one comment, and puts the answer on screen.
  ///
  /// Do the thing, then say it: the map is updated from what the server stored,
  /// and only then is anything said about it.
  Future<void> _saveComment(String fen, String body) async {
    setState(() => _savingComment = true);
    final done = await _api.putComment(
      color: widget.color,
      fen: fen,
      body: body,
    );
    if (!mounted) return;
    final key = _keyOf(fen);
    setState(() {
      _savingComment = false;
      final next = {..._comments};
      final stored = done.comment;
      if (stored != null) {
        next[key] = stored;
      } else if (done.saved) {
        next.remove(key);
      }
      _comments = next;
    });
    if (!done.saved) {
      AppFeedback.error(context, 'Komentar nije sačuvan — server ne odgovara.');
    }
  }

  /// Takes the comment off this position, after asking.
  Future<void> _deleteComment() async {
    final fen = _commentFen;
    if (fen == null || _commentHere == null) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obriši komentar?'),
        content: const Text(
          'Briše se samo ono što ste napisali o ovoj poziciji. Potezi i ocene '
          'ostaju.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _savingComment = true);
    final done = await _api.deleteComment(color: widget.color, fen: fen);
    if (!mounted) return;
    setState(() {
      _savingComment = false;
      if (done) {
        final next = {..._comments};
        next.remove(_keyOf(fen));
        _comments = next;
      }
    });
    if (!done) {
      AppFeedback.error(context, 'Komentar nije obrisan — server ne odgovara.');
    }
  }

  /// Asks the model about the position on the board.
  ///
  /// Not a second judge. The verdict on a move stays the opening judge's — what
  /// real people played — and this answers a different question: what is going
  /// on here, in words. It is offered for reading, and carried into the
  /// student's own comment only if they say so.
  ///
  /// It spends the AI allowance, not the Lichess one, which is why it is a
  /// button and not something the screen does on arrival.
  Future<void> _askModel() async {
    final fen = _commentFen;
    if (fen == null || _asking) return;
    setState(() => _asking = true);
    final note = _notes[_keyOf(fen)];
    final advice = await askAboutPosition(
      fen: fen,
      evals: {
        if (note != null) 'cp': note.evalCp,
        if (note?.bestUci != null) 'bestMove': note!.bestUci,
        if (note?.bestLineSan != null) 'continuation': note!.bestLineSan,
      },
    );
    if (!mounted) return;
    setState(() => _asking = false);
    if (advice == null) {
      AppFeedback.error(context, 'AI nije odgovorio o ovoj poziciji.');
      return;
    }
    final keep = await showPositionAdviceDialog(context, advice);
    if (keep == null || !mounted) return;
    await _editComment(prefill: keep);
  }

  /// The node the board is standing on, for the tree to highlight.
  ///
  /// The *board*, not the question: standing after a move tapped in the tree,
  /// the card that lights up is that move. A picture that highlighted the
  /// position behind the board would be pointing somewhere else than the pieces
  /// are.
  AnalysisNode? get _activeNode {
    final root = _treeRoot;
    final fen = _standingAfter?.fen ?? _current;
    if (root == null || fen == null) return null;
    return findNodeByFen(root, fen) ?? root;
  }

  /// Takes the board to a position in the tree.
  ///
  /// Two kinds of card, and they mean two different things:
  ///
  ///   * **The opponent's move.** The position after it is one this screen can
  ///     ask a question about, so the board simply goes there.
  ///   * **One of the student's own.** The position after it has the opponent
  ///     to move and carries no question — but "show me what comes back" is
  ///     plainly what tapping it means, and that answer is already stored and
  ///     costs nothing. So the board stands after the move and the replies are
  ///     drawn beneath it.
  ///
  /// The second used to be bounced to the card's parent, which on the line you
  /// are standing in is the position you are already on: the tap looked like a
  /// card that does nothing, and it quietly threw away the engine lines and the
  /// verdict on the way. A jump that lands where the board already is now does
  /// nothing at all, which is the honest version of that.
  ///
  /// The queue is left alone either way. The board shows a position; the queue
  /// is where the next question comes from, and those were never the same
  /// thing.
  Future<void> _jumpTo(AnalysisNode node) async {
    if (_isMine(node.fen)) {
      // Already here, and nothing standing in front of it: a jump that redraws
      // this position would only clear what the reader just computed.
      if (node.fen == _current && !_afterMyMove) return;
      await _show(_Pending(
        fen: node.fen,
        path: _pathTo(node),
        lastUci: node.moveUci,
      ));
      return;
    }

    final from = node.parent;
    final uci = node.moveUci;
    final san = node.moveSan;
    // A card whose parent is not a position the student moves in is not one of
    // their moves at all — a drawing this screen did not build. Left alone
    // rather than guessed at.
    if (from == null || uci == null || san == null || !_isMine(from.fen)) {
      return;
    }
    await _standAfter(from, fen: node.fen, uci: uci, san: san);
  }

  /// Puts the board after one of the student's own moves.
  ///
  /// The question stays on the position the move was played from, because that
  /// is what the queue is about; only the board moves on. Everything belonging
  /// to the old board is cleared through [_show] first when the position it was
  /// played from is not the one already showing.
  Future<void> _standAfter(
    AnalysisNode from, {
    required String fen,
    required String uci,
    required String san,
  }) async {
    if (from.fen != _current) {
      await _show(_Pending(
        fen: from.fen,
        path: _pathTo(from),
        lastUci: from.moveUci,
      ));
      if (!mounted) return;
    }
    await _standAfterMove(fen: fen, uci: uci, san: san);
  }

  /// The same, for a move that is already on the board: everything belonging to
  /// the position behind it is cleared, the board stays where it is, and the
  /// panel below becomes what the opponent answers with.
  ///
  /// [path] is only used when the caller knows the line — a move played by hand
  /// on a board that is already standing in the right place.
  Future<void> _standAfterMove({
    required String fen,
    required String uci,
    required String san,
    List<String>? path,
  }) async {
    setState(() {
      // A move on the board, a verdict or an engine line belongs to the
      // position that is no longer the one being shown.
      _proposalUci = null;
      _proposalSan = null;
      _verdict = null;
      _verdictReason = null;
      _lines = const [];
      _linesFen = null;
      _showTail = false;
      _lastMoveFrom = uci.substring(0, 2);
      _lastMoveTo = uci.substring(2, 4);
      _standingAfter = (uci: uci, san: san, fen: fen);
    });
    _boardController.loadFen(fen);
    // Free: it comes out of what anybody's build session already paid for.
    await _loadStoredBook();
  }

  /// The card's move as this screen holds it: the position it is played from,
  /// and the move itself.
  ///
  /// Null for a card whose parent is missing — the root has no move — and that
  /// is the one case both edits below simply decline.
  ({AnalysisNode from, String uci, String san})? _moveOf(AnalysisNode node) {
    final from = node.parent;
    final uci = node.moveUci;
    final san = node.moveSan;
    if (from == null || uci == null || san == null) return null;
    return (from: from, uci: uci, san: san);
  }

  /// "Unapredi u glavnu liniju" on a card.
  ///
  /// Only means something for the student's own moves: one primary per
  /// position is a rule about *their* decisions, and the opponent's move is not
  /// theirs to promote. Said out loud rather than ignored — a menu item that
  /// quietly does nothing is what this menu was for a day.
  Future<void> _promoteFromTree(AnalysisNode node) async {
    final move = _moveOf(node);
    if (move == null || _busy) return;
    if (!_isMine(move.from.fen)) {
      // Said out loud, and through AppFeedback: a menu item that does nothing
      // and explains nothing is what this menu was for a day.
      AppFeedback.info(
          context, 'To je protivnikov potez — glavni potez biraju samo vaši.');
      return;
    }
    final kept = await _keptAt(move.from);
    if (kept == null) return;
    final mine = kept.where((m) => m.uci == move.uci).firstOrNull;
    if (mine == null) {
      if (!mounted) return;
      AppFeedback.warning(context, '${move.san} više nije u repertoaru.');
      return;
    }
    await _makePrimary(mine);
    if (!mounted) return;
    // Do the thing, then say it. The tree redraws with the star somewhere else,
    // which is easy to miss on a canvas that is being panned.
    AppFeedback.success(context, '${move.san} je sada vaš glavni potez.');
  }

  /// „Izdvoji u novo otvaranje" from a card in the tree.
  ///
  /// The action existed only on the row under the board, which forks the
  /// position standing there. What somebody actually points at is a *move* —
  /// usually an alternate, the second thing they play here — and that is a fork
  /// of the position it is played from, gated on the move itself. Same dialog,
  /// arriving with the gate already set.
  Future<void> _forkFromTree(AnalysisNode node) async {
    final move = _moveOf(node);
    if (move == null || _busy) return;
    await showDialog(
      context: context,
      builder: (context) => ForkRepertoireDialog(
        color: widget.color,
        rootFen: move.from.fen,
        rootPath: _pathTo(move.from),
        initialViaUci: move.uci,
        api: _api,
      ),
    );
  }

  /// "Obriši ovu varijantu" on a card, which means two different things.
  ///
  /// On the student's own move it is a removal, with the sweep of everything
  /// that becomes unreachable and the question about the decisions among them.
  /// On the opponent's it is the **cut**: their moves are not rows anybody
  /// chose, so there is nothing to delete — what somebody means by it is "I am
  /// not preparing this", which is a decision and is stored as one.
  Future<void> _deleteFromTree(AnalysisNode node) async {
    final move = _moveOf(node);
    if (move == null || _busy) return;

    if (!_isMine(move.from.fen)) {
      // The board goes there first: cutting is about the position in front of
      // you, the undo names it, and the queue below it is cleared by the same
      // method the button uses.
      await _show(_Pending(fen: node.fen, path: _pathTo(node)));
      if (!mounted) return;
      await _cutBranch();
      if (!mounted) return;
      AppFeedback.success(context,
          'Granu posle ${move.san} više ne spremam — nema je u crtežu.');
      return;
    }

    final kept = await _keptAt(move.from);
    if (kept == null) return;
    final mine = kept.where((m) => m.uci == move.uci).firstOrNull;
    if (mine == null) {
      if (!mounted) return;
      AppFeedback.warning(context, '${move.san} više nije u repertoaru.');
      return;
    }
    await _remove(mine);
    if (!mounted) return;
    AppFeedback.success(context, '${move.san} je uklonjen iz repertoara.');
  }

  /// Takes the board to the position a card's move is played from, and hands
  /// back what is kept there.
  ///
  /// The edits below run through the same methods the buttons under the board
  /// do — one removal, one promotion, one orphan sweep — and those read
  /// `_kept`, which belongs to the position on the board. So the board goes
  /// there first. Null when the jump did not land, and the caller stops.
  Future<List<RepertoireMove>?> _keptAt(AnalysisNode from) async {
    if (from.fen != _current || _standingAfter != null) {
      await _show(_Pending(fen: from.fen, path: _pathTo(from)));
      if (!mounted) return null;
    }
    return _kept;
  }

  /// Whether the student is the one to move here.
  bool _isMine(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 && parts[1] == widget.color;
  }

  /// The line the board is standing in: the root, everything down to the
  /// board, and then the main line onwards to its end.
  ///
  /// It runs *past* the board on purpose. A palette whose forward buttons are
  /// dead the moment you open it is not navigation — the same rule
  /// [MoveTreeCursor] keeps, following first children to the end of the line
  /// rather than stopping where the cursor happens to be.
  List<AnalysisNode> _lineNodes() {
    final active = _activeNode;
    if (active == null) return const [];
    final line = <AnalysisNode>[];
    AnalysisNode? at = active;
    while (at != null) {
      line.insert(0, at);
      at = at.parent;
    }
    var deepest = active;
    while (deepest.children.isNotEmpty) {
      deepest = deepest.children.first;
      line.add(deepest);
    }
    return line;
  }

  /// Where the board stands in that line: everything above it.
  int _lineIndex() {
    final active = _activeNode;
    if (active == null) return 0;
    var above = 0;
    AnalysisNode? at = active.parent;
    while (at != null) {
      above += 1;
      at = at.parent;
    }
    return above;
  }

  /// The strip under the board, over the line the board is in.
  ///
  /// The same four buttons as the lesson viewer, the review session and the
  /// endgame walk, driven by the same cursor — this screen was the one place
  /// that had a board and no palette under it.
  /// The one cursor this screen is walked by — the strip's buttons and the
  /// arrow keys read it from here rather than each building their own, so
  /// there is no second copy to fall out of step.
  ///
  /// The tree's own cursor rather than a flattened list, and that is what buys
  /// the fork: [AnalysisNodeCursor] knows what leads forward from a position,
  /// so the strip asks which line instead of walking into the first child. The
  /// rule holds on every screen with a branching model now, rather than being
  /// written here a second time.
  ///
  /// Selecting goes through the same door a tap on a card uses, so walking the
  /// line and tapping the tree cannot end in two different states: the
  /// opponent's move puts the board on it, one of mine stands the board after
  /// it.
  MoveCursor _moveCursor() => AnalysisNodeCursor(
        currentNode: _activeNode ?? AnalysisNode(fen: widget.rootFen),
        onSelect: _jumpTo,
      );

  /// The strip under the board, and the two buttons that act on the position
  /// standing in it.
  ///
  /// They live here because that is where the Analysis Studio's comment button
  /// lives, and a person who has learned one screen should not have to find the
  /// same action somewhere else on the next. `MoveNavigationControls` wraps
  /// rather than clipping, so a phone folds them onto a second line instead of
  /// hiding them past the edge with no warning in a release build.
  ///
  /// Drawn even when the line is too short to navigate: without this the whole
  /// strip disappeared at the root, and with it would go the only way to write
  /// a comment on the very first position.
  Widget _buildNavigation(BuildContext context) {
    final line = _lineNodes();
    final wrote = _commentHere != null;
    return MoveNavigationControls(
      cursor: _moveCursor(),
      canNavigate: line.length >= 2,
      centerLabel: line.length >= 2
          ? 'Potez ${_lineIndex()} od ${line.length - 1}'
          : null,
      iconSize: 20,
      trailing: [
        IconButton(
          icon: Icon(Icons.call_split,
              size: 18, color: context.colors.textSecondary),
          tooltip: 'Izdvoji u novo otvaranje',
          onPressed: _activeNode == null ? null : _forkHere,
        ),
        IconButton(
          icon: Icon(
            wrote ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
            size: 18,
            color: context.colors.info,
          ),
          tooltip: wrote ? 'Izmeni komentar' : 'Dodaj komentar',
          onPressed: _savingComment || _commentFen == null
              ? null
              : () => _editComment(),
        ),
        IconButton(
          icon: _asking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.auto_awesome,
                  size: 18, color: context.colors.accent),
          tooltip: 'Pitaj AI o poziciji',
          onPressed: _asking || _commentFen == null ? null : _askModel,
        ),
      ],
    );
  }

  /// The comment on the position, drawn wherever there is room for it.
  ///
  /// [dense] is the under-the-board mounting, where an empty comment draws
  /// nothing: the column under a board at 360 dp is the most expensive space in
  /// the app, and a card saying "nothing written" would push the question off
  /// the bottom.
  Widget _buildComment(BuildContext context, {required bool dense}) {
    if (_commentFen == null) return const SizedBox.shrink();
    return RepertoireCommentPanel(
      body: _commentHere?.body,
      dense: dense,
      busy: _savingComment,
      onEdit: () => _editComment(),
      onDelete: _commentHere == null ? null : _deleteComment,
    );
  }

  /// This position becomes an opening of its own.
  ///
  /// Nothing is copied and nothing moves: the new repertoire is a second door
  /// onto the same graph, so the screen stays exactly where it is and the tree
  /// under the board is as true after the fork as it was before it.
  Future<void> _forkHere() async {
    final active = _activeNode;
    if (active == null) return;

    await showDialog(
      context: context,
      builder: (context) => ForkRepertoireDialog(
        color: widget.color,
        rootFen: active.fen,
        rootPath: _pathTo(active),
        api: _api,
      ),
    );
  }

  /// The moves from the repertoire's root down to a node.
  List<String> _pathTo(AnalysisNode node) {
    final moves = <String>[];
    AnalysisNode? at = node;
    while (at != null && at.moveSan != null) {
      moves.insert(0, at.moveSan!);
      at = at.parent;
    }
    return moves;
  }

  String _keyOf(String fen) => fenKeyOf(fen);

  /// Puts a position in the queue where its `reach` says it belongs.
  ///
  /// The same rule the server sorts by, applied to positions that arrive during
  /// a session: most-reached first, and among equals the shallower one. Sorted
  /// on insert rather than appended, so what opens deep in the main line
  /// overtakes a sideline that was queued earlier — and so leaving the screen
  /// and coming back does not reshuffle the walk.
  void _enqueue(String fen, List<String> path,
      {String kind = 'undecided', double reach = 0}) {
    final key = _keyOf(fen);
    if (_seen.contains(key)) return;
    _seen.add(key);
    final node = _Pending(fen: fen, path: path, kind: kind, reach: reach);
    var at = 0;
    while (at < _queue.length &&
        (_queue[at].reach > node.reach ||
            (_queue[at].reach == node.reach &&
                _queue[at].path.length <= node.path.length))) {
      at += 1;
    }
    _queue.insert(at, node);
  }

  /// Moves to the next position in the queue, or to the "nothing left" state.
  Future<void> _advance() => _show(_queue.isEmpty ? null : _queue.removeAt(0));

  /// Puts the repertoire's own root back on the board.
  ///
  /// The finished screen tells the reader to go back to a position and take
  /// more replies, and then offered them one button, which was „Nazad". The
  /// tree, the board and every action on this screen were unreachable the
  /// moment the queue emptied — on a repertoire with a hundred moves in it.
  Future<void> _openRoot() async {
    _seen.remove(_keyOf(widget.rootFen));
    _enqueue(widget.rootFen, widget.rootPath, reach: 1);
    await _advance();
  }

  /// Puts one position on the board, or the finished screen when there is none.
  ///
  /// Everything belonging to the previous position is cleared here, in one
  /// place. A verdict, a book, an engine line or a set of answers that outlived
  /// the board it was about is a bug this screen has met more than once, and it
  /// is only ever avoided by there being a single door.
  Future<void> _show(_Pending? node) async {
    setState(() {
      _proposalUci = null;
      _proposalSan = null;
      _verdict = null;
      _verdictReason = null;
      _here = null;
      _hereFor = null;
      _answers = null;
      _answersFen = null;
      _answersSan = null;
      _standingAfter = null;
      _showTail = false;
      // Marked when the caller knew the way in, cleared when it did not: a
      // pair of squares from a position no longer on screen is worse than
      // none, and no mark at all on a position that was walked to is how the
      // reader loses the thread of the line.
      _lastMoveFrom =
          node?.lastUci == null ? null : node!.lastUci!.substring(0, 2);
      _lastMoveTo =
          node?.lastUci == null ? null : node!.lastUci!.substring(2, 4);
      _preparedUcis.clear();
      _lines = const [];
      _linesFen = null;
      _thinking = false;
      _node = node;
      _kept = const [];
    });
    final fen = _current;
    if (fen == null) return;
    _boardController.loadFen(fen);
    await _loadKept();
  }

  /// The line that leads to the board in front of the student, numbered the way
  /// a book numbers it.
  ///
  /// The repertoire's own root path first, so a repertoire built from move four
  /// reads from move one rather than pretending the game began where the
  /// student stopped playing.
  String _lineText() {
    final moves = [
      ...widget.rootPath,
      ...?_node?.path,
      // The board is one move further on while the answers are up, or while
      // the reader is standing after a move they tapped in the tree. A
      // breadcrumb that stopped short of it would name a position that is not
      // the one being looked at.
      if (_answers != null && _answersSan != null) _answersSan!,
      if (_standingAfter != null) _standingAfter!.san,
    ];
    // With a root path the game began at move one; without one, the root FEN is
    // the only thing that knows where the counting starts.
    return numberedLine(
      moves,
      from: widget.rootPath.isEmpty ? widget.rootFen : null,
    );
  }

  Future<void> _loadKept() async {
    final fen = _current;
    if (fen == null) return;
    final moves = await _api.movesAt(color: widget.color, fen: fen);
    if (!mounted) return;
    setState(() => _kept = moves);
    await _loadHereBook();
    await _loadStoredBook();
  }

  /// What is played in the position on the board.
  ///
  /// Free, like everything that reads what somebody has already paid for. This
  /// is the list the repertoire is now built from, so it is not behind a button
  /// and not behind an admission.
  Future<void> _loadHereBook() async {
    final fen = _current;
    if (fen == null) {
      if (!mounted) return;
      setState(() {
        _here = null;
        _hereFor = null;
      });
      return;
    }
    final book = await _api.storedBook(
      color: widget.color,
      fen: fen,
      minRating: widget.minRating,
    );
    if (!mounted || _current != fen) return;
    setState(() {
      _here = book;
      _hereFor = fen;
    });
  }

  /// One request, and only because the reader pressed for it: the position
  /// nobody has ever opened. What comes back is stored by the route, so it is
  /// free for everybody from now on.
  Future<void> _openHereBook() async {
    final fen = _current;
    if (fen == null || _busy) return;
    setState(() => _busy = true);
    final lookup = await _judge.replies(fen, minRating: widget.minRating);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _asked += 1;
      if (!lookup.isAvailable) {
        _note = 'Knjiga nije dostupna (${lookup.reason}).';
      }
    });
    await _loadHereBook();
  }

  /// Plays a move from the list as the reader's own proposal, so it goes
  /// through the same judging and the same decision as one dragged on the
  /// board. Choosing from the statistics is building; it is not a shortcut past
  /// anything.
  void _playFromBook(String uci) {
    if (uci.length < 4) return;
    _onMove(uci.substring(0, 2), uci.substring(2, 4),
        uci.length > 4 ? uci.substring(4, 5) : '');
  }

  /// Reads the opponent's book for the position after the main move here.
  ///
  /// Free: it comes out of `opening_replies`, which holds whatever anybody's
  /// build session already paid for. A panel that follows the board and
  /// refetched on every move would spend the reader's allowance on a drawing
  /// they never asked for — one token serves every child using this app.
  Future<void> _loadStoredBook() async {
    final fen = _current;
    // Only while the board is standing after one of the student's own moves.
    // On their own turn the panel below the board is about the position they
    // are looking at, and a second list about the position after it was the
    // clutter the owner reported.
    final looking = _standingAfter;
    if (fen == null || looking == null) {
      if (!mounted) return;
      setState(() {
        _stored = null;
        _storedFor = null;
      });
      return;
    }
    final after = looking.fen;
    final book = await _api.storedBook(
      color: widget.color,
      fen: after,
      minRating: widget.minRating,
    );
    if (!mounted) return;
    // The book that arrives is the book for the board it was asked about.
    if (_current != fen) return;
    setState(() {
      _stored = book;
      _storedFor = after;
    });
  }

  /// The student's main move in the position on the board, and where it leads.
  ///
  /// Null when nothing is kept here yet, which is most of the walk.
  ({String uci, String san, String fen})? get _mainMoveHere {
    final fen = _current;
    final primary = _kept.isEmpty ? null : _kept.first;
    if (fen == null || primary == null) return null;
    final after = _fenAfter(fen, primary.uci);
    if (after == null) return null;
    return (uci: primary.uci, san: primary.san, fen: after);
  }

  /// Opens the book for a position nobody has looked at yet. One request, and
  /// only because the reader pressed for it.
  Future<void> _openStoredBook() async {
    final after = _storedFor;
    if (after == null || _busy) return;
    setState(() => _busy = true);
    final lookup = await _judge.replies(after, minRating: widget.minRating);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _asked += 1;
      if (!lookup.isAvailable) {
        _note = 'Knjiga nije dostupna (${lookup.reason}).';
      }
    });
    // The route stores what it fetched, so reading it back is free from now on.
    await _loadStoredBook();
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

    final played = ChessBoardWithOverlay.lastMoveSquares(_boardController.game);
    setState(() {
      _lastMoveFrom = played?.from;
      _lastMoveTo = played?.to;
    });

    final san = board.getHistory().last.toString();
    final uci = isPromotion ? '$from$to$piece' : '$from$to';

    // Already in the repertoire. Playing it on the board is then the same act
    // as picking it in the tree — "go and look at what comes after it" — and
    // not a proposal to be judged and accepted a second time. Asking "Uzmi
    // Re1?" about a move that is already kept is the screen not knowing what
    // it holds.
    final already = _kept.where((move) => move.uci == uci).firstOrNull;
    if (already != null) {
      final after = _fenAfter(fen, uci);
      _boardController.loadFen(fen);
      if (after == null) return;
      final node = _node;
      await _standAfterMove(
        fen: after,
        uci: uci,
        san: already.san,
        path: node == null ? const [] : [...node.path, already.san],
      );
      return;
    }

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

    // No second book here. It used to be fetched automatically the moment a
    // move was played — a Lichess request per move, for a list that is already
    // on screen above and has been since the position opened. What it carried
    // that the stored one cannot is how those games *ended*; that is worth
    // having and is not worth a request per move against a token that serves
    // every child using this app. If it comes back, it comes back as a column
    // in `opening_replies`, fetched once for everybody.
  }

  /// The moves played from the position in front of the student, and how those
  /// games went. Fetched once per position; the counter says what it cost.
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

    bool saved = false;
    if (_draftToReplaceFen == fen && _draftToReplaceUci != null) {
      final rejected = _draftToReplaceUci!;
      final result = await _api.playAlternative(
        color: widget.color,
        fen: fen,
        uci: uci,
        san: san,
        rejectedUci: rejected,
        minRating: widget.minRating,
        includeDecisions: false,
      );
      if (result.result != null && result.result!.decisions > 0) {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Obrisati vaše odluke?'),
            content: Text(
                'Ispod tog predloga su ${result.result!.decisions} vaše odluke. Obrisati i njih?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Obriši'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final forceResult = await _api.playAlternative(
            color: widget.color,
            fen: fen,
            uci: uci,
            san: san,
            rejectedUci: rejected,
            minRating: widget.minRating,
            includeDecisions: true,
          );
          saved = forceResult.error == null;
        }
      } else {
        saved = result.error == null;
      }
      if (mounted) {
        setState(() {
          _draftToReplaceFen = null;
          _draftToReplaceUci = null;
        });
      }
    } else {
      saved = await _api.keepMove(
        color: widget.color,
        fen: fen,
        uci: uci,
        san: san,
        verdict: verdict,
      );
    }

    await _api.recordAttempt(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
      verdict: verdict,
      kept: true,
      // Nothing is a confession any more: the statistics stand beside the
      // board from the moment the position opens, so "answered by looking" is
      // not a thing that can be told from "answered by thinking".
      lookedUp: false,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = saved ? null : 'Potez nije sačuvan — server nije odgovorio.';
    });
    if (saved) {
      await _loadKept();
      await _loadTree();
      // The banner above the board is about to be wrong by one. Not awaited:
      // the reader is already looking at the next position.
      _refreshCounts();
    }
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
      lookedUp: false,
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
  /// What the engine makes of this position, at the reader's depth and with as
  /// many lines as they asked for.
  /// This board's analysis dials — see [EngineAnalysisDials]. Up to 50 plies
  /// here: on a repertoire position it is worth waiting for, and the old
  /// ceiling of 28 was a leftover from when this number also decided how long
  /// the engine thought before playing a move.
  int _analysisDepth = AppSettingsService.instance.analysisDepth;
  int _analysisLines = AppSettingsService.instance.analysisLines;

  /// What the board draws, and in which order of precedence.
  ///
  /// One layer at a time, never two. Three arrow sets answering three different
  /// questions on one board is not richer, it is unreadable — and the badges
  /// would then be percentages of different things sitting next to each other.
  ///
  /// Every arrow here is drawn for the position actually on the board. That is
  /// not bookkeeping: an arrow from the previous position points at pieces that
  /// have moved, which is the same bug the engine readout had.
  List<EngineArrow> _boardArrows() {
    final settings = AppSettingsService.instance;

    if (settings.showStatisticsArrows) {
      // Standing after our own move, looking at what comes back.
      if (_answers != null) return _replyArrows(_answers!);
      // The same thing from the stored book, after a move tapped in the tree.
      if (_standingAfter != null) {
        final book = _stored;
        // Drawn only for the board it was asked about, like every other layer
        // here: arrows from the previous position point at pieces that moved.
        if (book == null || _storedFor != _standingAfter!.fen) return const [];
        return _shareArrows([
          for (final reply in book.replies)
            (uci: reply.uci, share: reply.share),
        ]);
      }
    }

    if (settings.showEngineArrows) {
      // The engine, if it was asked about this position and answered.
      final engine = _engineArrows();
      if (engine.isNotEmpty) return engine;
    }

    // A move is on the board waiting to be judged, so the pieces are no longer
    // where the kept moves start.
    if (_proposalUci != null) return const [];

    if (settings.showChosenMoveArrow) {
      return _keptArrows();
    }

    return const [];
  }

  /// A share, as a reader reads it. Below one percent is `<1%` rather than
  /// `0%`, which would say "never played" about a move that is on screen
  /// precisely because it was.
  String _shareText(double share) {
    final percent = share * 100;
    if (percent <= 0) return '';
    return percent < 1 ? '<1%' : '${percent.round()}%';
  }

  /// The opponent's answers, most played first.
  ///
  /// The number beside each is its **share** of games from that position, not
  /// how those games ended. Share is what decides whether a move has to be
  /// prepared for; the result percentage says how it went for people who are
  /// not this student, and putting it on an arrow invites picking the biggest
  /// number, which is the wrong lesson. It is still in the panel below, where
  /// there is room to say what it means.
  List<EngineArrow> _replyArrows(OpponentReplies answers) => _shareArrows([
        for (final reply in answers.replies)
          (uci: reply.uci, share: reply.share),
      ]);

  /// Moves and how often they are played, as arrows. One drawing for the wave's
  /// answers and for the stored book, because they are the same picture of the
  /// same thing and two copies would drift.
  /// How many book arrows a board can carry before it stops being readable.
  ///
  /// The list underneath keeps every move; the board is a picture of where the
  /// weight is. Ten arrows with `<1%` on them, crossing each other over the
  /// pieces, is not that picture — it was on the owner's screen, and the moves
  /// that mattered were the two he could no longer find.
  static const _maxBookArrows = 4;

  /// Below this a move is in the list and not on the board. A one-in-a-hundred
  /// reply is a decision to make deliberately, not something to trip over.
  static const _minArrowShare = 0.02;

  List<EngineArrow> _shareArrows(List<({String uci, double share})> moves) {
    final worth = [
      for (final move in moves)
        if (move.uci.length >= 4 && move.share >= _minArrowShare) move,
    ]..sort((a, b) => b.share.compareTo(a.share));

    final arrows = <EngineArrow>[];
    var rank = 1;
    for (final move in worth.take(_maxBookArrows)) {
      arrows.add(EngineArrow(
        from: move.uci.substring(0, 2),
        to: move.uci.substring(2, 4),
        evalText: _shareText(move.share),
        rank: rank,
      ));
      rank += 1;
    }
    return arrows;
  }

  /// The moves the student has already decided on here.
  ///
  /// The primary is marked with a star and drawn thickest — rank carries stroke
  /// width as well as colour, and the star is a third channel again. Which move
  /// is the main one must never rest on hue alone.
  ///
  /// The share comes from the stored book for this position, which is on
  /// screen anyway and costs nothing. Nothing is fetched for an arrow: a
  /// drawing is not worth a Lichess request the student did not ask for, and
  /// the star says the thing that matters without one.
  List<EngineArrow> _keptArrows() {
    final book = _hereFor == _current ? _here : null;
    final shares = <String, double>{
      if (book != null)
        for (final move in book.replies) move.uci: move.share,
    };

    final arrows = <EngineArrow>[];
    var rank = 1;
    for (final move in _kept) {
      if (move.uci.length < 4) continue;
      final share = shares[move.uci];
      final percent = share == null ? '' : _shareText(share);
      arrows.add(EngineArrow(
        from: move.uci.substring(0, 2),
        to: move.uci.substring(2, 4),
        evalText:
            move.isPrimary ? (percent.isEmpty ? '★' : '★ $percent') : percent,
        rank: rank,
      ));
      rank += 1;
    }
    return arrows;
  }

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

    List<AnalysisLine> lines;
    try {
      lines = await _analyse(
        fen,
        _analysisDepth,
        _analysisLines,
        // A deep search takes a while, and a panel that says nothing until it
        // finishes is indistinguishable from an engine that is not answering.
        // The lines are shown as they come and simply get better; the depth
        // beside each one says how much to trust it.
        onProgress: (partial) {
          if (!mounted || _current != fen) return;
          setState(() {
            _lines = partial;
            _linesFen = fen;
          });
        },
      );
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

    // Kept on the node. The number is worth having tomorrow as well, and the
    // review list is built out of exactly these.
    if (lines.isNotEmpty) await _saveNote(fen, lines.first);
  }

  /// One engine run. The local Stockfish, or whatever a test injected.
  ///
  /// One door rather than two: the whole-line pass and the single question ask
  /// the same way, so an engine set up differently for one of them is not a
  /// thing that can happen.
  Future<List<AnalysisLine>> _analyse(
    String fen,
    int depth,
    int multiPV, {
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    final injected = widget.analyse;
    if (injected != null) return injected(fen, depth, multiPV);
    final engine = StockfishService();
    await engine.initEngine();
    return engine.analyzePositionSync(
      fen,
      depth: depth,
      multiPV: multiPV,
      timeout: Duration(seconds: 5 + depth),
      onProgress: onProgress,
    );
  }

  /// The engine's evaluation as two numbers: centipawns, and a mate if it is
  /// one.
  ///
  /// The pawn value comes from [parseWhiteRelativeEval], the one parser this
  /// app has — a second reading of "M4" written here is how one node ends up
  /// with two evaluations two orders of magnitude apart, which has happened.
  /// The mate is read out separately because a forced mate stored only as a
  /// large number of pawns is a number that reads as an evaluation.
  ({int cp, int? mateIn})? _evalOf(String raw) {
    final pawns = parseWhiteRelativeEval(raw);
    if (pawns == null) return null;
    final cp = (pawns * 100).round();
    final mate = RegExp(r'^\s*(-)?M(\d+)\s*$').firstMatch(raw);
    if (mate == null) return (cp: cp, mateIn: null);
    final moves = int.tryParse(mate.group(2)!) ?? 0;
    if (moves == 0) return (cp: cp, mateIn: null);
    return (cp: cp, mateIn: mate.group(1) != null ? -moves : moves);
  }

  /// Stores what the engine said about one position.
  ///
  /// What comes back is what is on the node, which is not always what was sent:
  /// a shallower answer never overwrites a deeper one, and the screen must draw
  /// the stored number rather than the one it hoped to store.
  Future<void> _saveNote(String fen, AnalysisLine line) async {
    final parsed = _evalOf(line.evaluation);
    if (parsed == null) return;
    final stored = await _api.putNote(
      color: widget.color,
      fen: fen,
      evalCp: parsed.cp,
      mateIn: parsed.mateIn,
      evalDepth: line.depth,
      bestUci: line.bestMoveLan.isEmpty ? null : line.bestMoveLan,
      bestLineSan: line.continuationSan.isEmpty
          ? line.bestMoveSan
          : line.continuationSan,
    );
    if (!mounted || stored == null) return;
    setState(() => _notes = {..._notes, stored.fenKey: stored});
  }

  /// The positions along the line the board is standing on, the root first.
  ///
  /// Both sides' turns, because the size of a disagreement is the evaluation
  /// before a move minus the one after it — a pass that skipped the opponent's
  /// positions would produce a review list that could name no numbers.
  List<String> _lineFens() {
    final active = _activeNode;
    if (active == null) return const [];
    final fens = <String>[];
    AnalysisNode? at = active;
    while (at != null) {
      fens.insert(0, at.fen);
      at = at.parent;
    }
    return fens;
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
    final node = _node;
    if (node == null || kept.isEmpty) return;

    setState(() => _busy = true);
    var added = 0;
    var coveredSum = 0.0;
    var tailMoves = 0;
    var counted = 0;
    OpponentReplies? shown;
    String? shownFen;
    String? shownSan;
    String? shownUci;

    for (final move in kept) {
      final after = _fenAfter(node.fen, move.uci);
      if (after == null) continue;
      final lookup = await _judge.replies(after, minRating: widget.minRating);
      if (!mounted) return;
      _asked += 1;
      final replies = lookup.replies;
      if (replies == null) continue;
      counted += 1;
      // The first kept move is the primary — the server hands them back that
      // way — so this is the line the student actually plays, and its answers
      // are the ones worth putting on the board. The alternates are opened all
      // the same; they are simply not what the board is showing.
      if (shown == null) {
        shown = replies;
        shownFen = after;
        shownSan = move.san;
        shownUci = move.uci;
      }
      coveredSum += replies.coveredShare;
      tailMoves += replies.tailMoves;
      for (final reply in replies.replies) {
        final next = _fenAfter(after, reply.uci);
        if (next != null) {
          final before = _queue.length;
          // Two moves further from the root than the position we are standing
          // on: the student's own, and the opponent's answer to it.
          //
          // The reach is this position's, multiplied by how often the opponent
          // plays that reply — and only by that. The student's own move does
          // not divide it: which of their moves they play is a decision, not a
          // coin. Same arithmetic as the server's, so the queue built here and
          // the queue derived tomorrow are the same queue.
          _enqueue(
            next,
            [...node.path, move.san, reply.san],
            reach: node.reach * reply.share,
          );
          if (_queue.length > before) added += 1;
        }
      }
    }

    final covered = counted == 0 ? 0 : (coveredSum / counted * 100).round();
    setState(() {
      _busy = false;
      _answers = shown;
      _answersFen = shownFen;
      _answersSan = shownSan;
      // Written out in full rather than glued from a stem: Serbian inflects
      // the participle with the noun, so „Dodata 1 pozicija" and „Dodate 2
      // pozicije" differ in two words, not in a suffix.
      final addedText = serbianCount(
        added,
        one: 'Dodata $added pozicija',
        few: 'Dodate $added pozicije',
        many: 'Dodato $added pozicija',
      );
      final tailText = serbianCount(
        tailMoves,
        one: 'još $tailMoves potez',
        few: 'još $tailMoves poteza',
        many: 'još $tailMoves poteza',
      );
      _note = counted == 0
          ? 'Nijedan odgovor nije stigao — pozicija ostaje bez vašeg odgovora.'
          : '$addedText. '
              'Spremno je $covered% onoga što ćete sresti; '
              'van toga $tailText.';
    });

    // A stop, not a step. These answers cost a Lichess request and they decide
    // what the whole next wave looks like; walking straight past them is how
    // the student ended up building a tree whose shape nobody had seen.
    // A wave of replies is new branches, so the picture moved too.
    await _loadTree();
    if (shownFen == null || shownUci == null || shownSan == null) {
      await _advance();
      return;
    }
    // Through `_standAfterMove`, not `loadFen`.
    //
    // Loading the FEN moves the pieces and tells nothing else: `_standingAfter`
    // stays null, and that is what the tree highlights and what the stored book
    // is read for. The board stood after the move while the picture went on
    // lighting up the position behind it — „pita me za potez, a u stablu mi je
    // fokus na drugoj poziciji", reported live 4.9.2026.
    //
    // There is exactly one way to put this screen after a move, and this is it.
    await _standAfterMove(fen: shownFen, uci: shownUci, san: shownSan);
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

  /// "I am not preparing this branch."
  ///
  /// The only control in this loop that makes the tree *smaller*. Every other
  /// one adds: each wave of replies multiplies the queue, and a repertoire that
  /// answers every sideline is one nobody finishes. Without it the only way to
  /// say this is to close the screen, which says it for one session and then
  /// forgets — and the same dead line is back tomorrow, on every device.
  ///
  /// Everything below the cut leaves the queue with it. A cut that left the
  /// positions underneath it would make the tree exactly as big as it was,
  /// which is how a control teaches people not to press it.
  ///
  /// The moves kept here are left alone, deliberately. Cutting says how far to
  /// prepare, not what to forget, and the drill goes on asking for them.
  Future<void> _cutBranch() async {
    final node = _node;
    if (node == null || _busy) return;

    setState(() => _busy = true);
    final done = await _api.skipNode(color: widget.color, fen: node.fen);
    if (!mounted) return;
    if (!done) {
      setState(() {
        _busy = false;
        _note = 'Grana je ostala — server nije odgovorio.';
      });
      return;
    }

    // Everything below it goes too. A queued position is below this one exactly
    // when its line starts with this line — the same test the server makes by
    // simply not walking past a cut node.
    final below = _queue.where((p) => _isBelow(p, node)).toList();
    for (final gone in below) {
      _queue.remove(gone);
      // Out of `_seen` as well, not only out of the queue. One of these
      // positions may also be reachable down a line that was *not* cut, and a
      // key left behind would keep it out of the queue when it arrives that
      // other way — cutting one branch would then quietly cut a second.
      _seen.remove(_keyOf(gone.fen));
    }

    // Where the board goes next, decided *before* the tree is redrawn: one
    // step back up the line that was just cut. The queue's next position is
    // somewhere else in the repertoire entirely, and being moved there without
    // a word is how somebody loses the place they were working in.
    final back = _findNode(node.fen, _treeRoot)?.parent;

    setState(() {
      _busy = false;
      _cutHere.add(node);
      _lastCut = node;
      // In a local, not inside the sentence: a string nested in an
      // interpolation is invisible to the copy gate, and these three are the
      // wording that changes.
      final gone = serbianCount(
        below.length,
        one: 'izašla još ${below.length} pozicija',
        few: 'izašle još ${below.length} pozicije',
        many: 'izašlo još ${below.length} pozicija',
      );
      _note = below.isEmpty
          ? 'Ovu granu više ne spremam. Neće se javljati.'
          : 'Ovu granu više ne spremam — s njom je $gone.';
    });
    if (back != null) {
      await _show(_Pending(
        fen: back.fen,
        path: _pathTo(back),
        lastUci: back.moveUci,
      ));
    } else {
      await _advance();
    }
    await _loadTree();
    _refreshCounts();
  }

  /// "Prepare this one too" — one opponent move from past the covered wave.
  ///
  /// The wave stops at 80% of what is played, up to four moves, and names the
  /// remainder. That is a good default and a bad wall: the owner met it on his
  /// first line, with twenty-eight moves left over carrying a sixth of the
  /// games and no way at all to say "that one as well".
  ///
  /// It is written down on the server rather than only queued here, and that is
  /// the whole difference between this and a position the screen shows once.
  /// The frontier follows only covered replies — deliberately, or the queue
  /// would fill with moves nobody enqueued — so a hand-picked one has to be
  /// stored, or closing the screen would lose it.
  Future<void> _prepareReply(
    OpponentReply reply, {
    String? fromFen,
    String? afterSan,
  }) async {
    final from = fromFen ?? _answersFen;
    final san = afterSan ?? _answersSan;
    final node = _node;
    if (from == null || san == null || node == null || _busy) return;

    setState(() => _busy = true);
    final done = await _api.prepareReply(
      color: widget.color,
      fen: from,
      uci: reply.uci,
      san: reply.san,
    );
    if (!mounted) return;
    if (!done) {
      setState(() {
        _busy = false;
        _note = 'Potez nije dodat u pripremu — server nije odgovorio.';
      });
      return;
    }

    final next = _fenAfter(from, reply.uci);
    final before = _queue.length;
    if (next != null) {
      // Ordered by reach like everything else. Choosing it deliberately says it
      // must be prepared, not that it is suddenly common — a move played in one
      // game in twenty waits behind the ones that are not.
      _enqueue(
        next,
        [...node.path, san, reply.san],
        reach: node.reach * reply.share,
      );
    }
    setState(() {
      _busy = false;
      _preparedUcis.add(reply.uci);
      _note = _queue.length > before
          ? 'U pripremi je i ${reply.san}. Vratiće se u red i sutra.'
          : '${reply.san} je već u pripremi.';
    });
    await _loadTree();
  }

  /// Whether a queued position lies under [root] — its line starts with that
  /// one.
  bool _isBelow(_Pending node, _Pending root) {
    if (node.path.length <= root.path.length) return false;
    for (var i = 0; i < root.path.length; i++) {
      if (node.path[i] != root.path[i]) return false;
    }
    return true;
  }

  /// Puts the last cut branch back, and puts the student back on it.
  ///
  /// Cutting has to be as cheap to undo as it is to do, or it stops being a
  /// decision and becomes a risk — and nobody prunes a tree they cannot
  /// unprune. What was below the cut does not come back with it: those
  /// positions are opened again by taking the replies, which is where they came
  /// from in the first place.
  Future<void> _restoreBranch() async {
    final node = _lastCut;
    if (node == null || _busy) return;

    setState(() => _busy = true);
    final done = await _api.unskipNode(color: widget.color, fen: node.fen);
    if (!mounted) return;
    if (!done) {
      setState(() {
        _busy = false;
        _note = 'Grana nije vraćena — server nije odgovorio.';
      });
      return;
    }

    setState(() {
      _busy = false;
      _cutHere.remove(node);
      _lastCut = null;
      _note = 'Grana je vraćena u red.';
      // Back into the queue in its own place, not at the front: it is worth
      // exactly as much as its reach said it was before it was cut.
      _seen.remove(_keyOf(node.fen));
    });
    _enqueue(node.fen, node.path, kind: node.kind, reach: node.reach);
    // Only when there is nothing on the board. Undo returns the branch to the
    // queue, in its own place; it does not shove aside the position the student
    // is in the middle of answering.
    if (_current == null) await _advance();
    await _loadTree();
    _refreshCounts();
  }

  /// Re-reads the walk for its numbers and leaves the board where it is.
  ///
  /// `_resume` cannot be used for this: it refills the queue and advances, so
  /// calling it after every kept move would move the board out from under the
  /// reader. What changes after an answer is the *count* — how many positions
  /// are still unanswered, how many drafts are still waiting — and the banner
  /// above the board is where that is read.
  ///
  /// Deliberately not awaited by its callers: it is a walk, about a third of a
  /// second, and nothing on screen has to wait for a number to catch up.
  Future<void> _refreshCounts() async {
    final walk = await _api.frontier(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
      gateUci: widget.gateUci,
      breadth: _breadth,
    );
    // A walk that could not be read leaves the old number standing rather than
    // replacing it with a zero nobody measured.
    if (!mounted || walk == null) return;
    setState(() => _frontier = walk);
  }

  /// Takes the board to the first position nobody has decided in.
  ///
  /// A sheet used to open over the board with the drafted move and three
  /// buttons in it, and it was the wrong shape for the question: deciding needs
  /// the position, what the book says about it, and the engine — all of which
  /// this screen already has, and none of which fits in a sheet. So the button
  /// navigates instead. The move waiting there shows up in the list under the
  /// board as „predlog — nije još vaš izbor", with „Potvrdi" beside it, and
  /// everything else on the screen works the way it does for a move typed by
  /// hand.
  ///
  /// Available whether or not the banner is up: „where is the work" is a
  /// question worth asking on any position, and the answer is one request.
  Future<void> _reviewDrafts() async {
    if (_busy) return;
    setState(() => _busy = true);
    final walk = await _api.unconfirmedPositions(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      gateUci: widget.gateUci,
      breadth: _breadth,
      minRating: widget.minRating,
      limit: 1,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    // Three answers, not two. „We could not ask" must never be shown as
    // „there is nothing left to do" — that is exactly what the review did for
    // as long as it sent an empty rating band.
    if (walk == null) {
      AppFeedback.error(
          context, 'Nepotvrđeni potezi nisu mogli da se pročitaju.');
      return;
    }
    if (walk.positions.isEmpty) {
      final said = await _emptyDraftMessage();
      if (!mounted) return;
      AppFeedback.info(context, said);
      return;
    }
    final at = walk.positions.first;
    // The drafted move travels with the position. Playing something else here
    // is not just adding a move: what the rejected draft was the only way to
    // has to go with it, and that sweep is keyed on knowing which move was
    // turned down.
    await _goToDraft(at.fen, at.moves.isEmpty ? null : at.moves.first.uci);
  }

  /// „There are none" is only true when there are none **anywhere**.
  ///
  /// The review walks this repertoire — its gate, its width — and a draft
  /// outside either is one it cannot reach. Found live 4.9.2026 with 21 of
  /// them: a spine written while the width was wider, then read back at „Samo
  /// glavna linija", where the walk follows one reply a position and every one
  /// of those drafts sits under the second. The screen said „Nema više
  /// nepotvrđenih poteza." — which was the walk's honest answer and the wrong
  /// sentence, because they were all still there.
  ///
  /// So the colour is counted before that sentence is said, and the reader is
  /// told which of the two they are looking at. The count costs one query and
  /// no Lichess request, and it is asked only on the empty answer.
  Future<String> _emptyDraftMessage() async {
    final counts = await _api.unconfirmedCounts();
    final held = counts == null
        ? 0
        : (widget.color == 'w' ? counts.w : counts.b).positions;
    if (held <= 0) return 'Nema više nepotvrđenih poteza.';
    return 'U ovom repertoaru nema nepotvrđenih poteza koje ovoliko odgovora '
        'dohvata — u grafu ih ima $held. Proširite repertoar ili ih '
        'potvrdite sa druge grane.';
  }

  /// Puts a drafted position on the board, whether or not the drawing reaches
  /// it.
  ///
  /// The tree is cut off at sixteen half-moves, so a draft deeper than that is
  /// not a card anywhere — and a jump that quietly does nothing is how a button
  /// stops being believed.
  Future<void> _goToDraft(String fen, String? rejectedUci) async {
    setState(() {
      _draftToReplaceFen = rejectedUci == null ? null : fen;
      _draftToReplaceUci = rejectedUci;
    });
    final node = _findNode(fen, _treeRoot);
    if (node != null) {
      await _jumpTo(node);
      return;
    }
    _seen.remove(_keyOf(fen));
    _enqueue(fen, const [], reach: 1);
    await _advance();
  }

  /// Builds the trunk from the position on the board.
  ///
  /// The answer to "thirty questions before it looks like an opening". What it
  /// writes is a draft — drawn, walked through, never drilled until confirmed —
  /// and it follows any move already here instead of overwriting it, so running
  /// it again from further down is the same action as starting.
  Future<void> _buildSpine() async {
    final fen = _current;
    if (fen == null || _busy) return;

    final chosen = await showDialog<({int depth, String breadth})>(
      context: context,
      builder: (context) => BreadthDialog(
        id: widget.id,
        api: _api,
        current: _breadth,
      ),
    );
    if (chosen == null || !mounted) return;
    final depth = chosen.depth;
    // Adopted before the spine runs, so the walk and the picture that follow
    // it are read at the width the reader just chose rather than at the one
    // the screen was opened with.
    setState(() => _breadth = chosen.breadth);

    setState(() {
      _busy = true;
      _note =
          'Predlažem glavnu liniju — ovo troši $depth do ${depth * 2} upita.';
    });
    final out = await _api.buildSpine(
      color: widget.color,
      rootFen: fen,
      depth: depth,
      minRating: widget.minRating,
    );
    if (!mounted) return;
    final result = out.result;
    if (result == null) {
      setState(() {
        _busy = false;
        _note = out.error ?? 'Glavna linija nije predložena.';
      });
      return;
    }

    // The line is built from where the spine *started*, so it is read before
    // the walk is re-read and the board moves on.
    final note = _spineNote(result, from: _node?.path ?? const []);
    setState(() {
      _busy = false;
      _asked += result.path.length;
    });
    // The queue and the picture both changed, and neither costs an allowance.
    // The board stays: the spine was grown from the position in front of the
    // reader, and the first thing to look at is what it wrote under it.
    await _resume(keepBoard: true);
    if (!mounted) return;
    // Said *after* the reload, not before it. `_resume` writes its own note
    // when the walk cannot be read, and setting this first meant the one thing
    // the reader had just asked for was the one thing they did not get told.
    //
    // And if the picture that came back does not contain the position the
    // spine was grown from, that is said too. Reported live 4.9.2026: a spine
    // built from a branch off the trunk, with „Samo glavna linija" chosen in
    // the same dialog, wrote its moves and then vanished — the width narrowed
    // the walk to one reply a position, the branch fell out of it, and the new
    // line went with it. The moves are in the graph either way; what is gone
    // is the way to see them, and that is exactly the kind of silence this
    // codebase keeps paying for.
    final lost = result.written > 0 && _findNode(fen, _treeRoot) == null;
    setState(() => _note = lost
        ? '$note Ova pozicija je izvan onoga što spremate („${breadthName(_breadth)}"), pa je '
            'stablo ne crta — spremajte više odgovora da biste videli šta je upisano.'
        : note);
  }

  /// What the spine did, in one sentence that never claims more than it did.
  String _spineNote(SpineResult result, {required List<String> from}) {
    if (result.path.isEmpty) {
      return 'Ništa nije upisano — već na ovoj poziciji je linija pretanka '
          '(ispod ${result.minGames} partija).';
    }
    final line = numberedLine(
      [...widget.rootPath, ...from, ...result.path],
      from: widget.rootPath.isEmpty ? widget.rootFen : null,
    );
    final wrote = 'Upisano ${result.written} '
        '${result.written == 1 ? "predlog" : "predloga"}';
    final tail = result.ranTheWholeWay
        ? '.'
        : ' — stalo jer je dalje pretanko (${result.games} partija, prag '
            '${result.minGames}).';
    return '$wrote$tail Glavna linija: $line. Potvrdite ono sa čim se slažete.';
  }

  /// Says yes to a generated move.
  ///
  /// The act the whole draft idea rests on. A move somebody generated is drawn
  /// and walked through and never drilled; this is what turns it into a
  /// decision, and it is deliberately something the student does rather than
  /// something that happens to them.
  Future<void> _confirm(RepertoireMove move) async {
    final fen = _current;
    if (fen == null || _busy) return;
    setState(() => _busy = true);
    final done = await _api.confirmNode(
      color: widget.color,
      fen: fen,
      uci: move.uci,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = done ? null : 'Potez nije potvrđen — server nije odgovorio.';
    });
    if (done) {
      await _loadKept();
      await _loadTree();
      _refreshCounts();
    }
  }

  Future<void> _makePrimary(RepertoireMove move) async {
    final fen = _current;
    if (fen == null) return;
    await _api.makePrimary(color: widget.color, fen: fen, uci: move.uci);
    await _loadKept();
    await _loadTree();
  }

  /// Removes a move, and takes with it whatever nothing can reach any more.
  ///
  /// The rule as the owner asked for it is "everything behind the old choice
  /// goes". The rule as it has to be built is **unreachable**, not "behind":
  /// the store is a graph, so a position under the move being dropped may also
  /// stand on a line that is still played, and a subtree delete would silently
  /// damage a line nobody touched.
  ///
  /// Drafts go without a word. Decisions are counted and asked about, because
  /// losing an evening's work to a changed second move with no sentence about
  /// it is the kind of thing that happens once and ends trust in a feature.
  Future<void> _remove(RepertoireMove move) async {
    final fen = _current;
    if (fen == null || _busy) return;

    setState(() => _busy = true);
    // Before the removal. Afterwards the question has no answer: the move that
    // reached those positions is gone.
    final orphans = await _api.orphansOfRemoving(
      color: widget.color,
      fen: fen,
      uci: move.uci,
      minRating: widget.minRating,
    );
    await _api.removeMove(color: widget.color, fen: fen, uci: move.uci);
    if (!mounted) return;

    var swept = 0;
    if (orphans != null && orphans.keys.isNotEmpty) {
      if (orphans.drafts > 0) {
        swept += await _api.prune(
          color: widget.color,
          keys: orphans.keys,
          minRating: widget.minRating,
        );
      }
      if (!mounted) return;
      if (orphans.decisions > 0) {
        final also = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ostalo je bez veze'),
            content: Text(
              'Bez tog poteza do ${orphans.decisions} '
              '${orphans.decisions == 1 ? "vašeg poteza" : "vaših poteza"} '
              'više nema kako da se stigne. Obrisati i njih?\n\n'
              'Ako ih ostavite, biće tu ali ih ništa neće dosezati dok ne '
              'napravite put do njih.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Ostavi'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Obriši i njih'),
              ),
            ],
          ),
        );
        if (also == true && mounted) {
          swept += await _api.prune(
            color: widget.color,
            keys: orphans.keys,
            includeDecisions: true,
            minRating: widget.minRating,
          );
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = swept == 0
          ? null
          : 'Uklonjeno i $swept ${swept == 1 ? "potez" : "poteza"} do kojih se '
              'više nije moglo stići.';
    });
    await _loadKept();
    await _loadTree();
    _refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text(widget.name),
        elevation: 0,
        actions: [
          const SpeechToggleButton(),
          const BoardViewMenu(arrows: true),
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
      // The strip is the buttons; the arrows are the same four actions without
      // the mouse. They arrive together on every screen that has a board, and a
      // test reads the sources to keep it that way — the sixth screen is
      // exactly where one gets forgotten, and only somebody reaching for the
      // keyboard would ever find out.
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        onChanged: () {},
        // Never while a move is waiting to be judged or the wave's answers are
        // up: an arrow key would walk away from a decision that is half made.
        enabled: !_busy && _proposalUci == null && _answers == null,
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    // Told apart on purpose. "Still working out where you were" and "there is
    // nothing left to do" look identical if both render the finished screen,
    // and only one of them is good news.
    if (_resuming) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_current == null) return _buildDone();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Where there is room, the tree sits beside the board instead of on
        // another screen. This costs nothing: the board is capped, and on a
        // desktop window the space it does not use was empty.
        final wide = constraints.maxWidth >= Breakpoints.wide;
        if (!wide) {
          return _buildBoardColumn(context, _boardSize(constraints, wide));
        }
        // Wide enough for two: the board and its question on the left, the
        // picture on the right. The left column is the board plus its padding
        // and no more — everything past that belongs to the tree.
        final left = (constraints.maxWidth * 0.42).clamp(420.0, 620.0);
        // And wide enough for three: what was written about the position gets
        // its own column instead of standing in the queue under the board. The
        // width comes off the tree, never off the board — `_boardSize` is
        // computed from the same 42% either way — because a smaller board is
        // the one thing worse than a comment one scroll away.
        final third = constraints.maxWidth >= Breakpoints.ultraWide;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: left,
              child: _buildBoardColumn(context, _boardSize(constraints, wide),
                  commentBeside: third),
            ),
            VerticalDivider(width: 1, color: context.colors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _buildTree(context),
              ),
            ),
            if (third) ...[
              VerticalDivider(width: 1, color: context.colors.border),
              SizedBox(
                width: 320,
                // Its own scroll view. A long comment must not be able to make
                // the row taller than the window — in a release build that is
                // not a striped warning, it is a panel with its bottom cut off.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildComment(context, dense: false),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// How big the board may be here.
  ///
  /// Minus the padding, not the raw width: BoardWithCoordinates takes `size` as
  /// the whole thing, gutter included, so handing it the outer width overflows
  /// by exactly the padding — 24 px, invisible in a release build.
  ///
  /// The old ceiling of 420 is a phone number, and on a 1900 px window it left
  /// a phone layout wearing a desktop. Wide, it grows — but never past what the
  /// height allows, or the question below it goes off the bottom, which is the
  /// one thing worse than a small board.
  double _boardSize(BoxConstraints constraints, bool wide) {
    if (!wide) return (constraints.maxWidth - 24).clamp(200.0, 420.0);
    final byWidth = (constraints.maxWidth * 0.42).clamp(420.0, 620.0) - 24;
    final byHeight =
        constraints.maxHeight.isFinite ? constraints.maxHeight - 280 : byWidth;
    final smaller = byWidth < byHeight ? byWidth : byHeight;
    return smaller.clamp(200.0, 560.0);
  }

  /// The tree, drawn by the analysis board's own widget.
  ///
  /// Nothing until the walk has answered; an empty canvas would read as an
  /// empty repertoire, which is the one sentence this screen must not say by
  /// accident.
  Widget _buildTree(BuildContext context) {
    final root = _treeRoot;
    final active = _activeNode;
    if (root == null || active == null) return const SizedBox.shrink();
    return RepertoireTreePanel(
      root: root,
      active: active,
      nodeLook: (node) => _looks[node.id],
      onSelect: _jumpTo,
      onPromote: _promoteFromTree,
      onDelete: _deleteFromTree,
      truncatedAt: _tree?.truncated == true ? _tree?.maxPly : null,
      cutHidden: _tree == null ? 0 : countCutMoves(_tree!),
      showCut: _showCut,
      onToggleCut: _toggleCut,
      minRating: widget.minRating,
      breadth: _breadth,
      // Named for what it will actually do to *this* card. On the opponent's
      // move it is the cut, under the same words the button uses, so the two
      // stop looking like two different powers over the same branch.
      deleteLabel: (node) {
        final move = _moveOf(node);
        if (move == null) return 'Obriši ovu varijantu';
        return _isMine(move.from.fen)
            ? 'Obriši ovaj potez'
            : 'Ne spremam ovu granu';
      },
      // Only on the reader's own moves: an opening is a decision of theirs, and
      // the opponent's reply is not one to fork from.
      extraLabel: (node) {
        final move = _moveOf(node);
        if (move == null || !_isMine(move.from.fen)) return null;
        return 'Izdvoji u novo otvaranje';
      },
      onExtra: _forkFromTree,
    );
  }

  /// The board and everything that belongs to the position standing on it.
  ///
  /// [commentBeside] says the comment has a column of its own, so it is not
  /// drawn a second time here — one comment, in one place, whatever the width.
  Widget _buildBoardColumn(BuildContext context, double boardSize,
      {bool commentBeside = false}) {
    final active = _activeNode;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_current != null)
            // Deliberately unkeyed. A key that changes as the walk advances
            // destroys the banner's State, and its State is the carried
            // name — the whole point of the last-named rule. Opening another
            // repertoire pushes a new screen, so there is nothing a key here
            // could reset that is not reset already.
            OpeningBanner(
              fen: _standingAfter?.fen ?? _current!,
              lookup: widget.openingLookup,
            ),
          if (_frontier != null && _frontier!.draft > 0)
            UnconfirmedBanner(
              total: _frontier!.draft,
              // The walk is re-read when the review closes. Its number is a
              // snapshot taken when the screen opened, and the review is the
              // one thing on this screen that changes it — so without this the
              // banner advertises drafts the wizard then says do not exist.
              onOpenWizard: _reviewDrafts,
            ),
          Center(
            child: BoardWithCoordinates(
              size: boardSize,
              orientation: _forWhite ? PlayerColor.white : PlayerColor.black,
              builder: (inner) => ChessBoardWithOverlay(
                controller: _boardController,
                boardOrientation:
                    _forWhite ? PlayerColor.white : PlayerColor.black,
                boardSize: inner,
                // Nothing to play while the answers are up: the board is
                // showing a position it is the opponent's turn in, and a
                // move dragged there would be judged as the student's own.
                isAllowedToMove:
                    !_busy && _proposalUci == null && !_afterMyMove,
                isDrawingMode: false,
                drawingStartSquare: null,
                arrows: const [],
                lastMoveFrom: _lastMoveFrom,
                lastMoveTo: _lastMoveTo,
                // The engine's answer, on the board rather than only in a
                // list underneath it: one arrow per line, its evaluation
                // written beside it. Reading a move as "Nxd4" and finding
                // it on the board is work a beginner should not have to do
                // to see what the engine means.
                engineArrows: _boardArrows(),
                onMove: _onMove,
                onSquareTapForDrawing: (_) {},
              ),
            ),
          ),
          // The palette first, then the strip: one walks the line, the other
          // shows what branches off it.
          _buildNavigation(context),
          // Where you came from, where you are, and what comes next. The
          // part of the tree you need while answering a position, and the
          // only part readable at 360 dp — where the canvas below is one
          // scroll away rather than the thing you read.
          if (active != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            RepertoireLineStrip(active: active, onSelect: _jumpTo),
          ],
          // Under the board where there is no third column for it, and nothing
          // at all when nothing has been written. Above the question on
          // purpose: it is about the board, and the question is about what to
          // do next.
          if (!commentBeside) _buildComment(context, dense: true),
          const SizedBox(height: AppSpacing.md),
          _buildQuestion(context),
          const SizedBox(height: AppSpacing.sm),
          // One thing at a time. While the opponent's answers are on the
          // board, the verdict, the kept moves, the engine and the book all
          // belong to a position that is no longer the one being shown.
          if (_answers != null) _buildAnswers(context, _answers!),
          if (!_afterMyMove && _proposalSan != null) _buildVerdict(context),
          if (!_afterMyMove && _kept.isNotEmpty) _buildKept(context),
          // **One** statistics panel, and it is the one for the side to move
          // on the board. Two of them were on screen at once — what is played
          // here, and what the opponent answers the main move with — which is
          // two lists about two different positions stacked under one board.
          // The second is now where it belongs: one step forward, on the
          // position it is actually about.
          if (_answers == null)
            _standingAfter == null
                ? _buildHereBook(context)
                : _buildStoredReplies(context),
          // Open once the engine has been asked about *this* position —
          // including when it came back with nothing, because that is
          // exactly when the reader wants the depth dial and another go —
          // and whenever there is a stored evaluation to show, which is the
          // whole point of storing one.
          if (!_afterMyMove &&
              (_thinking || _linesFen == _current || _noteHere != null))
            _buildEngine(context),
          if (_note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            // Read aloud, like the same sentence is on the finished screen.
            //
            // This is where „Dodate 2 pozicije" and „Grana je odsečena — sa
            // njom je iz reda izašla još 1 pozicija" land, and it was a plain
            // grey caption: the one line saying what the button just did was
            // the one line nobody heard. Reported live 4.9.2026, twice, as the
            // plurals being silent — they were written and they were shown,
            // and the panel around them could not speak.
            SpeakableInfo(
              text: _note!,
              autoSpeak: true,
              child: Text(_note!,
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted)),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildControls(context),
          // Narrow: under the controls rather than beside them, and never a
          // navigation away. The panel caps its own height, so it sits in
          // this scroll view without eating the board.
          if (!Breakpoints.isWide(context)) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildTree(context),
          ],
        ],
      ),
    );
  }

  /// The gate, written as a move — "kroz 0-0", not "kroz e1g1".
  ///
  /// Worked out from the root rather than carried in a second parameter: the
  /// screen already has the position and the move, and two ways to know the
  /// same thing is two ways for them to disagree.
  String? get _gateSan {
    final gate = widget.gateUci;
    if (gate == null) return null;
    for (final option in gateOptionsFor(widget.rootFen)) {
      if (option.uci == gate) return option.san;
    }
    return gate;
  }

  Widget _buildQuestion(BuildContext context) {
    final left = _queue.length;
    final line = _lineText();
    final walk = _frontier;
    final gate = _gateSan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Which opening this is, when the same starting position holds more
        // than one. Said on the screen that builds it, because everything below
        // — the queue, the tree, the counts — is narrowed to it, and a filtered
        // view that does not say it is filtered is how somebody concludes their
        // work has been deleted.
        if (gate != null) ...[
          Row(
            children: [
              Icon(Icons.alt_route, size: 14, color: context.colors.info),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  'Ovaj repertoar ide kroz $gate — ostalo iz ove pozicije se '
                  'ne prikazuje.',
                  style: AppText.caption.copyWith(color: context.colors.info),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (line.isNotEmpty) ...[
          // Where this board came from. Without it the screen is a position
          // with no history and a count of an invisible list, which is exactly
          // how it felt to use: the moves were being kept and nothing on screen
          // said which line they belonged to.
          Text(
            line,
            style: AppText.caption.copyWith(color: context.colors.accent),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        // This screen asks a question, exactly as the drill does, so it reads
        // it out for the same reason: the panels that want something from the
        // reader speak, the ones that are merely true wait. Phase 2 wrapped
        // this screen's banner, its note and its finished sentence and missed
        // the one panel that actually asks — found live by the owner on
        // 3.9.2026, entering izgradnja and hearing nothing.
        Builder(builder: (context) {
          final question = _answers != null
              ? 'Posle $_answersSan — ovo igra protivnik'
              : _standingAfter != null
                  ? 'Posle ${_standingAfter!.san} — šta igra protivnik'
                  : (_forWhite ? 'Šta igrate belim?' : 'Šta igrate crnim?');
          // Says which count it is.
          //
          // Reported live 4.9.2026: „javlja mi da ima 9 neodgovorenih, a ja sam
          // izbrojao 7". Three numbers sit within two lines of each other here
          // and each measures something else — this one leaves out the position
          // on the board; the legend below says `otvoreno 10`, which still
          // counts it; and the picture draws however many fit under its depth
          // cap. All three were right and none of them said what it was
          // counting, which is the same defect as a wrong number and harder to
          // argue with.
          //
          // „ne računajući ovu" rather than a word for the list itself: the
          // glossary retired *red* on 3.9.2026 and chose „Još N neodgovorenih"
          // to say the same thing without a concept behind it. The first
          // version of this fix put the concept straight back, and the phase 4
          // table check is what caught it.
          final under = left == 0
              ? 'Poslednja neodgovorena pozicija koju ovaj repertoar dohvata.'
              : serbianCount(
                  left,
                  one: 'Još $left neodgovorena pozicija, ne računajući ovu.',
                  few: 'Još $left neodgovorene pozicije, ne računajući ovu.',
                  many: 'Još $left neodgovorenih pozicija, ne računajući ovu.',
                );
          return SpeakableInfo(
            autoSpeak: true,
            text: '$question $under',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  under,
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
              ],
            ),
          );
        }),
        if (!_afterMyMove && _node?.kind == 'unopened') ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Ovde ste već izabrali potez — ostalo je samo da uzmete odgovore.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
        ],
        if (walk != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _progressText(walk),
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
        ],
      ],
    );
  }

  /// How finished the repertoire is, in the one number that cannot flatter it.
  ///
  /// Not "how many positions you have" — a wide, one-move-deep tree scores well
  /// on that and loses games. This is the share of games arriving in the
  /// repertoire that run into a position with no answer yet, which starts at
  /// 100% and only falls when something the student will actually meet gets an
  /// answer.
  String _progressText(RepertoireFrontier walk) {
    final open = (walk.openReach * 100).clamp(0, 100).round();
    final parts = <String>[
      'odlučeno ${walk.decided}',
      'otvoreno ${walk.open.length}',
      'bez odgovora $open%',
      if (walk.draft > 0) 'nepotvrđeno ${walk.draft}',
    ];
    // Cut branches are counted apart and never taken off "bez odgovora".
    // Cutting makes that number fall without a single question having been
    // answered, so the share of games that run into a cut line is said out
    // loud beside it — those games are still going to be played.
    final cut = walk.pruned.length + _cutHere.length;
    if (cut > 0) {
      final reach = walk.prunedReach +
          _cutHere.fold<double>(0, (sum, node) => sum + node.reach);
      final percent = (reach * 100).clamp(0, 100).round();
      parts.add('ne spremam $cut${percent > 0 ? " ($percent%)" : ""}');
    }
    if (walk.truncated) parts.add('pregled skraćen');
    return parts.join(' · ');
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
                        move.isDraft
                            ? 'predlog — nije još vaš izbor'
                            : (move.isPrimary
                                ? 'glavni'
                                : 'dodirnite za glavni'),
                        style: AppText.micro.copyWith(
                          color: move.isDraft
                              ? context.colors.warning
                              : context.colors.textMuted,
                        ),
                      ),
                    ),
                    // Saying yes is an act. Until it happens the drill leaves
                    // this move alone, which is what makes offering generated
                    // moves safe at all.
                    if (move.isDraft)
                      TextButton(
                        onPressed: _busy ? null : () => _confirm(move),
                        child: const Text('Potvrdi'),
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

  /// What the opponent answers the main move with — beside the board, always.
  ///
  /// Drawn from the stored book, so it costs nothing and can simply sit there.
  /// It is also the one list that decides what the next wave looks like, which
  /// is why it stopped being something you only get after pressing `Dalje`.
  ///
  /// Every row leads somewhere: a reply already in the preparation takes the
  /// board there, and one from past the cut offers to prepare it.
  /// What is played in the position on the board, and a way to play it.
  ///
  /// The panel the build loop now runs on. It used to be behind "Ne znam",
  /// because the loop was a quiz and the book was the answer sheet; the
  /// repertoire is built from the statistics and the evaluation now, so there
  /// is nothing left for it to spoil.
  Widget _buildHereBook(BuildContext context) {
    final book = _here;
    if (book == null || _hereFor != _current) return const SizedBox.shrink();
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
              Icon(Icons.insights, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Šta se ovde igra',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            book.opened
                ? 'Statistika iz sačuvane baze — ne troši upit. ★ je potez '
                    'koji već držite ovde.'
                : 'Ovu poziciju još niko nije otvarao.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          if (!book.opened)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openHereBook,
                icon: const Icon(Icons.menu_book, size: 18),
                label: const Text('Otvori knjigu (1 upit)'),
              ),
            )
          else
            for (final move in book.replies)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(
                        kept.contains(move.uci) ? '${move.san} ★' : move.san,
                        style: (kept.contains(move.uci)
                                ? AppText.bodyBold
                                : AppText.body)
                            .copyWith(color: context.colors.textPrimary),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(_shareText(move.share),
                          style: AppText.caption
                              .copyWith(color: context.colors.textPrimary)),
                    ),
                    Expanded(
                      child: Text('${move.games} partija',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted)),
                    ),
                    OutlinedButton(
                      onPressed: _busy || _proposalUci != null
                          ? null
                          : () => _playFromBook(move.uci),
                      child: const Text('Igraj'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildStoredReplies(BuildContext context) {
    final book = _stored;
    final after = _storedFor;
    // The move the board is standing after. The rows below carry its name into
    // the path they build, so naming the wrong one would file a position under
    // a line it is not on.
    final looking = _standingAfter;
    if (book == null || after == null || looking == null) {
      return const SizedBox.shrink();
    }

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
              Icon(Icons.alt_route, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Posle ${looking.san} — šta igra protivnik',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            book.opened
                ? 'Iz sačuvane knjige — ne troši upit.'
                : 'Poziciju posle ${looking.san} još niko nije otvarao.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          if (!book.opened)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openStoredBook,
                icon: const Icon(Icons.menu_book, size: 18),
                label: Text('Otvori knjigu posle ${looking.san} (1 upit)'),
              ),
            )
          else
            for (final reply in book.replies)
              _storedRow(context, reply, after: after, mine: looking.san),
        ],
      ),
    );
  }

  /// True when the board is standing on a branch that was cut.
  ///
  /// A cut made in an earlier session could not be undone from anywhere: the
  /// undo button knows only the last cut of *this* session, so a reader who
  /// found an old ✂ branch through „Prikaži odsečene grane" could look at it
  /// and do nothing else — not change their mind, not carry on building.
  bool get _standingOnCut {
    final fen = _current;
    if (fen == null) return false;
    if (_cutHere.any((node) => _keyOf(node.fen) == _keyOf(fen))) return true;
    return _findTreeMove(_tree?.children ?? const [], fen)?.state == 'cut';
  }

  /// Puts the branch in front of the reader back into the walk.
  ///
  /// The same call as the undo, aimed at the position on the board rather than
  /// at the last thing this session did.
  Future<void> _restoreHere() async {
    final fen = _current;
    if (fen == null || _busy) return;
    setState(() => _busy = true);
    final done = await _api.unskipNode(color: widget.color, fen: fen);
    if (!mounted) return;
    if (!done) {
      setState(() {
        _busy = false;
        _note = 'Grana nije vraćena — server nije odgovorio.';
      });
      return;
    }
    setState(() {
      _busy = false;
      _cutHere.removeWhere((node) => _keyOf(node.fen) == _keyOf(fen));
      if (_lastCut != null && _keyOf(_lastCut!.fen) == _keyOf(fen)) {
        _lastCut = null;
      }
      _note = 'Grana je vraćena — možete da nastavite odavde.';
    });
    await _loadKept();
    await _loadTree();
    _refreshCounts();
  }

  /// True when this reply's position was cut out of the walk.
  ///
  /// The book's `covered` flag is about the 80% wave and knows nothing about
  /// what *this* reader refused: the panel was offering „Idi" on branches they
  /// had cut themselves, while the drawing marked the same branches ✂ and hid
  /// them. Two screens, one repertoire, opposite answers.
  bool _isCutReply(String afterFen, String uci) {
    final landed = _fenAfter(afterFen, uci);
    if (landed == null) return false;
    if (_cutHere.any((node) => _keyOf(node.fen) == _keyOf(landed))) return true;
    final drawn = _findTreeMove(_tree?.children ?? const [], landed);
    return drawn?.state == 'cut';
  }

  RepertoireTreeMove? _findTreeMove(
      List<RepertoireTreeMove> where, String fen) {
    for (final move in where) {
      if (_keyOf(move.fen) == _keyOf(fen)) return move;
      final deeper = _findTreeMove(move.children, fen);
      if (deeper != null) return deeper;
    }
    return null;
  }

  Widget _storedRow(BuildContext context, StoredReply reply,
      {required String after, required String mine}) {
    final node = _node;
    final cut = _isCutReply(after, reply.uci);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(reply.san,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
          ),
          SizedBox(
            width: 52,
            child: Text(_shareText(reply.share),
                style:
                    (reply.isInPreparation ? AppText.bodyBold : AppText.caption)
                        .copyWith(color: context.colors.textPrimary)),
          ),
          Expanded(
            child: Text(
                cut
                    ? '✂ ne spremam · ${reply.games} partija'
                    : '${reply.games} partija',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          if (cut)
            // Said, not silently offered as prepared. Going there is still
            // allowed — that is how a cut is looked at again — but the row has
            // to carry the fact, because this panel is the one place a cut
            // branch is otherwise invisible.
            TextButton(
              onPressed: _busy || node == null
                  ? null
                  : () {
                      final landed = _fenAfter(after, reply.uci);
                      if (landed == null) return;
                      _show(_Pending(
                        fen: landed,
                        path: [...node.path, mine, reply.san],
                      ));
                    },
              child: const Text('Vidi šta ne spremam'),
            )
          else if (reply.isInPreparation)
            TextButton(
              // Already prepared, so the useful thing is to go and work on it.
              onPressed: _busy || node == null
                  ? null
                  : () {
                      final landed = _fenAfter(after, reply.uci);
                      if (landed == null) return;
                      _show(_Pending(
                        fen: landed,
                        path: [...node.path, mine, reply.san],
                      ));
                    },
              child: const Text('Idi'),
            )
          else
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _prepareReply(
                        OpponentReply(
                          uci: reply.uci,
                          san: reply.san,
                          games: reply.games,
                          share: reply.share,
                        ),
                        fromFen: after,
                        afterSan: mine,
                      ),
              child: const Text('Spremi'),
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
  /// The opponent's answers, in words, beside the same arrows on the board.
  ///
  /// The board says *where*; this says *how often*, and names the part that was
  /// left out. The tail is the point of printing it at all: "four moves
  /// covered, 86% of what you will meet" is honest, and "prepared" without the
  /// remainder is the sentence that lets somebody think a repertoire is
  /// finished when it is not.
  Widget _buildAnswers(BuildContext context, OpponentReplies answers) {
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
              Icon(Icons.alt_route, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Odgovori protivnika',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
              Text('${answers.total} partija',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Broj uz strelicu je koliko se često taj potez igra — to odlučuje '
            'da li morate da ga spremite. Drugi procenat je kako su te partije '
            'prošle po vas.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 6),
          if (answers.replies.isEmpty)
            Text('Nijedan odgovor nije stigao iz baze.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted))
          else
            for (final reply in answers.replies) _answerRow(context, reply),
          if (answers.tailMoves > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Van pripreme još ${answers.tailMoves} '
              '${answers.tailMoves == 1 ? "potez" : "poteza"} — '
              '${(answers.tailShare * 100).round()}% partija. Njih ćete sresti '
              'bez spremljenog odgovora.',
              style: AppText.caption.copyWith(color: context.colors.warning),
            ),
            // The way through the wall. Folded away rather than always open:
            // ten moves at one per cent each under every position would bury
            // the answers that decide the shape of the next wave.
            if (_tailOf(answers).isNotEmpty)
              TextButton.icon(
                onPressed:
                    _busy ? null : () => setState(() => _showTail = !_showTail),
                icon: Icon(_showTail ? Icons.expand_less : Icons.expand_more,
                    size: 18),
                label: Text(_showTail
                    ? 'Sakrij ostale poteze'
                    : 'Spremi i neki od njih'),
              ),
            if (_showTail)
              for (final reply in _tailOf(answers)) _tailRow(context, reply),
          ],
        ],
      ),
    );
  }

  /// The opponent's moves the wave left outside, most played first.
  ///
  /// Out of what the book already returned — no request is made for this. The
  /// book keeps a dozen moves and the rest of a long tail is a fraction of a
  /// per cent each, which is not a decision anybody needs offered to them.
  List<OpponentReply> _tailOf(OpponentReplies answers) {
    // Both tests, and on purpose. `covered` is the flag the server sets while
    // it applies the rule, and the covered list is what it applied the rule to;
    // an answer missing one of the two still comes out right, and a move that
    // is already being prepared never appears as something to add.
    final covered = {for (final reply in answers.replies) reply.uci};
    return [
      for (final reply in answers.all)
        if (!reply.covered && !covered.contains(reply.uci)) reply,
    ];
  }

  Widget _tailRow(BuildContext context, OpponentReply reply) {
    final prepared = _preparedUcis.contains(reply.uci);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(reply.san,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
          ),
          SizedBox(
            width: 52,
            child: Text(_shareText(reply.share),
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          Expanded(
            child: Text('${reply.games} partija',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          if (prepared)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 16, color: context.colors.success),
                const SizedBox(width: 4),
                Text('u pripremi',
                    style: AppText.micro
                        .copyWith(color: context.colors.textMuted)),
              ],
            )
          else
            OutlinedButton(
              onPressed: _busy ? null : () => _prepareReply(reply),
              child: const Text('Spremi'),
            ),
        ],
      ),
    );
  }

  Widget _answerRow(BuildContext context, OpponentReply reply) {
    final score = reply.scoreFor(white_: _forWhite);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(reply.san,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
          ),
          SizedBox(
            width: 52,
            child: Text(_shareText(reply.share),
                style: AppText.bodyBold
                    .copyWith(color: context.colors.textPrimary)),
          ),
          Expanded(
            child: Text(
              '${score.round()}% po vas · ${reply.games} partija',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
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
        if (_answers != null) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _advance,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Sledeća pozicija'),
          ),
        ] else if (_standingAfter != null) ...[
          // Back to the position the move was played from — the one that
          // carries the question, and the only one this screen can be asked
          // about. Without it the only way out of a tapped move is another tap
          // in the tree, which is a corner rather than a state.
          FilledButton.icon(
            onPressed: _busy ? null : () => _show(_node),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text('Nazad na ${_standingAfter!.san}'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _advance,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Sledeća pozicija'),
          ),
        ] else if (_proposalSan != null) ...[
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
          // Told apart from "Preskoči" on purpose, and the labels have to carry
          // the difference: skipping puts the position at the back of the same
          // queue, cutting takes it and everything under it out of the walk for
          // good — until it is put back.
          //
          // Never offered on the repertoire's own root. Cutting that is not
          // pruning, it is deleting the repertoire from inside the screen that
          // builds it, and it is the one cut that leaves no way back in.
          if (_node != null && _node!.path.isNotEmpty)
            _standingOnCut
                // Standing on a branch that was already refused, the one thing
                // worth offering is the way back into it.
                ? OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreHere,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Vrati ovu granu'),
                  )
                : OutlinedButton.icon(
                    onPressed: _busy ? null : _cutBranch,
                    icon: const Icon(Icons.content_cut, size: 18),
                    label: const Text('Ne spremam ovo'),
                  ),
          // The branch in front of the student, practised on its own. This is
          // where it belongs: the ten positions just built are what somebody
          // sits down to drill, and from the list screen the whole repertoire
          // is the only thing that can be asked for.
          // The trunk, from wherever the board is standing. Offered on every
          // position rather than only at the root, because "continue from here"
          // and "start here" are the same action.
          OutlinedButton.icon(
            onPressed: _busy ? null : _buildSpine,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Predloži glavnu liniju'),
          ),
          // Here as well as in the banner: the banner is only up while there
          // are drafts, and „take me to the next one" is the question somebody
          // asks in the middle of the work.
          OutlinedButton.icon(
            onPressed: _busy ? null : _reviewDrafts,
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Pregledaj nepotvrđene'),
          ),
          if (widget.onDrillHere != null && _node != null)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => widget.onDrillHere!(_node!.fen),
              icon: const Icon(Icons.fitness_center, size: 18),
              label: const Text('Vežbaj ovu granu'),
            ),
        ],
        if (_lastCut != null && !_afterMyMove && _proposalSan == null)
          TextButton.icon(
            onPressed: _busy ? null : _restoreBranch,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Ipak spremi ovu granu'),
          ),
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
          _buildStoredNote(context),
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

  /// The evaluation stored on this position, with its depth and its date.
  ///
  /// Both of those are on screen because an eval without them is a number that
  /// ages invisibly: depth 12 from a fortnight ago and depth 30 from a minute
  /// ago look identical written as `+0.35`.
  Widget _buildStoredNote(BuildContext context) {
    final note = _noteHere;
    if (note == null) return const SizedBox.shrink();
    final when = note.updatedAt?.toLocal();
    final date =
        when == null ? null : '${when.day}.${when.month}.${when.year}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              'Sačuvano: ${note.text}',
              'dubina ${note.evalDepth}',
              if (date != null) date,
            ].join(' · '),
            style: AppText.caption.copyWith(color: context.colors.textPrimary),
          ),
          if (note.bestLineSan != null)
            Text(
              note.bestLineSan!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.micro.copyWith(color: context.colors.textMuted),
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
    // Written once, shown and spoken from the same string. Two copies of a
    // sentence drift the first time somebody edits the visible one.
    const done =
        'Odgovorili ste na sve pozicije do kojih ovaj repertoar stiže.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 40),
            const SizedBox(height: AppSpacing.md),
            SpeakableInfo(
              text: done,
              child: Text(
                done,
                style: AppText.bodyBold,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            // No waves and no queue. Both were this screen's own vocabulary,
            // and neither is something the reader has to hold: the number says
            // where things stand and the buttons below say what can be done
            // next, on any position, at any time.
            Text(
              _frontier == null || _frontier!.draft == 0
                  ? 'Sve je sačuvano. Repertoar ide dublje kad negde uzmete '
                      'još protivnikovih odgovora.'
                  : 'Sve je sačuvano. Čeka još ${_frontier!.draft} '
                      'nepotvrđenih poteza.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            // What the last wave covered, said here too. Emptying the queue is
            // exactly when the number matters most, and it used to vanish with
            // the position it was written under.
            if (_note != null) ...[
              const SizedBox(height: 10),
              SpeakableInfo(
                text: _note!,
                child: Text(
                  _note!,
                  style: AppText.caption.copyWith(color: context.colors.accent),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Here as well as in the controls, because a cut is exactly what
            // can empty the queue — and an undo that disappears with the last
            // position is an undo nobody can reach when they need it.
            if (_lastCut != null)
              TextButton.icon(
                onPressed: _busy ? null : _restoreBranch,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Ipak spremi ovu granu'),
              ),
            // The door the sentence above promises. Without it the reader is
            // told to go back to a position and given no way to reach one.
            // The door the sentence above promises. Without it the reader is
            // told to go back to a position and given no way to reach one.
            FilledButton.icon(
              onPressed: _busy ? null : _openRoot,
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('Otvori repertoar'),
            ),
            if (_frontier != null && _frontier!.draft > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _busy ? null : _reviewDrafts,
                icon: const Icon(Icons.edit_note, size: 18),
                label: Text('Pregledaj nepotvrđene (${_frontier!.draft})'),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Nazad'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One position waiting for an answer, and the way it was reached.
///
/// The path is the whole reason this type exists. A queue of bare FENs cannot
/// tell anybody where they are, and "where am I in this tree" was the first
/// thing the screen was asked for and could not do.
class _Pending {
  const _Pending({
    required this.fen,
    required this.path,
    this.kind = 'undecided',
    this.reach = 0,
    this.lastUci,
  });

  final String fen;

  /// The move that led here, when the caller knows it — a card tapped in the
  /// tree does, the queue does not. The board marks it, so the reader is not
  /// asked "what do you play here" on a position they cannot see the way into.
  final String? lastUci;

  /// SAN from the repertoire's root to here. Joined with the repertoire's own
  /// root path to read from move one.
  final List<String> path;

  /// `undecided` — nothing kept here yet.
  /// `unopened` — kept, but the opponent's replies were never taken, so this
  /// came back not to be answered again but to be opened.
  final String kind;

  /// How often a game played down this repertoire actually arrives here — the
  /// product of the opponent's shares along the path. It is the queue's order,
  /// and it is the same number the server sorts by, so a session's order and a
  /// resumed walk's order are one order.
  final double reach;
}
