// Phase 6c of docs/PLAN-REORGANIZACIJA.md — one editor for a tutorial.
//
// The last group of what was docs/gates/home_map_test.dart, kept as a gate
// after the rest moved into test/ with phase 5. Red on master until 6c
// deletes LessonStepEditorPanel and the platform guard.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phase 6c — one editor', () {
    test('the two other editors and the platform guard are gone', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll('\\', '/'))
          .toSet();
      expect(
        files.where((p) => p.endsWith('lesson_step_editor_panel.dart')),
        isEmpty,
      );
      expect(
        files.where((p) => p.endsWith('tutorial_studio_availability.dart')),
        isEmpty,
      );
    });
  });
}
