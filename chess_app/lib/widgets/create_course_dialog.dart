import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';

class CreateCourseDialog extends StatefulWidget {
  final UserSession userSession;
  final List<dynamic> lessons;
  final VoidCallback onCourseCreated;

  const CreateCourseDialog({
    super.key,
    required this.userSession,
    required this.lessons,
    required this.onCourseCreated,
  });

  @override
  State<CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<CreateCourseDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final List<Map<String, dynamic>> selectedPositions = [];
  bool isSaving = false;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.collections_bookmark, color: Colors.deepPurpleAccent),
          SizedBox(width: 8),
          Text('Kreiraj lekciju (Više pozicija)', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 360,
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
                'Izaberite pozicije iz baze koje ulaze u ovu lekciju:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: widget.lessons.isEmpty
                    ? const Center(child: Text('Nema sačuvanih pozicija.', style: TextStyle(fontSize: 11, color: Colors.grey)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.lessons.length,
                        itemBuilder: (context, index) {
                          final lesson = widget.lessons[index];
                          final isSelected = selectedPositions.any((p) => p['id'] == lesson['id']);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(lesson['title'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text(lesson['fen'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedPositions.add(lesson);
                                } else {
                                  selectedPositions.removeWhere((p) => p['id'] == lesson['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              if (selectedPositions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Izabrano pozicija: ${selectedPositions.length}',
                  style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
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
        ElevatedButton(
          onPressed: isSaving
              ? null
              : () async {
                  final title = titleController.text.trim();
                  final desc = descController.text.trim();
                  if (title.isEmpty) {
                    _showError('Unesite naziv lekcije.');
                    return;
                  }
                  if (selectedPositions.isEmpty) {
                    _showError('Izaberite bar jednu poziciju.');
                    return;
                  }

                  setState(() => isSaving = true);
                  try {
                    final response = await http.post(
                      Uri.parse('$backendUrl/lessons/save'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ${widget.userSession.token}'
                      },
                      body: jsonEncode({
                        'title': title,
                        'description': desc,
                        'tags': ['lekcija_kurs'],
                        'positionList': selectedPositions,
                      }),
                    );
                    if (response.statusCode == 201) {
                      _showSuccess('Lekcija sa ${selectedPositions.length} pozicija je kreirana!');
                      widget.onCourseCreated();
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      _showError('Neuspešno kreiranje lekcije.');
                    }
                  } catch (e) {
                    _showError('Greška na mreži pri kreiranju lekcije.');
                  } finally {
                    if (mounted) setState(() => isSaving = false);
                  }
                },
          child: isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sačuvaj lekciju'),
        ),
      ],
    );
  }
}
