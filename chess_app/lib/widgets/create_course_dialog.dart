import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';

class CreateCourseDialog extends StatefulWidget {
  final UserSession userSession;
  final List<dynamic> lessons;
  final VoidCallback onCourseCreated;

  /// When set, the dialog opens pre-filled for editing this existing saved
  /// lesson (must be a course — i.e. have a position_list) instead of
  /// starting a blank one.
  final Map<String, dynamic>? existingLesson;

  const CreateCourseDialog({
    super.key,
    required this.userSession,
    required this.lessons,
    required this.onCourseCreated,
    this.existingLesson,
  });

  @override
  State<CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<CreateCourseDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final List<Map<String, dynamic>> selectedPositions = [];
  bool isSaving = false;
  bool isAddingAnalysis = false;

  bool get isEditing => widget.existingLesson != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingLesson;
    if (existing != null) {
      titleController.text = existing['title'] ?? '';
      descController.text = existing['description'] ?? '';
      final items = (existing['position_list'] as List?) ?? const [];
      selectedPositions.addAll(
        items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _pickAnalysisToAdd() async {
    setState(() => isAddingAnalysis = true);
    final analyses =
        await AnalysisPersistenceService.instance.listSavedAnalyses(
      userToken: widget.userSession.token,
    );
    if (!mounted) return;
    setState(() => isAddingAnalysis = false);

    if (analyses.isEmpty) {
      _showError(
          'Nema sačuvanih analiza. Sačuvajte jednu u Studiju za analizu.');
      return;
    }

    final picked = await showDialog<SavedAnalysisSummary>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Izaberi sačuvanu analizu',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: SizedBox(
          width: 340,
          height: 300,
          child: ListView.separated(
            itemCount: analyses.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (context, index) {
              final a = analyses[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.biotech,
                    color: Colors.tealAccent, size: 18),
                title: Text(a.title,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () => Navigator.pop(ctx, a),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              child: const Text('Otkaži'), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );

    if (picked == null || !mounted) return;

    final tree = await AnalysisPersistenceService.instance.loadAnalysis(
      id: picked.id,
      userToken: widget.userSession.token,
    );
    if (!mounted) return;

    if (tree == null) {
      _showError('Učitavanje analize nije uspelo.');
      return;
    }

    setState(() {
      selectedPositions.add({
        'title': picked.title,
        'fen': tree.fen,
        'pgn': PgnExporterService.exportToPgn(tree),
      });
    });
  }

  Future<void> _submit({required bool asNew}) async {
    final title = titleController.text.trim();
    final desc = descController.text.trim();
    if (title.isEmpty) {
      _showError('Unesite naziv lekcije.');
      return;
    }
    if (selectedPositions.isEmpty) {
      _showError('Dodajte bar jedan korak.');
      return;
    }

    setState(() => isSaving = true);
    try {
      final updateInPlace = isEditing && !asNew;
      final uri = updateInPlace
          ? Uri.parse('$backendUrl/lessons/${widget.existingLesson!['id']}')
          : Uri.parse('$backendUrl/lessons/save');
      final body = jsonEncode({
        'title': title,
        'description': desc,
        'tags': ['lekcija_kurs'],
        'positionList': selectedPositions,
      });
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.userSession.token}',
      };

      final response = updateInPlace
          ? await http.put(uri, headers: headers, body: body)
          : await http.post(uri, headers: headers, body: body);

      if (!mounted) return;

      final ok = updateInPlace
          ? response.statusCode == 200
          : response.statusCode == 201;
      if (ok) {
        _showSuccess(updateInPlace
            ? 'Lekcija je izmenjena (${selectedPositions.length} koraka)!'
            : 'Lekcija sa ${selectedPositions.length} koraka je sačuvana!');
        widget.onCourseCreated();
        Navigator.pop(context);
      } else {
        _showError(updateInPlace
            ? 'Neuspešna izmena lekcije.'
            : 'Neuspešno kreiranje lekcije.');
      }
    } catch (e) {
      _showError('Greška na mreži.');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A saved course (position_list already set) can't itself be nested as a step.
    final availablePositions =
        widget.lessons.where((l) => l['position_list'] == null).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.collections_bookmark,
              color: Colors.deepPurpleAccent),
          const SizedBox(width: 8),
          Text(isEditing ? 'Izmeni lekciju' : 'Kreiraj lekciju (Više koraka)',
              style: const TextStyle(fontSize: 16)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Naziv lekcije / kursa',
                  hintText: 'Npr. Završnice sa skakačem - Kompletna modul',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Opis kursa (opciono)',
                  hintText: 'Kratak opis zadataka...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                'Dodaj gole pozicije iz baze:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: availablePositions.isEmpty
                    ? const Center(
                        child: Text('Nema sačuvanih pozicija.',
                            style: TextStyle(fontSize: 11, color: Colors.grey)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: availablePositions.length,
                        itemBuilder: (context, index) {
                          final lesson = availablePositions[index];
                          final isSelected = selectedPositions
                              .any((p) => p['id'] == lesson['id']);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(lesson['title'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text(lesson['fen'] ?? '',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                                maxLines: 1),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedPositions.add(lesson);
                                } else {
                                  selectedPositions.removeWhere(
                                      (p) => p['id'] == lesson['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: isAddingAnalysis
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.biotech, size: 16),
                  label: const Text('Dodaj sačuvanu analizu'),
                  onPressed: isAddingAnalysis ? null : _pickAnalysisToAdd,
                ),
              ),
              const SizedBox(height: 16),
              if (selectedPositions.isNotEmpty) ...[
                const Text(
                  'Redosled koraka (prevuci da promeniš):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: selectedPositions.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = selectedPositions.removeAt(oldIndex);
                        selectedPositions.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = selectedPositions[index];
                      final isAnalysis = item['pgn'] != null &&
                          item['pgn'].toString().isNotEmpty &&
                          item['id'] == null;
                      return Card(
                        key: ValueKey(identityHashCode(item)),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isAnalysis
                                ? Icons.biotech
                                : Icons.push_pin_outlined,
                            color: isAnalysis ? Colors.tealAccent : Colors.grey,
                            size: 18,
                          ),
                          title: Text(
                            '${index + 1}. ${item['title'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 18, color: Colors.redAccent),
                                tooltip: 'Ukloni',
                                onPressed: () => setState(
                                    () => selectedPositions.removeAt(index)),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle,
                                    size: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        if (isEditing)
          OutlinedButton(
            onPressed: isSaving ? null : () => _submit(asNew: true),
            child: const Text('Sačuvaj kao novu'),
          ),
        ElevatedButton(
          onPressed: isSaving ? null : () => _submit(asNew: !isEditing),
          child: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEditing ? 'Sačuvaj izmene' : 'Sačuvaj lekciju'),
        ),
      ],
    );
  }
}
