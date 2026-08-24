import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/training/screens/training_hub_screen.dart';
import 'package:chess_app/features/training/widgets/resume_strip.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/session_service.dart';

/// What the shell opens on, and what it offers.
///
/// The first tab used to be rooms, recordings and homework - everything that
/// needs a second person - so somebody who practises alone, or makes studies,
/// was shown other people's business first. Practice is the one thing everybody
/// here does, so it leads; the rest is gathered under one name.
///
/// These are held by a test because they are the kind of thing that drifts back
/// one card at a time.
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

  Future<GoRouter> openHomeRouter(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: appRouteTable,
      errorBuilder: appRouteErrorBuilder,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 200));
    return router;
  }

  Future<void> openHome(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: appRouteTable,
      errorBuilder: appRouteErrorBuilder,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Not pumpAndSettle: the home screen keeps requests and a socket going that
    // nothing answers in a test.
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('the app opens on practice, not on other people', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);
    expect(find.byType(TrainingHubScreen), findsOneWidget,
        reason: 'prvi tab mora biti Trening');
  });

  testWidgets('four tabs, and settings is not one of them', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);

    for (final label in ['Trening', 'Časovi', 'Biblioteka', 'Ljudi']) {
      expect(find.text(label), findsWidgets, reason: 'nema taba „$label"');
    }
    // Settings has a path of its own and opens over what is underneath. A tab
    // would be a place to live in, and nobody lives in settings.
    expect(find.text('Podešavanja'), findsNothing);
    // At least one way in, and which one depends on the layout: the foot of
    // the rail where there is a rail, the app bar where there is a bar. A
    // window that has both shows both, which costs nothing.
    expect(find.byTooltip('Podešavanja'), findsWidgets,
        reason: 'nema nijednog ulaza u podešavanja');
  });

  testWidgets('the rail is still there after an exercise is closed',
      (tester) async {
    // Reported from the desktop build: entering "Mat u N" and coming back left
    // the window without its side tabs.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = await openHomeRouter(tester);
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'pre ulaska');

    await tester.ensureVisible(find.text('Mat u 2').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mat u 2').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Out the way a person gets out: the arrow on the screen. A desktop window
    // is landscape, and this screen used to drop its bar there because the
    // shell's rail was beside it - which stopped being true when it became a
    // pushed route. Without the bar there is no way back at all.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: 'u landscape prozoru nema izlaza iz vežbe');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(TrainingHubScreen), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget,
        reason: 'posle povratka nema tabova sa strane');
  });

  testWidgets('settings can be reached where there is no app bar',
      (tester) async {
    // The bug this exists for: on Windows the shell's AppBar is null, because
    // the window is always landscape - so anything that lives only in the bar
    // cannot be reached at all. The bell above the rail carries a comment
    // saying exactly this, and settings was put in the bar anyway.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);

    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    expect(
      find.descendant(of: rail, matching: find.byTooltip('Podešavanja')),
      findsOneWidget,
      reason: 'u rail-u nema ulaza u podešavanja',
    );
  });

  testWidgets('nothing left open means no strip at all', (tester) async {
    // An empty state that has to be read is worse than a space that is not
    // there. With no room running and no analysis saved, the first screen is
    // the list of exercises and nothing above it.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);
    expect(find.byType(ResumeStrip), findsOneWidget,
        reason: 'traka postoji u stablu');
    expect(find.text('Nastavi'), findsNothing,
        reason: 'ali se ne vidi kad nema šta da se nastavi');
  });

  testWidgets('a room left running is offered back', (tester) async {
    // The one thing a reader most wants from the first screen when there is
    // one: the lesson they stepped out of.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await GameSessionService.instance.setActive('123456', 'trener');
    addTearDown(GameSessionService.instance.clear);

    await openHome(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nastavi'), findsOneWidget);
    expect(find.textContaining('123456'), findsWidgets);
  });

  testWidgets('the tabs are on a phone too, and nothing overflows',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openHome(tester);

    // Four destinations fit a 360 dp bar; five with words on them did not have
    // much room to spare, which is half of why settings left.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
