// The gate of phase 1 of docs/PLAN-FORENZIKA-PADA.md: what the app was doing
// just before a native crash, on disk at the moment it happened.
//
// A native crash kills the process before Dart runs again, so every case reads
// the file with `readAsStringSync` **immediately after the event and before
// any pump or await** — an entry that reaches the disk a frame later is an
// entry the crash of 26.9.2026 would never have left behind.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/services/account_local_state.dart';
import 'package:chess_app/services/crash_breadcrumb_service.dart';
import 'package:chess_app/services/crash_trail.dart';

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('screen'));
}

class _TestException implements Exception {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  final sep = Platform.pathSeparator;
  File trailFile() => File('${support.path}${sep}crash_logs${sep}trail.log');
  File previousFile() =>
      File('${support.path}${sep}crash_logs${sep}trail-previous.log');
  List<String> lines() => trailFile().existsSync()
      ? trailFile()
          .readAsStringSync()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList()
      : const [];

  setUp(() {
    support = Directory.systemTemp.createTempSync('crash_trail_');
    CrashTrail.instance.resetForTest();
  });

  tearDown(() {
    CrashTrail.instance.resetForTest();
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  Future<void> start([WidgetTester? tester]) async {
    Future<void> go() =>
        CrashTrail.instance.init(supportDirectory: () async => support);
    if (tester == null) {
      await go();
    } else {
      await tester.runAsync(go);
    }
  }

  group('navigation', () {
    testWidgets('a pushed MaterialPageRoute is named by its screen',
        (tester) async {
      await start(tester);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        navigatorObservers: [CrashTrail.instance.observer],
        home: const SizedBox(),
      ));

      unawaited(key.currentState!
          .push(MaterialPageRoute<void>(builder: (_) => const _Screen())));
      expect(lines().last, contains('push _Screen'));
      await tester.pumpAndSettle();

      key.currentState!.pop();
      expect(lines().last, contains('pop _Screen'));
      await tester.pumpAndSettle();
    });

    testWidgets('a route with a name is named by it', (tester) async {
      await start(tester);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        navigatorObservers: [CrashTrail.instance.observer],
        home: const SizedBox(),
      ));

      unawaited(key.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'export-dialog'),
        builder: (_) => const _Screen(),
      )));
      expect(lines().last, contains('push export-dialog'));
      await tester.pumpAndSettle();
    });

    testWidgets('a watched GoRouter writes the location it went to',
        (tester) async {
      await start(tester);
      final router = CrashTrail.instance.watched(GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () => context.go('/b'),
              child: const Text('go'),
            ),
          ),
          GoRoute(path: '/b', builder: (_, __) => const Text('at b')),
        ],
      ));
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('at b'), findsOneWidget);
      expect(lines(), contains(endsWith('route /b')));
    });
  });

  group('taps', () {
    Future<void> down(WidgetTester tester, Finder target, int pointer) async {
      tester.binding.handlePointerEvent(PointerDownEvent(
        pointer: pointer,
        position: tester.getCenter(target),
      ));
    }

    Future<void> up(WidgetTester tester, Finder target, int pointer) async {
      tester.binding.handlePointerEvent(PointerUpEvent(
        pointer: pointer,
        position: tester.getCenter(target),
      ));
      await tester.pump();
    }

    testWidgets('a button is named by its text, on disk before the next frame',
        (tester) async {
      await start(tester);
      CrashTrail.instance.startTaps();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Export video'),
            ),
          ),
        ),
      ));
      final target = find.text('Export video');
      await down(tester, target, 1);
      expect(lines().last, endsWith('tap "Export video"'));
      await up(tester, target, 1);
    });

    testWidgets('an icon button is named by its tooltip, not by its glyph',
        (tester) async {
      await start(tester);
      CrashTrail.instance.startTaps();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: IconButton(
              tooltip: 'Delete part',
              icon: const Icon(Icons.delete),
              onPressed: () {},
            ),
          ),
        ),
      ));
      final target = find.byIcon(Icons.delete);
      await down(tester, target, 2);
      expect(lines().last, endsWith('tap "Delete part"'));
      await up(tester, target, 2);
    });

    testWidgets('a long label is cut at 60 characters', (tester) async {
      await start(tester);
      CrashTrail.instance.startTaps();
      final long = 'x' * 100;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: () {}, child: Text(long)),
          ),
        ),
      ));
      final target = find.text(long);
      await down(tester, target, 3);
      expect(lines().last, endsWith('tap "${'x' * 60}"'));
      await up(tester, target, 3);
    });

    testWidgets('a tap on nothing named says so', (tester) async {
      await start(tester);
      CrashTrail.instance.startTaps();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SizedBox.expand()),
      ));
      final target = find.byType(Scaffold);
      await down(tester, target, 4);
      expect(lines().last, endsWith('tap ?'));
      await up(tester, target, 4);
    });
  });

  test('the ring keeps the last 40 lines', () async {
    await start();
    for (var i = 0; i < 50; i++) {
      CrashTrail.instance.record('entry $i');
    }
    final got = lines();
    expect(got, hasLength(40));
    expect(got.first, endsWith('entry 10'));
    expect(got.last, endsWith('entry 49'));
    expect(got.any((l) => l.endsWith('entry 0')), isFalse);
  });

  test('what arrives before the directory is known is written once it is',
      () async {
    CrashTrail.instance.record('early one');
    CrashTrail.instance.record('early two');
    await start();
    final got = lines();
    expect(got, contains(endsWith('early one')));
    expect(got, contains(endsWith('early two')));
  });

  test('what arrives before the directory is known is capped like the ring',
      () async {
    // A directory that never comes (a platform call that fails, or a test
    // that never calls init) must not grow a buffer for ever.
    for (var i = 0; i < 50; i++) {
      CrashTrail.instance.record('early $i');
    }
    // What is held in memory, not only what reaches the file: init trims
    // what it flushes, so the file alone cannot see an unbounded buffer.
    expect(CrashTrail.instance.pendingForTest, 40);
    await start();
    final got = lines();
    expect(got, hasLength(40));
    expect(got.last, endsWith('early 49'));
  });

  testWidgets('a lasting line goes to crash.log with the last route',
      (tester) async {
    await start(tester);
    final router = CrashTrail.instance.watched(GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
        GoRoute(path: '/prep', builder: (_, __) => const Text('prep')),
      ],
    ));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/prep');
    await tester.pumpAndSettle();

    CrashTrail.instance.recordLasting('semantics orphan [7] "" "" ""');
    final crashLog = File('${support.path}${sep}crash_logs${sep}crash.log')
        .readAsStringSync();
    expect(crashLog, contains('semantics orphan [7]'));
    expect(crashLog, contains('route /prep'));
    expect(lines().last, endsWith('semantics orphan [7] "" "" ""'));
  });

  test("the last run's trail is kept apart, not overwritten", () async {
    // After a crash the owner starts the app again to read what happened; the
    // first route of the new run must not replace the trail of the old one.
    Directory('${support.path}${sep}crash_logs').createSync(recursive: true);
    trailFile().writeAsStringSync('2026-09-26T21:25:47 tap "the old run"\n');
    await start();
    CrashTrail.instance.record('route /');
    expect(previousFile().readAsStringSync(), contains('the old run'));
    expect(trailFile().readAsStringSync(), isNot(contains('the old run')));
  });

  test('a sign-out takes the trail with the account', () async {
    SharedPreferences.setMockInitialValues({});
    await start();
    CrashTrail.instance.record('tap "A student\'s name"');
    Directory('${support.path}${sep}crash_logs').createSync(recursive: true);
    previousFile().writeAsStringSync('tap "the last run\'s student"\n');
    expect(trailFile().existsSync(), isTrue);

    await AccountLocalState.clear();
    expect(trailFile().existsSync(), isFalse);
    expect(previousFile().existsSync(), isFalse);

    // The ring in memory goes too: the next line must not bring the old ones
    // back with it.
    CrashTrail.instance.record('route /login');
    expect(trailFile().readAsStringSync(), isNot(contains('student')));
  });

  test('a directory that cannot be written costs nothing and throws nothing',
      () async {
    final notADir = File('${support.path}${sep}not_a_dir')
      ..writeAsStringSync('a file');
    await CrashTrail.instance
        .init(supportDirectory: () async => Directory(notADir.path));
    CrashTrail.instance.record('route /');
    CrashTrail.instance.record('tap "x"');
    expect(notADir.readAsStringSync(), 'a file');
  });

  test('a recorded error leaves a line in the trail too', () async {
    await start();
    CrashBreadcrumbService.instance.setTestDirectory(() async => support);
    addTearDown(() => CrashBreadcrumbService.instance.setTestDirectory(null));
    final written = CrashBreadcrumbService.instance
        .recordError(_TestException(), StackTrace.empty);
    expect(lines().last, endsWith('error _TestException'));
    await written;
  });

  group('the app is wired to it', () {
    List<String> sourceLines(String path) =>
        File(path).readAsLinesSync().map((l) => l.trim()).toList();

    test('the app router is the watched one', () {
      expect(identical(appRouter, CrashTrail.instance.watching), isTrue);
    });

    test("the app router passes the trail's observer", () {
      expect(sourceLines('lib/routing/app_router.dart'),
          contains('observers: [CrashTrail.instance.observer],'));
    });

    test('main starts the trail and its taps', () {
      final main = sourceLines('lib/main.dart');
      expect(main, contains('unawaited(CrashTrail.instance.init());'));
      expect(main, contains('CrashTrail.instance.startTaps();'));
    });
  });
}
