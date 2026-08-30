import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/features/archive/screens/player_profile_screen.dart';

void main() {
  testWidgets(
      'PlayerProfileScreen lays out correctly without overflow on small screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Provide a mocked response or just wait for error to render
    // The screen should handle the error and not overflow anyway.
    final router = GoRouter(
      initialLocation: AppRoutes.archiveProfilePath('testuser'),
      routes: [
        GoRoute(
          path: AppRoutes.archiveProfile,
          builder: (context, state) => PlayerProfileScreen(
              username: state.uri.queryParameters['subject'] ?? ''),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Verify it doesn't throw overflow errors.
    expect(tester.takeException(), isNull);
  });
}
