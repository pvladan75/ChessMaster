// Phase 6c of docs/PLAN-REORGANIZACIJA.md — one editor for a tutorial.
//
// The last group of what was docs/gates/home_map_test.dart, kept as a gate
// after the rest moved into test/ with phase 5, and grown on 17.9.2026 (red on
// master at f768a38) with what the plan's row 6c asks for beyond the two files:
// no code in lib/ names the retired editors or the platform guard, the door
// opens the studio everywhere, and the Analysis screen's tutorial rows are no
// longer behind a platform. Read by structure (`codeOf` strips comments and
// strings), so a comment that remembers the old panel is not a failure.
//
// If you believe a test in this gate is wrong, stop and say so in the report
// — do not work around it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_source.dart';

/// Every Dart file under lib/, path → code without comments and strings.
Map<String, String> _codeOfLib() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll('\\', '/'): codeOf(file.readAsStringSync()),
    };

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

    test('no code in lib/ names the retired editors or the guard', () {
      final code = _codeOfLib();
      for (final name in [
        'LessonStepEditorPanel',
        'CreateCourseDialog',
        'isTutorialStudioAvailable',
        'debugTutorialStudioAvailable',
        'studioAvailable',
      ]) {
        final where = [
          for (final entry in code.entries)
            if (entry.value.contains(name)) entry.key,
        ];
        expect(where, isEmpty, reason: '$name survives in $where');
      }
    });

    test('the door opens the studio everywhere', () {
      final entry = codeOf(
          File('lib/features/tutorial_studio/tutorial_editor_entry.dart')
              .readAsStringSync());
      expect(entry, contains('TutorialStudioScreen('));
      expect(entry, isNot(contains('Scaffold(')),
          reason: 'the second route, the one that wrapped the old panel');
    });
  });
}
