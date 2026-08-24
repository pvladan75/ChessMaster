import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/training/screens/training_hub_screen.dart';
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
    expect(find.byTooltip('Podešavanja'), findsOneWidget,
        reason: 'ikonica u traci je jedini ulaz u podešavanja odavde');
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
