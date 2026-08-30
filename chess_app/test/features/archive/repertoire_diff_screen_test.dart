import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/repertoire_diff_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/endgame_audit.dart';
import 'package:chess_app/features/archive/models/endgame_mistake.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';

class FakeArchiveApiService implements ArchiveApiService {
  @override
  Future<String> startEndgameAudit(String username) async => 'fake-id';
  @override
  Future<EndgameAudit> getEndgameAudit(String id) async =>
      throw UnimplementedError();
  @override
  Future<List<EndgameMistake>> getEndgameMistakes({int limit = 50}) async => [];

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

  @override
  Future<RepertoireSeedResult> seedRepertoire(
      {required String username,
      String? color,
      int? minGames,
      bool? dryRun}) async {
    if (dryRun == true) {
      return const RepertoireSeedResult(
        dryRun: true,
        positionsCount: 1,
        movesCount: 2,
        unplayable: 0,
        plan: [],
      );
    }
    return const RepertoireSeedResult(
      dryRun: false,
      positionsCount: 1,
      movesCount: 2,
      unplayable: 0,
      added: 2,
      primary: 1,
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

  testWidgets('RepertoireDiffScreen displays diff and allows seeding',
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

    // Click seed button
    await tester.tap(find.text('Izvuci repertoar iz partija'));
    await tester.pumpAndSettle();

    // Dialog shows plan
    expect(find.text('Predlog repertoara'), findsOneWidget);
    expect(find.text('Nađeno pozicija: 1'), findsOneWidget);

    // Confirm
    await tester.tap(find.text('Upiši'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 100)); // Let it slide up

    // Success snackbar
    expect(find.byType(SnackBar), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
  });
}
