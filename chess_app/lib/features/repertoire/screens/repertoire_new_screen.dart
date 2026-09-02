import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
// `hide Color`: the board package re-exports the chess package, whose `Color`
// is a piece colour, and it would otherwise shadow the paint one.
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_picker.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_gate_picker.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

const kStartFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Naming a repertoire, and saying where it starts — by playing the moves.
///
/// The first version of this asked for a FEN in a text field. That is a
/// programmer's way to name a position: nobody who teaches chess thinks in
/// placement strings, and the one person who tried it pasted half of one and
/// got a refusal that did not say which half was wrong. Here the opening is
/// played out on the board, the way it would be shown to a child, and the FEN
/// is something the screen works out for itself.
///
/// The colour and the position are one decision, not two: the button that
/// finishes the job is only alive while the side being prepared is the side to
/// move. That is why the old "you are building for White but Black is to move"
/// error no longer exists — the screen cannot produce the state that caused it.
class RepertoireNewScreen extends StatefulWidget {
  const RepertoireNewScreen({
    super.key,
    required this.api,
    this.startFen,
    this.nameFor,
    this.openingPicker,
  });

  final RepertoireApiService api;

  /// Where the board opens. Passed in when a repertoire is started from a
  /// position the reader is already looking at.
  final String? startFen;

  /// What this position is called, for the suggested name. The bundled ECO
  /// dataset by default.
  ///
  /// Injected in tests, and not out of habit: loading that dataset goes through
  /// `compute()`, and an isolate never completes inside `testWidgets` — the
  /// first test that awaited it hung until the whole run was killed at ten
  /// minutes. A screen that reaches for a singleton it cannot be given is a
  /// screen that cannot be tested at all.
  final String? Function(String fen)? nameFor;

  /// Stands in for the ECO search dialog, returning (name, pgn). Same reason as
  /// [nameFor]: the real one reads the dataset.
  final (String, String)? Function()? openingPicker;

  @override
  State<RepertoireNewScreen> createState() => _RepertoireNewScreenState();
}

class _RepertoireNewScreenState extends State<RepertoireNewScreen> {
  final ChessBoardController _boardController = ChessBoardController();
  final TextEditingController _name = TextEditingController();

  late String _root = widget.startFen ?? kStartFen;
  late chess.Chess _game = chess.Chess.fromFEN(_root);

  /// The moves played to get here, in the notation the reader recognises.
  final List<String> _line = [];

  String _color = 'w';
  bool _saving = false;
  String? _error;

  /// The opening the played line is standing in, or the last one it passed
  /// through. Kept rather than looked up fresh each time, because a repertoire
  /// usually walks *past* the last named position — four moves into the
  /// Smith-Morra the book has a name, six moves in it often does not, and
  /// "Smit-Mora" is still the right answer to "what is this".
  String? _opening;

  /// True once the reader has typed. From then on the suggestion stops
  /// overwriting what they wrote — a field that keeps correcting you is worse
  /// than one that never helped.
  bool _named = false;

  /// What this student already plays in the position on the board.
  ///
  /// Read because it decides whether the question below is worth asking at all:
  /// a starting position nobody has answered needs no gate, and one that
  /// already holds a first move is the case this whole feature is for — a
  /// second repertoire from the same board, meaning a different opening.
  List<RepertoireMove> _keptHere = const [];

  /// The move this repertoire will go through, chosen or not.
  ///
  /// Null means no gate: the whole graph from that root, which is what every
  /// repertoire did before and is still right when the position is empty.
  String? _gateUci;
  String? _gateSan;

  @override
  void initState() {
    super.initState();
    _boardController.loadFen(_root);
    // A position handed in decides the side as well: it is the one to move.
    _color = _game.turn == chess.Color.WHITE ? 'w' : 'b';
    if (widget.nameFor == null) {
      // The names come from the bundled ECO dataset, so this costs no request
      // and works with no token at all. It takes a second or two, and the field
      // fills itself in when it arrives.
      OpeningBookService.instance.ensureLoaded().then((_) {
        if (mounted) setState(_suggestName);
      });
    } else {
      _suggestName();
    }
    // What is already played in the position the screen opened on. A repertoire
    // started from a board the reader is already looking at usually lands here
    // with moves in it — that is the whole case for a gate.
    _readKeptHere();
  }

