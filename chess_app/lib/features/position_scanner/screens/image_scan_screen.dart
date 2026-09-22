import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/fen_legality.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/image_scan.dart';
import '../services/scanner_api_service.dart';

/// Sets up one board while looking at its picture; the placement, or null if
/// the trainer backed out. A parameter so a test can stand in for the editor.
typedef PositionPicker = Future<String?> Function(
    BuildContext context, Uint8List picture, String initialPlacement);

/// The board editor, with the book's picture beside the board.
///
/// The editor closes itself after `onPositionSet`, as it does for every other
/// caller, so the callback only keeps the answer. Closing it here too was a
/// close too many: it took the calibration screen with it (the owner's live
/// pass of 22.9.2026).
Future<String?> pickPositionWithEditor(
    BuildContext context, Uint8List picture, String initialPlacement) async {
  String? placement;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AnalysisBoardSetupDialog(
      initialFen: '$initialPlacement w - - 0 1',
      referencePicture: picture,
      placementOnly: true,
      onPositionSet: (fen) => placement = fen.split(' ').first,
    ),
  );
  return placement;
}

/// How many boards the trainer sets up by hand before the rest are read.
const calibrationBoards = 3;

enum _Stage { working, calibrating, confirming, failed }

/// A book whose diagrams are pictures — phase 3 of `docs/PLAN-SKENER-SLIKE.md`.
///
/// The scanner reads a book with templates from a few of its own boards, so
/// the first time a book is opened the trainer sets up three of them, each
/// beside its picture. That calibration is remembered on the account, by the
/// SHA-256 of the file, and the next chapter goes straight to reading. Every
/// board read is then shown beside its picture: an uncertain square is marked
/// by shape — a dashed outline and a question mark — and nothing is saved
/// until the trainer has looked.
class ImageScanScreen extends StatefulWidget {
  const ImageScanScreen({
    super.key,
    required this.api,
    required this.filePath,
    required this.fileName,
    required this.fromPage,
    required this.toPage,
    this.pickPosition = pickPositionWithEditor,
  });

  final ScannerApiService api;
  final String filePath;
  final String fileName;
  final int fromPage;
  final int toPage;
  final PositionPicker pickPosition;

  @override
  State<ImageScanScreen> createState() => _ImageScanScreenState();
}

class _ImageScanScreenState extends State<ImageScanScreen> {
  _Stage _stage = _Stage.working;
  String _working = 'Looking for this book on your account…';
  String? _failure;

  String? _bookHash;
  List<FoundBoard> _found = const [];

  /// The boards chosen for calibrating, in order, and what the trainer set up
  /// on each (null until set).
  final List<BoardRef> _chosen = [];
  final Map<BoardRef, String> _placements = {};

