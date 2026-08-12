import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess/chess.dart' as chess;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';

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
  State<AnalysisBoardSetupDialog> createState() => _AnalysisBoardSetupDialogState();
}

class _AnalysisBoardSetupDialogState extends State<AnalysisBoardSetupDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: FEN Input
  late TextEditingController _fenTextController;
  bool _isFenValid = true;
  String _fenErrorMessage = '';

  // Tab 2: PGN Import
  final TextEditingController _pgnTextController = TextEditingController();
  bool _isPgnValid = true;

  // Tab 3: Manual Board Builder
  late List<List<String>> _builderBoard; // 8x8 grid
  PlayerColor _builderSideToMove = PlayerColor.white;
  bool _whiteCastleK = true;
  bool _whiteCastleQ = true;
  bool _blackCastleK = true;
  bool _blackCastleQ = true;
  String _selectedPalettePiece = 'P'; // Default White Pawn, 'CLEAR' for eraser

  // Tab 4: Opening Search
  final TextEditingController _openingSearchController = TextEditingController();
  List<OpeningBookEntry> _openingSearchResults = [];
  bool _openingBookLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fenTextController = TextEditingController(text: widget.initialFen);
    _validateFen(widget.initialFen);
    _initBuilderBoardFromFen(widget.initialFen);
    OpeningBookService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _openingBookLoading = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fenTextController.dispose();
    _pgnTextController.dispose();
    _openingSearchController.dispose();
    super.dispose();
  }

  void _onOpeningSearchChanged(String query) {
    setState(() {
      _openingSearchResults = OpeningBookService.instance.search(query);
    });
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
        _builderSideToMove = parts[1] == 'b' ? PlayerColor.black : PlayerColor.white;
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
    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        height: 580,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: Colors.tealAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Unos Pozicije (Board Setup)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.tealAccent,
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.edit_note, size: 18), text: 'FEN String'),
                Tab(icon: Icon(Icons.file_upload, size: 18), text: 'PGN Uvoz'),
                Tab(icon: Icon(Icons.grid_on, size: 18), text: 'Ručno Slaganje'),
                Tab(icon: Icon(Icons.travel_explore, size: 18), text: 'Otvaranja'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFenInputTab(),
                  _buildPgnImportTab(),
                  _buildManualBuilderTab(),
                  _buildOpeningSearchTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFenInputTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unesite važeći FEN string (Forsyth-Edwards Notation):',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fenTextController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black45,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            errorText: _isFenValid ? null : _fenErrorMessage,
          ),
          onChanged: _validateFen,
        ),
        const SizedBox(height: 12),
        Row(
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
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Početna Pozicija'),
              onPressed: () {
                const defaultFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
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
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Zalepite PGN tekst (Portable Game Notation) sa partijom ili varijantom:',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _pgnTextController,
            maxLines: 8,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black45,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: '1. e4 e5 2. Nf3 Nc6 3. Bb5 ...',
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.paste, size: 16),
              label: const Text('Zalepi PGN'),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data != null && data.text != null) {
                  _pgnTextController.text = data.text!.trim();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.file_open),
            label: const Text('Uvezi PGN Partiju'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
    final Map<String, String> pieceSymbols = {
      'P': '♙', 'N': '♘', 'B': '♗', 'R': '♖', 'Q': '♕', 'K': '♔',
      'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚',
      'CLEAR': '❌',
    };

    return Column(
      children: [
        // Palette Selection
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: pieceSymbols.entries.map((entry) {
              final isSelected = _selectedPalettePiece == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: ChoiceChip(
                  label: Text(entry.value, style: const TextStyle(fontSize: 18)),
                  selected: isSelected,
                  selectedColor: Colors.teal,
                  onSelected: (_) {
                    setState(() => _selectedPalettePiece = entry.key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              label: const Text('Obriši tablu 🗑️', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () {
                setState(() {
                  _initBuilderBoardFromFen('8/8/8/8/8/8/8/8 w - - 0 1');
                });
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16, color: Colors.tealAccent),
              label: const Text('Početna pozicija 🔄', style: TextStyle(fontSize: 11, color: Colors.tealAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.tealAccent),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () {
                setState(() {
                  _initBuilderBoardFromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
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
                border: Border.all(color: Colors.tealAccent, width: 2),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 64,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemBuilder: (context, index) {
                  final row = index ~/ 8;
                  final col = index % 8;
                  final isDarkSquare = (row + col) % 2 == 1;
                  final piece = _builderBoard[row][col];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedPalettePiece == 'CLEAR') {
                          _builderBoard[row][col] = '';
                        } else {
                          _builderBoard[row][col] = _selectedPalettePiece;
                        }
                      });
                    },
                    child: Container(
                      color: isDarkSquare ? Colors.teal.shade900 : Colors.teal.shade100,
                      child: Center(
                        child: Text(
                          pieceSymbols[piece] ?? '',
                          style: TextStyle(
                            fontSize: 22,
                            color: RegExp(r'[A-Z]').hasMatch(piece) ? Colors.white : Colors.black87,
                            shadows: const [Shadow(blurRadius: 1, color: Colors.black45)],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Controls: Side to move & Castling
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Na potezu: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DropdownButton<PlayerColor>(
                  value: _builderSideToMove,
                  dropdownColor: Colors.grey.shade900,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: PlayerColor.white, child: Text('⚪ Beli')),
                    DropdownMenuItem(value: PlayerColor.black, child: Text('⚫ Crni')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _builderSideToMove = val);
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Rokade: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                FilterChip(
                  label: const Text('K', style: TextStyle(fontSize: 10)),
                  selected: _whiteCastleK,
                  onSelected: (v) => setState(() => _whiteCastleK = v),
                ),
                FilterChip(
                  label: const Text('Q', style: TextStyle(fontSize: 10)),
                  selected: _whiteCastleQ,
                  onSelected: (v) => setState(() => _whiteCastleQ = v),
                ),
                FilterChip(
                  label: const Text('k', style: TextStyle(fontSize: 10)),
                  selected: _blackCastleK,
                  onSelected: (v) => setState(() => _blackCastleK = v),
                ),
                FilterChip(
                  label: const Text('q', style: TextStyle(fontSize: 10)),
                  selected: _blackCastleQ,
                  onSelected: (v) => setState(() => _blackCastleQ = v),
                ),
              ],
            ),
          ],
        ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Generiši i Postavi Poziciju'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pretražite otvaranja i varijante po imenu (npr. "Najdorf"):',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _openingSearchController,
          enabled: !_openingBookLoading,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black45,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: _openingBookLoading ? 'Učitavanje baze otvaranja...' : 'Naziv otvaranja ili varijante...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
          ),
          onChanged: _onOpeningSearchChanged,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _openingSearchResults.isEmpty
              ? Center(
                  child: Text(
                    _openingBookLoading
                        ? ''
                        : (_openingSearchController.text.trim().isEmpty
                            ? 'Ukucajte naziv otvaranja da vidite rezultate.'
                            : 'Nema rezultata.'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _openingSearchResults.length,
                  itemBuilder: (context, index) {
                    final entry = _openingSearchResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        entry.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${entry.eco} · ${entry.pgn}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        widget.onPgnLoaded?.call(entry.pgn);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
