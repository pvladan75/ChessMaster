import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/position_scanner/screens/saved_positions_screen.dart';
import 'package:chess_app/features/position_scanner/screens/scan_review_screen.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/widgets/desktop_shortcuts.dart';

/// The keys a desktop window is expected to answer.
///
/// Held by a test because they are invisible: nothing on the screen says the
/// window responds to Escape, so nothing on the screen will say when it stops.
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

  Future<GoRouter> open(WidgetTester tester, String path) async {
    final router = GoRouter(
      initialLocation: path,
      routes: appRouteTable,
      errorBuilder: appRouteErrorBuilder,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => DesktopShortcuts(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return router;
  }

  testWidgets('Escape leaves what was opened over the work', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = await open(tester, AppRoutes.scan);
    router.push(AppRoutes.savedPositions);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SavedPositionsScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SavedPositionsScreen), findsNothing);
    expect(find.byType(ScanReviewScreen), findsOneWidget);
  });

  testWidgets('Escape on the bottom screen does nothing at all',
      (tester) async {
    // Nothing to pop, so nothing happens - rather than the window emptying
    // itself, which is what an unguarded pop does to the first route.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester, AppRoutes.scan);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ScanReviewScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chord works when the layout does not send a comma',
      (tester) async {
    // Reported from the desktop build: everything answered but this one. The
    // logical key a layout produces for that position is not guaranteed to be a
    // comma, and a chord bound to a key nobody can press fails in the quietest
    // possible way - nothing happens, nothing is logged. So it is also bound by
    // where the key sits, which every layout agrees on.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester, AppRoutes.scan);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    // The comma's place on the board, sending some other logical key - which is
    // what a non-US layout does.
    await simulateKeyDownEvent(
      LogicalKeyboardKey.semicolon,
      physicalKey: PhysicalKeyboardKey.comma,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(find.byType(SettingsScreen), findsOneWidget,
        reason: 'prečica mora da radi i kad raspored ne šalje zarez');
  });

  testWidgets('Ctrl+comma opens settings, and only once', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester, AppRoutes.scan);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Held down, it must not stack settings on settings.
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // And Escape closes it again, which is the pair of keys a reader expects.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(ScanReviewScreen), findsOneWidget);
  });
}
