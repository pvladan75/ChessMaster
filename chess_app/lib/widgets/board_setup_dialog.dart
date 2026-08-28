import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

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
    final colors = context.colors;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.dashboard_customize, color: colors.accent),
          const SizedBox(width: AppSpacing.sm),
          const Text('Postavi poziciju (Board Setup)', style: AppText.title),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Izaberite figuru i kliknite na polje da je postavite. '
                'Ponovni klik na istu figuru je uklanja, a dug pritisak '
                '(ili desni klik) prazni polje.',
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.canvas,
                  borderRadius: AppRadii.roundedSm,
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
                              color: isSel
                                  ? colors.accent.withValues(alpha: 0.30)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: chessPieceWidget(p, size: 26),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['k', 'q', 'r', 'b', 'n', 'p'].map((p) {
                        final isSel = selectedPiece == p;
                        return InkWell(
                          onTap: () => setState(() => selectedPiece = p),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? colors.accent.withValues(alpha: 0.30)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: chessPieceWidget(p, size: 26),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: () => setState(() => selectedPiece = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: selectedPiece == null
                              ? colors.danger
                              : colors.border,
                          borderRadius: AppRadii.roundedXs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cleaning_services,
                                size: 14,
                                color: selectedPiece == null
                                    ? colors.canvas
                                    : colors.textPrimary),
                            const SizedBox(width: AppSpacing.xs),
                            Text('Brisač (Ukloni figuru)',
                                style: AppText.caption.copyWith(
                                    color: selectedPiece == null
                                        ? colors.canvas
                                        : colors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: colors.textMuted)),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      int r = index ~/ 8;
                      int c = index % 8;
                      bool isLight = (r + c) % 2 == 0;
                      final p = grid[r][c];
                      return InkWell(
                        // Tapping a square that already holds the armed piece
                        // takes it off again, so correcting one square does not
                        // mean switching to the eraser and back. Long-press and
                        // right-click clear regardless of what is armed, which
                        // is the shortcut a mouse and a phone each expect.
                        onTap: () {
                          setState(() {
                            grid[r][c] = (p != null && p == selectedPiece)
                                ? null
                                : selectedPiece;
                          });
                        },
                        onLongPress: () {
                          setState(() => grid[r][c] = null);
                        },
                        onSecondaryTap: () {
                          setState(() => grid[r][c] = null);
                        },
                        child: Container(
                          color: isLight
                              ? const ui.Color(0xFFEEEED2)
                              : const ui.Color(0xFF769656),
                          child: Center(child: chessPieceWidget(p, size: 32)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Text('Na potezu: ', style: AppText.bodyBold),
                  ChoiceChip(
                    label: const Text('Beli (w)', style: AppText.caption),
                    selected: turn == 'w',
                    onSelected: (val) {
                      if (val) setState(() => turn = 'w');
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    label: const Text('Crni (b)', style: AppText.caption),
                    selected: turn == 'b',
                    onSelected: (val) {
                      if (val) setState(() => turn = 'b');
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Prava na rokadu:', style: AppText.bodyBold),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Beli O-O', style: AppText.micro),
                    selected: wk,
                    onSelected: (val) => setState(() => wk = val),
                  ),
                  FilterChip(
                    label: const Text('Beli O-O-O', style: AppText.micro),
                    selected: wq,
                    onSelected: (val) => setState(() => wq = val),
                  ),
                  FilterChip(
                    label: const Text('Crni O-O', style: AppText.micro),
                    selected: bk,
                    onSelected: (val) => setState(() => bk = val),
                  ),
                  FilterChip(
                    label: const Text('Crni O-O-O', style: AppText.micro),
                    selected: bq,
                    onSelected: (val) => setState(() => bq = val),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
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
                        wk = true;
                        wq = true;
                        bk = true;
                        bq = true;
                      });
                    },
                    icon: const Icon(Icons.restart_alt, size: 14),
                    label:
                        const Text('Početna pozicija', style: AppText.caption),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        grid = List.generate(8, (_) => List.filled(8, null));
                        wk = false;
                        wq = false;
                        bk = false;
                        bq = false;
                      });
                    },
                    icon: Icon(Icons.clear, size: 14, color: colors.danger),
                    label: Text('Očisti tablu',
                        style: AppText.caption.copyWith(color: colors.danger)),
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
