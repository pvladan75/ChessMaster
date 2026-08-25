import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/scanned_position.dart';
import '../services/scanner_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Reads positions out of a trainer's own book and lets them confirm each one.
///
/// The confirmation step is the whole point, not a formality. Measuring the
/// scanner on two real books turned up a position the parser read perfectly and
/// a solution the *book* printed wrong — no amount of accuracy removes the need
/// for someone to look. So nothing here is dropped on the trainer's behalf:
/// doubtful positions arrive selected, marked, and one tap from being fixed.
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final ScannerApiService _api =
      ScannerApiService(authToken: widget.session.token);

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

  @override
  void dispose() {
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
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    if (file.path == null) {
      _toast('Nije moguće pročitati izabrani fajl.');
      return;
    }
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
      _result = null;
    });
  }

  Future<void> _scan() async {
    if (_filePath == null) return;
    final from = int.tryParse(_fromController.text.trim()) ?? 1;
    final to = int.tryParse(_toController.text.trim()) ?? from;
    if (to < from) {
      _toast('Krajnja strana ne može biti pre početne.');
      return;
    }

    setState(() => _scanning = true);
    final outcome = await _api.scan(
      filePath: _filePath!,
      fileName: _fileName ?? 'dokument.pdf',
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

    if (!outcome.ok) {
      _toast(outcome.code == 'unknown_font'
          ? 'Dijagrami u ovoj knjizi koriste font koji još ne umemo da čitamo.'
          : outcome.error ?? 'Skeniranje nije uspelo.');
    } else if (outcome.result!.positions.isEmpty) {
      _toast('Na tim stranama nema dijagrama koje umemo da pročitamo.');
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final chosen = result.positions.where((p) => p.accepted).toList();
    if (chosen.isEmpty) {
      _toast('Nijedna pozicija nije označena za čuvanje.');
      return;
    }

    setState(() => _saving = true);
    final outcome =
        await _api.confirm(sourceTitle: result.documentName, positions: chosen);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!outcome.ok) {
      _toast(outcome.error ?? 'Čuvanje nije uspelo.');
      return;
    }
    // Saying only "saved" leaves the trainer with no idea where the positions
    // went — the first live run stored 120 of them and the answer to "where are
    // they" was nowhere on screen. The message carries the way there.
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text('U „Moje pozicije": ${outcome.summary}.'),
        action: SnackBarAction(
          label: 'Pogledaj',
          onPressed: () => context.push(AppRoutes.savedPositions),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
    setState(() => _result = null);
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
        title: const Text('Skeniranje pozicija'),
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
            onPick: _pickDocument,
            onScan: _filePath == null ? null : _scan,
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
    final result = _result;
    if (result == null) {
      return const _EmptyHint();
    }
    final items = _visible;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _onlyDoubtful
              ? 'Nijedna pozicija nije sporna.'
              : 'Nema pročitanih dijagrama.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: colors.surfaceRaised,
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${result.documentName} · strane ${result.scannedFrom}–${result.scannedTo} od ${result.pageCount}',
            style: TextStyle(
                color: colors.textPrimary, fontWeight: FontWeight.w600),
          ),
          Text('${result.positions.length} pozicija, označeno $accepted',
              style: TextStyle(color: colors.textSecondary)),
          if (result.needingReview > 0)
            FilterChip(
              label: Text('${result.needingReview} traži pogled'),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Sačuvane pozicije ostaju samo tvoje — ne ulaze u zajedničku bazu zagonetki.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _saving || chosen == 0 ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text('Sačuvaj ($chosen)'),
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
    required this.onPick,
    required this.onScan,
  });

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: scanning ? null : onPick,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Izaberi PDF'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName ?? 'Nije izabran dokument',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fileName == null
                          ? colors.textMuted
                          : colors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PageField(label: 'Od strane', controller: fromController),
              _PageField(label: 'Do strane', controller: toController),
              _PageField(
                  label: 'Rešenja od',
                  controller: solutionsFromController,
                  optional: true),
              _PageField(
                  label: 'Rešenja do',
                  controller: solutionsToController,
                  optional: true),
              FilledButton.icon(
                onPressed: scanning ? null : onScan,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Skeniraj'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Najviše 40 strana po prolazu. Strane sa rešenjima su neobavezne — '
            'ako ih ima, iz njih se čita ko je na potezu i koji je potez.',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
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
          hintText: optional ? 'nije obavezno' : null,
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
          borderRadius: BorderRadius.circular(8),
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
                      ? 'str. ${position.page}'
                      : '#${position.label} · str. ${position.page}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
            const SizedBox(height: 8),
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
                    white ? 'beli na potezu' : 'crni na potezu',
                    style: TextStyle(color: colors.textPrimary, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.swap_horiz, size: 14, color: colors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _sideNote(position.sideSource),
              style: TextStyle(
                color: position.sideSource == 'nepoznato'
                    ? colors.warning
                    : colors.textMuted,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            if (position.solutionSan != null && position.solutionLegal == true)
              Text('rešenje: ${position.solutionSan}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12))
            else if (position.problem != null)
              Text(
                position.problem!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.warning, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  String _sideNote(String source) {
    switch (source) {
      case 'resenje':
        return 'iz rešenja u knjizi';
      case 'jedina legalna strana':
        return 'jedina legalna strana';
      default:
        return 'knjiga ne kaže — proveri';
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 48, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Izaberi PDF svoje knjige i opseg strana.',
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Dijagrami se čitaju iz teksta, ne sa slike, pa rade knjige složene '
              'šahovskim fontom. Dokument se ne čuva na serveru.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
