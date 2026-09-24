import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/archive/models/archive_homework_response.dart';

import 'package:chess_app/core/services/mistake_rule.dart' show MistakeReason;
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/opening_leak_report_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';

// Three habit moves at the flagged node, one of each judgement shape §9.3
// asks the screen to tell apart.
const _holdingMove = LeakReportMove(
  san: 'Nf3',
  games: 5,
  score: 0.40,
  share: 0.20,
  uci: 'g1f3',
  habit: true,
  judgement: HabitJudgement(
    verdict: HabitVerdict.holds,
    lostChances: 3,
    bestUci: 'd2d4',
    bestLine: ['d4'],
    moveLine: ['Nf3'],
    depth: 20,
    engine: 'sf-test',
  ),
);

const _losingMove = LeakReportMove(
  san: 'Nc3',
  games: 6,
  score: 0.30,
  share: 0.25,
  uci: 'b1c3',
  habit: true,
  judgement: HabitJudgement(
    verdict: HabitVerdict.mistake,
    reason: MistakeReason.lostChances,
    lostChances: 18,
    bestUci: 'd2d4',
    bestSan: 'd4',
    bestLine: ['d4'],
    moveLine: ['Nc3'],
    depth: 20,
    engine: 'sf-test',
  ),
);

const _unjudgedMove = LeakReportMove(
  san: 'a3',
  games: 4,
  score: 0.35,
  share: 0.15,
  uci: 'a2a3',
  habit: true,
);

class FakeArchiveApiService implements ArchiveApiService {
  // Added with the deletes of 22.9.2026; this fake implements every method by
  // hand, so a new one must be here to compile.
  @override
  Future<String?> deleteSubjectGames(String subject) async =>
      throw UnimplementedError();
  @override
  Future<String?> removeMistake(String id) async => throw UnimplementedError();
  // Added with `GET /games/:id/moves` (D4 of docs/PLAN-SKELET.md). This fake
  // implements every method by hand, so a new one must be here to compile.
  @override
  Future<({String startFen, List<String> uciMoves, String? subjectColor})>
      fetchGameMoves(String gameId) async => throw UnimplementedError();
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

  /// Every `judge` flag this screen sent, in order. Judging spends the
  /// player's own Lichess allowance, so *whether it was asked for* is the
  /// behaviour under test, not an implementation detail.
  final List<bool?> judgeAsked = [];

  // §9.3, docs/PLAN-MOJE-PARTIJE.md: habit moves this screen never asks the
  // engine to judge in a widget test (no engine is on disk in `flutter
  // test`), so the fake only needs to hand back what a real
  // `getLeaks`/`GET /games/openings/leaks` answer would already carry.
  List<LeakReportMove> extraMoves = const [];
  List<LosingHabit> losingHabits = const [];

  @override
  Future<OpeningNodesReport> getOpeningNodes(
          {required String subject, String? color}) async =>
      throw UnimplementedError();

  @override
  Future<JudgementTally> sendJudgements(
          List<Map<String, dynamic>> judgements) async =>
      throw UnimplementedError();

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
          moves: [
            const LeakReportMove(san: 'c5', games: 40, score: 0.60, share: 0.8),
            const LeakReportMove(san: 'e5', games: 10, score: 0.30, share: 0.2),
            ...extraMoves,
          ],
          judgement: asked
              ? const LeakJudgement(
                  verdict: OpeningVerdict.mistake, lossCp: 50, better: 'e5')
              : null,
        ),
      ],
      losingHabits: losingHabits,
    );
  }

  @override
  Future<Map<String, int>> backfill() async => {'games': 10, 'nodes': 10};
}

