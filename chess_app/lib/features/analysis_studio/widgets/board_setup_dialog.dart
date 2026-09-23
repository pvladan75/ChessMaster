import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess_app/services/fen_legality.dart';
import 'package:file_picker/file_picker.dart';
// `hide Color`: the chess package exports a `Color` of its own (the side to
// move), and it is not the one a border is painted in. Without this, every
// `Color` written out in this file is ambiguous.
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:chess_app/features/analysis_studio/widgets/opening_picker.dart';
import 'package:chess_app/move_tree.dart' show PgnGameInfo, MoveTree;
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';
import 'package:chess_app/features/analysis_studio/services/chess_platform_import_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// One way of naming a position, and the tab that offers it.
///
/// The labels are one word each, and that is a size decision as much as a
/// wording one. Measured: „FEN String", „PGN Import", „Piece Placement",
/// „Openings" and „Chess.com/Lichess" are **846dp of text and a 974dp strip**,
/// and the bar is 728 — **314 past the right edge, on every size including a
/// desktop**. So the strip scrolled sideways and „FEN String" read „N String"
/// on a phone held sideways. A tab a reader has to scroll to find is the same
/// fault as a palette piece past the edge, one row higher up.
///
/// These five are 495 and fit twice over.
///
/// Each one still says what it takes: a FEN, a PGN, pieces you place, an
/// opening by name, a game from an online account.
enum _SetupTab {
  fen(Icons.edit_note, 'FEN'),
  pgn(Icons.file_upload, 'PGN'),
  manual(Icons.grid_on, 'Pieces'),
  openings(Icons.travel_explore, 'Openings'),
  platform(Icons.cloud_download, 'Online');

  const _SetupTab(this.icon, this.label);

  final IconData icon;
  final String label;

  /// The icon is the part that gives way when the dialog is short.
  ///
  /// A tab drawn with an icon above its text is 72dp tall; with text alone, 46.
  /// A phone held sideways gives the whole dialog 398, so those 26 are a real
  /// share of what is left for the board.
  Tab tabWidget({required bool compact}) =>
      compact ? Tab(text: label) : Tab(icon: Icon(icon, size: 18), text: label);
}

class AnalysisBoardSetupDialog extends StatefulWidget {
  final String initialFen;
  final Function(String fen) onPositionSet;
  final Function(String pgn)? onPgnLoaded;

  /// A picture of the board being copied — a diagram from a book the image
  /// scanner is learning (docs/PLAN-SKENER-SLIKE.md, phase 3). Drawn only when
  /// given, beside the controls where there is room and above the palette
  /// where there is not, and the builder tab opens first: setting up a board
  /// from a picture means placing pieces while looking at it.
  final Uint8List? referencePicture;

  /// Only where the pieces stand is wanted — the image scanner's calibration
  /// and its „fix this board", which keep the placement and drop the rest.
  /// The builder then asks neither who is to move nor castling (the owner,
  /// 23.9.2026: „kako da znam ko je na potezu?" — he did not need to), and a
  /// board is accepted when it is a position with **either** side to move,
  /// the rule the scanner itself reads by: with the side hidden and left on
  /// White, a board with Black to move would be refused with no way to say so.
  final bool placementOnly;

  const AnalysisBoardSetupDialog({
    super.key,
    required this.initialFen,
    required this.onPositionSet,
    this.onPgnLoaded,
    this.referencePicture,
    this.placementOnly = false,
  });

  @override
  State<AnalysisBoardSetupDialog> createState() =>
      _AnalysisBoardSetupDialogState();
}

