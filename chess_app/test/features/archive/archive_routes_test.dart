import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/archive/screens/archive_import_screen.dart';
import 'package:chess_app/features/archive/screens/opening_leak_report_screen.dart';
import 'package:chess_app/routing/app_routes.dart';

/// The report is per-player and the archive is per-handle, so the one thing
/// these routes must not do is open a report for nobody: an empty list looks
/// exactly like a clean archive.
void main() {
  test('a handle with a space or a slash survives the query', () {
    expect(AppRoutes.archiveLeaksPath('igrač 1/2'),
        '/archive/leaks?subject=igra%C4%8D+1%2F2');
  });

  Future<void> pumpAt(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: AppRoutes.archiveImport,
          builder: (context, state) => const ArchiveImportScreen(),
        ),
        GoRoute(
          path: AppRoutes.archiveLeaks,
          builder: (context, state) {
            final subject = state.uri.queryParameters['subject']?.trim() ?? '';
            if (subject.isEmpty) return const ArchiveImportScreen();
            return OpeningLeakReportScreen(subject: subject);
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
  }

  testWidgets('the leaks route carries the handle it was given',
      (tester) async {
    await pumpAt(tester, AppRoutes.archiveLeaksPath('igrač 1'));

    final screen = tester
        .widget<OpeningLeakReportScreen>(find.byType(OpeningLeakReportScreen));
    expect(screen.subject, 'igrač 1');
  });

  testWidgets('a leaks route with no handle lands on the import screen',
      (tester) async {
    await pumpAt(tester, AppRoutes.archiveLeaks);

    expect(find.byType(OpeningLeakReportScreen), findsNothing);
    expect(find.byType(ArchiveImportScreen), findsOneWidget);
  });
}
