import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/endgame_audit.dart';
import 'package:chess_app/features/archive/models/endgame_mistake.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/archive_import_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';

class FakeArchiveApiService implements ArchiveApiService {
  @override
  Future<String> startEndgameAudit(String username) async => 'fake-id';
  @override
  Future<EndgameAudit> getEndgameAudit(String id) async =>
      throw UnimplementedError();
  @override
  Future<List<EndgameMistake>> getEndgameMistakes({int limit = 50}) async => [];

  @override
  Future<List<MistakeItem>> fetchMistakesDue({int limit = 20}) async => [];

  @override
  Future<GradeResponse> gradeMistake(String id, String grade) async =>
      const GradeResponse(ok: true);

  @override
  Future<Map<String, int>> fetchMistakeStats() async => {};

  @override
  Future<MistakeRecurrence> fetchMistakeRecurrence() async =>
      const MistakeRecurrence();

  @override
  Future<RepertoireSeedResult> seedRepertoire(
          {required String username,
          String? color,
          int? minGames,
          bool? dryRun}) async =>
      const RepertoireSeedResult(
          dryRun: true, positionsCount: 0, movesCount: 0, unplayable: 0);

  @override
  Future<RepertoireDiff> getRepertoireDiff(
          {required String username, String? color, int? limit}) async =>
      RepertoireDiff(
          subject: username,
          color: color ?? 'white',
          coveredGames: 0,
          followedGames: 0,
          leftGames: 0);

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