class _AnalysisBoardSetupDialogState extends State<AnalysisBoardSetupDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: FEN Input
  late TextEditingController _fenTextController;
  bool _isFenValid = true;
  String _fenErrorMessage = '';

  // Tab 2: the „PGN" tab
  final TextEditingController _pgnTextController = TextEditingController();
  final bool _isPgnValid = true;

  // Tab 3: Manual Board Builder
  late List<List<String>> _builderBoard; // 8x8 grid
  PlayerColor _builderSideToMove = PlayerColor.white;
  bool _whiteCastleK = true;
  bool _whiteCastleQ = true;
  bool _blackCastleK = true;
  bool _blackCastleQ = true;
  String _selectedPalettePiece = 'P'; // Default White Pawn, 'CLEAR' for eraser

  // Tab 5: the „Online" tab - a game from a Chess.com or Lichess account
  ChessPlatform _importPlatform = ChessPlatform.lichess;
  final TextEditingController _importUsernameController =
      TextEditingController();
  bool _importLoading = false;

  /// The tabs this dialog can actually deliver.
  ///
  /// Three of the five — „PGN", „Openings" and „Online" —
  /// hand their result over through [onPgnLoaded], and a caller that passes
  /// none gets tabs that close the dialog and drop what was asked for. The
  /// tutorial studio is exactly that caller, and deliberately so: importing a
  /// PGN into a tree is the Analysis Studio's job, and a second importer beside
  /// the first is how the two come to disagree. So a trainer picking "Najdorf"
  /// in the tutorial studio watched the window close and nothing happen.
  ///
  /// Same fault as the tree's context menu, which drew "Delete This Variation"
  /// for a screen that had wired nothing to it. The tabs are drawn where they
  /// work.
  late final List<_SetupTab> _tabs = [
    _SetupTab.fen,
    if (widget.onPgnLoaded != null) _SetupTab.pgn,
    _SetupTab.manual,
    if (widget.onPgnLoaded != null) ...[
      _SetupTab.openings,
      _SetupTab.platform,
    ],
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex:
          widget.referencePicture != null ? _tabs.indexOf(_SetupTab.manual) : 0,
    );
    _fenTextController = TextEditingController(text: widget.initialFen);
    _validateFen(widget.initialFen);
    _initBuilderBoardFromFen(widget.initialFen);
    // The ECO dataset is loaded by the picker that uses it, so it is not this
    // dialog's business any more.
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fenTextController.dispose();
    _pgnTextController.dispose();
    _importUsernameController.dispose();
    super.dispose();
  }

  /// Fetches the user's recent games from the selected platform and hands the
  /// PGN blob to [_loadPgnContent] — the same path a pasted or file-loaded PGN
  /// already goes through, including the multi-game picker. Landing on the PGN
  /// tab afterward lets the user review what was loaded before confirming with
  /// the existing "Uvezi PGN Partiju" button, rather than importing blind.
  Future<void> _fetchFromPlatform() async {
    final username = _importUsernameController.text.trim();
    if (username.isEmpty) {
      _showPgnFileError('Enter a username.');
      return;
    }
    setState(() => _importLoading = true);
    try {
      final pgn = await ChessPlatformImportService.instance
          .fetchRecentGames(_importPlatform, username);
      if (!mounted) return;
      // Waits for the multi-game picker (if it appears) to actually close
      // before switching tabs — otherwise the tab underneath flips to "PGN
      // Import" while the picker is still open, and the still-empty text box
      // is what greets the user once they pick a game and it closes.
      await _loadPgnContent(pgn);
      if (!mounted) return;
      // By name, not by number: the tabs are built from what the caller can
      // receive, so „the second one" is not always the PGN tab.
      _tabController.animateTo(_tabs.indexOf(_SetupTab.pgn));
    } on ChessImportException catch (e) {
      _showPgnFileError(e.message);
    } catch (e) {
      _showPgnFileError('Error fetching games: $e');
    } finally {
      if (mounted) setState(() => _importLoading = false);
    }
  }

  Future<void> _pickPgnFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pgn'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.single;
      String content;
      if (pickedFile.bytes != null) {
        content = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        content = await File(pickedFile.path!).readAsString();
      } else {
        _showPgnFileError('Cannot read file contents.');
        return;
      }

      _loadPgnContent(content);
    } catch (e) {
      _showPgnFileError('Error loading file: $e');
    }
  }

  /// A pasted or loaded PGN blob may contain more than one game (e.g. a
  /// lichess game-history export) — [MoveTree.splitGames] tells them apart
  /// by header blocks. A single game goes straight into the text box as
  /// before; more than one prompts the user to pick which one via the same
  /// [GameSelectorDialog] used for multi-game files elsewhere in the app.
  /// Awaits the picker dialog rather than firing it and moving on, so a
  /// caller that needs to act after the text is loaded (e.g. switching tabs
  /// once a platform-fetched game is chosen) doesn't race ahead of the user's
  /// selection — see `_fetchFromPlatform`.
  Future<void> _loadPgnContent(String content) async {
    final games = MoveTree.splitGames(content);
    if (games.length <= 1) {
      setState(() => _pgnTextController.text = content.trim());
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => GameSelectorDialog(
        games: games,
        onGameSelected: (game) {
          setState(() => _pgnTextController.text = _reconstructPgnText(game));
        },
      ),
    );
  }

  /// [PgnGameInfo] keeps headers and move text separate; PGN import here
  /// goes through `chess.Chess.load_pgn`, which reads player names/Elo/FEN
  /// etc. straight from `[Tag "value"]` header lines, so they need to be
  /// re-attached to the move text rather than passed as a bare movetext.
  String _reconstructPgnText(PgnGameInfo game) {
    final buffer = StringBuffer();
    for (final entry in game.headers.entries) {
      buffer.writeln('[${entry.key} "${entry.value}"]');
    }
    buffer.writeln();
    buffer.writeln(game.pgnBody);
    return buffer.toString();
  }

  void _showPgnFileError(String message) {
    if (!mounted) return;
    AppFeedback.show(
      context,
      () => SnackBar(
          content: Text(message), backgroundColor: context.colors.danger),
    );
  }

  void _validateFen(String fen) {
    // Ranije je ovde stajalo samo `chess.Chess.fromFEN` u try/catch, sto
    // proverava da li se zapis moze procitati — a ne da li je pozicija moguca.
    // Pozicija bez kralja se uredno procita, prodje kao ispravna, i srusi
    // aplikaciju kad je motor dobije. Nadjeno uzivo 30.8.2026.
    final razlog = fenIllegalReason(fen);
    setState(() {
      _isFenValid = razlog == null;
      _fenErrorMessage = razlog ?? '';
    });
  }

  void _initBuilderBoardFromFen(String fen) {
    _builderBoard = List.generate(8, (_) => List.generate(8, (_) => ''));
    try {
      final parts = fen.trim().split(' ');
      final rows = parts[0].split('/');
      for (int r = 0; r < 8 && r < rows.length; r++) {
        int c = 0;
        for (int i = 0; i < rows[r].length; i++) {
          final char = rows[r][i];
          if (RegExp(r'[1-8]').hasMatch(char)) {
            c += int.parse(char);
          } else {
            if (c < 8) {
              _builderBoard[r][c] = char;
              c++;
            }
          }
        }
      }
      if (parts.length > 1) {
        _builderSideToMove =
            parts[1] == 'b' ? PlayerColor.black : PlayerColor.white;
      }
      if (parts.length > 2) {
        final castling = parts[2];
        _whiteCastleK = castling.contains('K');
        _whiteCastleQ = castling.contains('Q');
        _blackCastleK = castling.contains('k');
        _blackCastleQ = castling.contains('q');
      }
    } catch (_) {}
  }

  String _generateFenFromBuilder() {
    final buffer = StringBuffer();
    for (int r = 0; r < 8; r++) {
      int emptyCount = 0;
      for (int c = 0; c < 8; c++) {
        final piece = _builderBoard[r][c];
        if (piece.isEmpty) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          buffer.write(piece);
        }
      }
      if (emptyCount > 0) buffer.write(emptyCount);
      if (r < 7) buffer.write('/');
    }

    buffer.write(_builderSideToMove == PlayerColor.white ? ' w ' : ' b ');

    String castling = '';
    if (_whiteCastleK) castling += 'K';
    if (_whiteCastleQ) castling += 'Q';
    if (_blackCastleK) castling += 'k';
    if (_blackCastleQ) castling += 'q';
    if (castling.isEmpty) castling = '-';

    buffer.write('$castling - 0 1');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 550x620 was hard-coded, and on a 360dp phone that is a size the screen
    // cannot give: everything inside laid out against a width that was not
    // there. In debug it striped; in release it would simply have been clipped,
    // which is how three of these were found by looking at a phone rather than
    // by any test. Desktop is unchanged - the min() only bites where it must.
    final screen = MediaQuery.sizeOf(context);
    // 900 was a desktop test, and it read a phone on its side as a phone: a
    // 932x430 screen took the 550 width, which left 518 for the contents —
    // just under the 620 at which the editor can put its controls beside the
    // board instead of under it. The room is there; the threshold was what
    // refused it.
    // Measured on the owner's phone, 19.9.2026: held sideways it reports
    // **667x300**, so a 700 threshold read it as a phone held upright and gave
    // it the 550 width — 518 for the contents, under the width at which the
    // board and its controls can sit side by side. The screen was wide enough
    // the whole time; the number was what refused it.
    final wide = screen.width >= 640;
    // 40dp a side is a desktop margin; on a phone it is a quarter of the
    // board. And where there is room the dialog is wider than the old 550, so
    // the manual builder fits without scrolling to reach its own button.
    final inset = wide ? 40.0 : AppSpacing.md;

    // Read from the screen, not from the dialog, because the dialog's own
    // height depends on it: a short screen also gets a smaller margin, and
    // deriving „short" from the height that margin decides is a circle.
    final compact = screen.height < 500;
    final verticalInset = compact ? AppSpacing.sm : AppSpacing.lg;
    final dialogHeight = math.min(720.0, screen.height - 2 * verticalInset);
    final scrollTabs = _tabs.length > 3 && !wide;

    return Dialog(
      shape: AppRadii.dialogShape,
      insetPadding:
          EdgeInsets.symmetric(horizontal: inset, vertical: verticalInset),
      child: Container(
        width: math.min(wide ? 760.0 : 550.0, screen.width - 2 * inset),
        height: dialogHeight,
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.lg),
        child: Column(
          children: [
            // On a short dialog the title and the tabs share one row.
            //
            // Asked for on 19.9.2026: „prostor iznad može da se smanji što je
            // moguće više". Stacked they are 48 + 12 + 46 = 106 of the 268 a
            // phone held sideways has; on one row they are 46, and the 60 goes
            // to the board. The title keeps its place rather than being
            // dropped: a dialog that does not say what it is is worse than a
            // smaller board.
            if (compact)
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    Icon(Icons.tune, color: colors.accent, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Board Setup',
                      style: AppText.body.copyWith(color: colors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _tabBar(colors, compact, scrollTabs)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, color: colors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // The title is the part that gives way: the icon and the
                  // close button have fixed sizes, a sentence does not.
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.tune, color: colors.accent, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Board Setup',
                            style: AppText.title
                                .copyWith(color: colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              _tabBar(colors, compact, scrollTabs),
            ],
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final tab in _tabs)
                    switch (tab) {
                      _SetupTab.fen => _buildFenInputTab(),
                      _SetupTab.pgn => _buildPgnImportTab(),
                      _SetupTab.manual => _buildManualBuilderTab(),
                      _SetupTab.openings => _buildOpeningSearchTab(),
                      _SetupTab.platform => _buildPlatformImportTab(),
                    },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Scrollable only where the labels cannot all be seen at once.
  ///
  /// Five of them need 443dp of tabs and a 360dp phone gives the strip 304, so
  /// upright they scroll — and that is the better of the two: a filled bar at
  /// 304 gives each tab 61 and every label is cut off mid-word, which cannot be
  /// read at all. Where they do fit the bar fills instead, and a caller with
  /// two tabs fits anywhere.
  ///
  /// A scrollable bar in Material 3 also pays a 52dp leading offset, and it
  /// lets a tab sit past the right edge, which is how „FEN String" came to read
  /// „N String" on a phone.
  Widget _tabBar(AppColorTokens colors, bool compact, bool scrollTabs) =>
      TabBar(
        controller: _tabController,
        isScrollable: scrollTabs,
        tabAlignment: scrollTabs ? TabAlignment.start : null,
        indicatorColor: colors.accent,
        labelColor: colors.accent,
        unselectedLabelColor: colors.textMuted,
        tabs: [for (final t in _tabs) t.tabWidget(compact: compact)],
      );

  /// A tab that fills its height where it fits and scrolls where it does not.
  ///
  /// The FEN, PGN and platform tabs pin their button to the bottom with a
  /// `Spacer` or an `Expanded`, which in a plain Column overflows as soon as
  /// the dialog is shorter than its contents — a phone on its side is 360 dp
  /// tall, and the column overflowed by 140. At least the tab's height and at
  /// most what the contents need, and one shape of tree either way, so a field
  /// being typed into is not rebuilt as the keyboard shrinks the dialog.
  Widget _fillOrScroll(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFenInputTab() {
    final colors = context.colors;

    return _fillOrScroll([
      Text(
        'Enter a valid FEN string (Forsyth-Edwards Notation):',
        style: AppText.bodyLarge.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _fenTextController,
        maxLines: 3,
        style: AppText.bodyLarge
            .copyWith(color: colors.textPrimary, fontFamily: 'monospace'),
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.canvas,
          border: OutlineInputBorder(borderRadius: AppRadii.roundedSm),
          errorText: _isFenValid ? null : _fenErrorMessage,
        ),
        onChanged: _validateFen,
      ),
      const SizedBox(height: AppSpacing.md),
      // Two buttons with long Serbian labels do not fit a phone side by
      // side; wrapped, the second drops to its own line instead of past the
      // edge.
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.paste, size: 16),
            label: const Text('Paste from Clipboard'),
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              if (data != null && data.text != null) {
                _fenTextController.text = data.text!.trim();
                _validateFen(data.text!.trim());
              }
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Starting Position'),
            onPressed: () {
              const defaultFen =
                  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
              _fenTextController.text = defaultFen;
              _validateFen(defaultFen);
            },
          ),
        ],
      ),
      const Spacer(),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Set FEN Position'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          onPressed: _isFenValid
              ? () {
                  widget.onPositionSet(_fenTextController.text.trim());
                  Navigator.pop(context);
                }
              : null,
        ),
      ),
    ]);
  }

  Widget _buildPgnImportTab() {
    final colors = context.colors;

    return _fillOrScroll([
      Text(
        'Paste PGN text (Portable Game Notation) with a game or variation:',
        style: AppText.bodyLarge.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
        child: TextField(
          controller: _pgnTextController,
          maxLines: 8,
          style: AppText.bodyLarge
              .copyWith(color: colors.textPrimary, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.canvas,
            border: OutlineInputBorder(borderRadius: AppRadii.roundedSm),
            hintText: '1. e4 e5 2. Nf3 Nc6 3. Bb5 ...',
            hintStyle: TextStyle(color: colors.textMuted),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.paste, size: 16),
            label: const Text('Paste PGN'),
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              if (data != null &&
                  data.text != null &&
                  data.text!.trim().isNotEmpty) {
                _loadPgnContent(data.text!);
              }
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Load .pgn file'),
            onPressed: _pickPgnFile,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.file_open),
          label: const Text('Import PGN Game'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          onPressed: () {
            final pgn = _pgnTextController.text.trim();
            if (pgn.isNotEmpty) {
              widget.onPgnLoaded?.call(pgn);
              Navigator.pop(context);
            }
          },
        ),
      ),
    ]);
  }

  /// White's six, then Black's six, in the same order on both rows.
  ///
  /// The eraser is deliberately not among them: it is an action, not a piece,
  /// and as a thirteenth chip it was the one item that pushed the row past
  /// every screen this app runs on.
  static const _whitePalette = ['P', 'N', 'B', 'R', 'Q', 'K'];
  static const _blackPalette = ['p', 'n', 'b', 'r', 'q', 'k'];

  /// A palette cell, and six of them plus their gaps: 6*38 + 5*4 = 248.
  ///
  /// That is the number the rest of this tab is built around. The narrowest
  /// phone still in use is 320dp, which leaves 264 inside the dialog's
  /// padding, so the row fits there without wrapping and without scrolling.
  static const _paletteCell = 38.0;

  /// The width the controls need beside the board before the split is worth
  /// making: the palette's 248, plus room for a castling chip to sit beside
  /// its neighbour rather than under it.
  static const _controlsWidth = 260.0;

  /// The content width at which the controls move from under the board to
  /// beside it. Below it they stack; above it the dialog is a row.
  ///
  /// 620 was a guess and it was 180 too high: the controls need 260 and a board
  /// needs 140 at the very least, which is 412 with the gap. The owner's phone
  /// held sideways gives 555, and at 620 it was still getting the stacked
  /// layout — a board sized from the height, which on that screen is 300.
  static const _sideBySideWidth = 440.0;

  Widget _buildManualBuilderTab() {
    final colors = context.colors;

    // The button that finishes the job is pinned, not scrolled to.
    //
    // It used to be the last child of a column that was taller than the tab on
    // every size measured — 918 on a 360dp phone, 1142 on a phone held
    // sideways. A scroll view found it, and so did any test asking whether it
    // existed, which is why this went unnoticed: the question worth asking is
    // where the button *is*, not whether it is there.
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= _sideBySideWidth;
      final short = constraints.maxHeight < 300;
      return Column(
        children: [
          Expanded(
            child: wide ? _builderSideBySide(colors) : _builderStacked(colors),
          ),
          SizedBox(height: short ? AppSpacing.xs : AppSpacing.sm),
          _builderConfirmButton(colors, compact: short),
        ],
      );
    });
  }

  /// Board on the left, everything that acts on it on the right.
  ///
  /// This is the shape a desktop and a phone held sideways now share, and it
  /// is what fixes both of the faults reported on 19.9.2026. The board is
  /// sized from **both** dimensions: sizing it from the width alone is what
  /// put a 724x724 board inside a 398-tall dialog on a 932x430 phone, and a
  /// column can never use the width a landscape screen has most of.
  Widget _builderSideBySide(AppColorTokens colors) {
    return LayoutBuilder(builder: (context, c) {
      final side = math.min(
        c.maxHeight,
        math.min(
          c.maxWidth * 0.6,
          math.max(140.0, c.maxWidth - _controlsWidth - AppSpacing.md),
        ),
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: side,
            height: side,
            child: _builderBoardGrid(colors),
          ),
          const SizedBox(width: AppSpacing.md),
          // The controls scroll *vertically* where they do not fit. That is
          // the whole difference from what was here before: a mouse wheel and
          // a thumb both scroll down, and neither scrolls a horizontal strip.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.referencePicture != null) ...[
                    _referencePicture(
                        math.min(220.0, c.maxWidth - side - AppSpacing.md)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _builderPalette(colors),
                  const SizedBox(height: AppSpacing.sm),
                  // The three buttons sit **below** the side to move and the
                  // castling rights, asked for on 19.9.2026. What a trainer
                  // does constantly is arm a piece and place it; „clear the
                  // whole board" is a thing they do once, and it had been
                  // sitting between the palette and everything else.
                  _builderPositionControls(colors),
                  const SizedBox(height: AppSpacing.sm),
                  _builderActions(colors, compact: false),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Palette, board, controls, in that order down the screen.
  ///
  /// The board takes what is left over where there is anything left over. On a
  /// tab too short for that the column scrolls and the board is sized from the
  /// height as well as the width — never from the width alone.
  Widget _builderStacked(AppColorTokens colors) {
    return LayoutBuilder(builder: (context, c) {
      // Both dimensions, because the controls below the board grow *sideways*
      // and pay for it in height: on a narrow tab the four castling rights
      // wrap onto a second and third line and take the board's space with
      // them. A height test alone let a 320dp phone through by sixteen pixels.
      final pictureSide = widget.referencePicture == null
          ? 0.0
          : math.min(150.0, c.maxWidth * 0.45);
      final tall = c.maxHeight >= 380 + pictureSide && c.maxWidth >= 300;
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.referencePicture != null) ...[
            Center(child: _referencePicture(pictureSide)),
            const SizedBox(height: AppSpacing.xs),
          ],
          _builderPalette(colors),
          const SizedBox(height: AppSpacing.xs),
          if (tall)
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _builderBoardGrid(colors),
              ),
            )
          else
            // The smaller of the two, which is what „fits on the screen"
            // means. A fraction of the height was tried first and cost
            // portrait a quarter of its board for nothing: on a phone held
            // upright the width is already the smaller number, and the column
            // below scrolls anyway.
            Center(
              child: SizedBox(
                width: math.min(c.maxWidth, c.maxHeight),
                height: math.min(c.maxWidth, c.maxHeight),
                child: _builderBoardGrid(colors),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          _builderPositionControls(colors),
          const SizedBox(height: AppSpacing.xs),
          _builderActions(colors, compact: c.maxWidth < 380),
        ],
      );
      return tall ? column : SingleChildScrollView(child: column);
    });
  }

  /// The picture being copied, square, never stretched out of shape.
  Widget _referencePicture(double side) => SizedBox.square(
        key: const ValueKey('setup-reference-picture'),
        dimension: side,
        child: Image.memory(
          widget.referencePicture!,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'The diagram in the book',
        ),
      );

  /// Two rows of six, White above Black, in the same order on both.
  ///
  /// The single row this replaces was 848dp wide on every screen, in a
  /// horizontal scroll view. The dialog gives it 728 on Windows, so the last
  /// 120 — Black's queen, Black's king and the eraser — sat past the right
  /// edge with no scrollbar and nothing a mouse wheel could do about it.
  /// Reported live on 19.9.2026: „ne može da dohvati do crne dame i crnog
  /// kralja".
  ///
  /// Two rows also say which piece is which without asking anyone to read a
  /// colour: the row is labelled, and a piece keeps its column between rows.
  Widget _builderPalette(AppColorTokens colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paletteLabel('White', colors),
        _paletteRow(_whitePalette, colors),
        const SizedBox(height: AppSpacing.xs),
        _paletteLabel('Black', colors),
        _paletteRow(_blackPalette, colors),
      ],
    );
  }

  Widget _paletteLabel(String text, AppColorTokens colors) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child:
            Text(text, style: AppText.micro.copyWith(color: colors.textMuted)),
      );

  /// A [Wrap] rather than a [Row]: 248 fits the 264 a 320dp phone leaves, but
  /// a row that is wider than its parent is clipped in a release build, and a
  /// wrap is merely two lines. Both rows hold the same six cells at the same
  /// size, so if one wraps the other wraps identically and the columns still
  /// line up.
  Widget _paletteRow(List<String> keys, AppColorTokens colors) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [for (final key in keys) _paletteButton(key, colors)],
      );

  Widget _paletteButton(String key, AppColorTokens colors) {
    final isSelected = _selectedPalettePiece == key;
    return InkWell(
      key: ValueKey('palette-$key'),
      borderRadius: AppRadii.roundedXs,
      onTap: () => setState(() => _selectedPalettePiece = key),
      child: Container(
        width: _paletteCell,
        height: _paletteCell,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // The piece stands on a light square, not on the dialog's own
          // surface. On a dark surface a black piece is a black shape on a
          // dark ground — „crne figure se skoro i ne vide od iste pozadine",
          // reported live on 8.9.2026 — and the fix has to be a difference in
          // *lightness*, because the reader of this app does not read hue.
          color: AppSettingsService.instance.boardSkin.lightSquare,
          borderRadius: AppRadii.roundedXs,
          // And the armed piece carries a thicker outline as well as a
          // brighter one, so „which one am I placing" survives without colour.
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: chessPieceWidget(key, size: 28),
      ),
    );
  }

  /// The eraser and the two whole-board actions.
  ///
  /// The eraser is a mode, so it is drawn as one: it stays lit while it is
  /// armed, the same way a palette cell does.
  Widget _builderActions(AppColorTokens colors, {required bool compact}) {
    void clear() => setState(() {
          _initBuilderBoardFromFen('8/8/8/8/8/8/8/8 w - - 0 1');
        });
    void reset() => setState(() {
          _initBuilderBoardFromFen(
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
        });

    final erase = _actionButton(
      icon: Icons.backspace_outlined,
      label: 'Erase',
      color: colors.accent,
      idle: colors.border,
      selected: _selectedPalettePiece == 'CLEAR',
      compact: compact,
      onPressed: () => setState(() => _selectedPalettePiece = 'CLEAR'),
      buttonKey: const ValueKey('palette-CLEAR'),
    );
    final clearBoard = _actionButton(
      icon: Icons.delete_outline,
      label: 'Clear board',
      color: colors.danger,
      idle: colors.danger,
      selected: false,
      compact: compact,
      onPressed: clear,
    );
    final startingPosition = _actionButton(
      icon: Icons.restart_alt,
      label: 'Starting position',
      color: colors.accent,
      idle: colors.accent,
      selected: false,
      compact: compact,
      onPressed: reset,
    );

    // Three icons in a row where there is no room for words, and otherwise the
    // shape asked for on 19.9.2026: the two that replace the whole board side
    // by side and as wide as they can be, the eraser under them. They are not
    // the same kind of thing — „Erase" arms the pointer and stays lit, the
    // other two happen once and are over — and a row of three equals said they
    // were.
    if (compact) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [erase, clearBoard, startingPosition],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: startingPosition),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: clearBoard),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        erase,
      ],
    );
  }

  /// The eraser and the two whole-board actions, labelled where there is room
  /// and drawn as their icon alone where there is not.
  ///
  /// Three labelled buttons need two lines on a 360dp phone, and those 52dp
  /// come straight off the board. The label survives as a tooltip, which is
  /// also what keeps it a string literal in `lib/` — the manual quotes these
  /// words, and `manual_labels_test` fails if they stop existing.
  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color idle,
    required bool selected,
    required bool compact,
    required VoidCallback onPressed,
    Key? buttonKey,
  }) {
    final style = OutlinedButton.styleFrom(
      side: BorderSide(color: selected ? color : idle, width: selected ? 2 : 1),
      padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : 10, vertical: AppSpacing.xs),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Tooltip(
      message: label,
      child: compact
          ? OutlinedButton(
              key: buttonKey,
              style: style,
              onPressed: onPressed,
              child: Icon(icon, size: 18, color: color),
            )
          : OutlinedButton.icon(
              key: buttonKey,
              icon: Icon(icon, size: 16, color: color),
              label: Text(label, style: AppText.caption.copyWith(color: color)),
              style: style,
              onPressed: onPressed,
            ),
    );
  }

  Widget _builderBoardGrid(AppColorTokens colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.accent, width: 2),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 64,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemBuilder: (context, index) {
          final row = index ~/ 8;
          final col = index % 8;
          final isDarkSquare = (row + col) % 2 == 1;
          final piece = _builderBoard[row][col];

          return InkWell(
            // Row 0 is the eighth rank, as it is in the FEN this writes.
            key: ValueKey('square-$row-$col'),
            // Same three ways to clear a square as the lesson room's setup
            // board: tap the armed piece again, long-press, or right-click.
            // Switching to the eraser and back to place one more piece is the
            // part that made this tedious.
            onTap: () {
              setState(() {
                if (_selectedPalettePiece == 'CLEAR' ||
                    (piece.isNotEmpty && piece == _selectedPalettePiece)) {
                  _builderBoard[row][col] = '';
                } else {
                  _builderBoard[row][col] = _selectedPalettePiece;
                }
              });
            },
            onLongPress: () {
              setState(() => _builderBoard[row][col] = '');
            },
            onSecondaryTap: () {
              setState(() => _builderBoard[row][col] = '');
            },
            child: Container(
              // A third board, until 29.8.2026: this editor was teal while the
              // thumbnails were green and every live board was brown. All
              // three now draw the reader's skin.
              color: isDarkSquare
                  ? AppSettingsService.instance.boardSkin.darkSquare
                  : AppSettingsService.instance.boardSkin.lightSquare,
              // As large as its square, as on the live board and the
              // thumbnails: a fixed 28 filled two fifths of a 68 px square
              // on a desktop dialog.
              child: LayoutBuilder(
                builder: (context, cell) => Center(
                  child: chessPieceWidget(
                    piece.isEmpty ? null : piece,
                    size: cell.biggest.shortestSide,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The four castling rights, in the order they are written in a FEN.
  ///
  /// `K`, `Q`, `k`, `q` is FEN's spelling, not a person's: the case of a letter
  /// is the only thing separating White's rights from Black's, and a chip
  /// reading „q" tells a trainer nothing about whose queenside it is. „White
  /// O-O" said it and cost the width; „W O-O" says it in a letter that is an
  /// initial rather than a case, beside an O-O that is already the notation,
  /// and the full name is a press away in the tooltip.
  static const _castlingRights = [
    ('W O-O', 'White kingside'),
    ('W O-O-O', 'White queenside'),
    ('B O-O', 'Black kingside'),
    ('B O-O-O', 'Black queenside'),
  ];

  /// The width at which the four fit on one line.
  ///
  /// Measured rather than guessed, because the first guess was 64 short and the
  /// gate caught it: „W O-O-O" is **70dp** of text at 10pt and a chip adds
  /// **20** of padding, so four of them and three gaps is **372**.
  ///
  /// It was 444 while the chips drew Material's tick, which is 18 of that
  /// overhead each — and 444 is more than a phone held sideways has, so the row
  /// the owner asked for could not have been built with it. The tick is not the
  /// only way to show a chip is on, and it is not the way the palette four
  /// inches above does it: **a brighter fill and a thicker border**, which is a
  /// difference in lightness and in shape and so survives a reader who does not
  /// read hue. One rule for „this is on", in one dialog.
  static const _castlingOneRowWidth = 380.0;

  /// Side to move, then the four castling rights in a grid of their own.
  ///
  /// They were one flat `Wrap` with the „To move" label and its dropdown, and
  /// a Wrap fills each line before starting the next — so „White O-O" ended up
  /// beside the dropdown, the next two shared a line, and the fourth sat alone.
  /// Reported live on 19.9.2026 with the picture: „ima mesta, samo ih
  /// rasporedi u dva reda". Their own rows, and `Expanded` rather than
  /// intrinsic widths, so the four are equal and the grid is a grid.
  Widget _builderPositionControls(AppColorTokens colors) {
    if (widget.placementOnly) {
      return Text(
        'Only where the pieces stand is kept here — who is to move is not '
        'needed.',
        style: AppText.caption.copyWith(color: colors.textMuted),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final oneRow = c.maxWidth >= _castlingOneRowWidth;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              Text('To move:',
                  style: AppText.body.copyWith(color: colors.textMuted)),
              DropdownButton<PlayerColor>(
                value: _builderSideToMove,
                dropdownColor: colors.surface,
                isDense: true,
                style: AppText.body.copyWith(color: colors.textPrimary),
                items: const [
                  DropdownMenuItem(
                      value: PlayerColor.white, child: Text('⚪ White')),
                  DropdownMenuItem(
                      value: PlayerColor.black, child: Text('⚫ Black')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _builderSideToMove = val);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // The heading goes where the four are stacked and the eye needs
          // telling what they are. On one row each chip already reads „W O-O",
          // and the 24dp the heading costs is 24 the column does not have: a
          // phone held sideways gives it 218 and it wants a little more.
          if (!oneRow) ...[
            Text('Castling:',
                style: AppText.body.copyWith(color: colors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (oneRow)
            Row(children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(child: _castlingChip(i, colors)),
              ],
            ])
          else
            Column(children: [
              Row(children: [
                Expanded(child: _castlingChip(0, colors)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: _castlingChip(1, colors)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(child: _castlingChip(2, colors)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: _castlingChip(3, colors)),
              ]),
            ]),
        ],
      );
    });
  }

  bool _castlingValue(int index) => switch (index) {
        0 => _whiteCastleK,
        1 => _whiteCastleQ,
        2 => _blackCastleK,
        _ => _blackCastleQ,
      };

  void _setCastling(int index, bool value) => setState(() => switch (index) {
        0 => _whiteCastleK = value,
        1 => _whiteCastleQ = value,
        2 => _blackCastleK = value,
        _ => _blackCastleQ = value,
      });

  Widget _castlingChip(int index, AppColorTokens colors) {
    final (label, full) = _castlingRights[index];
    final on = _castlingValue(index);
    return Tooltip(
      message: full,
      child: FilterChip(
        key: ValueKey('castling-$index'),
        label: Center(child: Text(label, style: AppText.micro)),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        showCheckmark: false,
        side: BorderSide(
          color: on ? colors.accent : colors.border,
          width: on ? 2 : 1,
        ),
        selected: on,
        onSelected: (v) => _setCastling(index, v),
      ),
    );
  }

  /// The button, and the reason it is off.
  ///
  /// **A position that is not chess must not leave this dialog.** The FEN tab
  /// has refused one since 30.8.2026, when a hand-made position with no king
  /// reached the engine and took the app down with it; the room's paste field
  /// and the tutorial importer refuse one too. The editor was the one door
  /// that did not, so the very fault the guard was written for could still be
  /// built by hand, one piece at a time — two white kings, ten pawns, a pawn
  /// on the first rank, a king already in check on the side not to move.
  ///
  /// [fenIllegalReason] is that rule and this asks it rather than repeating
  /// any part of it: a second opinion about what chess is would be a second
  /// answer the day one of them is corrected.
  ///
  /// The reason is shown, not hidden behind a disabled button: „you cannot do
  /// this" without „because there are two white kings" is what sends a trainer
  /// to count pieces.
  Widget _builderConfirmButton(AppColorTokens colors, {required bool compact}) {
    var fen = _generateFenFromBuilder();
    var illegal = fenIllegalReason(fen);
    if (widget.placementOnly) {
      // Either side to move, no castling: what the scanner keeps and reads by.
      final placement = fen.split(' ').first;
      final asWhite = '$placement w - - 0 1';
      final asBlack = '$placement b - - 0 1';
      final whiteReason = fenIllegalReason(asWhite);
      final blackReason = fenIllegalReason(asBlack);
      fen = whiteReason == null ? asWhite : asBlack;
      illegal = whiteReason == null || blackReason == null ? null : whiteReason;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (illegal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: colors.danger),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    illegal,
                    key: const ValueKey('builder-illegal'),
                    style: AppText.caption.copyWith(color: colors.danger),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Generate and Set Position'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: compact ? 4 : 10),
          ),
          onPressed: illegal != null
              ? null
              : () {
                  widget.onPositionSet(fen);
                  Navigator.pop(context);
                },
        ),
      ],
    );
  }

  Widget _buildOpeningSearchTab() {
    // The search itself now lives in [OpeningPicker], because the repertoire
    // screen needs exactly this and none of the four tabs around it. One
    // implementation, two doors.
    return OpeningPicker(
      hint: 'Search openings and variations by name (e.g. "Najdorf"):',
      onPicked: (entry) {
        widget.onPgnLoaded?.call(entry.pgn);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildPlatformImportTab() {
    final colors = context.colors;

    return _fillOrScroll([
      Text(
        'Enter a username to download recent games:',
        style: AppText.bodyLarge.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          ChoiceChip(
            label: const Text('Lichess'),
            selected: _importPlatform == ChessPlatform.lichess,
            selectedColor: colors.accent.withValues(alpha: 0.22),
            onSelected: _importLoading
                ? null
                : (_) =>
                    setState(() => _importPlatform = ChessPlatform.lichess),
          ),
          const SizedBox(width: AppSpacing.sm),
          ChoiceChip(
            label: const Text('Chess.com'),
            selected: _importPlatform == ChessPlatform.chessCom,
            selectedColor: colors.accent.withValues(alpha: 0.22),
            onSelected: _importLoading
                ? null
                : (_) =>
                    setState(() => _importPlatform = ChessPlatform.chessCom),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _importUsernameController,
        enabled: !_importLoading,
        style: AppText.bodyLarge.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.canvas,
          border: OutlineInputBorder(borderRadius: AppRadii.roundedSm),
          hintText: 'username',
          hintStyle: TextStyle(color: colors.textMuted),
          prefixIcon: Icon(Icons.person, color: colors.textMuted),
        ),
        onSubmitted: (_) => _fetchFromPlatform(),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Loads the last 20 games; if there are more, you choose which to import.',
        style: AppText.caption.copyWith(color: colors.textMuted),
      ),
      const Spacer(),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: _importLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textPrimary,
                  ),
                )
              : const Icon(Icons.cloud_download),
          label: Text(_importLoading ? 'Downloading...' : 'Download Games'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          onPressed: _importLoading ? null : _fetchFromPlatform,
        ),
      ),
    ]);
  }
}
