import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Finding an opening, out of the bundled ECO dataset.
///
/// Extracted from the analysis board's setup dialog, where it was one tab among
/// five, because a second screen needed exactly this and nothing else around
/// it: building a repertoire starts by naming an opening, and asking somebody
/// to play out seven moves — or paste a placement string — to say "Smith-Morra"
/// is asking them to spell what they can name.
///
/// **Two ways in, and the second one is the point.** The search field answers
/// "what is this called"; the lists answer "what is there". It opened as an
/// empty box with a search field for a while, which serves only somebody who
/// already knows the name of the thing they are looking up — the owner asked
/// for the lists, and he was asking for the half that was missing. So: every
/// opening by name, then its lines inside it, and typing at any point cuts
/// straight across both.
///
/// It answers with the whole entry rather than with a position: the caller
/// decides whether it wants the line (`pgn`), the name, or both. The repertoire
/// screen wants both, which is the point.
class OpeningPicker extends StatefulWidget {
  const OpeningPicker({super.key, required this.onPicked, this.hint});

  final void Function(OpeningBookEntry entry) onPicked;

  /// A line above the field, when the caller has something to say about what
  /// picking will do.
  final String? hint;

  @override
  State<OpeningPicker> createState() => _OpeningPickerState();
}

class _OpeningPickerState extends State<OpeningPicker> {
  final TextEditingController _query = TextEditingController();
  List<OpeningBookEntry> _results = const [];
  List<String> _families = const [];
  bool _loading = true;

  /// The opening being looked inside, or null while the list is of openings.
  ///
  /// One level, not a stack: the book is two deep — an opening and its lines —
  /// and a breadcrumb over two levels is furniture around a back button.
  String? _openFamily;

  @override
  void initState() {
    super.initState();
    // Already parsed, which it is every time after the first: the list is there
    // at once rather than flashing "Ucitavanje..." for a frame on a screen that
    // has nothing to wait for. The service is a singleton and keeps what it
    // read, so asking it is free.
    if (OpeningBookService.instance.isLoaded) {
      _loading = false;
      _families = OpeningBookService.instance.families();
      return;
    }
    // The dataset is an asset and costs no request; it takes a second or two,
    // and until it is here the field says so rather than answering "no results"
    // to everything.
    OpeningBookService.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _families = OpeningBookService.instance.families();
      });
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _results = OpeningBookService.instance.search(query);
      // Typing cuts across the lists rather than inside the one that happens to
      // be open: somebody who types "Najdorf" means the Najdorf, not the
      // Najdorf among the lines of whatever they were browsing.
      if (query.trim().isNotEmpty) _openFamily = null;
    });
  }

  bool get _searching => _query.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.hint != null) ...[
          Text(widget.hint!,
              style: AppText.caption.copyWith(color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: _query,
          enabled: !_loading,
          autofocus: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: _loading
                ? 'Učitavanje baze otvaranja…'
                : 'Naziv otvaranja ili varijante…',
          ),
          onChanged: _search,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_openFamily != null && !_searching) ...[
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _openFamily = null),
                icon: const Icon(Icons.arrow_back, size: 18),
                tooltip: 'Nazad na spisak otvaranja',
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  _openFamily!,
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Expanded(child: _buildList(context)),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    // Typed: one flat list of matches, wherever they live.
    if (_searching) {
      if (_results.isEmpty) {
        return Center(
          child: Text('Nema rezultata.',
              style: AppText.caption.copyWith(color: context.colors.textMuted)),
        );
      }
      return ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) => _entryTile(context, _results[index]),
      );
    }

    // Inside one opening: its lines, shortest first, so the first row is the
    // opening itself rather than whatever begins with A.
    final family = _openFamily;
    if (family != null) {
      final lines = OpeningBookService.instance.variationsOf(family);
      return ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) =>
            _entryTile(context, lines[index], asVariation: true),
      );
    }

    // The way in for somebody who cannot spell what they want.
    return ListView.builder(
      itemCount: _families.length,
      itemBuilder: (context, index) {
        final name = _families[index];
        return ListTile(
          dense: true,
          title: Text(name, style: AppText.body),
          trailing:
              Icon(Icons.chevron_right, size: 18, color: context.colors.accent),
          onTap: () => setState(() => _openFamily = name),
        );
      },
    );
  }

  /// One line of the book. [asVariation] drops the opening's own name from the
  /// title, which is already at the top of the list and would otherwise be
  /// repeated on every row.
  Widget _entryTile(BuildContext context, OpeningBookEntry entry,
      {bool asVariation = false}) {
    return ListTile(
      dense: true,
      title:
          Text(asVariation ? entry.variation : entry.name, style: AppText.body),
      subtitle: Text(
        '${entry.eco} · ${entry.pgn}',
        style: AppText.micro.copyWith(color: context.colors.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => widget.onPicked(entry),
    );
  }
}
