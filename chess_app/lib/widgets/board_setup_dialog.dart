import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:chess_app/services/app_settings_service.dart';
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
    final screen = MediaQuery.sizeOf(context);

    // Two problems, one measurement, and they pull in opposite directions.
    //
    // 360 was a fixed width. On a 360dp phone the dialog's own inset (40 a
    // side) and content padding (24 a side) leave about 230, so a tight 360
    // overflowed by the difference and the rows inside it went off the edge.
    //
    // On Windows the opposite: palette, board and controls stacked into a
    // column taller than the screen, so "Učitaj na tablu" sat below the fold
    // and the whole thing had to be scrolled. Where there is room the three
    // parts now sit side by side and the height is the board's alone.
    //
    // The width stays *tight* rather than becoming a maximum. AlertDialog
    // wraps its content in an IntrinsicWidth, and a content that is not
    // width-tight sends that pass into the board's GridView, where
    // RenderShrinkWrappingViewport asserts — the trap dialog_layout_test.dart
    // was written for.
    final wide = screen.width >= 900;

    // A phone has the room; the default inset was spending it. 40dp a side is
    // a desktop margin, and on a 360dp screen it costs the board a quarter of
    // its width for nothing. 12 a side, and the grid gets 56 pixels back.
    final inset = wide ? 40.0 : AppSpacing.md;
    final room = math.max(240.0, screen.width - 2 * inset - 48);
    final width = math.min(wide ? 760.0 : 360.0, room);

    return AlertDialog(
      insetPadding:
          EdgeInsets.symmetric(horizontal: inset, vertical: AppSpacing.xl),
      title: Row(
        children: [
          Icon(Icons.dashboard_customize, color: colors.accent),
          const SizedBox(width: AppSpacing.sm),
          // The title gives way, not the icon: a sentence can be elided and a
          // 24dp icon cannot.
          const Flexible(
            child: Text(
              'Postavi poziciju (Board Setup)',
              style: AppText.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 420, child: _board(colors)),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _hint(colors),
                          const SizedBox(height: AppSpacing.sm),
                          _palette(colors),
                          const SizedBox(height: AppSpacing.md),
                          ..._controls(colors),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _hint(colors),
                    const SizedBox(height: AppSpacing.sm),
                    _palette(colors),
                    const SizedBox(height: AppSpacing.md),
                    _board(colors),
                    const SizedBox(height: AppSpacing.md),
                    ..._controls(colors),
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

  Widget _hint(AppColorTokens colors) => Text(
        'Izaberite figuru i kliknite na polje da je postavite. '
        'Ponovni klik na istu figuru je uklanja, a dug pritisak '
        '(ili desni klik) prazni polje.',
        style: AppText.caption.copyWith(color: colors.textMuted),
      );

  /// One row of pieces. A Wrap and not a Row: six of them at 26dp plus their
  /// padding need more than a 360dp phone leaves a dialog, and a Row put the
  /// last piece past the edge where it could not be tapped.
  Widget _pieceRow(AppColorTokens colors, List<String> pieces) => Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xxs,
        children: pieces.map((p) {
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
      );

  Widget _palette(AppColorTokens colors) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius: AppRadii.roundedSm,
        ),
        child: Column(
          children: [
            _pieceRow(colors, const ['K', 'Q', 'R', 'B', 'N', 'P']),
            const SizedBox(height: AppSpacing.xs),
            _pieceRow(colors, const ['k', 'q', 'r', 'b', 'n', 'p']),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: () => setState(() => selectedPiece = null),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: selectedPiece == null ? colors.danger : colors.border,
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
                    Flexible(
                      child: Text('Brisač (Ukloni figuru)',
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                              color: selectedPiece == null
                                  ? colors.canvas
                                  : colors.textPrimary)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _board(AppColorTokens colors) {
    // The editor and the board it edits should not be two different boards.
    final skin = AppSettingsService.instance.boardSkin;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: colors.textMuted)),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8),
          itemCount: 64,
          itemBuilder: (context, index) {
            int r = index ~/ 8;
            int c = index % 8;
            bool isLight = (r + c) % 2 == 0;
            final p = grid[r][c];
            return InkWell(
              // Tapping a square that already holds the armed piece takes it
              // off again, so correcting one square does not mean switching
              // to the eraser and back. Long-press and right-click clear
              // regardless of what is armed, which is the shortcut a mouse
              // and a phone each expect.
              onTap: () {
                setState(() {
                  grid[r][c] =
                      (p != null && p == selectedPiece) ? null : selectedPiece;
                });
              },
              onLongPress: () {
                setState(() => grid[r][c] = null);
              },
              onSecondaryTap: () {
                setState(() => grid[r][c] = null);
              },
              child: Container(
                color: isLight ? skin.lightSquare : skin.darkSquare,
                child: Center(child: chessPieceWidget(p, size: 32)),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Side to move, castling rights, and the two reset buttons.
  List<Widget> _controls(AppColorTokens colors) => [
        // Wrap rather than Row, for the same reason the castling
        // chips below already are: two chips and a label do not fit a
        // narrow phone, and a Row would push the second one off the edge
        // where it cannot be tapped.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            const Text('Na potezu: ', style: AppText.bodyBold),
            ChoiceChip(
              label: const Text('Beli (w)', style: AppText.caption),
              selected: turn == 'w',
              onSelected: (val) {
                if (val) setState(() => turn = 'w');
              },
            ),
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
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.sm,
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
              label: const Text('Početna pozicija', style: AppText.caption),
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
      ];
}