  ImageScanResult? _result;
  List<CalibrationBoard> _calibration = const [];
  bool _onlyToCheck = false;
  bool _saving = false;

  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = AppFeedback.messengerOf(context);
  }

  @override
  void dispose() {
    AppFeedback.dismiss(_messenger);
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _failure = message;
    });
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.working;
      _working = 'Looking for this book on your account…';
    });
    final hash = await bookHashOf(widget.filePath);
    final load = await widget.api.loadCalibration(hash);
    if (!mounted) return;
    _bookHash = hash;
    if (load.error != null) {
      // "The server could not be asked" is not "this book has none": setting
      // up three boards that can never be remembered would be work for nothing.
      _fail(load.error!);
      return;
    }
    if (load.found) {
      await _read(load.boards);
    } else {
      await _findBoards();
    }
  }

  Future<void> _findBoards() async {
    setState(() {
      _stage = _Stage.working;
      _working = 'Finding the boards…';
    });
    final outcome = await widget.api.scanImages(
      filePath: widget.filePath,
      fileName: widget.fileName,
      fromPage: widget.fromPage,
      toPage: widget.toPage,
    );
    if (!mounted) return;
    final result = outcome.result;
    if (result == null) {
      _fail(outcome.error ?? 'Reading the pictures failed.');
      return;
    }
    setState(() {
      _found = result.boards;
      _chosen
        ..clear()
        ..addAll(result.suggested.take(calibrationBoards));
      _placements.clear();
      _stage = _Stage.calibrating;
    });
  }

  FoundBoard? _foundBoard(BoardRef ref) {
    for (final b in _found) {
      if (b.ref == ref) return b;
    }
    return null;
  }

  Future<void> _setUp(BoardRef ref) async {
    final board = _foundBoard(ref);
    if (board == null) return;
    final placement = await widget.pickPosition(
        context, board.preview, _placements[ref] ?? '8/8/8/8/8/8/8/8');
    if (placement == null || !mounted) return;
    setState(() => _placements[ref] = placement);
  }

  Future<void> _replace(BoardRef old) async {
    final picked = await showModalBottomSheet<BoardRef>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _BoardChooser(
        boards: _found.where((b) => !_chosen.contains(b.ref)).toList(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _chosen[_chosen.indexOf(old)] = picked;
      _placements.remove(old);
    });
  }

  bool get _calibrationReady =>
      _chosen.isNotEmpty && _chosen.every(_placements.containsKey);

  Future<void> _readWithChosen() async {
    final boards = [
      for (final ref in _chosen)
        CalibrationBoard(ref: ref, placement: _placements[ref]!),
    ];
    // Read first, remember after: the reading is what the trainer asked for,
    // and a calibration that could not be remembered only means setting it up
    // again next time — said, never allowed to stop the reading. Remembered
    // only once it has read: a calibration that fails would otherwise be
    // offered back on every visit, failing the same way each time.
    if (!await _read(boards)) return;
    final hash = _bookHash;
    if (hash == null) return;
    final error = await widget.api.saveCalibration(
        bookHash: hash, bookName: widget.fileName, boards: boards);
    if (error != null && mounted) {
      AppFeedback.warning(context, 'This book could not be remembered: $error');
    }
  }

  /// Whether the reading came back.
  Future<bool> _read(List<CalibrationBoard> calibration) async {
    setState(() {
      _stage = _Stage.working;
      _working = 'Reading the boards…';
      _calibration = calibration;
    });
    final outcome = await widget.api.scanImages(
      filePath: widget.filePath,
      fileName: widget.fileName,
      fromPage: widget.fromPage,
      toPage: widget.toPage,
      calibration: calibration,
    );
    if (!mounted) return false;
    final result = outcome.result;
    if (result == null) {
      _fail(outcome.error ?? 'Reading the pictures failed.');
      return false;
    }
    setState(() {
      _result = result;
      _onlyToCheck = false;
      _stage = _Stage.confirming;
    });
    return true;
  }

  /// Forget the book's calibration and set it up again.
  Future<void> _recalibrate() async {
    final hash = _bookHash;
    if (hash != null) await widget.api.deleteCalibration(hash);
    if (!mounted) return;
    await _findBoards();
  }

  Future<void> _fix(ReadBoard board) async {
    final placement =
        await widget.pickPosition(context, board.preview, board.placement);
    if (placement == null || !mounted) return;
    setState(() {
      board.placement = placement;
      // The trainer has looked at every square now; what they set is theirs.
      board.uncertain = [];
      board.legal = fenIllegalReason('$placement w - - 0 1') == null ||
          fenIllegalReason('$placement b - - 0 1') == null;
      board.accepted = board.legal;
    });
  }

  Future<void> _save() async {
    final chosen = _result!.positions.where((p) => p.accepted && p.legal);
    setState(() => _saving = true);
    final outcome = await widget.api.confirm(
      sourceTitle: widget.fileName,
      positions: chosen.map((p) => p.toScannedPosition()).toList(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!outcome.ok) {
      AppFeedback.error(context, outcome.error ?? 'Save failed.');
      return;
    }
    final router = GoRouter.maybeOf(context);
    AppFeedback.show(
      context,
      () => SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('In "Saved Positions": ${outcome.summary}.'),
        action: router == null
            ? null
            : SnackBarAction(
                label: 'View',
                onPressed: () => router.push(AppRoutes.savedPositions),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pictures · ${widget.fileName}',
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_stage == _Stage.confirming)
            TextButton(
              key: const ValueKey('image-scan-recalibrate'),
              onPressed: _recalibrate,
              child: const Text('Set up again'),
            ),
        ],
      ),
      body: SafeArea(child: _body()),
      bottomNavigationBar: _stage == _Stage.confirming ? _saveBar() : null,
    );
  }

  Widget _body() {
    final colors = context.colors;
    switch (_stage) {
      case _Stage.working:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(_working,
                  style: AppText.body.copyWith(color: colors.textSecondary)),
            ],
          ),
        );
      case _Stage.failed:
        return Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_failure ?? 'Reading the pictures failed.',
                    key: const ValueKey('image-scan-failure'),
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: colors.textPrimary)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                        onPressed: _start, child: const Text('Try again')),
                    // A remembered calibration that no longer reads would
                    // fail the same way on every try; this is the way out.
                    if (_calibration.isNotEmpty)
                      OutlinedButton(
                        key: const ValueKey('image-scan-failed-recalibrate'),
                        onPressed: _recalibrate,
                        child: const Text('Set up the boards again'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      case _Stage.calibrating:
        return _calibrating();
      case _Stage.confirming:
        return _confirming();
    }
  }

  Widget _calibrating() {
    final colors = context.colors;
    final toRead = _found.length - _chosen.length;
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Teach the scanner this book',
              style: AppText.headline.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Set up these ${_chosen.length} positions by hand, each beside its '
            'picture. The scanner learns from them how this book draws its '
            'pieces, and reads the other $toRead. Your account remembers them '
            'for this book; no picture from it is kept.',
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveCardRows(
            key: const ValueKey('calibration-boards'),
            children: [
              for (final ref in _chosen)
                _CalibrationCard(
                  key: ValueKey('calibrate-${ref.page}-${ref.index}'),
                  ref: ref,
                  picture: _foundBoard(ref)?.preview,
                  placement: _placements[ref],
                  onSetUp: () => _setUp(ref),
                  onReplace: _found.length > _chosen.length
                      ? () => _replace(ref)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('calibration-read'),
              onPressed: _calibrationReady ? _readWithChosen : null,
              child: Text('Read $toRead boards'),
            ),
          ),
          if (!_calibrationReady)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${_placements.length} of ${_chosen.length} set up',
                textAlign: TextAlign.right,
                style: AppText.caption.copyWith(color: colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  List<ReadBoard> get _visible {
    final all = _result?.positions ?? const <ReadBoard>[];
    return _onlyToCheck
        ? all.where((p) => p.uncertain.isNotEmpty || !p.legal).toList()
        : all;
  }

  String _composedWords(List<String> composed) {
    const names = {
      'P': 'white pawn',
      'N': 'white knight',
      'B': 'white bishop',
      'R': 'white rook',
      'Q': 'white queen',
      'K': 'white king',
      'p': 'black pawn',
      'n': 'black knight',
      'b': 'black bishop',
      'r': 'black rook',
      'q': 'black queen',
      'k': 'black king',
    };
    return composed.map((c) {
      final parts = c.split('/');
      return 'a ${names[parts.first] ?? parts.first} on a ${parts.last} square';
    }).join(', ');
  }

  Widget _confirming() {
    final colors = context.colors;
    final result = _result!;
    final toCheck =
        result.positions.where((p) => p.uncertain.isNotEmpty).length;
    final notPositions = result.positions.where((p) => !p.legal).length;
    final selected =
        result.positions.where((p) => p.accepted && p.legal).length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverList.list(
            children: [
              if (result.composed.isNotEmpty) ...[
                Container(
                  key: const ValueKey('image-scan-composed'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadii.roundedSm,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'No board you set up shows '
                          '${_composedWords(result.composed)}, so the scanner '
                          'is guessing how this book draws it. Setting up one '
                          'that does makes the guess a reading.',
                          style:
                              AppText.body.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                          onPressed: _recalibrate,
                          child: const Text('Set up again')),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${result.positions.length} boards, $selected selected',
                      style: AppText.body.copyWith(color: colors.textPrimary)),
                  if (toCheck > 0) Chip(label: Text('$toCheck to check')),
                  if (notPositions > 0)
                    Chip(label: Text('$notPositions not a position')),
                  FilterChip(
                    key: const ValueKey('image-scan-only-to-check'),
                    label: const Text('Only the ones to check'),
                    selected: _onlyToCheck,
                    onSelected: (v) => setState(() => _onlyToCheck = v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AdaptiveCardRows(
                key: const ValueKey('image-scan-boards'),
                children: [
                  for (final board in _visible)
                    _ReadBoardCard(
                      key:
                          ValueKey('read-${board.ref.page}-${board.ref.index}'),
                      board: board,
                      onToggle: board.legal
                          ? () =>
                              setState(() => board.accepted = !board.accepted)
                          : null,
                      onFlipSide: () => setState(board.flipSide),
                      onFix: () => _fix(board),
                    ),
                ],
              ),
              if (_calibration.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    'Read against ${_calibration.length} boards you set up: '
                    '${_calibration.map((c) => c.ref).join(', ')}.',
                    style:
                        AppText.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _saveBar() {
    final chosen =
        _result?.positions.where((p) => p.accepted && p.legal).length ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              key: const ValueKey('image-scan-save'),
              onPressed: _saving || chosen == 0 ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_alt),
              label: Text('Save ($chosen)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A picture and a board beside it, equal and square, sized from the width
/// the card is given.
class _PictureAndBoard extends StatelessWidget {
  const _PictureAndBoard({
    required this.picture,
    required this.board,
    required this.pictureKey,
  });

  final Uint8List? picture;
  final Widget Function(double side) board;
  final Key pictureKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(builder: (context, c) {
      final side = math.max(0.0, (c.maxWidth - AppSpacing.sm) / 2);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            key: pictureKey,
            dimension: side,
            child: picture == null
                ? ColoredBox(color: colors.surface)
                : Image.memory(picture!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    semanticLabel: 'The diagram in the book'),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox.square(dimension: side, child: board(side)),
        ],
      );
    });
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({
    super.key,
    required this.ref,
    required this.picture,
    required this.placement,
    required this.onSetUp,
    required this.onReplace,
  });

  final BoardRef ref;
  final Uint8List? picture;
  final String? placement;
  final VoidCallback onSetUp;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = placement != null;
    return Card(
      shape: AppRadii.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Page ${ref.page}, board ${ref.index}',
                      style:
                          AppText.body.copyWith(color: colors.textSecondary)),
                ),
                // Set up or not, told by the shape of the icon, not its colour.
                Icon(
                    done
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 20,
                    semanticLabel: done ? 'Set up' : 'Not set up yet',
                    color: colors.textPrimary),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _PictureAndBoard(
              pictureKey:
                  ValueKey('calibrate-picture-${ref.page}-${ref.index}'),
              picture: picture,
              board: (side) => done
                  ? BoardThumbnail(fen: '$placement w - - 0 1', size: side)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                          border: Border.all(color: colors.border)),
                      child: Center(
                        child: Text('Not set up',
                            style: AppText.caption
                                .copyWith(color: colors.textSecondary)),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.tonal(
                  key: ValueKey('calibrate-setup-${ref.page}-${ref.index}'),
                  onPressed: onSetUp,
                  child: Text(done ? 'Edit' : 'Set up this position'),
                ),
                if (onReplace != null)
                  TextButton(
                      onPressed: onReplace,
                      child: const Text('Choose a different board')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardChooser extends StatelessWidget {
  const _BoardChooser({required this.boards});

  final List<FoundBoard> boards;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose a board to set up',
                style: AppText.title.copyWith(color: colors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: GridView.extent(
                shrinkWrap: true,
                maxCrossAxisExtent: 140,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                children: [
                  for (final b in boards)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(b.ref),
                      child: Column(
                        children: [
                          Expanded(
                              child:
                                  Image.memory(b.preview, fit: BoxFit.contain)),
                          Text('p. ${b.ref.page} · ${b.ref.index}',
                              style: AppText.caption
                                  .copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A board as read, with every uncertain square outlined in a dashed line and
/// marked with a question mark — told by shape, never by colour alone.
class ReadBoardView extends StatelessWidget {
  const ReadBoardView({super.key, required this.board, required this.size});

  final ReadBoard board;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = size / 8;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          BoardThumbnail(fen: board.fen, size: size),
          for (final square in board.uncertain)
            Positioned(
              left: (square.codeUnitAt(0) - 97) * cell,
              top: (8 - int.parse(square.substring(1))) * cell,
              width: cell,
              height: cell,
              child: _UncertainMark(
                key: ValueKey(
                    'uncertain-${board.ref.page}-${board.ref.index}-$square'),
              ),
            ),
        ],
      ),
    );
  }
}

class _UncertainMark extends StatelessWidget {
  const _UncertainMark({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.textPrimary;
    return CustomPaint(
      painter: _DashedSquare(ink),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text('?',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: ink)),
        ),
      ),
    );
  }
}

class _DashedSquare extends CustomPainter {
  _DashedSquare(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    final r = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    void line(Offset a, Offset b) {
      final length = (b - a).distance;
      final dir = (b - a) / length;
      for (var d = 0.0; d < length; d += dash * 2) {
        canvas.drawLine(
            a + dir * d, a + dir * math.min(d + dash, length), paint);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedSquare old) => old.color != color;
}

class _ReadBoardCard extends StatelessWidget {
  const _ReadBoardCard({
    super.key,
    required this.board,
    required this.onToggle,
    required this.onFlipSide,
    required this.onFix,
  });

  final ReadBoard board;
  final VoidCallback? onToggle;
  final VoidCallback onFlipSide;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final white = board.sideToMove == 'w';
    final String status;
    if (!board.legal) {
      status = 'Not a position — fix it before saving';
    } else if (board.uncertain.isNotEmpty) {
      status = board.uncertain.length == 1
          ? '1 square to check'
          : '${board.uncertain.length} squares to check';
    } else {
      status = 'Looks right';
    }
    return Opacity(
      opacity: board.accepted || !board.legal ? 1 : 0.5,
      child: Card(
        shape: AppRadii.cardShape,
        child: InkWell(
          onTap: onFix,
          borderRadius: AppRadii.roundedLg,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          'Page ${board.ref.page}, board ${board.ref.index}',
                          style: AppText.body
                              .copyWith(color: colors.textSecondary)),
                    ),
                    // A board that is not a position cannot be saved, so it
                    // has no tick box to tick until it is fixed.
                    if (onToggle != null)
                      IconButton(
                        key: ValueKey(
                            'read-accept-${board.ref.page}-${board.ref.index}'),
                        onPressed: onToggle,
                        tooltip: board.accepted ? 'Leave out' : 'Keep',
                        icon: Icon(
                          board.accepted
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: colors.textPrimary,
                        ),
                      ),
                  ],
                ),
                _PictureAndBoard(
                  pictureKey: ValueKey(
                      'read-picture-${board.ref.page}-${board.ref.index}'),
                  picture: board.preview,
                  board: (side) => ReadBoardView(
                    key: ValueKey(
                        'read-board-${board.ref.page}-${board.ref.index}'),
                    board: board,
                    size: side,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (board.uncertain.isNotEmpty || !board.legal) ...[
                      Icon(Icons.help_outline,
                          size: 16, color: colors.textPrimary),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(status,
                          style:
                              AppText.body.copyWith(color: colors.textPrimary)),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onFlipSide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(white ? Icons.circle : Icons.circle_outlined,
                            size: 12, color: colors.textPrimary),
                        const SizedBox(width: 6),
                        Text(white ? 'White to move' : 'Black to move',
                            style: AppText.body
                                .copyWith(color: colors.textPrimary)),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(Icons.swap_horiz,
                            size: 14, color: colors.textMuted),
                      ],
                    ),
                  ),
                ),
                if (!board.sideTouched)
                  Text('The book does not say whose move — check',
                      style: AppText.caption
                          .copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
