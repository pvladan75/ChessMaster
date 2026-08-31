import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/archive/models/archive_homework_response.dart';

import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/repertoire_diff_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';

class FakeArchiveApiService implements ArchiveApiService {
  @override
  Future<List<ArchiveSubject>> getSubjects() async => [];
  @override
  Future<List<ArchiveRun>> listImports() async => [];

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
  Future<RepertoireDiff> getRepertoireDiff(
      {required String username, String? color, int? limit}) async {
    return RepertoireDiff(
      subject: username,
      color: color ?? 'white',
      coveredGames: 10,
      followedGames: 8,
      leftGames: 2,
      positions: [
        RepertoireDiffPosition(
          fenKey: 'some_fen_key',
          fen: 'some_fen',
          ply: 4,
          color: 'white',
          games: 10,
          prepared: [RepertoireDiffMove(san: 'e4', games: 1)],
          played: [RepertoireDiffMove(san: 'd4', games: 2)],
          leftGames: 2,
        ),
      ],
    );
  }

  // Stubs
  @override
  Future<int> importFile(String filePath, String username) async => 1;
  @override
  Future<int> importPgn(String pgn, String username) async => 1;
  @override
  Future<ArchiveRun> getImport(int id) async => const ArchiveRun(
      id: 1,
      source: 'file',
      subject: 'test',
      status: 'done',
      gamesStored: 0,
      gamesRead: 0,
      gamesDuplicate: 0,
      gamesSkipped: 0,
      skippedByReason: {},
      startedAt: '2023-01-01');
  @override
  Future<LeakReport> getLeaks(
          {required String subject,
          String? color,
          int? fromPly,
          int? toPly,
          int? minGames,
          double? maxScore,
          String? speed,
          int? limit,
          bool? judge,
          int? judgeLimit,
          int? minRating}) async =>
      const LeakReport(
          subject: 'test',
          games: 0,
          gamesWithoutNodes: 0,
          nodes: [],
          judge: LeakReportJudge(requested: false, judged: 0, nodes: 0));
  @override
  Future<Map<String, int>> backfill() async => {};
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
}

void main() {
  setUp(() {
    ArchiveApiService.setMock(FakeArchiveApiService());
  });

  testWidgets('the diff is shown, and nothing is written into the repertoire',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const RepertoireDiffScreen(subject: 'magnus'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Repertoar: magnus'), findsOneWidget);
    expect(find.text('Praćen repertoar'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // followedGames
    expect(find.text('Potez 3'), findsOneWidget); // ply = 4 -> move 3

    // The seed is gone: a repertoire built out of imported games wrote into
    // the same graph the trainer reads, so moves nobody had chosen were
    // indistinguishable from decisions. This screen only compares now.
    expect(find.text('Izvuci repertoar iz partija'), findsNothing);
    expect(find.textContaining('Uvezene partije se u repertoar ne upisuju'),
        findsOneWidget);
  });
}
