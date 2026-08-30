import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/screens/archive_import_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/theme/app_theme.dart';

class FakeArchiveApiService implements ArchiveApiService {
  @override
  Future<int> importFile(String filePath, String username) async => 1;

  @override
  Future<int> importPgn(String pgn, String username) async => 1;

  @override
  Future<ArchiveRun> getImport(int id) async {
    return ArchiveRun(
      id: id,
      source: 'file',
      subject: 'test_user',
      status: 'done',
      gamesRead: 10,
      gamesStored: 8,
      gamesDuplicate: 1,
      gamesSkipped: 1,
      skippedByReason: {'no-moves': 1},
      startedAt: '2026-08-30',
    );
  }

  @override
  Future<LeakReport> getLeaks({
    required String subject,
    String? color,
    int? fromPly,
    int? toPly,
    int? minGames,
    double? maxScore,
    String? speed,
    int? limit,
    bool? judge,
    int? judgeLimit,
    int? minRating,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, int>> backfill() async => {'games': 10, 'nodes': 10};
}

void main() {
  setUp(() {
    ArchiveApiService.setMock(FakeArchiveApiService());
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.dark,
      home: const ArchiveImportScreen(),
    );
  }

  testWidgets('ArchiveImportScreen layout fits on 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byType(TextField), 'test_user');
    await tester.pumpAndSettle();

    expect(find.text('test_user'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
