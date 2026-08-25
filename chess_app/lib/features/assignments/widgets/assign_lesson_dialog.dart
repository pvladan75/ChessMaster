import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';
import '../services/assignment_api_service.dart';

/// Lets a trainer send one of their own saved lessons as homework.
///
/// Lessons already exist and are the strongest thing a trainer builds in the
/// app, but until now they could only be shown live in a session. This is the
/// path that lets a student go through one alone.
class AssignLessonDialog extends StatefulWidget {
  const AssignLessonDialog({
    super.key,
    required this.api,
    required this.session,
    required this.studentId,
    required this.studentName,
  });

  final AssignmentApiService api;
  final UserSession session;
  final int studentId;
  final String studentName;

  @override
  State<AssignLessonDialog> createState() => _AssignLessonDialogState();
}

class _AssignLessonDialogState extends State<AssignLessonDialog> {
  final _instructions = TextEditingController();

  List<Map<String, dynamic>> _lessons = const [];
  int? _selectedId;
  DateTime? _dueAt;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/lessons'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => Map<String, dynamic>.from(e))
            // Only lessons the trainer owns can be assigned; the list also
            // carries lessons shared with them by someone else.
            .where((lesson) => lesson['is_trainer_lesson'] != true)
            .toList();
        setState(() {
          _lessons = list;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Ne mogu da učitam lekcije.';
        });
      }
    } catch (e) {
      AppLogger.log('[Assignments] Učitavanje lekcija nije uspelo: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Nema veze sa serverom.';
        });
      }
    }
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
    if (_selectedId == null) {
      setState(() => _error = 'Izaberite lekciju.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await widget.api.createLessonAssignment(
      studentId: widget.studentId,
      lessonId: _selectedId!,
      instructions: _instructions.text.trim(),
      dueAt: _dueAt,
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

  int _stepCount(Map<String, dynamic> lesson) {
    final list = lesson['position_list'];
    if (list is List) return list.length;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 128).clamp(180.0, 420.0);

    return AlertDialog(
      title: Text('Zadaj lekciju — ${widget.studentName}'),
      content: SizedBox(
        width: width,
        child: _loading
            ? const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(child: _buildBody(context)),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: _saving || _lessons.isEmpty ? null : _submit,
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

  Widget _buildBody(BuildContext context) {
    if (_lessons.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error ??
                'Nemate nijednu sačuvanu lekciju. Napravite je u sesiji preko '
                    '"Kreiraj lekciju", pa je odavde možete zadati.',
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lekcija', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: SingleChildScrollView(
            child: RadioGroup<int>(
              groupValue: _selectedId,
              onChanged: (value) => setState(() => _selectedId = value),
              child: Column(
                children: [
                  for (final lesson in _lessons)
                    RadioListTile<int>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: (lesson['id'] as num).toInt(),
                      title: Text(
                        lesson['title']?.toString() ?? 'Lekcija',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_stepCount(lesson)} koraka',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _instructions,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Napomena učeniku (opciono)',
          ),
        ),
        const SizedBox(height: 6),
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
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: context.colors.danger, fontSize: 12.5)),
      ],
    );
  }
}
