import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/archive/models/archive_homework_response.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/archive_import_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';

class FakeArchiveApiService implements ArchiveApiService {
  ArchiveRun? returnedImport;
  int? returnedImportId;

  @override
  Future<PlayerProfile> getPlayerProfile(String username) async =>
      throw UnimplementedError();

  @override
  Future<TrainerStudentArchive> getTrainerStudentArchive(
          String studentId) async =>
      throw UnimplementedError();

  @override
  Future<ArchiveHomeworkResponse> createHomeworkFromArchive({
    required String studentId,
    int? count,
    String? kind,
    String? title,
    String? instructions,
    String? dueAt,
    bool? dryRun,
  }) async =>
      throw UnimplementedError();

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
  Future<List<ArchiveSubject>> getSubjects() async => [];

  @override
  Future<List<ArchiveRun>> listImports() async => [];

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

  testWidgets(
      'shows analysis buttons when run is done and duplicate games exist',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('miguelruivo.flutter.plugins.filepicker'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'custom' || methodCall.method == 'pickFiles') {
          return [
            {
              'name': 'test.pgn',
              'path': '/test.pgn',
              'size': 100,
              'bytes': null,
            }
          ];
        }
        return null;
      },
    );

    final mockApi = FakeArchiveApiService();
    ArchiveApiService.setMock(mockApi);
    mockApi.returnedImport = ArchiveRun(
      id: 1,
      source: 'file',
      subject: 'test_user',
      status: 'done',
      gamesRead: 4126,
      gamesStored: 0,
      gamesDuplicate: 4126,
      gamesSkipped: 0,
      skippedByReason: {},
      startedAt: '2026-08-30',
    );
    mockApi.returnedImportId = 1;

    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byType(TextField), 'test_user');
    await tester.tap(find.byType(ElevatedButton).first);

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    expect(find.text('Pogledaj rupe u otvaranju'), findsOneWidget);
  });
}
