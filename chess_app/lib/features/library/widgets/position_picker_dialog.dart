import 'package:chess_app/theme/app_typography.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';

import '../models/library_entry.dart';
import '../services/position_library_service.dart';

/// Why the picker was opened. It decides only what may be chosen, never what is
/// shown: an entry that cannot be used is greyed out with the reason beside it,
/// because a position the trainer knows they saved and cannot find reads as a
/// bug, while one that says "nema rešenje" answers itself.
enum PickerPurpose {
  /// Building a lesson. A lesson is read, so anything with a board qualifies.
  lesson,

  /// Setting homework. The answer has to be judgeable, which the server decides.
  homework,
}

/// One picker over all three shelves, used wherever positions are chosen.
///
/// Before it there were two lists that could not see each other — the lesson
/// editor read saved lessons and analyses, "Moje pozicije" read the scanner's
/// table — and a scanned position could not be put into a lesson at all.
class PositionPickerDialog extends StatefulWidget {
  const PositionPickerDialog({
    super.key,
    required this.service,
    this.purpose = PickerPurpose.lesson,
    this.multiSelect = true,
    this.loader,
  });

  final PositionLibraryService service;
  final PickerPurpose purpose;
  final bool multiSelect;

  /// Where the entries come from. Overridden only in tests, which have no
  /// server: this dialog embeds a lazy list inside an AlertDialog, the exact
  /// shape that twice left a dialog unlaid out here, and a layout test cannot
  /// reach the list at all if loading always fails.
  final Future<List<LibraryEntry>?> Function(
      {LibraryKind? kind, String? search})? loader;

  @override
  State<PositionPickerDialog> createState() => _PositionPickerDialogState();
}

class _PositionPickerDialogState extends State<PositionPickerDialog> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<LibraryEntry>? _entries;
  bool _loading = true;
  bool _failed = false;
  LibraryKind? _kind;

  /// Chosen entries, by "kind:id" — the two id spaces overlap (a scan's
  /// `cust_7` and a lesson's `7`), so neither is unique on its own.
  final Set<String> _picked = {};

  static String _key(LibraryEntry e) => '${libraryKindWire(e.kind)}:${e.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final load = widget.loader ?? widget.service.list;
    final items = await load(kind: _kind, search: _search.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = items == null;
      _entries = items;
    });
  }

  /// The shelf is searched on the server, not in this list: only the first 500
  /// rows per source ever arrive, so filtering what is already here would hide
  /// exactly the positions a trainer with a big library is looking for.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  bool _usable(LibraryEntry entry) =>
      widget.purpose == PickerPurpose.lesson || entry.assignable;

  void _toggle(LibraryEntry entry) {
    final key = _key(entry);
    setState(() {
      if (_picked.contains(key)) {
        _picked.remove(key);
      } else {
        if (!widget.multiSelect) _picked.clear();
        _picked.add(key);
      }
    });
  }

  void _confirm() {
    final chosen = (_entries ?? const <LibraryEntry>[])
        .where((e) => _picked.contains(_key(e)))
        .toList();
    Navigator.pop(context, chosen);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.collections_bookmark_outlined, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            widget.purpose == PickerPurpose.homework
                ? 'Izaberi pozicije za domaći'
                : 'Izaberi iz biblioteke',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      // The width must be tight and fixed. AlertDialog wraps its content in an
      // IntrinsicWidth, and that pass walks into the lazy list below, which
      // cannot report intrinsic dimensions — the dialog then never lays out.
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Traži po knjizi, zadatku ili temi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('sve'),
                    selected: _kind == null,
                    onSelected: (_) {
                      setState(() => _kind = null);
                      _load();
                    },
                  ),
                  for (final kind in LibraryKind.values)
                    ChoiceChip(
                      label: Text(libraryKindLabel(kind)),
                      selected: _kind == kind,
                      onSelected: (_) {
                        setState(() => _kind = kind);
                        _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(child: _list()),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        FilledButton(
          onPressed: _picked.isEmpty ? null : _confirm,
          child: Text(_picked.isEmpty ? 'Dodaj' : 'Dodaj (${_picked.length})'),
        ),
      ],
    );
  }

  Widget _list() {
    final colors = context.colors;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // "Nothing saved" and "the server is not answering" must not look the same:
    // a trainer told they have no positions goes looking for ones they have.
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: colors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            const Text('Nije moguće doći do servera.',
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: _load, child: const Text('Pokušaj opet')),
          ],
        ),
      );
    }

    final entries = _entries ?? const <LibraryEntry>[];
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Text(
          _search.text.trim().isEmpty
              ? 'Nema sačuvanih pozicija. Skenirajte dijagrame iz knjige ili '
                  'sačuvajte poziciju iz Studija za analizu.'
              : 'Ništa ne odgovara traženom.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: entries.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final usable = _usable(entry);
        final picked = _picked.contains(_key(entry));

        return ListTile(
          dense: true,
          enabled: usable,
          leading: Icon(
            switch (entry.kind) {
              LibraryKind.scan => Icons.menu_book_outlined,
              LibraryKind.position => Icons.push_pin_outlined,
              LibraryKind.analysis => Icons.biotech_outlined,
            },
            size: 18,
            color: usable ? colors.accent : colors.textMuted,
          ),
          title: Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyLarge,
          ),
          subtitle: Text(
            // The reason it cannot be used replaces the ordinary subtitle: it
            // is the only thing the trainer needs to read on that row.
            usable
                ? (entry.instruction ?? entry.subtitle)
                : (entry.blockedReason ?? 'ne može se zadati'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(
              color: usable ? colors.textSecondary : colors.warning,
            ),
          ),
          trailing: usable
              ? Icon(
                  picked ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: picked ? colors.accent : colors.textMuted,
                )
              : null,
          onTap: usable ? () => _toggle(entry) : null,
        );
      },
    );
  }
}
