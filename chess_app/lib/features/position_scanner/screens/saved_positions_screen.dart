import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/scanned_position.dart';
import '../services/scanner_api_service.dart';

/// Everything the trainer has kept from their own books.
///
/// The scanner without this screen saved into a void: the first live run stored
/// 120 positions correctly and there was nowhere in the app to see them. Kept
/// deliberately plain — a position is useful the moment it can be opened on the
/// analysis board, which is one tap from here.
class SavedPositionsScreen extends StatefulWidget {
  const SavedPositionsScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<SavedPositionsScreen> createState() => _SavedPositionsScreenState();
}

class _SavedPositionsScreenState extends State<SavedPositionsScreen> {
  late final ScannerApiService _api =
      ScannerApiService(authToken: widget.session.token);

  List<SavedPosition>? _positions;
  bool _loading = true;
  bool _failed = false;
  String? _source; // null = all books

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final list = await _api.listSaved();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = list == null;
      _positions = list;
    });
  }

  List<String> get _sources {
    final names = <String>{};
    for (final p in _positions ?? const <SavedPosition>[]) {
      names.add(p.sourceTitle ?? 'bez izvora');
    }
    return names.toList()..sort();
  }

  List<SavedPosition> get _visible {
    final all = _positions ?? const <SavedPosition>[];
    if (_source == null) return all;
    return all
        .where((p) => (p.sourceTitle ?? 'bez izvora') == _source)
        .toList();
  }

  Future<void> _delete(SavedPosition position) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obrisati poziciju?'),
        content: Text(position.sourceLabel == null
            ? 'Pozicija sa strane ${position.sourcePage}.'
            : 'Dijagram #${position.sourceLabel}, strana ${position.sourcePage}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Odustani')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Obriši')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _api.deleteSaved(position.puzzleId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Brisanje nije uspelo.')));
      return;
    }
    setState(() => _positions =
        _positions?.where((p) => p.puzzleId != position.puzzleId).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Moje pozicije'),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Osveži',
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final colors = context.colors;
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_failed) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Nije moguće doći do servera.',
        detail: 'Pozicije su sačuvane, samo se trenutno ne mogu učitati.',
        action:
            FilledButton(onPressed: _load, child: const Text('Pokušaj opet')),
      );
    }

    final all = _positions ?? const <SavedPosition>[];
    if (all.isEmpty) {
      return _Message(
        icon: Icons.auto_stories_outlined,
        title: 'Još nema sačuvanih pozicija.',
        detail: 'Skenirajte dijagrame iz svoje knjige i potvrdite ih.',
        action: FilledButton.icon(
          onPressed: () => context.push(AppRoutes.scan),
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Skeniraj pozicije'),
        ),
      );
    }

    final items = _visible;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: colors.surfaceRaised,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${all.length} pozicija',
                  style: TextStyle(
                      color: colors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('sve'),
                selected: _source == null,
                onSelected: (_) => setState(() => _source = null),
              ),
              for (final name in _sources)
                ChoiceChip(
                  label: Text(name),
                  selected: _source == name,
                  onSelected: (_) => setState(() => _source = name),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              mainAxisExtent: 250,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _SavedCard(
              position: items[index],
              onOpen: () =>
                  context.push(AppRoutes.analysisPath(fen: items[index].fen)),
              onDelete: () => _delete(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.position,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedPosition position;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: position.needsReview ? colors.warning : colors.border),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    position.sourceLabel == null
                        ? 'str. ${position.sourcePage ?? '?'}'
                        : '#${position.sourceLabel} · str. ${position.sourcePage}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
                InkWell(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline,
                      size: 18, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(child: BoardThumbnail(fen: position.fen, size: 140)),
            const Spacer(),
            Row(
              children: [
                Icon(
                    position.sideToMove == 'w'
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 11,
                    color: colors.textPrimary),
                const SizedBox(width: 5),
                Text(
                  position.solutionSan ?? 'bez rešenja',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(color: colors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(detail,
                style: TextStyle(color: colors.textMuted, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
