import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';

/// Sends a hand-picked set of the trainer's own positions to one student.
///
/// Started from the positions rather than from the student, because that is
/// where the choosing happens: a trainer looks through a chapter, marks the six
/// worth setting, and only then thinks about who gets them.
class AssignPositionsDialog extends StatefulWidget {
  const AssignPositionsDialog({
    super.key,
    required this.session,
    required this.puzzleIds,
  });

  final UserSession session;
  final List<String> puzzleIds;

  @override
  State<AssignPositionsDialog> createState() => _AssignPositionsDialogState();
}

class _AssignPositionsDialogState extends State<AssignPositionsDialog> {
  final _title = TextEditingController();
  final _instructions = TextEditingController();

  List<Map<String, dynamic>> _students = const [];
  int? _studentId;
  DateTime? _dueAt;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Positions the server would not accept, with its reason for each. Shown
  /// rather than counted: "three could not be set" leaves a trainer hunting.
  List<Map<String, dynamic>> _refused = const [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.session.token}',
      };

  Future<void> _loadStudents() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/trainer/students'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list =
            (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() {
          _students = list;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Lista učenika nije učitana.';
        });
      }
    } catch (e) {
      AppLogger.log('Load students failed: $e', name: 'PositionScanner');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Nije moguće doći do servera.';
        });
      }
    }
  }

  Future<void> _submit() async {
    final studentId = _studentId;
    if (studentId == null || _title.text.trim().isEmpty) {
      setState(() => _error = 'Izaberi učenika i unesi naslov.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _refused = const [];
    });

    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/assignments/custom'),
            headers: _headers,
            body: jsonEncode({
              'studentId': studentId,
              'title': _title.text.trim(),
              'instructions': _instructions.text.trim(),
              'dueAt': _dueAt?.toIso8601String(),
              'puzzleIds': widget.puzzleIds,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201) {
        final refused = (body['refused'] as List?)?.length ?? 0;
        Navigator.pop(
          context,
          refused == 0
              ? 'Zadato ${widget.puzzleIds.length} pozicija.'
              : 'Zadato ${widget.puzzleIds.length - refused}, odbijeno $refused.',
        );
        return;
      }

      setState(() {
        _saving = false;
        _error = body['error']?.toString() ?? 'Zadavanje nije uspelo.';
        _refused = (body['refused'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
      });
    } catch (e) {
      AppLogger.log('Assign custom failed: $e', name: 'PositionScanner');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Nije moguće doći do servera.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text('Zadaj ${widget.puzzleIds.length} pozicija'),
      content: SizedBox(
        width: 380,
        child: _loading
            ? const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_students.isEmpty)
                      Text(
                        'Nemate nijednog učenika. Odnos se zasniva u tabu Prijatelji, '
                        'i mora ga potvrditi druga strana.',
                        style: TextStyle(color: colors.warning, fontSize: 12),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _studentId,
                        decoration: const InputDecoration(labelText: 'Učenik'),
                        items: _students
                            .map((s) => DropdownMenuItem(
                                  value: (s['id'] as num).toInt(),
                                  child:
                                      Text(s['name']?.toString() ?? 'učenik'),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _studentId = value),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Naslov zadatka',
                        hintText: 'npr. Matovi u jedan — strane 32–51',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _instructions,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Napomena za ceo zadatak (opciono)',
                        hintText: 'npr. uradi do petka, bez motora',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dueAt == null
                                ? 'Bez roka'
                                : 'Rok: ${_dueAt!.day}.${_dueAt!.month}.${_dueAt!.year}.',
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: now.add(const Duration(days: 7)),
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => _dueAt = picked);
                          },
                          child: const Text('Rok'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: colors.danger, fontSize: 12)),
                    ],
                    // Naming each refusal, because "three could not be set"
                    // leaves the trainer hunting through two hundred cards.
                    for (final item in _refused.take(6))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${item['puzzleId']}: ${item['reason']}',
                          style: TextStyle(color: colors.warning, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _saving || _students.isEmpty ? null : _submit,
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
