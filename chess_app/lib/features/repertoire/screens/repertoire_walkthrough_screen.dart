import 'package:flutter/material.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_beats.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_speech.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/repertoire/models/walkthrough_cursor.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/speakable_info.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;

class RepertoireWalkthroughScreen extends StatefulWidget {
  const RepertoireWalkthroughScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    required this.api,
    this.rootPath = const [],
    this.gateUci,
    this.minRating,
    this.breadth,
    this.onBuildHere,
  });

  final String name;
  final String color; // 'w' | 'b'
  final String rootFen;
  final List<String> rootPath;
  final String? gateUci;
  final int? minRating;
  final String? breadth;
  final RepertoireApiService api;
  final void Function(String fen)? onBuildHere;

  @override
  State<RepertoireWalkthroughScreen> createState() =>
      _RepertoireWalkthroughScreenState();
}

class _RepertoireWalkthroughScreenState
    extends State<RepertoireWalkthroughScreen> {
  RepertoireTree? _tree;
  Map<String, RepertoireComment>? _comments;
  bool _loading = true;
  bool _failed = false;

  List<WalkthroughStop> _stops = [];
  List<WalkthroughBeat> _beats = [];
  AnalysisNode? _root;
  final Map<String, MoveTreeNodeLook> _looks = {};

  int _index = 0;

  /// Whether the board is shown from the other side. A repertoire for Black
  /// opens from Black's side, which is right; the button is there for the
  /// moment the reader wants to see the position the way the opponent does.
  bool _flipped = false;
  final ChessBoardController _boardController = ChessBoardController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tree = await widget.api.repertoireTree(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
      gateUci: widget.gateUci,
      breadth: widget.breadth,
      maxPly: 30,
    );
    final comments = await widget.api.comments(color: widget.color);

    if (!mounted) return;

    if (tree == null) {
      setState(() {
        _failed = true;
        _loading = false;
      });
      return;
    }

    _stops = walkthroughOrder(tree);
    _beats = walkthroughBeats(_stops);
    _root = repertoireTreeToNodes(tree, looks: _looks);

    setState(() {
      _tree = tree;
      _comments = comments;
      _loading = false;
      if (_stops.isEmpty) {
        _index = -1;
      } else {
        _index = 0;
      }
    });

    _syncBoard();
  }

  /// The stop the board stands on for the beat at [index], or -1 for the root.
  ///
  /// One place, because both of the readers below had the same bug: `_index`
  /// counts **beats** and both were bounding and indexing it against `_stops`.
  /// There are more beats than stops, so the tour stopped dead at the last
  /// climb — the forward button did nothing, silently — and before that the
  /// board loaded whatever stop happened to share the beat's number, which on
  /// a returning beat is the wrong position and looks like a working screen.
  int _stopAt(int index) =>
      index < 0 || index >= _beats.length ? -1 : _beats[index].stopIndex;

  void _syncBoard() {
    if (_tree == null) return;
    final at = _stopAt(_index);
    _boardController.loadFen(at < 0 ? _tree!.rootFen : _stops[at].move.fen);
  }

  void _onSelect(int index) {
    if (index < -1 || index >= _beats.length) return;
    setState(() {
      _index = index;
    });
    _syncBoard();
  }

  @override
  Widget build(BuildContext context) {
    final tree = _tree;

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upoznaj repertoar',
                style:
                    AppText.title.copyWith(color: context.colors.textPrimary)),
            Text(widget.name,
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary)),
          ],
        ),
        backgroundColor: context.colors.surface,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        // Anything drawn on a board must be switchable off from the screen
        // drawing it. The owner found the AI Studio with engine arrows over a
        // menu that offered only „Koordinate", and `board_arrows_reach_test`
        // has read the sources for that mistake ever since — it caught this
        // screen the moment it started drawing.
        // Only the switch this screen governs. The tour draws the book's
        // shares and nothing else — no engine by design, and its own moves are
        // played rather than pointed at — so offering those two switches here
        // would be a control that changes nothing you can see.
        // The tour's own switch, and it holds for the whole reading. The
        // speaker under the board only ever silenced the sentence in front of
        // it: the next stop with something to say spoke again, because that is
        // a fresh `autoSpeak`. This one writes the setting.
        actions: const [
          SpeechToggleButton(),
          BoardViewMenu(statistics: true),
        ],
      ),
      body: _buildBody(context, tree),
    );
  }

  Widget _buildBody(BuildContext context, RepertoireTree? tree) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Text(
          'Ne mogu da učitam repertoar. Pokušajte ponovo.',
          style: AppText.body.copyWith(color: context.colors.danger),
        ),
      );
    }
    if (tree == null || _stops.isEmpty) {
      return Center(
        child: Text(
          'U ovom repertoaru još nema poteza.',
          style: AppText.body.copyWith(color: context.colors.textMuted),
        ),
      );
    }

    final cursor = WalkthroughCursor(
      tree: tree,
      stops: _stops,
      beats: _beats,
      index: _index,
      onSelect: _onSelect,
    );

    final isWide = Breakpoints.isWide(context);
    final ownSide = widget.color == 'w' ? PlayerColor.white : PlayerColor.black;
    final boardOrientation = _flipped
        ? (ownSide == PlayerColor.white ? PlayerColor.black : PlayerColor.white)
        : ownSide;

    // The move the board is standing on. On a returning beat that is the
    // fork's own move, which is right: the reader is being shown that position
    // again, so the marker has to point at how it was reached.
    final at = cursor.beat?.stopIndex ?? -1;
    String? lastMoveFrom;
    String? lastMoveTo;
    if (at >= 0 && at < _stops.length) {
      final uci = _stops[at].move.uci;
      if (uci.length >= 4) {
        lastMoveFrom = uci.substring(0, 2);
        lastMoveTo = uci.substring(2, 4);
      }
    }

    final boardCol = Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size =
                constraints.maxWidth < 600 ? constraints.maxWidth : 600.0;
            return SizedBox(
              width: size,
              height: size,
              child: ChessBoardWithOverlay(
                controller: _boardController,
                boardSize: size,
                boardOrientation: boardOrientation,
                isAllowedToMove: false,
                isDrawingMode: false,
                drawingStartSquare: null,
                arrows: const [],
                engineArrows: _replyArrows(cursor),
                onMove: (String from, String to, String promotion) {},
                onSquareTapForDrawing: (String square) {},
                lastMoveFrom: lastMoveFrom,
                lastMoveTo: lastMoveTo,
              ),
            );
          },
        ),
        MoveKeyboardShortcuts(
          cursor: cursor,
          onChanged: () {},
          child: MoveNavigationControls(
            cursor: cursor,
            // Numbered by the move, not by the beat: a returning beat is not
            // a new move and the counter going back to it is the truth — that
            // is the position the reader has been brought back to.
            centerLabel: _stops.length > 1 && at >= 0
                ? 'Potez ${at + 1} od ${_stops.length}'
                : null,
            canNavigate: _beats.length > 1,
            onFlipBoard: () => setState(() => _flipped = !_flipped),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildCard(context, cursor),
            ],
          ),
        ),
      ],
    );

    if (isWide && _root != null) {
      final currentFen = cursor.currentFen;
      AnalysisNode? activeNode = _root;
      if (currentFen != null) {
        activeNode = findNodeByFen(_root!, currentFen) ?? _root;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 1, child: boardCol),
          Container(
            width: 1,
            color: context.colors.border,
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: RepertoireTreePanel(
                root: _root!,
                active: activeNode!,
                onSelect: (node) {
                  final key = fenKeyOf(node.fen);
                  final idx =
                      _stops.indexWhere((s) => fenKeyOf(s.move.fen) == key);
                  if (idx < 0) return;
                  final beat = _beats
                      .indexWhere((b) => !b.returning && b.stopIndex == idx);
                  if (beat >= 0) _onSelect(beat);
                },
                nodeLook: (node) => _looks[node.id],
                showCut: false,
                minRating: widget.minRating,
                breadth: widget.breadth,
              ),
            ),
          ),
        ],
      );
    } else {
      return boardCol;
    }
  }

  /// The opponent's replies, drawn on the board at a fork.
  ///
  /// Ranked in **tour order**, not by share. The rank decides both the colour
  /// and the stroke width, so the thickest arrow is the reply the tour will
  /// take first — and it has to be the same reply the first chip and the first
  /// name in the sentence point at. `_shareArrows` on the build screen sorts by
  /// share, which is right for a book and wrong here: two orderings on one
  /// screen is the defect this feature has already been careful about twice.
  ///
  /// Only at a fork. One reply needs no arrow — the board is about to move
  /// there anyway — which keeps one rule behind the arrows, the chips and the
  /// spoken sentence rather than three.
  ///
  /// No share floor. The build screen drops anything under 2% because a book
  /// position has a long tail of noise; a tour walks only what this repertoire
  /// actually contains, and a rare reply that is in it is in it on purpose.
  /// The cap of four stays: past that the strokes are thin and crossing, and
  /// the count is in the sentence and every reply is a chip regardless.
  List<EngineArrow> _replyArrows(WalkthroughCursor cursor) {
    if (!AppSettingsService.instance.showStatisticsArrows) return const [];

    final theirs = [
      for (final move in cursor.forwardMoves)
        if (!move.mine && move.uci.length >= 4) move,
    ];
    if (theirs.length < 2) return const [];

    final arrows = <EngineArrow>[];
    for (var i = 0; i < theirs.length && i < 4; i++) {
      final move = theirs[i];
      final share = shareLabel(move.share) ?? '';
      // The hole carries the tree's own glyph rather than a colour. Hue is
      // never the difference here.
      final hole = lookOfRepertoireMove(move) == MoveTreeNodeLook.gap;
      arrows.add(EngineArrow(
        from: move.uci.substring(0, 2),
        to: move.uci.substring(2, 4),
        evalText: hole ? '$share ?'.trim() : share,
        rank: i + 1,
      ));
    }
    return arrows;
  }

  Widget _buildCard(BuildContext context, WalkthroughCursor cursor) {
    final beat = cursor.beat;
    if (beat == null) return const SizedBox.shrink();

    final replies = cursor.forwardMoves;
    final stop = beat.stopIndex >= 0 ? _stops[beat.stopIndex] : null;

    // One composition, drawn twice. `line.parts` become the lines on the card
    // and `line.spoken` is those same words joined for the voice, so what is
    // read aloud is what is on screen by construction rather than by two
    // functions agreeing. Two registers, one shape: a move, or the tour coming
    // back to the fork it is about to branch from.
    final WalkthroughLine line;
    if (beat.returning) {
      line = walkthroughReturn(beat, replies: replies);
    } else {
      final comment = _comments?[fenKeyOf(stop!.move.fen)];
      line = walkthroughLine(stop!, replies: replies, note: comment?.body);
    }

    final parts = <Widget>[];
    for (var i = 0; i < line.parts.length; i++) {
      if (i > 0) parts.add(const SizedBox(height: AppSpacing.xs));
      parts.add(Text(
        line.parts[i],
        style: AppText.body.copyWith(
          color: i == 0
              ? context.colors.textPrimary
              : context.colors.textSecondary,
        ),
      ));
    }

    // The chips read the same list the sentence names, in the same order, so
    // the two cannot disagree about which reply comes first.
    final theirs = replies.where((move) => !move.mine).length;
    if (theirs > 1) {
      final branches = cursor.replyBranches;
      parts.add(const SizedBox(height: AppSpacing.sm));
      parts.add(Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: branches.asMap().entries.map((e) {
          return ActionChip(
            backgroundColor: context.colors.surfaceRaised,
            label: Text(e.value.label,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
            onPressed: () => cursor.takeBranch(e.key),
          );
        }).toList(),
      ));
    }

    if (!beat.returning &&
        stop!.kind == MoveTreeNodeLook.gap &&
        widget.onBuildHere != null) {
      parts.add(const SizedBox(height: AppSpacing.sm));
      parts.add(ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.brand,
          foregroundColor: context.colors.canvas,
        ),
        onPressed: () => widget.onBuildHere!(stop.move.fen),
        child: const Text('Napravi odgovor'),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
      ),
      // `autoSpeak` is the whole anti-fatigue design: a fork, a hole or a note
      // is worth interrupting the reader for and an ordinary move on the trunk
      // is not. Nothing here calls `stop()` — the reader ends a sentence by
      // moving, and on Windows a `stop()` before anything was said takes the
      // process with it.
      child: SpeakableInfo(
        text: line.spoken,
        autoSpeak: line.speak,
        // With the switch above off there is no speaker here at all. Two
        // speakers on one screen, one of which does nothing until the other is
        // on, is a press that produces silence and reads as a broken feature.
        hideButtonWhenOff: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: parts,
        ),
      ),
    );
  }
}
