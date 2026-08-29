import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import '../models/assignment.dart';
import '../services/assignment_api_service.dart';

/// What a trainer fills in to set homework.
///
/// The trainer chooses criteria, not individual puzzles: picking twenty puzzles
/// by hand is work nobody does twice. The server resolves the criteria into a
/// fixed list at creation time, so the set is still exact and measurable.
class CreateAssignmentDialog extends StatefulWidget {
  const CreateAssignmentDialog({
    super.key,
    required this.api,
    required this.studentId,
    required this.studentName,
    this.suggestedThemes = const [],
  });

  final AssignmentApiService api;
  final int studentId;
  final String studentName;

  /// The student's weakest motifs, pre-ticked so the obvious assignment is the
  /// default one.
  final List<String> suggestedThemes;

  @override
  State<CreateAssignmentDialog> createState() => _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<CreateAssignmentDialog> {
  static const _offerableThemes = [
    'fork',
    'pin',
    'skewer',
    'discoveredAttack',
    'hangingPiece',
    'deflection',
    'attraction',
    'backRankMate',
    'trappedPiece',
    'sacrifice',
    'mateIn1',
    'mateIn2',
    'mateIn3',
    'rookEndgame',
    'pawnEndgame',
  ];

  late final TextEditingController _title;
  final _instructions = TextEditingController();

  late Set<String> _themes;
  int _count = 10;
  RangeValues _ratingRange = const RangeValues(1000, 1800);
  DateTime? _dueAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _themes = widget.suggestedThemes.take(3).toSet();
    _title = TextEditingController(
      text: _themes.isEmpty
          ? 'Domaći zadatak'
          : 'Vežba: ${_themes.map(themeLabel).join(', ')}',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Naslov je obavezan.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await widget.api.create(
      studentId: widget.studentId,
      title: _title.text.trim(),
      instructions: _instructions.text.trim(),
      dueAt: _dueAt,
      themes: _themes.toList(),
      minRating: _ratingRange.start.round(),
      maxRating: _ratingRange.end.round(),
      count: _count,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _saving = false;
      _error = result.quotaExceeded
          ? '${result.error} Premium nalog uklanja ovo ograničenje.'
          : result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    // An AlertDialog reserves 40px of screen inset on each side and another 24
    // of content padding, so the child actually has screenWidth - 128 to work
    // with. A fixed width wider than that overflows instead of shrinking, which
    // is what a 420px box did on any phone.
    final available = MediaQuery.of(context).size.width - 128;

    return AlertDialog(
      title: Text('Zadatak za ${widget.studentName}'),
      content: SizedBox(
        width: available.clamp(180.0, 420.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Naslov'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _instructions,
                decoration: const InputDecoration(
                  labelText: 'Napomena učeniku (opciono)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 18),

              Text('Teme', style: Theme.of(context).textTheme.labelLarge),
              if (widget.suggestedThemes.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(top: AppSpacing.xxs, bottom: 6),
                  child: Text(
                    'Predložene su teme na kojima učenik najviše greši.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final theme in _offerableThemes)
                    FilterChip(
                      label: Text(themeLabel(theme), style: AppText.body),
                      selected: _themes.contains(theme),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _themes.add(theme);
                        } else {
                          _themes.remove(theme);
                        }
                      }),
                    ),
                ],
              ),
              if (_themes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Bez izabrane teme zadatak uzima zagonetke svih vrsta.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                ),

              const SizedBox(height: 18),
              Text('Broj zagonetki: $_count',
                  style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: _count.toDouble(),
                min: 5,
                max: 50,
                divisions: 9,
                label: '$_count',
                onChanged: (value) => setState(() => _count = value.round()),
              ),

              Text(
                'Težina: ${_ratingRange.start.round()}–${_ratingRange.end.round()}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              RangeSlider(
                values: _ratingRange,
                min: 400,
                max: 2800,
                divisions: 24,
                labels: RangeLabels(
                  '${_ratingRange.start.round()}',
                  '${_ratingRange.end.round()}',
                ),
                onChanged: (values) => setState(() => _ratingRange = values),
              ),

              const SizedBox(height: 6),
              // A Wrap rather than a Row: on a narrow phone the label and the
              // button do not fit side by side, and a Row overflows instead of
              // stacking them.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      _dueAt == null
                          ? 'Postavi rok'
                          : 'Rok: ${_dueAt!.day}.${_dueAt!.month}.${_dueAt!.year}.',
                    ),
                  ),
                  if (_dueAt != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Ukloni rok',
                      onPressed: () => setState(() => _dueAt = null),
                    ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(
                        color: context.colors.danger, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Zadaj'),
        ),
      ],
    );
  }
}
