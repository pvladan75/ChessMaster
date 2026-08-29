import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Finding an opening by name, out of the bundled ECO dataset.
///
/// Extracted from the analysis board's setup dialog, where it was one tab among
/// five, because a second screen needed exactly this and nothing else around
/// it: building a repertoire starts by naming an opening, and asking somebody
/// to play out seven moves — or paste a placement string — to say "Smith-Morra"
/// is asking them to spell what they can name.
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // The dataset is an asset and costs no request; it takes a second or two,
    // and until it is here the field says so rather than answering "no results"
    // to everything.
    OpeningBookService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() => _results = OpeningBookService.instance.search(query));
  }

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
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    _loading
                        ? ''
                        : (_query.text.trim().isEmpty
                            ? 'Ukucajte naziv otvaranja da vidite rezultate.'
                            : 'Nema rezultata.'),
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final entry = _results[index];
                    return ListTile(
                      dense: true,
                      title: Text(entry.name, style: AppText.body),
                      subtitle: Text(
                        '${entry.eco} · ${entry.pgn}',
                        style: AppText.micro
                            .copyWith(color: context.colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onPicked(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
