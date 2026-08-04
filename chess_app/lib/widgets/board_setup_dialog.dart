import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class BoardSetupDialog extends StatefulWidget {
  final Function(String fen) onFenGenerated;

  const BoardSetupDialog({super.key, required this.onFenGenerated});

  @override
  State<BoardSetupDialog> createState() => _BoardSetupDialogState();
}

class _BoardSetupDialogState extends State<BoardSetupDialog> {
  List<List<String?>> grid = [
    ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'],
    ['p', 'p', 'p', 'p', 'p', 'p', 'p', 'p'],
    [null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null],
    ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P'],
    ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R'],
  ];

  String turn = 'w';
  bool wk = true, wq = true, bk = true, bq = true;
  String? selectedPiece = 'P';

  final Map<String, String> pieceIcons = {
    'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
    'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
  };

  String generateFen() {
    List<String> rankStrings = [];
    for (int r = 0; r < 8; r++) {
      int emptyCount = 0;
      String rankStr = '';
      for (int c = 0; c < 8; c++) {
        final p = grid[r][c];
        if (p == null || p.isEmpty) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rankStr += emptyCount.toString();
            emptyCount = 0;
          }
          rankStr += p;
        }
      }
      if (emptyCount > 0) rankStr += emptyCount.toString();
      rankStrings.add(rankStr);
    }
    final boardPart = rankStrings.join('/');
    String castling = '';
    if (wk) castling += 'K';
    if (wq) castling += 'Q';
    if (bk) castling += 'k';
    if (bq) castling += 'q';
    if (castling.isEmpty) castling = '-';
    return '$boardPart $turn $castling - 0 1';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.dashboard_customize, color: Colors.tealAccent),
          SizedBox(width: 8),
          Text('Postavi poziciju (Board Setup)', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Izaberite figuru i kliknite na polje tabele da je postavite:',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['K', 'Q', 'R', 'B', 'N', 'P'].map((p) {
                      final isSel = selectedPiece == p;
                      return InkWell(
                        onTap: () => setState(() => selectedPiece = p),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSel ? Colors.teal : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(pieceIcons[p]!, style: const TextStyle(fontSize: 22, color: Colors.white)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['k', 'q', 'r', 'b', 'n', 'p'].map((p) {
                      final isSel = selectedPiece == p;
                      return InkWell(
                        onTap: () => setState(() => selectedPiece = p),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSel ? Colors.teal : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(pieceIcons[p]!, style: const TextStyle(fontSize: 22, color: Colors.amberAccent)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setState(() => selectedPiece = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: selectedPiece == null ? Colors.redAccent : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.cleaning_services, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Brisač (Ukloni figuru)', style: TextStyle(fontSize: 11, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                  itemCount: 64,
                  itemBuilder: (context, index) {
                    int r = index ~/ 8;
                    int c = index % 8;
                    bool isLight = (r + c) % 2 == 0;
                    final p = grid[r][c];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          grid[r][c] = selectedPiece;
                        });
                      },
                      child: Container(
                        color: isLight ? const ui.Color(0xFFEEEED2) : const ui.Color(0xFF769656),
                        child: Center(
                          child: p != null
                              ? Text(
                                  pieceIcons[p] ?? p,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: 'KQRBNP'.contains(p) ? Colors.white : Colors.black,
                                    shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Na potezu: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ChoiceChip(
                  label: const Text('Beli (w)', style: TextStyle(fontSize: 11)),
                  selected: turn == 'w',
                  onSelected: (val) {
                    if (val) setState(() => turn = 'w');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Crni (b)', style: TextStyle(fontSize: 11)),
                  selected: turn == 'b',
                  onSelected: (val) {
                    if (val) setState(() => turn = 'b');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Prava na rokadu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Beli O-O', style: TextStyle(fontSize: 10)),
                  selected: wk,
                  onSelected: (val) => setState(() => wk = val),
                ),
                FilterChip(
                  label: const Text('Beli O-O-O', style: TextStyle(fontSize: 10)),
                  selected: wq,
                  onSelected: (val) => setState(() => wq = val),
                ),
                FilterChip(
                  label: const Text('Crni O-O', style: TextStyle(fontSize: 10)),
                  selected: bk,
                  onSelected: (val) => setState(() => bk = val),
                ),
                FilterChip(
                  label: const Text('Crni O-O-O', style: TextStyle(fontSize: 10)),
                  selected: bq,
                  onSelected: (val) => setState(() => bq = val),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      grid = [
                        ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'],
                        ['p', 'p', 'p', 'p', 'p', 'p', 'p', 'p'],
                        [null, null, null, null, null, null, null, null],
                        [null, null, null, null, null, null, null, null],
                        [null, null, null, null, null, null, null, null],
                        [null, null, null, null, null, null, null, null],
                        ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P'],
                        ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R'],
                      ];
                      turn = 'w';
                      wk = true; wq = true; bk = true; bq = true;
                    });
                  },
                  icon: const Icon(Icons.restart_alt, size: 14),
                  label: const Text('Početna pozicija', style: TextStyle(fontSize: 11)),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      grid = List.generate(8, (_) => List.filled(8, null));
                      wk = false; wq = false; bk = false; bq = false;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 14, color: Colors.redAccent),
                  label: const Text('Očisti tablu', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: () {
            final generatedFen = generateFen();
            Navigator.pop(context);
            widget.onFenGenerated(generatedFen);
          },
          child: const Text('Učitaj na tablu'),
        ),
      ],
    );
  }
}
