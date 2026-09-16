// The map of the app after docs/PLAN-REORGANIZACIJA.md, Variant B.
//
// Lives in docs/gates/ until the phases make it green — a red suite hides the
// next real failure (the rule every anchor in this project follows). Run it by
// copying it into chess_app/test/ and running that one file. Each group is one
// phase's half of the gate, so a phase is graded by its group and the others
// may stay red until their turn.
//
// Written 17.9.2026, proved red on `master` at bd64f9c: the tabs group fails on
// the four old names, the phase-2 group on the strings the plan deletes, the
// phase-6c group on the three files that still exist.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/session_service.dart';

import 'support/dart_source.dart';

/// Every string literal in `lib/`, read by structure — a comment that quotes a
/// retired label does not count.
Set<String> _literalsOfLib() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          ...literalsIn(file.readAsStringSync()),
    };

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'test-token',
      'user_id': 1,
      'user_email': 'test@example.com',
      'user_name': 'Test',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
  });

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: appRouteTable,
      errorBuilder: appRouteErrorBuilder,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Not pumpAndSettle: the home keeps requests and a socket going that
    // nothing answers in a test.
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('phase 5 — the tabs', () {
    testWidgets('four destinations: Home, Practise, Analyse, Teach',
        (tester) async {
      await openHome(tester);
      final rail = find.byType(NavigationRail);
      expect(rail, findsOneWidget);
      for (final label in ['Home', 'Practise', 'Analyse', 'Teach']) {
        expect(find.descendant(of: rail, matching: find.text(label)),
            findsOneWidget,
            reason: 'the rail has no „$label"');
      }
      for (final old in ['Training', 'Sessions', 'Library', 'People']) {
        expect(find.descendant(of: rail, matching: find.text(old)),
            findsNothing,
            reason: '„$old" is not a tab any more');
      }
      // Settings keeps its path and opens over what is underneath.
      expect(find.descendant(of: rail, matching: find.text('Settings')),
          findsNothing);
      expect(find.byTooltip('Settings'), findsWidgets);
    });
  });

  // Phase 1 — one door in Analysis — has its own gate,
  // docs/gates/analysis_teach_door_test.dart, because it is the first to run
  // and is graded alone.

  group('phase 2 — dead UI, the room, the names', () {
    test('the deleted strings are deleted', () {
      final literals = _literalsOfLib();
      for (final gone in [
        // S1 — the third editor
        'Create tutorial (multiple positions)',
        'Create tutorial (multiple steps)',
        'Edit positions',
        'Save as new version',
        // S4 — dead dialogs
        'Schedule a Session',
        'Schedule and Save',
        'Scheduled Successfully!',
        'Chess Trainer Premium',
        // S5 — one door to Preparation
        'Open Preparation with an empty board',
        // names
        'Interactive tutorials',
        'Library of positions and tutorials',
        'Recorded material',
        'You have no saved material.',
        'Friends & Contacts',
        'Save current tutorial / position',
        'Tutorial / position name',
        'Tutorials and positions',
        'Start a session as host or schedule a time for students.',
      ]) {
        expect(literals, isNot(contains(gone)), reason: '„$gone" survives');
      }
    });

    test('the new names are there', () {
      final literals = _literalsOfLib();
      for (final there in [
        'Recordings',
        'No recordings yet.',
        'Students and trainers',
        'Save position',
        'Position name',
        'Open a room and invite your student.',
        'Scan a book',
      ]) {
        expect(literals, contains(there), reason: '„$there" is missing');
      }
    });
  });

  group('phase 6c — one editor', () {
    test('the two other editors and the platform guard are gone', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll('\\', '/'))
          .toSet();
      expect(files.where((p) => p.endsWith('lesson_step_editor_panel.dart')),
          isEmpty);
      expect(files.where((p) => p.endsWith('create_course_dialog.dart')),
          isEmpty);
      expect(
          files.where((p) => p.endsWith('tutorial_studio_availability.dart')),
          isEmpty);
    });
  });
}
