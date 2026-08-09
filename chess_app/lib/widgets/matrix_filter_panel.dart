import 'package:flutter/material.dart';

class MatrixFilterPanel extends StatefulWidget {
  final List<String> availableUserLabels;
  final List<String> selectedIncludeTags;
  final List<String> selectedExcludeTags;
  final String filterMatchMode; // 'all' or 'any'
  final Function(List<String> include, List<String> exclude, String mode) onFilterChanged;

  const MatrixFilterPanel({
    super.key,
    required this.availableUserLabels,
    required this.selectedIncludeTags,
    required this.selectedExcludeTags,
    required this.filterMatchMode,
    required this.onFilterChanged,
  });

  @override
  State<MatrixFilterPanel> createState() => _MatrixFilterPanelState();
}

class _MatrixFilterPanelState extends State<MatrixFilterPanel> {
  bool isExpanded = false;

  void toggleIncludeTag(String tag) {
    List<String> inc = List.from(widget.selectedIncludeTags);
    List<String> exc = List.from(widget.selectedExcludeTags);

    if (inc.contains(tag)) {
      inc.remove(tag);
    } else {
      inc.add(tag);
      exc.remove(tag);
    }
    widget.onFilterChanged(inc, exc, widget.filterMatchMode);
  }

  void toggleExcludeTag(String tag) {
    List<String> inc = List.from(widget.selectedIncludeTags);
    List<String> exc = List.from(widget.selectedExcludeTags);

    if (exc.contains(tag)) {
      exc.remove(tag);
    } else {
      exc.add(tag);
      inc.remove(tag);
    }
    widget.onFilterChanged(inc, exc, widget.filterMatchMode);
  }

  void resetFilters() {
    widget.onFilterChanged([], [], 'all');
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = widget.selectedIncludeTags.length + widget.selectedExcludeTags.length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.blueGrey.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        initiallyExpanded: false,
        dense: true,
        onExpansionChanged: (val) => setState(() => isExpanded = val),
        title: Row(
          children: [
            const Icon(Icons.filter_list, size: 16, color: Colors.tealAccent),
            const SizedBox(width: 6),
            const Text(
              'Matrica Filter Labela',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeCount > 0)
              IconButton(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                onPressed: resetFilters,
                tooltip: 'Poništi filtere',
              ),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Režim uslova: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ChoiceChip(
                      label: const Text('SVE (AND)', style: TextStyle(fontSize: 10)),
                      selected: widget.filterMatchMode == 'all',
                      onSelected: (val) {
                        if (val) widget.onFilterChanged(widget.selectedIncludeTags, widget.selectedExcludeTags, 'all');
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('BILO KOJA (OR)', style: TextStyle(fontSize: 10)),
                      selected: widget.filterMatchMode == 'any',
                      onSelected: (val) {
                        if (val) widget.onFilterChanged(widget.selectedIncludeTags, widget.selectedExcludeTags, 'any');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kliknite labelu jednom za [Sadrži (+)], drugi put za [Ne sadrži (-)]:',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if (widget.availableUserLabels.isEmpty)
                  const Text('Nema dostupnih labela u bazi.', style: TextStyle(fontSize: 11, color: Colors.grey))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.availableUserLabels.map((tag) {
                      final isInc = widget.selectedIncludeTags.contains(tag);
                      final isExc = widget.selectedExcludeTags.contains(tag);

                      Color chipBg = Colors.grey.withValues(alpha: 0.2);
                      Color chipText = Colors.white;
                      IconData? chipIcon;

                      if (isInc) {
                        chipBg = Colors.green.withValues(alpha: 0.3);
                        chipText = Colors.greenAccent;
                        chipIcon = Icons.add_circle;
                      } else if (isExc) {
                        chipBg = Colors.red.withValues(alpha: 0.3);
                        chipText = Colors.redAccent;
                        chipIcon = Icons.remove_circle;
                      }

                      return InkWell(
                        onTap: () => toggleIncludeTag(tag),
                        onLongPress: () => toggleExcludeTag(tag),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isInc ? Colors.green : (isExc ? Colors.red : Colors.transparent),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (chipIcon != null) ...[
                                Icon(chipIcon, size: 12, color: chipText),
                                const SizedBox(width: 4),
                              ],
                              Text(tag, style: TextStyle(fontSize: 11, color: chipText)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
