import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/archive/models/archive_homework_response.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/endgame_audit.dart';
import 'package:chess_app/features/archive/models/endgame_mistake.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/opening_leak_report_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';

class FakeArchiveApiService implements ArchiveApiService {
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

  /// Every `judge` flag this screen sent, in order. Judging spends the
  /// player's own Lichess allowance, so *whether it was asked for* is the
  /// behaviour under test, not an implementation detail.
  final List<bool?> judgeAsked = [];

  @override
  Future<int> importFile(String filePath, String username) async => 1;

  @override
  Future<int> importPgn(String pgn, String username) async => 1;

  @override
  Future<ArchiveRun> getImport(int id) async {
    throw UnimplementedError();
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
    judgeAsked.add(judge);
    final asked = judge == true;
    return LeakReport(
      subject: subject,
      games: 100,
      gamesWithoutNodes: 10,
      judge: LeakReportJudge(
          requested: asked, judged: asked ? 1 : 0, nodes: asked ? 1 : 0),
      nodes: [
        LeakReportNode(
          fenKey: 'fen1',
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          ply: 2,
          games: 50,
          score: 0.45,
          moves: const [
            LeakReportMove(san: 'c5', games: 40, score: 0.60, share: 0.8),
            LeakReportMove(san: 'e5', games: 10, score: 0.30, share: 0.2),
          ],
          judgement: asked
              ? const LeakJudgement(
                  verdict: OpeningVerdict.mistake, lossCp: 50, better: 'e5')
              : null,
        ),
      ],
    );
  }

  @override
  Future<Map<String, int>> backfill() async => {'games': 10, 'nodes': 10};
}

void main() {
  late FakeArchiveApiService api;

  setUp(() {
    api = FakeArchiveApiService();
    ArchiveApiService.setMock(api);
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.dark,
      home: const OpeningLeakReportScreen(subject: 'test_user'),
    );
  }

  testWidgets('Renders leak report nodes successfully on 360x640',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // The line carries the ply and the position's own success rate; the
    // exact-match finder that used to be here matched neither.
    expect(find.textContaining('2. polupotez'), findsOneWidget);
    expect(find.textContaining('uspeh 45.0%'), findsOneWidget);
    expect(find.textContaining('c5 — 40 od 50 partija'), findsOneWidget);
    // Counted only, until someone asks: the verdict is not on screen yet.
    expect(find.textContaining('Bolje je bilo e5.'), findsNothing);
    expect(api.judgeAsked, [null]);

    await tester.tap(find.text('Presudi poteze'));
    await tester.pumpAndSettle();

    expect(api.judgeAsked, [null, true]);
    expect(find.textContaining('Bolje je bilo e5.'), findsOneWidget);
    expect(find.text('Sumnjiv potez'), findsOneWidget);
    expect(find.text('Presudi poteze'), findsNothing);

    expect(
        find.text('10 partija nije indeksirano za otvaranja.'), findsOneWidget);
    expect(find.text('Indeksiraj stare partije'), findsOneWidget);
  });
}
