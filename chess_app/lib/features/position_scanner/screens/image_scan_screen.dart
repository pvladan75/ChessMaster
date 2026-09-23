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

/// Pages the book browser asks for at a time. The server finds and draws a
/// page's boards in a fraction of a second (plan, 3e.0 (d)); twenty is a
/// window a trainer can look through, and well under its 40-page limit.
const browsePages = 20;

enum _Stage { working, calibrating, pages, confirming, failed }

/// Which boards the confirming screen shows. The counters above the boards
/// looked like filters and did nothing until 23.9.2026; now they are.
enum _Show { all, toCheck, notPosition, setUp }

/// A book whose diagrams are pictures — phase 3 of `docs/PLAN-SKENER-SLIKE.md`.
///
/// The scanner reads a book with templates from a few of its own boards, so
/// the first time a book is opened the trainer chooses boards from anywhere in
/// it and sets each up beside its picture, guided by a table of what the
/// scanner has still not seen (phase 3e). That calibration is remembered on
/// the account, by the SHA-256 of the file, as it is set up; once complete it
/// is skipped, and the trainer chooses the pages to read (phase 3f: the
/// calibration first, then the pages). Every
/// board read is then shown beside its picture: an uncertain square is marked
/// by shape — a dashed outline and a question mark — and nothing is saved
/// until the trainer has looked.
class ImageScanScreen extends StatefulWidget {
  const ImageScanScreen({
    super.key,
    required this.api,
    required this.filePath,
    required this.fileName,
    this.fromPage,
    this.toPage,
    this.pickPosition = pickPositionWithEditor,
  });

  final ScannerApiService api;
  final String filePath;
  final String fileName;

  /// The pages first offered for reading: the range a font scan found
  /// pictures on, or null when the book was known to be pictures the moment
  /// it was chosen (phase 3f) — the pages are then chosen after the
  /// calibration.
  final int? fromPage;
  final int? toPage;
  final PositionPicker pickPosition;

  @override
  State<ImageScanScreen> createState() => _ImageScanScreenState();
}

class _ImageScanScreenState extends State<ImageScanScreen> {
  _Stage _stage = _Stage.working;
  String _working = 'Looking for this book on your account…';
  String? _failure;

  String? _bookHash;

  /// The boards chosen for calibrating, in the order they were chosen, what
  /// the trainer set up on each, and each one's picture from the book.
  final List<BoardRef> _chosen = [];
  final Map<BoardRef, String> _placements = {};
  final Map<BoardRef, Uint8List> _pictures = {};

  /// Pieces the trainer says this book never draws: not asked for.
  final Set<String> _absent = {};

  /// Boards another user set up, offered but not yet checked here against
  /// their pictures (phase 3g). They count for nothing and are not remembered
  /// until they are: a board is never taken on someone else's word.
  final Set<BoardRef> _unconfirmed = {};

  /// The book's boards, by the first page of each browsed window, so turning
  /// back does not upload the book again — kept as the request itself, so two
  /// asking for one window at once share it.
  final Map<int, Future<({List<FoundBoard> boards, String? error})>> _browsed =
      {};
  int _pageCount = 0;

  ImageScanResult? _result;
  List<CalibrationBoard> _calibration = const [];
  _Show _show = _Show.all;
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

  late final _fromPage = TextEditingController(text: '${widget.fromPage ?? 1}');
  late final _toPage = TextEditingController(
      text: '${widget.toPage ?? (widget.fromPage ?? 1) + browsePages - 1}');
  String? _pagesProblem;

  @override
  void dispose() {
    AppFeedback.dismiss(_messenger);
    _fromPage.dispose();
    _toPage.dispose();
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
    _absent
      ..clear()
      ..addAll(load.absent);
    // A calibration is remembered as it is set up, so one left half-way comes
    // back to the table; one that shows every piece is skipped, and the
    // trainer chooses the pages to read (the owner, 23.9.2026: the
    // calibration first, then the pages).
    final ready = load.found &&
        load.boards.isNotEmpty &&
        CalibrationCoverage.of(load.boards.map((b) => b.placement),
                absent: _absent)
            .ready;
    if (ready) {
      _toPages(load.boards);
    } else {
      _calibrate(load.boards);
      // Another user's boards: the whole book as they set it up for a book new
      // to this account, and only what is missing for one half set up.
      _offerShared(onlyAdding: load.found);
    }
  }