void main() {
  late FakeArchiveApiService api;

  setUp(() {
    // `localEnginePath()` reads `custom_engine_path` from SharedPreferences;
    // unmocked, `SharedPreferences.getInstance()` never settles under
    // `TestWidgetsFlutterBinding` (a hang, not a throw — rule 9). An empty
    // store answers „no engine path saved", which is exactly what these
    // tests want by default.
    SharedPreferences.setMockInitialValues({});
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
    expect(find.textContaining('Ply 2'), findsOneWidget);
    expect(find.textContaining('score 45.0%'), findsOneWidget);
    expect(find.textContaining('c5 — 40 of 50 games'), findsOneWidget);
    // Counted only, until someone asks: the verdict is not on screen yet.
    expect(find.textContaining('Better was e5.'), findsNothing);
    expect(api.judgeAsked, [null]);

    await tester.tap(find.text('Judge moves'));
    await tester.pumpAndSettle();

    expect(api.judgeAsked, [null, true]);
    expect(find.textContaining('Better was e5.'), findsOneWidget);
    expect(find.text('Dubious move'), findsOneWidget);
    expect(find.text('Judge moves'), findsNothing);

    expect(find.text('10 games are not indexed for openings.'), findsOneWidget);
    expect(find.text('Index older games'), findsOneWidget);
  });

  // §9.3 of docs/PLAN-MOJE-PARTIJE.md. No engine is on disk in `flutter
  // test`, so these never drive the judge itself (that is
  // `opening_tree_judge_test.dart`'s job) — they read what the screen does
  // with a report that already carries judgements, at both sizes the gate
  // names.
  for (final size in [const Size(360, 640), const Size(1280, 800)]) {
    testWidgets(
        'a holding, a losing and an unjudged habit each read as their own '
        'sentence on $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      api.extraMoves = [_holdingMove, _losingMove, _unjudgedMove];
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Your move holds — the problem comes later'),
          findsOneWidget);
      expect(find.textContaining('Your move loses: d4 was better'),
          findsOneWidget);
      expect(find.textContaining('Not judged yet'), findsOneWidget);
      // The unjudged move's own line says so — never „holds".
      final unjudgedText = tester
          .widget<Text>(find.byKey(const ValueKey('habit-judgement-fen1-a2a3')))
          .data;
      expect(unjudgedText, 'Not judged yet');

      for (final finder in [
        find.textContaining('Your move holds — the problem comes later'),
        find.textContaining('Your move loses: d4 was better'),
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: finder, matching: find.byType(RichText)));
        expect(paragraph.didExceedMaxLines, isFalse,
            reason: '„${paragraph.text.toPlainText()}" is cut in '
                '${tester.getSize(finder)}');
      }
    });

    testWidgets(
        'losing habits lists a habit whose node is not flagged, and not one '
        'whose node is, on $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const flaggedHabit = LosingHabit(
        fenKey: 'fen1', // the node already shown above — must not repeat here
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        ply: 2,
        nodeGames: 50,
        nodeScore: 0.45,
        san: 'c5',
        uci: 'c7c5',
        games: 40,
        score: 0.60,
        share: 0.8,
        habit: true,
        cost: 5,
      );
      const quietHabit = LosingHabit(
        fenKey: 'fen2', // a node the score never flagged
        fen: 'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
        ply: 3,
        nodeGames: 20,
        nodeScore: 0.60,
        san: 'Nc3',
        uci: 'b1c3',
        games: 6,
        score: 0.10,
        share: 0.30,
        habit: true,
        judgement: HabitJudgement(
          verdict: HabitVerdict.mistake,
          reason: MistakeReason.lostChances,
          lostChances: 22,
          bestUci: 'g1f3',
          bestSan: 'Nf3',
          bestLine: ['Nf3'],
          moveLine: ['Nc3'],
          depth: 20,
          engine: 'sf-test',
        ),
        cost: 132,
      );
      api.losingHabits = [flaggedHabit, quietHabit];

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The section sits after every flagged node, past the fold on a phone
      // — a plain `ListView` still builds nothing below it, the same lesson
      // this codebase already paid for once (`docs/LESSONS.md`).
      final header = find.text("Losing habits your score doesn't show");
      await tester.scrollUntilVisible(header, 200,
          scrollable: find.byType(Scrollable).first);
      expect(header, findsOneWidget);
      expect(
          find.byKey(const ValueKey('losing-habit-fen2-b1c3')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('losing-habit-fen1-c7c5')), findsNothing);
      expect(find.textContaining('Nc3 — 6 of 20 games'), findsOneWidget);
      expect(find.textContaining('Loses 22 winning chances — Nf3 was better'),
          findsOneWidget);
    });

    testWidgets(
        'with no engine on disk the button is disabled and says why '
        'on $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Judge with the engine'));
      expect(button.onPressed, isNull);
      final reasonFinder =
          find.byKey(const Key('engine-judge-disabled-reason'));
      expect(reasonFinder, findsOneWidget);

      final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: reasonFinder, matching: find.byType(RichText)));
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '„${paragraph.text.toPlainText()}" is cut in '
              '${tester.getSize(reasonFinder)}');
    });
  }
}
