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

    expect(find.text('Nema arhiviranih partija.'), findsOneWidget);
    expect(find.text('Uvoz partija'), findsOneWidget);
  });

  testWidgets('shows error state and retries', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    apiService.shouldThrow = true;

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Greška pri učitavanju.'), findsOneWidget);

    apiService.shouldThrow = false;
    apiService.returnedSubjects = [];

    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pumpAndSettle();

    expect(find.text('Nema arhiviranih partija.'), findsOneWidget);
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
    expect(find.text('Partije: 4000'), findsOneWidget);
    expect(find.text('magnuscarlsen'), findsOneWidget);
    expect(find.text('Partije: 1000'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('pvladan (lichess)'), findsOneWidget);
    expect(find.text('Uvezeno: 100 / 100'), findsOneWidget);
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
    await tester.tap(find.text('Pogledaj rupe u otvaranju'));
    await tester.pumpAndSettle();
    expect(pushedRoute, AppRoutes.archiveLeaksPath('pvladan'));

    // 2. Endgames
    await tester.tap(find.text('Proveri završnice'));
    await tester.pumpAndSettle();
    expect(pushedRoute, AppRoutes.archiveEndgamesPath('pvladan'));

    // 3. Repertoire
    await tester.tap(find.text('Repertoar iz partija'));
    await tester.pumpAndSettle();
    expect(pushedRoute,
        '${AppRoutes.archiveRepertoire}?subject=${Uri.encodeQueryComponent("pvladan")}');

    // 4. Profile
    await tester.tap(find.text('Profil i navike'));
    await tester.pumpAndSettle();
    expect(pushedRoute, AppRoutes.archiveProfilePath('pvladan'));
  });
}