  /// Offers the boards other users set up for this book (phase 3g), each to be
  /// checked against its picture. [onlyAdding] offers only boards that show
  /// something the calibration here does not.
  Future<void> _offerShared({required bool onlyAdding}) async {
    final hash = _bookHash;
    if (hash == null) return;
    final shared = await widget.api.loadSharedCalibration(hash);
    if (!mounted || !shared.found || _stage != _Stage.calibrating) return;
    final shown = <String>{
      for (final p in _setUpPlacements) ...pieceClassesOf(p)
    };
    setState(() {
      for (final b in shared.boards) {
        if (_chosen.contains(b.ref)) continue;
        if (_chosen.length >= maxCalibrationBoards) break;
        final classes = pieceClassesOf(b.placement);
        if (onlyAdding && classes.difference(shown).isEmpty) continue;
        _chosen.add(b.ref);
        _placements[b.ref] = b.placement;
        _unconfirmed.add(b.ref);
        shown.addAll(classes);
      }
      if (!onlyAdding && _absent.isEmpty) _absent.addAll(shared.absent);
    });
    _loadMissingPictures();
  }

  /// Another user's board, checked against its picture and found right.
  void _confirm(BoardRef ref) {
    setState(() => _unconfirmed.remove(ref));
    _remember();
  }

  /// The choice of pages, read against [calibration].
  void _toPages(List<CalibrationBoard> calibration) => setState(() {
        _calibration = calibration;
        _pagesProblem = null;
        _stage = _Stage.pages;
      });

  /// The pages asked for, or null with the reason said on the screen.
  ({int from, int to})? get _pagesAsked {
    final from = int.tryParse(_fromPage.text.trim());
    final to = int.tryParse(_toPage.text.trim());
    String? problem;
    if (from == null || to == null || from < 1) {
      problem = 'Give the first and the last page.';
    } else if (to < from) {
      problem = 'The last page is before the first.';
    } else if (to - from + 1 > 40) {
      problem = 'At most 40 pages at a time.';
    } else if (_pageCount > 0 && from > _pageCount) {
      problem = 'The book has $_pageCount pages.';
    }
    if (problem != null) {
      setState(() => _pagesProblem = problem);
      return null;
    }
    return (from: from!, to: to!);
  }

  Future<void> _readPages() async {
    final pages = _pagesAsked;
    if (pages == null) return;
    await _read(_calibration, from: pages.from, to: pages.to);
  }

  /// Opens the calibration with [boards] already set up — none for a new
  /// book, the remembered ones when improving it.
  void _calibrate(List<CalibrationBoard> boards) {
    setState(() {
      _chosen
        ..clear()
        ..addAll(boards.map((b) => b.ref));
      _placements
        ..clear()
        ..addEntries(boards.map((b) => MapEntry(b.ref, b.placement)));
      _unconfirmed.clear();
      for (final p in _result?.positions ?? const <ReadBoard>[]) {
        _pictures.putIfAbsent(p.ref, () => p.preview);
      }
      _stage = _Stage.calibrating;
    });
    _loadMissingPictures();
  }

  /// Boards remembered, or offered, from outside the pages just read have no
  /// picture yet: one request a window, however many of them it holds.
  void _loadMissingPictures() {
    for (final first in {
      for (final ref in _chosen)
        if (!_pictures.containsKey(ref)) _windowOf(ref.page)
    }) {
      _loadPage(first);
    }
  }

  int _windowOf(int page) => ((page - 1) ~/ browsePages) * browsePages + 1;

  /// The book's boards on the window of pages starting at [first]; an error
  /// sentence when the server could not say. A window that failed is asked
  /// again next time.
  Future<({List<FoundBoard> boards, String? error})> _loadWindow(int first) {
    final pending = _browsed[first] ??= _fetchWindow(first);
    pending.then((loaded) {
      if (loaded.error != null && identical(_browsed[first], pending)) {
        _browsed.remove(first);
      }
    });
    return pending;
  }