  /// Fills the name in from the opening, unless the reader has written their
  /// own. Pressing "Napravi" straight away is then a complete answer.
  void _suggestName() {
    final lookup = widget.nameFor ??
        (fen) => OpeningBookService.instance.lookupByFen(fen)?.name;
    final found = lookup(_game.fen);
    if (found != null) _opening = found;
    if (_named) return;
    final opening = _opening;
    _name.text =
        opening == null ? '' : '$opening — ${_color == 'w' ? 'beli' : 'crni'}';
  }

  /// Re-reads what is already played in the position on the board.
  ///
  /// After every move, because the question is about *this* position and a
  /// stale answer would offer a gate out of a board nobody is looking at. A
  /// chosen gate is dropped the moment the position changes under it, for the
  /// same reason.
  Future<void> _readKeptHere() async {
    final fen = _game.fen;
    final kept = await widget.api.movesAt(color: _color, fen: fen);
    // The board moved on while the answer was in flight. Its answer is about a
    // position that is no longer on screen, so it is dropped rather than drawn.
    if (!mounted || _game.fen != fen) return;
    setState(() {
      _keptHere = kept;
      if (_gateUci != null && !kept.any((move) => move.uci == _gateUci)) {
        // Only cleared when it is not one of the kept moves *and* the position
        // changed — a gate on a move nobody has kept yet is perfectly good, so
        // this runs on the position change and not on the list.
        _gateUci = null;
        _gateSan = null;
      }
    });
  }

