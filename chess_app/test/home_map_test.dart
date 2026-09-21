// The map of the app after docs/PLAN-REORGANIZACIJA.md, Variant B.
//
// Written 17.9.2026 as a gate in docs/gates/, red on `master` at bd64f9c; it
// moved here with phase 5, green, when the shell became Home · Practise ·
// Analyse · Teach. Each group is one phase's half of it: the phase-2 group
// (dead UI, the room, the names) and the phase-5 group (the tabs). The
// phase-6c group — the two other editors deleted — is still a gate, in
// docs/gates/one_editor_test.dart.

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

  /// The shell's own bar, in the two sizes that matter.
  Future<void> openHomeAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: appRouteTable,
      errorBuilder: appRouteErrorBuilder,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('the shell draws no bar of its own', () {
    testWidgets('„Chess Trainer" is nowhere, on a phone or on a desktop',
        (tester) async {
      // It used to stand above each tab's own title - two headers saying the
      // same thing, 56 dp before any tab had drawn a pixel. Asked for on
      // 18.9.2026: „taj gornji deo mi uopste nije potreban".
      for (final size in [const Size(360, 800), const Size(1400, 1000)]) {
        await openHomeAt(tester, size);
        expect(find.text('Chess Trainer'), findsNothing, reason: '\$size');
        expect(find.byType(AppBar), findsNothing, reason: '\$size');
      }
    });

    testWidgets('what the bar carried is on the tab that replaced it',
        (tester) async {
      await openHomeAt(tester, const Size(360, 800));
      // Home draws its own header, and the two buttons moved into it rather
      // than out of the app.
      expect(find.text('Home'), findsWidgets);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('Notifications and Invitations'), findsOneWidget);
    });
  });

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
        expect(
            find.descendant(of: rail, matching: find.text(old)), findsNothing,
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
        'Set up position (Board Setup)',
        'Save current position',
        'Import PGN (file or text)',
        'Start a session as host or schedule a time for students.',
        'New Session',
      ]) {
        expect(literals, isNot(contains(gone)), reason: '„$gone" survives');
      }
    });

    test('the third editor is deleted, not hidden', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll('\\', '/'))
          .toSet();
      expect(
          files.where((p) => p.endsWith('create_course_dialog.dart')), isEmpty);
      final home =
          codeOf(File('lib/screens/home_screen.dart').readAsStringSync());
      for (final symbol in [
        'showScheduleSessionDialog',
        'showScheduledSuccessDialog',
        'showPremiumModal',
        '_scheduledSessions',
      ]) {
        expect(home, isNot(contains(symbol)), reason: '$symbol survives');
      }
    });

    // „the visible Join goes through the six-digit check" stood here. Typing a
    // room code was removed on 21.9.2026 (docs/PLAN-SESIJA.md, §5.7), and the
    // case went with the field it typed into.

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
        'New session',
        'Set up position',
        'Import PGN',
      ]) {
        expect(literals, contains(there), reason: '„$there" is missing');
      }
    });
  });
}
