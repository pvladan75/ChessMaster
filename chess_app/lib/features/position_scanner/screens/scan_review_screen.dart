import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/scanned_position.dart';
import '../services/scanner_api_service.dart';
import 'image_scan_screen.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Reads positions out of a trainer's own book and lets them confirm each one.
///
/// The confirmation step is the whole point, not a formality. Measuring the
/// scanner on two real books turned up a position the parser read perfectly and
/// a solution the *book* printed wrong — no amount of accuracy removes the need
/// for someone to look. So nothing here is dropped on the trainer's behalf:
/// doubtful positions arrive selected, marked, and one tap from being fixed.
/// A PDF chosen by the trainer, or null when they backed out. A parameter so a
/// test can stand in for the system's file picker.
typedef DocumentPicker = Future<({String path, String name})?> Function();

Future<({String path, String name})?> pickPdfWithSystemPicker() async {
  final picked = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf']);
  if (picked == null || picked.files.isEmpty) return null;
  final file = picked.files.single;
  if (file.path == null) return (path: '', name: file.name);
  return (path: file.path!, name: file.name);
}

class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({
    super.key,
    required this.session,
    this.api,
    this.pickDocument = pickPdfWithSystemPicker,
  });

  final UserSession session;

  /// The server; null builds one from [session].
  final ScannerApiService? api;
  final DocumentPicker pickDocument;

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final ScannerApiService _api =
      widget.api ?? ScannerApiService(authToken: widget.session.token);

  /// What kind of book the chosen PDF is (phase 3f): null until asked, then
  /// `font`, `pictures` or `unknown`. A picture book goes to its calibration
  /// and then to the choice of pages; the others are scanned by a page range.
  String? _kind;
  bool _identifying = false;

  /// Whether a picture book already has its calibration on the account.
  bool _kindCalibrated = false;

  final _fromController = TextEditingController(text: '1');
  final _toController = TextEditingController(text: '20');
  final _solutionsFromController = TextEditingController();
  final _solutionsToController = TextEditingController();

  String? _filePath;
  String? _fileName;
  ScanResult? _result;
  bool _scanning = false;
  bool _saving = false;
  bool _onlyDoubtful = false;

  /// How many diagrams on the last pages scanned are pictures, when the font
  /// path found none it could read — the door to the image path. Null when
  /// there is no door to offer.
  int? _imageDoor;

  /// Whether the book behind the door was calibrated before. The door used to
  /// say „set up three of them by hand" (a few, since phase 3e) every time,
  /// calibrated or not, and the owner read it as the scanner asking again for
  /// a book it remembered (23.9.2026).
  bool _doorCalibrated = false;

  /// The messenger this screen's messages go to, taken while it is still
  /// mounted.
  ///
  /// The save message is deliberately long-lived, because it carries the way
  /// to the positions that were just saved. But a SnackBar belongs to the
  /// ScaffoldMessenger *above* this route, not to the route, so it outlived
  /// the screen: it sat over whatever came next, and its action then ran
  /// `context.push` on a deactivated context, threw inside the action where
  /// AppFeedback cannot reach, and left the bar there for good. Reported
  /// 29.8.2026 as ISSUE-012.
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = AppFeedback.messengerOf(context);
  }

  @override
  void dispose() {
    AppFeedback.dismiss(_messenger);
    _fromController.dispose();
    _toController.dispose();
    _solutionsFromController.dispose();
    _solutionsToController.dispose();
    super.dispose();
  }

  List<ScannedPosition> get _visible {
    final all = _result?.positions ?? const <ScannedPosition>[];
    return _onlyDoubtful ? all.where((p) => p.needsReview).toList() : all;
  }

  Future<void> _pickDocument() async {
    final file = await widget.pickDocument();
    if (file == null || !mounted) return;
    if (file.path.isEmpty) {
      _toast('Cannot read the selected file.');
      return;
    }
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
      _result = null;
      _imageDoor = null;
      _kind = null;
    });
    await _identify(file.path);
  }

  /// Asks what kind of book [path] is, the moment it is chosen (the owner,
  /// 23.9.2026: the trainer need not know). A book with a calibration on the
  /// account is a picture book without asking. A picture book opens its
  /// calibration — or, when that is complete, the choice of pages — at once.
  Future<void> _identify(String path) async {
    setState(() => _identifying = true);
    var calibrated = false;
    String? kind;
    try {
      final hash = await bookHashOf(path);
      final load = await _api.loadCalibration(hash);
      calibrated = load.found && load.boards.isNotEmpty;
      // A book another user set up is pictures too (phase 3g): no need to
      // send it to be looked at.
      if (!calibrated && (await _api.loadSharedCalibration(hash)).found) {
        kind = 'pictures';
      }
    } catch (_) {
      calibrated = false;
    }
    if (calibrated) {
      kind = 'pictures';
    } else if (kind == null) {
      final outcome = await _api.bookKind(
          filePath: path, fileName: _fileName ?? 'document.pdf');
      // A book the server could not look at is scanned by a page range, as
      // before; nothing is lost by not knowing.
      kind = outcome.kind ?? 'unknown';
    }
    if (!mounted || path != _filePath) return;
    setState(() {
      _identifying = false;
      _kind = kind;
      _kindCalibrated = calibrated;
    });
    if (kind == 'pictures') _openImagePath(withPages: false);
  }

  Future<void> _scan() async {
    if (_filePath == null) return;
    final from = int.tryParse(_fromController.text.trim()) ?? 1;
    final to = int.tryParse(_toController.text.trim()) ?? from;
    if (to < from) {
      _toast('End page cannot be before start page.');
      return;
    }

    setState(() {
      _scanning = true;
      _imageDoor = null;
      _doorCalibrated = false;
    });
    final outcome = await _api.scan(
      filePath: _filePath!,
      fileName: _fileName ?? 'document.pdf',
      fromPage: from,
      toPage: to,
      solutionsFrom: int.tryParse(_solutionsFromController.text.trim()),
      solutionsTo: int.tryParse(_solutionsToController.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _result = outcome.result;
      _onlyDoubtful = false;
    });

    final door = imageDoorFor(outcome);
    if (door > 0) {
      // Not a refusal to read out: the pictures can be read another way, and
      // the screen says so where the positions would have been.
      setState(() => _imageDoor = door);
      final path = _filePath;
      if (path != null) {
        final calibrated = await bookIsCalibrated(_api, path);
        if (mounted && path == _filePath && _imageDoor == door) {
          setState(() => _doorCalibrated = calibrated);
        }
      }
    } else if (!outcome.ok) {
      _toast(scanFailureMessage(outcome));
    } else if (outcome.result!.positions.isEmpty) {
      _toast('There are no diagrams we can read on those pages.');
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final chosen = result.positions.where((p) => p.accepted).toList();
    if (chosen.isEmpty) {
      _toast('No positions selected to save.');
      return;
    }

    setState(() => _saving = true);
    final outcome =
        await _api.confirm(sourceTitle: result.documentName, positions: chosen);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!outcome.ok) {
      _toast(outcome.error ?? 'Save failed.');
      return;
    }
    // Saying only "saved" leaves the trainer with no idea where the positions
    // went — the first live run stored 120 of them and the answer to "where are
    // they" was nowhere on screen. The message carries the way there.
    // Taken before the bar is built, and used instead of this screen's
    // context: by the time somebody taps the action the screen may be gone,
    // and `context.push` on a dead context throws inside the action.
    final router = GoRouter.of(context);
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text('In "Saved Positions": ${outcome.summary}.'),
        // It covers the last row of scanned positions, and until now the only
        // way out of it was to follow it somewhere else.
        showCloseIcon: true,
        action: SnackBarAction(
          label: 'View',
          onPressed: () => router.push(AppRoutes.savedPositions),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
    setState(() => _result = null);
  }

  /// The image path. [withPages] carries the range the trainer scanned, when
  /// the font scan of it found pictures; a book known to be pictures from the
  /// start is asked for pages only after its calibration.
  void _openImagePath({bool withPages = true}) {
    final path = _filePath;
    if (path == null) return;
    final from = int.tryParse(_fromController.text.trim()) ?? 1;
    final to = int.tryParse(_toController.text.trim()) ?? from;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ImageScanScreen(
        api: _api,
        filePath: path,
        fileName: _fileName ?? 'document.pdf',
        fromPage: withPages ? from : null,
        toPage: withPages ? to : null,
      ),
    ));
  }

  void _toast(String message) {
    if (!mounted) return;
    AppFeedback.show(context, () => SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Position Scanner'),
        backgroundColor: colors.surface,
      ),
      body: Column(
        children: [
          _SetupPanel(
            fileName: _fileName,
            fromController: _fromController,
            toController: _toController,
            solutionsFromController: _solutionsFromController,
            solutionsToController: _solutionsToController,
            scanning: _scanning,
            identifying: _identifying,
            // A picture book is not scanned by a page range here: its pages
            // are chosen after its calibration.
            showRange: _kind != 'pictures',
            onPick: _pickDocument,
            onScan: _filePath == null || _identifying ? null : _scan,
          ),
          if (_result != null) _summary(_result!),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: _result == null ? null : _saveBar(),
    );
  }

  Widget _body() {
    if (_scanning) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_kind == 'pictures' && _result == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _PictureBook(
          calibrated: _kindCalibrated,
          onOpen: () => _openImagePath(withPages: false),
        ),
      );
    }
    final result = _result;
    final door = _imageDoor;
    if (result == null && door != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ImageDiagramsDoor(
            count: door, calibrated: _doorCalibrated, onOpen: _openImagePath),
      );
    }
    if (result == null) {
      return const _EmptyHint();
    }
    final items = _visible;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _onlyDoubtful ? 'No positions need review.' : 'No diagrams read.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 290,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _PositionCard(
        position: items[index],
        onToggleAccepted: () =>
            setState(() => items[index].accepted = !items[index].accepted),
        onFlipSide: () => setState(items[index].flipSide),
      ),
    );
  }

  Widget _summary(ScanResult result) {
    final colors = context.colors;
    final accepted = result.positions.where((p) => p.accepted).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 10),
      color: colors.surfaceRaised,
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${result.documentName} · pages ${result.scannedFrom}–${result.scannedTo} of ${result.pageCount}',
            style: TextStyle(
                color: colors.textPrimary, fontWeight: FontWeight.w600),
          ),
          Text('${result.positions.length} positions, $accepted selected',
              style: TextStyle(color: colors.textSecondary)),
          if (result.needingReview > 0)
            FilterChip(
              label: Text('${result.needingReview} needs a look'),
              selected: _onlyDoubtful,
              onSelected: (value) => setState(() => _onlyDoubtful = value),
              selectedColor: colors.warning.withValues(alpha: 0.25),
              labelStyle: TextStyle(color: colors.warning),
              backgroundColor: colors.surface,
            ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    final colors = context.colors;
    final chosen = _result?.positions.where((p) => p.accepted).length ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Saved positions remain only yours — they are not added to the public puzzle database.',
                style: AppText.body.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton.icon(
              onPressed: _saving || chosen == 0 ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text('Save ($chosen)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.fileName,
    required this.fromController,
    required this.toController,
    required this.solutionsFromController,
    required this.solutionsToController,
    required this.scanning,
    required this.identifying,
    required this.showRange,
    required this.onPick,
    required this.onScan,
  });

  final bool identifying;
  final bool showRange;
  final String? fileName;
  final TextEditingController fromController;
  final TextEditingController toController;
  final TextEditingController solutionsFromController;
  final TextEditingController solutionsToController;
  final bool scanning;
  final VoidCallback onPick;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: scanning ? null : onPick,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Select PDF'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  fileName ?? 'No document selected',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fileName == null
                          ? colors.textMuted
                          : colors.textPrimary),
                ),
              ),
            ],
          ),
          if (identifying) ...[
            const SizedBox(height: 10),
            Row(
              key: const ValueKey('scan-identifying'),
              children: [
                const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: AppSpacing.sm),
                Text('Looking at the book…',
                    style: AppText.body.copyWith(color: colors.textSecondary)),
              ],
            ),
          ] else if (showRange) ...[
            const SizedBox(height: 10),
            Wrap(
              key: const ValueKey('scan-range'),
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PageField(label: 'From page', controller: fromController),
                _PageField(label: 'To page', controller: toController),
                _PageField(
                    label: 'Solutions from',
                    controller: solutionsFromController,
                    optional: true),
                _PageField(
                    label: 'Solutions to',
                    controller: solutionsToController,
                    optional: true),
                FilledButton.icon(
                  onPressed: scanning ? null : onScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Maximum 40 pages per pass. Solution pages are optional — '
              'if provided, the side to move and solution move are read from them.',
              style: AppText.body.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A book whose diagrams are pictures, found so the moment it was chosen: the
/// way back to its calibration and pages after the trainer has left them.
class _PictureBook extends StatelessWidget {
  const _PictureBook({required this.calibrated, required this.onOpen});

  final bool calibrated;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      key: const ValueKey('scan-picture-book'),
      shape: AppRadii.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The diagrams in this book are pictures',
                style: AppText.title.copyWith(color: colors.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              calibrated
                  ? 'You set up this book before. Choose the pages to read, or '
                      'update its calibration.'
                  : 'First teach the scanner how this book draws its pieces, '
                      'then choose the pages to read.',
              style: AppText.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('scan-picture-book-open'),
              onPressed: onOpen,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageField extends StatelessWidget {
  const _PageField(
      {required this.label, required this.controller, this.optional = false});

  final String label;
  final TextEditingController controller;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          hintText: optional ? 'optional' : null,
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.position,
    required this.onToggleAccepted,
    required this.onFlipSide,
  });

  final ScannedPosition position;
  final VoidCallback onToggleAccepted;
  final VoidCallback onFlipSide;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final doubtful = position.needsReview;
    final white = position.sideToMove == 'w';

    return Opacity(
      opacity: position.accepted ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: doubtful ? colors.warning : colors.border),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  position.label == null
                      ? 'p. ${position.page}'
                      : '#${position.label} · p. ${position.page}',
                  style: AppText.body.copyWith(color: colors.textSecondary),
                ),
                const Spacer(),
                InkWell(
                  onTap: onToggleAccepted,
                  child: Icon(
                    position.accepted
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color:
                        position.accepted ? colors.success : colors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(child: BoardThumbnail(fen: position.fen, size: 150)),
            const SizedBox(height: AppSpacing.sm),
            // Whose move it is is the commonest thing a diagram cannot say, so
            // it is one tap away rather than buried in an edit dialog.
            InkWell(
              onTap: onFlipSide,
              child: Row(
                children: [
                  Icon(white ? Icons.circle : Icons.circle_outlined,
                      size: 12, color: colors.textPrimary),
                  const SizedBox(width: 6),
                  Text(
                    white ? 'White to move' : 'Black to move',
                    style: AppText.body.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.swap_horiz, size: 14, color: colors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _sideNote(position.sideSource),
              style: AppText.caption.copyWith(
                color: position.sideSource == 'unknown'
                    ? colors.warning
                    : colors.textMuted,
              ),
            ),
            const Spacer(),
            if (position.solutionSan != null && position.solutionLegal == true)
              Text('solution: ${position.solutionSan}',
                  style: AppText.body.copyWith(color: colors.textSecondary))
            else if (position.problem != null)
              Text(
                position.problem!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: colors.warning),
              ),
          ],
        ),
      ),
    );
  }

  String _sideNote(String source) {
    switch (source) {
      case 'solution':
        return 'from book solution';
      case 'only-legal-side':
        return 'only legal side';
      default:
        return 'book does not say — check';
    }
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 48, color: colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Select a PDF of your book and page range.',
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Diagrams set in a chess font are read at once; diagrams that '
              'are pictures, after you set up a few of them by hand. The '
              'document is not stored on the server.',
              style: AppText.body.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// How many diagrams a refusal says are pictures, when that is the reason the
/// font path found nothing — the only refusals that open the image path. The
/// owner decided on 22.9.2026 that the door opens by itself and there is no
/// switch for it (docs/PLAN-SKENER-SLIKE.md, phase 3).
int imageDoorFor(ScanOutcome outcome) {
  if (outcome.ok) return 0;
  if (outcome.code != 'no_text' && outcome.code != 'no_diagram_text') return 0;
  return outcome.imageDiagrams;
}

/// The door from a book the font path cannot read to the image path.
class ImageDiagramsDoor extends StatelessWidget {
  const ImageDiagramsDoor(
      {super.key,
      required this.count,
      required this.calibrated,
      required this.onOpen});

  final int count;

  /// This book was set up before, so its boards are read straight away.
  final bool calibrated;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      key: const ValueKey('image-diagrams-door'),
      shape: AppRadii.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.image_outlined, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The diagrams in this book are pictures',
                      style: AppText.title.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    count == 1
                        ? 'There is 1 on these pages. '
                        : 'There are $count on these pages. ',
                    style: AppText.body.copyWith(color: colors.textSecondary),
                  ),
                  Text(
                    calibrated
                        ? 'You set up this book before, so they are read '
                            'straight away. Nothing from the book is kept.'
                        : 'They can be read once you have set up a few of '
                            'them by hand, chosen from anywhere in the book '
                            'until every piece is shown, so the scanner learns '
                            'how this book draws its pieces. It remembers the '
                            'book, even renamed. Nothing from the book is kept.',
                    style: AppText.body.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('image-diagrams-open'),
                    onPressed: onOpen,
                    child: const Text('Read the pictures'),
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