  /// Asks which move this repertoire goes through.
  Future<void> _pickGate() async {
    final picked = await showGatePicker(
      context,
      rootFen: _game.fen,
      kept: _keptHere.map((move) => move.uci).toList(),
      current: _gateUci,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.isEmpty) {
        _gateUci = null;
        _gateSan = null;
        return;
      }
      _gateUci = picked;
      _gateSan = gateOptionsFor(_game.fen)
          .firstWhere((option) => option.uci == picked,
              orElse: () => GateOption(uci: picked, san: picked))
          .san;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _forWhite => _color == 'w';
  bool get _ourTurn => (_game.turn == chess.Color.WHITE ? 'w' : 'b') == _color;
  bool get _canSave => _whyNot == null && !_saving;

  /// Why "Napravi" is dead, or null when it is not.
  ///
  /// Every disabled button on this screen answers through here. A control that
  /// knows why it will not work and does not say is the same fault as an error
  /// message that lumps three causes into one sentence — it was on this very
  /// screen an hour ago, in the other direction: the position was fine, the
  /// name was empty, and nothing on screen said which.
  String? get _whyNot {
    if (_name.text.trim().isEmpty) return 'Upišite ime repertoara.';
    if (!_ourTurn) {
      return 'Na potezu je ${_forWhite ? "crni" : "beli"}. Odigrajte još jedan '
          'potez, ili promenite stranu.';
    }
    return null;
  }

  void _onMove(String from, String to, String promotion) {
    // Asked of the position, not of the destination rank: a piece other than a
    // pawn reaching the eighth is not a promotion, and a pawn capturing onto it
    // is one without ever standing there.
    final isPromotion = isPromotionMove(_game, from, to);
    final ok = _game.move({
      'from': from,
      'to': to,
      if (isPromotion) 'promotion': promotion.isEmpty ? 'q' : promotion,
    });
    if (ok == false) {
      _boardController.loadFen(_game.fen);
      return;
    }
    setState(() {
      _line.add(_game.getHistory().last.toString());
      _error = null;
      _gateUci = null;
      _gateSan = null;
      _suggestName();
    });
    _boardController.loadFen(_game.fen);
    _readKeptHere();
  }

  void _undo() {
    if (_line.isEmpty) return;
    _game.undo_move();
    setState(() {
      _line.removeLast();
      _error = null;
      _gateUci = null;
      _gateSan = null;
      _suggestName();
    });
    _boardController.loadFen(_game.fen);
    _readKeptHere();
  }

  void _reset() {
    setState(() {
      _game = chess.Chess.fromFEN(_root);
      _line.clear();
      _error = null;
      _gateUci = null;
      _gateSan = null;
      // Back to the start means back to not knowing what this is called.
      _opening = null;
      _suggestName();
    });
    _boardController.loadFen(_game.fen);
    _readKeptHere();
  }

  /// Choosing the opening by name, out of the same ECO search the analysis
  /// board already has.
  ///
  /// This is the short way to the same place: somebody who wants a Smith-Morra
  /// repertoire can name it instead of playing it out, and the line, the
  /// position and the suggested name all arrive together. Playing the moves is
  /// still there for a line the book has no name for.
  Future<void> _pickOpening() async {
    if (widget.openingPicker != null) {
      final picked = widget.openingPicker!();
      if (picked != null) _applyOpening(picked.$1, picked.$2);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 560,
          height: 460,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: OpeningPicker(
              hint: 'Izaberite otvaranje sa spiska, pa varijantu u njemu — '
                  'ili ukucajte naziv. Pozicija i ime dolaze s njim.',
              onPicked: (entry) {
                Navigator.of(ctx).pop();
                _applyOpening(entry.name, entry.pgn);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Replays the book line onto the board.
  ///
  /// A move the board refuses stops the replay rather than being skipped: half
  /// a line silently loaded is a position nobody asked for, wearing the name of
  /// one they did.
  void _applyOpening(String name, String pgn) {
    final board = chess.Chess.fromFEN(kStartFen);
    final played = <String>[];
    for (final token in pgn.split(RegExp(r'\s+'))) {
      final move = token.replaceAll(RegExp(r'^\d+\.+'), '').trim();
      if (move.isEmpty || move == '*') continue;
      if (board.move(move) == false) break;
      played.add(board.getHistory().last.toString());
    }

    setState(() {
      _root = kStartFen;
      _game = board;
      _line
        ..clear()
        ..addAll(played);
      _color = board.turn == chess.Color.WHITE ? 'w' : 'b';
      _opening = name;
      _error = null;
      _suggestName();
    });
    _boardController.loadFen(board.fen);
  }

  /// The way out for a position that is quicker to paste than to play — a study
  /// from a book, a position somebody sent. Kept small and off to the side,
  /// because it is the exception.
  Future<void> _pasteFen() async {
    // The controller belongs to the dialog, not to this method: disposing it
    // when `showDialog` returns kills it while the dialog is still animating
    // out, and the field rebuilds a frame later against a dead controller.
    final fen = await showDialog<String>(
      context: context,
      builder: (_) => _PasteFenDialog(initial: _game.fen),
    );
    if (fen == null || fen.isEmpty || !mounted) return;

    chess.Chess board;
    try {
      board = chess.Chess.fromFEN(fen);
    } catch (_) {
      setState(() => _error = 'Ta pozicija nije ispravna — proverite FEN.');
      return;
    }
    setState(() {
      _root = fen;
      _game = board;
      _line.clear();
      // The pasted position decides who is to move, so the side follows it
      // rather than arguing with it.
      _color = board.turn == chess.Color.WHITE ? 'w' : 'b';
      _error = null;
      _opening = null;
      _suggestName();
    });
    _boardController.loadFen(fen);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final made = await widget.api.create(
      name: _name.text.trim(),
      color: _color,
      rootFen: _game.fen,
      // Only from the real starting position. A repertoire begun from a pasted
      // FEN has moves in `_line` too, but they start from that FEN — writing
      // them down as the game's opening would put a breadcrumb on the screen
      // that names moves nobody played.
      rootPath: _root == kStartFen ? List<String>.from(_line) : const [],
      viaUci: _gateUci,
    );
    if (!mounted) return;

    if (made.made == null) {
      setState(() {
        _saving = false;
        // The server's own words, not a guess: a taken name, a stopped backend
        // and a refused position read differently and are fixed differently.
        _error = made.error ?? 'Nije sačuvano.';
      });
      return;
    }
    Navigator.of(context).pop(made.made);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Novi repertoar'),
        elevation: 0,
        actions: const [BoardCoordinatesButton()],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The board caps at 420, so the column caps with it: on a desktop
            // window an unconstrained Column drags the name field across the
            // whole screen, a metre away from the board it belongs to.
            final width =
                constraints.maxWidth < 560 ? constraints.maxWidth : 560.0;
            final boardSize = (width - 24).clamp(200.0, 420.0);
            return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                    child: SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        onChanged: (_) => setState(() => _named = true),
                        decoration: InputDecoration(
                          labelText: 'Ime',
                          hintText: 'npr. Smit-Mora — crni',
                          helperText: _named || _opening == null
                              ? null
                              : 'Predloženo iz baze otvaranja — možete ga '
                                  'izmeniti.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'w', label: Text('Beli')),
                            ButtonSegment(value: 'b', label: Text('Crni')),
                          ],
                          selected: {_color},
                          onSelectionChanged: (s) {
                            setState(() {
                              _color = s.first;
                              _gateUci = null;
                              _gateSan = null;
                              // The side is half of the suggested name.
                              _suggestName();
                            });
                            // What is already played here is a fact about a
                            // colour, so the other side has its own answer.
                            _readKeptHere();
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: BoardWithCoordinates(
                          size: boardSize,
                          orientation:
                              _forWhite ? PlayerColor.white : PlayerColor.black,
                          builder: (inner) => ChessBoardWithOverlay(
                            controller: _boardController,
                            boardOrientation: _forWhite
                                ? PlayerColor.white
                                : PlayerColor.black,
                            boardSize: inner,
                            isAllowedToMove: !_saving,
                            isDrawingMode: false,
                            drawingStartSquare: null,
                            arrows: const [],
                            engineArrows: const [],
                            onMove: _onMove,
                            onSquareTapForDrawing: (_) {},
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildLine(context),
                      const SizedBox(height: 6),
                      _buildStatus(context),
                      _buildGate(context),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!,
                            style: AppText.caption
                                .copyWith(color: context.colors.danger)),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _buildControls(context),
                    ],
                  ),
                )));
          },
        ),
      ),
    );
  }

  Widget _buildLine(BuildContext context) {
    if (_line.isEmpty) {
      return Text(
        'Odigrajte poteze do pozicije od koje krećete — obe strane, kao da '
        'pokazujete otvaranje.',
        style: AppText.caption.copyWith(color: context.colors.textMuted),
      );
    }
    final buffer = StringBuffer();
    for (var i = 0; i < _line.length; i++) {
      if (i.isEven) buffer.write('${(i ~/ 2) + 1}. ');
      buffer.write('${_line[i]} ');
    }
    return Text(buffer.toString().trim(),
        style: AppText.body.copyWith(color: context.colors.textPrimary));
  }

  /// The gate question, asked only where it means something.
  ///
  /// A position nobody has answered needs no gate and is not asked about — the
  /// row would be one more control to read on the way to a first repertoire.
  /// A position that already holds a move is the case this exists for: a second
  /// repertoire from the same board is a different opening, and without this
  /// the two would show each other's moves in every tree, queue and drill.
  Widget _buildGate(BuildContext context) {
    if (_keptHere.isEmpty) return const SizedBox.shrink();
    final already = _keptHere.map((move) => move.san).join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.roundedSm,
          border:
              Border.all(color: context.colors.info.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'U ovoj poziciji već igrate: $already.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _gateSan == null
                        ? 'Ovaj repertoar: bez ograničenja (ceo graf).'
                        : 'Ovaj repertoar ide kroz $_gateSan.',
                    style: AppText.body
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _pickGate,
                  icon: const Icon(Icons.alt_route, size: 18),
                  label: const Text('Izaberi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    // Two things have to be true before a repertoire can be made, so both are
    // on screen: whose turn it is, and what is still missing. The second line
    // is the button's own reason for being dead, printed where the reader is
    // already looking.
    final missing = _whyNot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _ourTurn
              ? 'Na potezu je ${_forWhite ? "beli" : "crni"} — vaša strana, pa '
                  'repertoar može da počne odavde.'
              : 'Na potezu je ${_forWhite ? "crni" : "beli"}. Odigrajte još '
                  'jedan potez, ili promenite stranu.',
          style: AppText.caption.copyWith(
            color: _ourTurn ? context.colors.success : context.colors.warning,
          ),
        ),
        if (missing != null && _ourTurn) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            missing,
            style: AppText.caption.copyWith(color: context.colors.warning),
          ),
        ],
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    // Wrap and not Row: four Serbian labels do not fit a 360 dp phone, and a
    // release build clips what does not fit without a word of warning.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _line.isEmpty || _saving ? null : _undo,
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('Nazad'),
        ),
        OutlinedButton.icon(
          onPressed: _line.isEmpty || _saving ? null : _reset,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Ispočetka'),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : _pickOpening,
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Izaberi otvaranje'),
        ),
        TextButton.icon(
          onPressed: _saving ? null : _pasteFen,
          icon: const Icon(Icons.content_paste, size: 18),
          label: const Text('Nalepi FEN'),
        ),
        FilledButton.icon(
          onPressed: _canSave ? _save : null,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Napravi'),
        ),
      ],
    );
  }
}

/// Pasting a position, with the controller living as long as the dialog.
class _PasteFenDialog extends StatefulWidget {
  const _PasteFenDialog({required this.initial});

  final String initial;

  @override
  State<_PasteFenDialog> createState() => _PasteFenDialogState();
}

class _PasteFenDialogState extends State<_PasteFenDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nalepi poziciju (FEN)'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          helperText: 'Ceo FEN, sa poljem koje kaže ko je na potezu.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Postavi'),
        ),
      ],
    );
  }
}