  Future<({List<FoundBoard> boards, String? error})> _fetchWindow(
      int first) async {
    final outcome = await widget.api.browseImages(
      filePath: widget.filePath,
      fileName: widget.fileName,
      fromPage: first,
      toPage: first + browsePages - 1,
    );
    final result = outcome.result;
    if (result == null) {
      // Pages with no picture on them are an empty window, not a failure.
      if (outcome.code == 'no_image_diagrams') {
        return (boards: const <FoundBoard>[], error: null);
      }
      return (
        boards: const <FoundBoard>[],
        error: outcome.error ?? 'The pages could not be loaded.'
      );
    }
    _pageCount = result.pageCount;
    return (boards: result.boards, error: null);
  }

  Future<void> _loadPage(int first) async {
    final loaded = await _loadWindow(first);
    if (!mounted) return;
    setState(() {
      for (final b in loaded.boards) {
        if (_chosen.contains(b.ref)) {
          _pictures.putIfAbsent(b.ref, () => b.preview);
        }
      }
    });
  }

  /// The trainer looks through the book, picks a board and sets it up; it
  /// joins the calibration only once it is set up.
  Future<void> _findInBook() async {
    final near = _chosen.isEmpty ? (widget.fromPage ?? 1) : _chosen.last.page;
    final picked = await showDialog<FoundBoard>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: BookBrowser(
          load: _loadWindow,
          pageCount: () => _pageCount,
          firstPage: _windowOf(near),
          taken: _chosen.toSet(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final placement =
        await widget.pickPosition(context, picked.preview, '8/8/8/8/8/8/8/8');
    if (placement == null || !mounted) return;
    setState(() {
      _pictures[picked.ref] = picked.preview;
      _placements[picked.ref] = placement;
      if (!_chosen.contains(picked.ref)) _chosen.add(picked.ref);
    });
    _remember();
  }

  Future<void> _setUp(BoardRef ref) async {
    final picture = _pictures[ref];
    if (picture == null) return;
    final placement = await widget.pickPosition(
        context, picture, _placements[ref] ?? '8/8/8/8/8/8/8/8');
    if (placement == null || !mounted) return;
    setState(() {
      _placements[ref] = placement;
      // Set up here, every square looked at: checked.
      _unconfirmed.remove(ref);
    });
    _remember();
  }

  void _remove(BoardRef ref) {
    setState(() {
      _chosen.remove(ref);
      _placements.remove(ref);
      _unconfirmed.remove(ref);
    });
    _remember();
  }

  void _setAbsent(String piece, bool absent) {
    setState(() => absent ? _absent.add(piece) : _absent.remove(piece));
    _remember();
  }

  /// The last save asked for, so saves go out one after another and the
  /// account ends with the latest.
  Future<void> _remembering = Future<void>.value();

  /// Remembers the calibration as it stands, after every board set up,
  /// changed or removed (the owner, 23.9.2026: a calibration set up and not
  /// yet read was lost when the reading was refused). Setting up boards is the
  /// trainer's work; it is kept the moment it is done, and said when it
  /// cannot be.
  void _remember() {
    final hash = _bookHash;
    if (hash == null) return;
    final boards = [
      for (final ref in _chosen)
        if (!_unconfirmed.contains(ref))
          if (_placements[ref] case final p?)
            CalibrationBoard(ref: ref, placement: p)
    ];
    final absent = _absent.toList()..sort();
    _remembering = _remembering.then((_) async {
      final error = boards.isEmpty
          ? (await widget.api.deleteCalibration(hash)
              ? null
              : 'Could not reach the server.')
          : await widget.api.saveCalibration(
              bookHash: hash,
              bookName: widget.fileName,
              boards: boards,
              absent: absent);
      if (error != null && mounted) {
        AppFeedback.warning(
            context, 'The calibration could not be remembered: $error');
      }
    });
  }

  /// The placements that count: set up or checked here.
  List<String> get _setUpPlacements => [
        for (final ref in _chosen)
          if (!_unconfirmed.contains(ref))
            if (_placements[ref] case final p?) p
      ];

  CalibrationCoverage get _coverage =>
      CalibrationCoverage.of(_setUpPlacements, absent: _absent);

  bool get _calibrationReady =>
      _chosen.isNotEmpty &&
      _chosen.length <= maxCalibrationBoards &&
      _chosen.every(_placements.containsKey) &&
      _unconfirmed.isEmpty &&
      _coverage.ready;

  /// The calibration is done: on to the pages. It was remembered as it was
  /// set up (_remember); it used to be remembered only after a reading came
  /// back, so a reading refused — by the scan limit, on 23.9.2026 — lost
  /// every board.
  void _calibrationDone() => _toPages([
        for (final ref in _chosen)
          CalibrationBoard(ref: ref, placement: _placements[ref]!),
      ]);

  /// Whether the reading came back.
  Future<bool> _read(List<CalibrationBoard> calibration,
      {required int from, required int to}) async {
    setState(() {
      _stage = _Stage.working;
      _working = 'Reading the boards…';
      _calibration = calibration;
    });
    final outcome = await widget.api.scanImages(
      filePath: widget.filePath,
      fileName: widget.fileName,
      fromPage: from,
      toPage: to,
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
      _show = _Show.all;
      _stage = _Stage.confirming;
    });
    return true;
  }

  /// Back to the calibration with its boards, to add what it lacks — and
  /// what other users set up that it lacks.
  void _improve() {
    _calibrate(_calibration);
    _offerShared(onlyAdding: true);
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
      board.fixedByHand = true;
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
    if (!outcome.ok) {
      setState(() => _saving = false);
      AppFeedback.error(context, outcome.error ?? 'Save failed.');
      return;
    }

    // Boards set up by hand that show what the calibration had to guess join
    // it, so the next reading of this book reads them. Done, then said.
    var grown = '';
    final hash = _bookHash;
    final growth = calibrationGrownBy(
        current: _calibration, saved: chosen, composed: _result!.composed);
    if (hash != null && growth.added.isNotEmpty) {
      final error = await widget.api.saveCalibration(
          bookHash: hash, bookName: widget.fileName, boards: growth.boards);
      if (!mounted) return;
      String where(List<CalibrationBoard> bs) =>
          bs.map((b) => 'page ${b.ref.page}, board ${b.ref.index}').join('; ');
      if (error == null) {
        _calibration = growth.boards;
        grown = ' The calibration now includes ${where(growth.added)}'
            '${growth.removed.isEmpty ? '' : ' in place of ${where(growth.removed)}, which showed nothing the others do not'}'
            ', so this book is read better next time.';
      } else {
        grown = ' The calibration could not be updated: $error';
      }
    }
    setState(() => _saving = false);

    final router = GoRouter.maybeOf(context);
    AppFeedback.show(
      context,
      () => SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('In "Saved Positions": ${outcome.summary}.$grown'),
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
              onPressed: _improve,
              child: const Text('Improve the calibration'),
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
                    // A calibration that does not read would fail the same
                    // way on every try; this is the way back to its table,
                    // where a board can be changed or removed. Nothing is
                    // forgotten on the way.
                    if (_calibration.isNotEmpty)
                      OutlinedButton(
                        key: const ValueKey('image-scan-failed-recalibrate'),
                        onPressed: _improve,
                        child: const Text('Back to the calibration'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      case _Stage.calibrating:
        return _calibrating();
      case _Stage.pages:
        return _pages();
      case _Stage.confirming:
        return _confirming();
    }
  }

  Widget _calibrating() {
    final colors = context.colors;
    final coverage = _coverage;
    final raw = CalibrationCoverage.of(_setUpPlacements);
    final String status;
    if (_unconfirmed.isNotEmpty) {
      status =
          'Another user set up ${_unconfirmed.length == 1 ? 'a board' : '${_unconfirmed.length} boards'} '
          'of this book. Check each against its picture: Correct, Edit or '
          'Remove.';
    } else if (_chosen.isEmpty) {
      status = 'Find a board in the book with many pieces on it to start.';
    } else if (_chosen.length > maxCalibrationBoards) {
      status = 'At most $maxCalibrationBoards boards: remove one that adds '
          'nothing.';
    } else if (!coverage.ready) {
      status = 'Still needed before reading: ${coverage.stillNeeded}.';
    } else if (coverage.guessedClasses.isNotEmpty) {
      status = 'Ready. Still guessed, and marked wherever read: '
          '${coverage.stillNeeded}.';
    } else {
      status = 'Ready: every piece is shown on both colours of square.';
    }
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Teach the scanner this book',
              style: AppText.headline.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose boards from anywhere in the book and set each one up '
            'beside its picture. The scanner learns from them how this book '
            'draws each piece, on a light and on a dark square; the grid '
            'shows what it has still not seen. Your account remembers each '
            'board as you set it up; no picture from the book is kept.',
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          CoverageTable(coverage: coverage),
          const SizedBox(height: AppSpacing.sm),
          Text(status,
              key: const ValueKey('calibration-status'),
              style: AppText.body.copyWith(color: colors.textPrimary)),
          // „This book has none" once there is a board to go on — on an empty
          // table every piece is missing and the chips say nothing. Not capped
          // by how many are missing: a book of rook endings has no queens,
          // bishops or knights, six pieces (the owner, 23.9.2026).
          if (_chosen.isNotEmpty && raw.unknownPieces.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final p in raw.unknownPieces)
                  FilterChip(
                    key: ValueKey('calibration-absent-$p'),
                    label: Text('No ${pieceName(p)} in this book'),
                    selected: _absent.contains(p),
                    onSelected: (on) => _setAbsent(p, on),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('calibration-find'),
              onPressed: _findInBook,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Find a board in the book'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveCardRows(
            key: const ValueKey('calibration-boards'),
            children: [
              for (final ref in _chosen)
                _CalibrationCard(
                  key: ValueKey('calibrate-${ref.page}-${ref.index}'),
                  ref: ref,
                  picture: _pictures[ref],
                  placement: _placements[ref],
                  adds: _placements[ref] == null
                      ? const {}
                      : classesAddedBy(_placements[ref]!, [
                          for (final o in _chosen)
                            if (o != ref && _placements[o] != null)
                              _placements[o]!
                        ]),
                  alone: _chosen.length == 1,
                  unconfirmed: _unconfirmed.contains(ref),
                  onConfirm: () => _confirm(ref),
                  onSetUp: () => _setUp(ref),
                  onRemove: () => _remove(ref),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('calibration-done'),
              onPressed: _calibrationReady ? _calibrationDone : null,
              child: const Text('Done — choose pages'),
            ),
          ),
        ],
      ),
    );
  }

  /// The pages to read, once the calibration is done or was found complete —
  /// with the way back to it, since a calibration is never final.
  Widget _pages() {
    final colors = context.colors;
    Widget field(String label, TextEditingController controller, Key key) =>
        SizedBox(
          width: 120,
          child: TextField(
            key: key,
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: label,
                isDense: true,
                border: const OutlineInputBorder()),
            onSubmitted: (_) => _readPages(),
          ),
        );
    final problem = _pagesProblem;
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose the pages to read',
              style: AppText.headline.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This book is read against ${_calibration.length} '
            '${_calibration.length == 1 ? 'board' : 'boards'} you set up'
            '${_pageCount > 0 ? '; it has $_pageCount pages' : ''}. At most '
            '40 pages at a time.',
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              field('From page', _fromPage, const ValueKey('pages-from')),
              field('To page', _toPage, const ValueKey('pages-to')),
              FilledButton.icon(
                key: const ValueKey('pages-read'),
                onPressed: _readPages,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Read'),
              ),
            ],
          ),
          if (problem != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: colors.textPrimary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(problem,
                      key: const ValueKey('pages-problem'),
                      style: AppText.body.copyWith(color: colors.textPrimary)),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const ValueKey('pages-update-calibration'),
            onPressed: _improve,
            icon: const Icon(Icons.tune),
            label: const Text('Update the calibration'),
          ),
        ],
      ),
    );
  }

  List<ReadBoard> get _visible {
    final all = _result?.positions ?? const <ReadBoard>[];
    return all.where((p) => _shows(_show, p)).toList();
  }

  static bool _shows(_Show show, ReadBoard p) => switch (show) {
        _Show.all => true,
        _Show.toCheck => p.legal && p.uncertain.isNotEmpty,
        _Show.notPosition => !p.legal,
        _Show.setUp => p.fixedByHand,
      };

  /// Ticks or unticks every board the filter shows; one that is not a
  /// position cannot be ticked.
  void _selectShown(bool accepted) => setState(() {
        for (final p in _visible) {
          p.accepted = accepted && p.legal;
        }
      });

  /// Saving only what was confirmed, in one tap rather than one untick per
  /// board (the owner, 23.9.2026).
  void _selectOnlySetUp() => setState(() {
        for (final p in _result?.positions ?? const <ReadBoard>[]) {
          p.accepted = p.fixedByHand && p.legal;
        }
      });

  /// A note above the boards, with the way back to the calibration.
  Widget _note(Key key, String text) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        key: key,
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
              child: Text(text,
                  style: AppText.body.copyWith(color: colors.textPrimary)),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
                onPressed: _improve, child: const Text('Add a board')),
          ],
        ),
      ),
    );
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
              if (result.unseen.isNotEmpty)
                _note(
                  const ValueKey('image-scan-unseen'),
                  'No board you set up shows '
                  '${result.unseen.map((p) => 'a ${pieceName(p)}').join(', ')} '
                  'at all, so the scanner cannot read one: it comes out as '
                  'another piece, marked only when it looks like nothing '
                  'known. Setting up a board that shows it fixes that.',
                ),
              if (result.composed.isNotEmpty)
                _note(
                  const ValueKey('image-scan-composed'),
                  'No board you set up shows '
                  '${result.composed.map(classWords).join(', ')}, so the '
                  'scanner is guessing how this book draws it. Setting up one '
                  'that does makes the guess a reading.',
                ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${result.positions.length} boards, $selected selected',
                      style: AppText.body.copyWith(color: colors.textPrimary)),
                  for (final (show, label) in [
                    (_Show.all, 'All'),
                    (_Show.toCheck, 'To check'),
                    (_Show.notPosition, 'Not a position'),
                    (_Show.setUp, 'Set up by me'),
                  ])
                    ChoiceChip(
                      key: ValueKey('image-scan-show-${switch (show) {
                        _Show.all => 'all',
                        _Show.toCheck => 'to-check',
                        _Show.notPosition => 'not-position',
                        _Show.setUp => 'set-up',
                      }}'),
                      label: Text('$label '
                          '(${result.positions.where((p) => _shows(show, p)).length})'),
                      selected: _show == show,
                      onSelected: (_) => setState(() => _show = show),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  TextButton(
                    key: const ValueKey('image-scan-select-shown'),
                    onPressed: () => _selectShown(true),
                    child: const Text('Select shown'),
                  ),
                  TextButton(
                    key: const ValueKey('image-scan-unselect-shown'),
                    onPressed: () => _selectShown(false),
                    child: const Text('Unselect shown'),
                  ),
                  TextButton(
                    key: const ValueKey('image-scan-select-set-up'),
                    onPressed: _selectOnlySetUp,
                    child: const Text('Only the ones I set up'),
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
        // A Wrap: at 360 dp the two buttons in a Row overflowed by 22 px.
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            // Chapter after chapter of one book: the calibration stays.
            TextButton(
              key: const ValueKey('image-scan-other-pages'),
              onPressed: () => _toPages(_calibration),
              child: const Text('Other pages'),
            ),
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
    required this.adds,
    required this.alone,
    required this.unconfirmed,
    required this.onConfirm,
    required this.onSetUp,
    required this.onRemove,
  });

  /// Set up by another user and not yet checked here.
  final bool unconfirmed;
  final VoidCallback onConfirm;

  final BoardRef ref;
  final Uint8List? picture;
  final String? placement;

  /// The classes this board shows and no other chosen board does.
  final Set<String> adds;

  /// The only board chosen: everything it shows is new, and saying so tells
  /// nothing.
  final bool alone;
  final VoidCallback onSetUp;
  final VoidCallback onRemove;

  /// `R/light` → „white rook (light)", in the table's order.
  static String _short(Set<String> classes) {
    final order = [
      for (final p in pieceLetters.split(''))
        for (final colour in const ['light', 'dark']) '$p/$colour'
    ];
    return [
      for (final c in order)
        if (classes.contains(c))
          '${pieceName(c.split('/').first)} (${c.split('/').last})'
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = placement != null;
    final redundant = done && !alone && adds.isEmpty;
    return Card(
      shape: AppRadii.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Page ${ref.page}, board ${ref.index}',
                style: AppText.body.copyWith(color: colors.textSecondary)),
            if (unconfirmed)
              Row(
                key: ValueKey('calibrate-shared-${ref.page}-${ref.index}'),
                children: [
                  Icon(Icons.people_outline,
                      size: 16, color: colors.textPrimary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                        'Set up by another user: check it against the picture',
                        style:
                            AppText.body.copyWith(color: colors.textPrimary)),
                  ),
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
            const SizedBox(height: AppSpacing.xs),
            if (done && !alone)
              Text(
                redundant
                    ? 'Shows nothing the other boards do not.'
                    : 'Adds: ${_short(adds)}',
                key: ValueKey('calibrate-adds-${ref.page}-${ref.index}'),
                style: AppText.body.copyWith(color: colors.textPrimary),
              ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (unconfirmed)
                  FilledButton(
                    key: ValueKey('calibrate-confirm-${ref.page}-${ref.index}'),
                    // Checked against the picture, so not before it arrives.
                    onPressed: picture == null ? null : onConfirm,
                    child: const Text('Correct'),
                  ),
                FilledButton.tonal(
                  key: ValueKey('calibrate-setup-${ref.page}-${ref.index}'),
                  onPressed: picture == null ? null : onSetUp,
                  child: Text(done ? 'Edit' : 'Set up this position'),
                ),
                TextButton(
                  key: ValueKey('calibrate-remove-${ref.page}-${ref.index}'),
                  onPressed: onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What a calibration shows, piece by piece and colour by colour — phase 3e
/// of `docs/PLAN-SKENER-SLIKE.md`. Each cell is told by **shape**, never by
/// colour alone (the owner is colourblind): a tick for shown, ≈ for guessed
/// from the other colour, an empty circle for not shown at all.
class CoverageTable extends StatelessWidget {
  const CoverageTable({super.key, required this.coverage});

  final CalibrationCoverage coverage;

  static const _names = ['Pawn', 'Knight', 'Bishop', 'Rook', 'Queen', 'King'];

  Widget _cell(BuildContext context, String piece, bool dark) {
    final colors = context.colors;
    final key = ValueKey('coverage-$piece-${dark ? 'dark' : 'light'}');
    if (coverage.absent.contains(piece)) {
      return Center(
          key: key,
          child: Text('–',
              semanticsLabel: 'not in this book',
              style: AppText.body.copyWith(color: colors.textMuted)));
    }
    return Center(
      key: key,
      child: switch (coverage.stateOf(piece, dark: dark)) {
        ClassState.seen => Icon(Icons.check,
            size: 18, color: colors.textPrimary, semanticLabel: 'shown'),
        ClassState.guessed => Text('≈',
            semanticsLabel: 'guessed',
            style: AppText.title.copyWith(color: colors.textPrimary)),
        ClassState.unknown => Icon(Icons.radio_button_unchecked,
            size: 16, color: colors.textSecondary, semanticLabel: 'not shown'),
      },
    );
  }

  Widget _side(BuildContext context, String title, String letters) {
    final colors = context.colors;
    final head = AppText.caption.copyWith(color: colors.textSecondary);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FixedColumnWidth(44),
        2: FixedColumnWidth(44),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          Text(title,
              style: AppText.body.copyWith(
                  color: colors.textPrimary, fontWeight: FontWeight.w600)),
          Center(child: Text('light', style: head)),
          Center(child: Text('dark', style: head)),
        ]),
        for (var i = 0; i < 6; i++)
          TableRow(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(_names[i],
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: colors.textPrimary)),
            ),
            _cell(context, letters[i], false),
            _cell(context, letters[i], true),
          ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('calibration-coverage'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _side(context, 'White', 'PNBRQK')),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _side(context, 'Black', 'pnbrqk')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '✓ shown   ≈ guessed from the other colour, marked when read   '
            '○ not shown: cannot be read',
            style: AppText.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The book, a window of pages at a time, to choose a calibration board from
/// — anywhere in it, since what is missing is usually elsewhere (the owner,
/// 23.9.2026). Answers the board chosen by popping it.
class BookBrowser extends StatefulWidget {
  const BookBrowser({
    super.key,
    required this.load,
    required this.pageCount,
    required this.firstPage,
    required this.taken,
  });

  /// The boards on the window of pages starting at a page.
  final Future<({List<FoundBoard> boards, String? error})> Function(int first)
      load;

  /// Pages in the book, known once a window has loaded; 0 before.
  final int Function() pageCount;
  final int firstPage;

  /// Boards already in the calibration.
  final Set<BoardRef> taken;

  @override
  State<BookBrowser> createState() => _BookBrowserState();
}

class _BookBrowserState extends State<BookBrowser> {
  late int _first = widget.firstPage;
  List<FoundBoard>? _boards;
  String? _error;
  final _jump = TextEditingController();

  @override
  void initState() {
    super.initState();
    _open(_first);
  }

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
  }

  Future<void> _open(int first) async {
    setState(() {
      _first = first;
      _boards = null;
      _error = null;
    });
    final loaded = await widget.load(first);
    if (!mounted || _first != first) return;
    setState(() {
      _boards = loaded.boards;
      _error = loaded.error;
    });
  }

  int get _last {
    final count = widget.pageCount();
    final last = _first + browsePages - 1;
    return count > 0 && last > count ? count : last;
  }

  void _go(String text) {
    final page = int.tryParse(text.trim());
    if (page == null || page < 1) return;
    final count = widget.pageCount();
    final target = count > 0 && page > count ? count : page;
    _open(((target - 1) ~/ browsePages) * browsePages + 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = widget.pageCount();
    final boards = _boards;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a board'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    key: const ValueKey('browse-previous'),
                    tooltip: 'Earlier pages',
                    onPressed: _first > 1
                        ? () => _open(
                            _first - browsePages < 1 ? 1 : _first - browsePages)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Pages $_first–$_last${count > 0 ? ' of $count' : ''}',
                    key: const ValueKey('browse-pages'),
                    style: AppText.body.copyWith(color: colors.textPrimary),
                  ),
                  IconButton(
                    key: const ValueKey('browse-next'),
                    tooltip: 'Later pages',
                    onPressed: count == 0 || _last < count
                        ? () => _open(_first + browsePages)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      key: const ValueKey('browse-jump'),
                      controller: _jump,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.go,
                      decoration: const InputDecoration(
                          isDense: true, labelText: 'Go to page'),
                      onSubmitted: _go,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: boards == null
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: AppText.body
                                      .copyWith(color: colors.textPrimary)),
                              const SizedBox(height: AppSpacing.sm),
                              OutlinedButton(
                                  onPressed: () => _open(_first),
                                  child: const Text('Try again')),
                            ],
                          ),
                        )
                      : boards.isEmpty
                          ? Center(
                              child: Text('No diagram pictures on these pages.',
                                  style: AppText.body
                                      .copyWith(color: colors.textSecondary)),
                            )
                          : GridView.extent(
                              key: const ValueKey('browse-boards'),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              maxCrossAxisExtent: 170,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.85,
                              children: [
                                for (final b in boards)
                                  _BrowsedBoard(
                                    board: b,
                                    taken: widget.taken.contains(b.ref),
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

class _BrowsedBoard extends StatelessWidget {
  const _BrowsedBoard({required this.board, required this.taken});

  final FoundBoard board;
  final bool taken;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      key: ValueKey('browse-${board.ref.page}-${board.ref.index}'),
      // A board already in the calibration is not chosen twice.
      onTap: taken ? null : () => Navigator.of(context).pop(board),
      child: Column(
        children: [
          Expanded(
            child: Opacity(
              opacity: taken ? 0.4 : 1,
              child: Image.memory(board.preview,
                  fit: BoxFit.contain,
                  semanticLabel: 'Page ${board.ref.page}, board '
                      '${board.ref.index}'),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (taken) ...[
                Icon(Icons.check, size: 14, color: colors.textPrimary),
                const SizedBox(width: 4),
              ],
              Text('p. ${board.ref.page} · ${board.ref.index}',
                  style: AppText.caption.copyWith(color: colors.textSecondary)),
            ],
          ),
        ],
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
    } else if (board.fixedByHand) {
      status = 'Set up by you';
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
