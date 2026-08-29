import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';

import '../models/library_entry.dart';
import '../services/position_library_service.dart';

/// Picks the lesson a position is being added to.
///
/// Only courses are offered — lessons that already have steps. A single saved
/// board is not a container of positions, and turning one into a course by
/// appending to it would change what it is without anyone saying so; the
/// server refuses that too.
class CoursePickerDialog extends StatefulWidget {
  const CoursePickerDialog({
    super.key,
    required this.service,
    this.count = 1,
    this.loader,
  });

  final PositionLibraryService service;

  /// How many positions are on their way in — the trainer should see that the
  /// choice applies to all of them.
  final int count;

  /// Test seam; see [PositionPickerDialog].
  final Future<List<CourseSummary>?> Function()? loader;

  @override
  State<CoursePickerDialog> createState() => _CoursePickerDialogState();
}

class _CoursePickerDialogState extends State<CoursePickerDialog> {
  List<CourseSummary>? _courses;
  bool _loading = true;
  bool _failed = false;

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
    final list = await (widget.loader ?? widget.service.listCourses)();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = list == null;
      _courses = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      title: Text(
        widget.count == 1
            ? 'U koju lekciju?'
            : 'U koju lekciju? (${widget.count} pozicije)',
        style: const TextStyle(fontSize: 16),
      ),
      // Fixed width, for the same reason as everywhere else in this codebase:
      // AlertDialog's IntrinsicWidth pass cannot descend into a lazy list.
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: _body(colors),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
      ],
    );
  }

  Widget _body(AppColorTokens colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: colors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          const Text('Nije moguće doći do servera.'),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: _load, child: const Text('Pokušaj opet')),
        ],
      );
    }

    final courses = _courses ?? const <CourseSummary>[];
    if (courses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'Nema nijedne lekcije sa koracima. Napravite je preko „Kreiraj lekciju".',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: courses.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, index) {
        final course = courses[index];
        return ListTile(
          dense: true,
          leading: Icon(Icons.menu_book, size: 18, color: colors.accent),
          title: Text(course.title, style: AppText.bodyLarge),
          subtitle: Text('${course.stepCount} koraka',
              style: AppText.caption.copyWith(color: colors.textSecondary)),
          onTap: () => Navigator.pop(context, course),
        );
      },
    );
  }
}
