import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/screens/archive_home_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_theme.dart';

class FakeArchiveApiService implements ArchiveApiService {
  List<ArchiveSubject>? returnedSubjects;
  List<ArchiveRun>? returnedRuns;
  bool shouldThrow = false;

  @override
  Future<List<ArchiveSubject>> getSubjects() async {
    if (shouldThrow) throw Exception('API Error');
    return returnedSubjects ?? [];
  }

  @override
  Future<List<ArchiveRun>> listImports() async {
    if (shouldThrow) throw Exception('API Error');
    return returnedRuns ?? [];
  }

  // „Delete these games", 22.9.2026: what was asked, and the answer.
  final List<String> deletedSubjects = [];
  String? deleteRefusal;
  @override
  Future<String?> deleteSubjectGames(String subject) async {
    deletedSubjects.add(subject);
    if (deleteRefusal == null) {
      returnedSubjects =
          returnedSubjects?.where((s) => s.subject != subject).toList();
    }
    return deleteRefusal;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeArchiveApiService apiService;

  setUp(() {
    apiService = FakeArchiveApiService();
    ArchiveApiService.setMock(apiService);
  });

  Widget buildScreen({GoRouter? router}) {
    final materialApp = MaterialApp(
      theme: AppTheme.dark,
      home: const ArchiveHomeScreen(),
    );

    if (router != null) {
      return MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
      );
    }

    return materialApp;
  }

  testWidgets('shows loading then empty state', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    apiService.returnedSubjects = [];
    apiService.returnedRuns = [];

    await tester.pumpWidget(buildScreen());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('No archived games.'), findsOneWidget);
    expect(find.text('Import games'), findsOneWidget);
  });

  testWidgets('shows error state and retries', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    apiService.shouldThrow = true;

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Failed to load.'), findsOneWidget);

    apiService.shouldThrow = false;
    apiService.returnedSubjects = [];

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('No archived games.'), findsOneWidget);
  });

  testWidgets('shows loaded state with subjects and runs', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    apiService.returnedSubjects = [
      const ArchiveSubject(
        subject: 'pvladan',
        games: 4000,
        reachedTablebase: 100,
        withClocks: 200,
      ),
      const ArchiveSubject(
        subject: 'magnuscarlsen',
        games: 1000,
        reachedTablebase: 50,
        withClocks: 10,
      ),
    ];

    apiService.returnedRuns = [
      const ArchiveRun(
        id: 1,
        source: 'lichess',
        subject: 'pvladan',
        status: 'done',
        gamesRead: 100,
        gamesStored: 100,
        gamesDuplicate: 0,
        gamesSkipped: 0,
        skippedByReason: {},
        startedAt: '2026-08-30',
      )
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('pvladan'), findsOneWidget);
    expect(find.text('Games: 4000'), findsOneWidget);
    expect(find.text('magnuscarlsen'), findsOneWidget);
    expect(find.text('Games: 1000'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('pvladan (lichess)'), findsOneWidget);
    expect(find.text('Imported: 100 / 100'), findsOneWidget);
  });

  testWidgets('doors push correct routes', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    apiService.returnedSubjects = [
      const ArchiveSubject(
        subject: 'pvladan',
        games: 4000,
        reachedTablebase: 100,
        withClocks: 200,
      ),
    ];

    String? pushedRoute;
    final router = GoRouter(
      initialLocation: AppRoutes.archiveHome,
      routes: [
        GoRoute(
          path: AppRoutes.archiveHome,
          builder: (context, state) => const ArchiveHomeScreen(),
        ),
      ],
      redirect: (context, state) {
        if (state.uri.toString() != AppRoutes.archiveHome) {
          pushedRoute = state.uri.toString();
          return AppRoutes.archiveHome;
        }
        return null;
      },
    );

    await tester.pumpWidget(buildScreen(router: router));
    await tester.pumpAndSettle();

    // 1. Leaks
    await tester.tap(find.text('View opening leaks'));
    await tester.pumpAndSettle();
    expect(pushedRoute, AppRoutes.archiveLeaksPath('pvladan'));

    // 3. Repertoire
    await tester.tap(find.text('Repertoire from games'));
    await tester.pumpAndSettle();
    expect(pushedRoute,
        '${AppRoutes.archiveRepertoire}?subject=${Uri.encodeQueryComponent("pvladan")}');

    // 4. Profile
    await tester.tap(find.text('Profile and habits'));
    await tester.pumpAndSettle();
    expect(pushedRoute, AppRoutes.archiveProfilePath('pvladan'));
  });

  // „Delete these games", 22.9.2026: until then nothing imported could be
  // deleted.
  group("deleting a player's games", () {
    Future<void> openWithTwo(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      apiService.returnedSubjects = [
        const ArchiveSubject(
            subject: 'pvladan',
            games: 4126,
            reachedTablebase: 0,
            withClocks: 0),
        const ArchiveSubject(
            subject: 'hikaru', games: 50, reachedTablebase: 0, withClocks: 0),
      ];
      apiService.returnedRuns = [];
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
    }

    Future<void> deleteVia(WidgetTester tester, String subject) async {
      await tester.tap(find.byKey(ValueKey('archive-delete-$subject')));
      await tester.pumpAndSettle();
      expect(apiService.deletedSubjects, isEmpty,
          reason: 'deleted before the reader was asked');
      expect(find.textContaining('All 4126 games of "pvladan"'), findsOneWidget,
          reason: 'the dialog does not say how many, or whose');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('asked, sent, and that player leaves the list', (tester) async {
      await openWithTwo(tester);
      await deleteVia(tester, 'pvladan');
      expect(apiService.deletedSubjects, ['pvladan']);
      expect(find.text('pvladan'), findsNothing);
      expect(find.text('hikaru'), findsOneWidget,
          reason: 'another player went with it');
    });

    // The survivor of the first mutation round: asking and then deleting
    // whatever the answer passed every case above, none of which said no.
    testWidgets('„Cancel" sends nothing and keeps the card', (tester) async {
      await openWithTwo(tester);
      await tester.tap(find.byKey(const ValueKey('archive-delete-pvladan')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(apiService.deletedSubjects, isEmpty);
      expect(find.text('pvladan'), findsOneWidget);
    });

    testWidgets('a refusal keeps the card and says why', (tester) async {
      await openWithTwo(tester);
      apiService.deleteRefusal = 'An import of these games is still running.';
      await deleteVia(tester, 'pvladan');
      expect(find.text('pvladan'), findsOneWidget);
      expect(find.text('An import of these games is still running.'),
          findsOneWidget);
    });
  });
}
