import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess/chess.dart' as chess;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_picker.dart';
import 'package:chess_app/move_tree.dart' show PgnGameInfo, MoveTree;
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';
import 'package:chess_app/features/analysis_studio/services/chess_platform_import_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class AnalysisBoardSetupDialog extends StatefulWidget {
  final String initialFen;
  final Function(String fen) onPositionSet;
  final Function(String pgn)? onPgnLoaded;

  const AnalysisBoardSetupDialog({
    super.key,
    required this.initialFen,
    required this.onPositionSet,
    this.onPgnLoaded,
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

  // Tab 2: PGN Import
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

  // Tab 5: Import from Chess.com / Lichess
  ChessPlatform _importPlatform = ChessPlatform.lichess;
  final TextEditingController _importUsernameController =
      TextEditingController();
  bool _importLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      _showPgnFileError('Unesite korisničko ime.');
      return;
    }
    setState(() => _importLoading = true);
    try {
      final pgn = await ChessPlatformImportService.instance
          .fetchRecentGames(_importPlatform, username);
      if (!mounted) return;
      // Waits for the multi-game picker (if it appears) to actually close
      // before switching tabs — otherwise the tab underneath flips to "PGN
      // Uvoz" while the picker is still open, and the still-empty text box
      // is what greets the user once they pick a game and it closes.
      await _loadPgnContent(pgn);
      if (!mounted) return;
      _tabController.animateTo(1);
    } on ChessImportException catch (e) {
      _showPgnFileError(e.message);
    } catch (e) {
      _showPgnFileError('Greška pri preuzimanju partija: $e');
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
        _showPgnFileError('Nemoguće pročitati sadržaj fajla.');
        return;
      }

      _loadPgnContent(content);
    } catch (e) {
      _showPgnFileError('Greška pri učitavanju fajla: $e');
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
    try {
      final game = chess.Chess.fromFEN(fen.trim());
      setState(() {
        _isFenValid = game.fen.isNotEmpty;
        _fenErrorMessage = '';
      });
    } catch (e) {
      setState(() {
        _isFenValid = false;
        _fenErrorMessage = 'Neispravan FEN format.';
      });
    }
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
    final wide = screen.width >= 900;
    // 40dp a side is a desktop margin; on a phone it is a quarter of the
    // board. And where there is room the dialog is wider than the old 550, so
    // the manual builder fits without scrolling to reach its own button.
    final inset = wide ? 40.0 : AppSpacing.md;

    return Dialog(
      shape: AppRadii.dialogShape,
      insetPadding:
          EdgeInsets.symmetric(horizontal: inset, vertical: AppSpacing.lg),
      child: Container(
        width: math.min(wide ? 760.0 : 550.0, screen.width - 2 * inset),
        height: math.min(720.0, screen.height - 2 * AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
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
                          'Unos Pozicije (Board Setup)',
                          style:
                              AppText.title.copyWith(color: colors.textPrimary),
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
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: colors.accent,
              labelColor: colors.accent,
              unselectedLabelColor: colors.textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.edit_note, size: 18), text: 'FEN String'),
                Tab(icon: Icon(Icons.file_upload, size: 18), text: 'PGN Uvoz'),
                Tab(
                    icon: Icon(Icons.grid_on, size: 18),
                    text: 'Ručno Slaganje'),
                Tab(
                    icon: Icon(Icons.travel_explore, size: 18),
                    text: 'Otvaranja'),
                Tab(
                    icon: Icon(Icons.cloud_download, size: 18),
                    text: 'Chess.com/Lichess'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFenInputTab(),
                  _buildPgnImportTab(),
                  _buildManualBuilderTab(),
                  _buildOpeningSearchTab(),
                  _buildPlatformImportTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFenInputTab() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unesite važeći FEN string (Forsyth-Edwards Notation):',
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
              label: const Text('Zalepi iz Klipborda'),
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
              label: const Text('Početna Pozicija'),
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
            label: const Text('Postavi FEN Poziciju'),
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
      ],
    );
  }

  Widget _buildPgnImportTab() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zalepite PGN tekst (Portable Game Notation) sa partijom ili varijantom:',
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
              label: const Text('Zalepi PGN'),
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
              label: const Text('Učitaj .pgn fajl'),
              onPressed: _pickPgnFile,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.file_open),
            label: const Text('Uvezi PGN Partiju'),
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
      ],
    );
  }

  Widget _buildManualBuilderTab() {
    final colors = context.colors;
    const paletteKeys = [
      'P',
      'N',
      'B',
      'R',
      'Q',
      'K',
      'p',
      'n',
      'b',
      'r',
      'q',
      'k',
      'CLEAR'
    ];

    return Column(
      children: [
        // Palette Selection
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: paletteKeys.map((key) {
              final isSelected = _selectedPalettePiece == key;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: ChoiceChip(
                  label: key == 'CLEAR'
                      ? Icon(Icons.close, size: 18, color: colors.danger)
                      : SizedBox(
                          width: 22,
                          height: 22,
                          child: chessPieceWidget(key, size: 22)),
                  selected: isSelected,
                  selectedColor: colors.accent.withValues(alpha: 0.22),
                  onSelected: (_) {
                    setState(() => _selectedPalettePiece = key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              icon: Icon(Icons.delete_outline, size: 16, color: colors.danger),
              label: Text('Obriši tablu 🗑️',
                  style: AppText.caption.copyWith(color: colors.danger)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.danger),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: AppSpacing.xs),
              ),
              onPressed: () {
                setState(() {
                  _initBuilderBoardFromFen('8/8/8/8/8/8/8/8 w - - 0 1');
                });
              },
            ),
            OutlinedButton.icon(
              icon: Icon(Icons.restart_alt, size: 16, color: colors.accent),
              label: Text('Početna pozicija 🔄',
                  style: AppText.caption.copyWith(color: colors.accent)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.accent),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: AppSpacing.xs),
              ),
              onPressed: () {
                setState(() {
                  _initBuilderBoardFromFen(
                      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 6),

        // 8x8 Board Representation
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.accent, width: 2),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 64,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8),
                itemBuilder: (context, index) {
                  final row = index ~/ 8;
                  final col = index % 8;
                  final isDarkSquare = (row + col) % 2 == 1;
                  final piece = _builderBoard[row][col];

                  return InkWell(
                    // Same three ways to clear a square as the lesson room's
                    // setup board: tap the armed piece again, long-press, or
                    // right-click. Switching to the eraser and back to place
                    // one more piece is the part that made this tedious.
                    onTap: () {
                      setState(() {
                        if (_selectedPalettePiece == 'CLEAR' ||
                            (piece.isNotEmpty &&
                                piece == _selectedPalettePiece)) {
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
                      // Domain constant: Board square colors preserved as chess literals
                      color: isDarkSquare
                          ? Colors.teal.shade900
                          : Colors.teal.shade100,
                      child: Center(
                          child: chessPieceWidget(piece.isEmpty ? null : piece,
                              size: 28)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Controls: Side to move & Castling.
        //
        // One flat Wrap, and every part of it can break: a Row here cost the
        // castling rights on a phone, overflowing by 168 pixels so that `Q`,
        // `k` and `q` sat past the right edge where nothing can be tapped.
        // Nesting Rows inside the Wrap only moved the problem - a Row is as
        // wide as its contents whatever it sits in, so the label and the
        // dropdown are children of the Wrap themselves.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text('Na potezu:',
                style: AppText.body.copyWith(color: colors.textMuted)),
            DropdownButton<PlayerColor>(
              value: _builderSideToMove,
              dropdownColor: colors.surface,
              isDense: true,
              style: AppText.body.copyWith(color: colors.textPrimary),
              items: const [
                DropdownMenuItem(
                    value: PlayerColor.white, child: Text('⚪ Beli')),
                DropdownMenuItem(
                    value: PlayerColor.black, child: Text('⚫ Crni')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _builderSideToMove = val);
              },
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Rokade:',
                style: AppText.body.copyWith(color: colors.textMuted)),
            FilterChip(
              label: const Text('K', style: AppText.micro),
              selected: _whiteCastleK,
              onSelected: (v) => setState(() => _whiteCastleK = v),
            ),
            FilterChip(
              label: const Text('Q', style: AppText.micro),
              selected: _whiteCastleQ,
              onSelected: (v) => setState(() => _whiteCastleQ = v),
            ),
            FilterChip(
              label: const Text('k', style: AppText.micro),
              selected: _blackCastleK,
              onSelected: (v) => setState(() => _blackCastleK = v),
            ),
            FilterChip(
              label: const Text('q', style: AppText.micro),
              selected: _blackCastleQ,
              onSelected: (v) => setState(() => _blackCastleQ = v),
            ),
          ],
        ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Generiši i Postavi Poziciju'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: () {
              final fen = _generateFenFromBuilder();
              widget.onPositionSet(fen);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOpeningSearchTab() {
    // The search itself now lives in [OpeningPicker], because the repertoire
    // screen needs exactly this and none of the four tabs around it. One
    // implementation, two doors.
    return OpeningPicker(
      hint: 'Pretražite otvaranja i varijante po imenu (npr. "Najdorf"):',
      onPicked: (entry) {
        widget.onPgnLoaded?.call(entry.pgn);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildPlatformImportTab() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unesite korisničko ime da preuzmete poslednje partije:',
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
            hintText: 'korisničko ime',
            hintStyle: TextStyle(color: colors.textMuted),
            prefixIcon: Icon(Icons.person, color: colors.textMuted),
          ),
          onSubmitted: (_) => _fetchFromPlatform(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Učitava poslednjih 20 partija; ako ih ima više, birate koju uvozite.',
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
            label: Text(_importLoading ? 'Preuzimanje...' : 'Preuzmi Partije'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            onPressed: _importLoading ? null : _fetchFromPlatform,
          ),
        ),
      ],
    );
  }
}
