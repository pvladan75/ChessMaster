import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/archive/models/archive_homework_response.dart';

import 'package:chess_app/core/services/mistake_rule.dart' show MistakeReason;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/opening_leak_report_screen.dart';
import 'package:chess_app/features/archive/screens/position_games_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/board_zoom_dialog.dart';

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

// Real positions for the door to Analysis (the owner, 30.9.2026), keyed as
// the server's chess.js 1.4 keys them — taken from a run, not from memory.
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterC5 = 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -';
const _afterD6 = 'rnbqkbnr/pp2pppp/3p4/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq -';

/// After 1.e4 c5 2.Nf3 d6: d4 in six of ten games, which the engine calls a
/// mistake next to Bb5+, and Nc3 twice, never judged.
const _realNode = LeakReportNode(
  fenKey: _afterD6,
  fen: '$_afterD6 0 1',
  ply: 5,
  games: 10,
  score: 0.3,
  line:
      OpeningLine(startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3', 'd7d6']),
  moves: [
    LeakReportMove(
      san: 'd4',
      uci: 'd2d4',
      games: 6,
      score: 0.25,
      share: 0.6,
      habit: true,
      judgement: HabitJudgement(
        verdict: HabitVerdict.mistake,
        reason: MistakeReason.lostChances,
        lostChances: 14,
        bestUci: 'f1b5',
        bestSan: 'Bb5+',
        bestLine: ['Bb5+', 'Bd7', 'Bxd7+', 'Qxd7', 'O-O', 'Nc6'],
        moveLine: ['d4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3', 'a6'],
        depth: 20,
        engine: 'sf-test',
      ),
    ),
    LeakReportMove(san: 'Nc3', uci: 'b1c3', games: 2, score: 0.5, share: 0.2),
  ],
);

/// After 1.e4 c5: Nc3 in eight of twenty games, where Nf3 was better.
const _realHabit = LosingHabit(
  fenKey: _afterC5,
  fen: '$_afterC5 0 1',
  ply: 3,
  nodeGames: 20,
  nodeScore: 0.6,
  san: 'Nc3',
  uci: 'b1c3',
  games: 8,
  score: 0.5,
  share: 0.4,
  habit: true,
  judgement: HabitJudgement(
    verdict: HabitVerdict.mistake,
    reason: MistakeReason.lostChances,
    lostChances: 11,
    bestUci: 'g1f3',
    bestSan: 'Nf3',
    bestLine: ['Nf3', 'd6', 'd4', 'cxd4', 'Nxd4', 'Nf6'],
    moveLine: ['Nc3', 'Nc6', 'Nf3', 'g6', 'd4', 'cxd4'],
    depth: 20,
    engine: 'sf-test',
  ),
  cost: 88,
  line: OpeningLine(startFen: _start, uciMoves: ['e2e4', 'c7c5']),
);

/// A card with no line and a key of its own: what fills a long report.
LeakReportNode _filler(int i) => LeakReportNode(
      fenKey: 'filler-$i',
      fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      ply: 2,
      games: 9,
      score: 0.3,
      moves: const [
        LeakReportMove(san: 'c5', games: 9, score: 0.3, share: 1.0),
      ],
    );

/// The SAN of the main line from [root] down to [to].
List<String> _pathTo(AnalysisNode to) {
  final out = <String>[];
  for (AnalysisNode? n = to; n != null && n.moveSan != null; n = n.parent) {
    out.insert(0, n.moveSan!);
  }
  return out;
}

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
      fetchGameMoves(String gameId) async {
    movesAsked.add(gameId);
    return gameMoves;
  }

  /// `GET /games/:id/moves`: what a game opens with, and which were asked.
  ({String startFen, List<String> uciMoves, String? subjectColor}) gameMoves =
      (startFen: _start, uciMoves: const <String>[], subjectColor: 'w');
  final movesAsked = <String>[];

  /// `GET /games/openings/games`: the games of a position, and who asked.
  PositionGames positionGames = const PositionGames(total: 0, games: []);
  final gamesAsked = <({String subject, String? color, String fenKey})>[];

  @override
  Future<PositionGames> getPositionGames(
      {required String subject, String? color, required String fenKey}) async {
    gamesAsked.add((subject: subject, color: color, fenKey: fenKey));
    return positionGames;
  }

  /// The report's thresholds, as `GET /games/openings/leaks` sends them.
  int? minGames;
  double? maxScore;
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

  /// The flagged positions, when a case needs real ones — with the moves
  /// that led to them — instead of the one made-up node below.
  List<LeakReportNode>? nodes;
  int leaksAsked = 0;

  @override
  Future<OpeningNodesReport> getOpeningNodes(
          {required String subject, String? color}) async =>
      throw UnimplementedError();

  /// §9.4: what the drill door answers, and who asked it.
  HabitDrillAnswer drillAnswer = const HabitDrillAnswer(
      habits: 0, stored: 0, alreadyInDrill: 0, withoutLoss: 0, rejected: 0);
  final drillCalls = <({String subject, String? color})>[];

  @override
  Future<HabitDrillAnswer> drillLosingHabits(
      {required String subject, String? color}) async {
    drillCalls.add((subject: subject, color: color));
    return drillAnswer;
  }

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
    leaksAsked++;
    final asked = judge == true;
    return LeakReport(
      subject: subject,
      games: 100,
      gamesWithoutNodes: 10,
      judge: LeakReportJudge(
          requested: asked, judged: asked ? 1 : 0, nodes: asked ? 1 : 0),
      nodes: nodes ??
          [
            LeakReportNode(
              fenKey: 'fen1',
              fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
              ply: 2,
              games: 50,
              score: 0.45,
              moves: [
                const LeakReportMove(
                    san: 'c5', games: 40, score: 0.60, share: 0.8),
                const LeakReportMove(
                    san: 'e5', games: 10, score: 0.30, share: 0.2),
                ...extraMoves,
              ],
              judgement: asked
                  ? const LeakJudgement(
                      verdict: OpeningVerdict.mistake, lossCp: 50, better: 'e5')
                  : null,
            ),
          ],
      losingHabits: losingHabits,
      // `this.`: the parameters of this very method carry the same names.
      minGames: this.minGames,
      maxScore: this.maxScore,
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

    // Rewritten openly on the owner's report of 30.9.2026. This case used to
    // hold „a habit whose node is flagged is not listed here", because the
    // card above already shows it; the button under the list counts every
    // losing habit, so the screen said „Drill these 9" under 8 rows and one
    // looked lost. The list is now what the button drills.
    testWidgets(
        'every losing habit the button drills is listed, the flagged one '
        'too, on $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const flaggedHabit = LosingHabit(
        fenKey: 'fen1', // the node already shown above, as a card
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
      final button = find.byKey(const Key('drill-losing-habits'));
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Losing habits'), findsOneWidget);
      expect(find.text('Drill these 2 losing habits'), findsOneWidget);
      final rows = find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('losing-habit-'));
      expect(rows, findsNWidgets(2),
          reason: 'the button says two, so two are listed');
      expect(
          find.byKey(const ValueKey('losing-habit-fen2-b1c3')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('losing-habit-fen1-c7c5')), findsOneWidget);
      // Each row carries its move's own score, in the card's format.
      expect(
          find.textContaining('Nc3 — 6 of 20 games · 10.0%'), findsOneWidget);
      // The flagged one is a row of the list too, not only the card below.
      expect(
          find.descendant(
              of: find.byKey(const Key('losing-habits-section')),
              matching: find.textContaining('c5 — 40 of 50 games · 60.0%')),
          findsOneWidget);
      expect(find.textContaining('Loses 22 winning chances — Nf3 was better'),
          findsOneWidget);
    });

    // §9.4, added by the lead: every losing habit, flagged or not, goes to the
    // drill from one button, and what happened is said.
    testWidgets(
        'the losing habits go to the drill, flagged ones included, and the '
        'answer is said, on $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Only a habit of a node already flagged: still listed (30.9.2026),
      // and still something to drill.
      api.losingHabits = const [
        LosingHabit(
          fenKey: 'fen1',
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
        ),
      ];
      api.drillAnswer = const HabitDrillAnswer(
          habits: 1, stored: 1, alreadyInDrill: 0, withoutLoss: 0, rejected: 0);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('drill-losing-habits'));
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).first);
      // `scrollUntilVisible` stops once the button is built and ends on an
      // `ensureVisible` jump that no frame has laid out yet; with the flagged
      // habit now listed above it, a tap without this frame lands where the
      // button used to be.
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('losing-habit-fen1-c7c5')), findsOneWidget);
      expect(find.text('Drill this losing habit'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(api.drillCalls, [(subject: 'test_user', color: 'w')]);
      expect(find.text('Added 1 habit to My mistakes.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no losing habit, no drill button, on $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drill-losing-habits')), findsNothing);
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

  // The owner, 30.9.2026: a click on a board enlarges it, and a position
  // opens in Analysis with the moves that led to it — and Back returns to
  // the same place.
  group('a position enlarges and opens in Analysis', () {
    final opened = <({AnalysisNode root, AnalysisNode standOn})>[];

    /// Analysis, as the door is asked for it: remembered, and — when
    /// [push] — stood in for by a page on top, as the real one is pushed.
    void fakeAnalysis({bool push = false}) {
      debugOpenTreeInAnalysis = (context, root, standOn) async {
        opened.add((root: root, standOn: standOn));
        if (!push) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            key: Key('fake-analysis'),
            body: Text('Analysis stand-in'),
          ),
        ));
      };
    }

    setUp(() {
      opened.clear();
      fakeAnalysis();
    });
    tearDown(() => debugOpenTreeInAnalysis = null);

    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
    }

    Future<Finder> reach(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      return finder;
    }

    // The owner's own window beside the two sizes of the rest of this file:
    // the enlarged board is asked for on a desktop.
    for (final size in const [
      Size(360, 640),
      Size(1280, 800),
      Size(1917, 1008),
    ]) {
      testWidgets(
          'a click on a board shows it square, whole, and as large as the '
          'window allows, on $size', (tester) async {
        api.nodes = [_realNode];
        await pumpAt(tester, size);

        await tester.tap(await reach(
            tester, find.byKey(const ValueKey('zoom-node-$_afterD6'))));
        await tester.pumpAndSettle();

        final dialog = find.byKey(const Key('board-zoom-dialog'));
        expect(dialog, findsOneWidget);
        // Measured, not asked whether it overflows: a board drawn larger
        // than its box complains nowhere (CLAUDE.md, „clipping is not
        // overflow").
        final board = tester.getRect(find.byKey(const Key('board-zoom-board')));
        final side = BoardZoomDialog.boardSideFor(size, details: 1);
        expect(board.width, side);
        expect(board.height, side);
        expect(side, greaterThan(size.width < 400 ? 280 : 500),
            reason: 'an enlarged board, not a thumbnail');
        final squares = tester.getSize(find.descendant(
            of: find.byKey(const Key('board-zoom-board')),
            matching: find.byType(BoardThumbnail)));
        expect(squares.width, squares.height);
        final window = Offset.zero & size;
        final door = find.byKey(const Key('board-zoom-open-in-analysis'));
        for (final rect in [board, tester.getRect(door)]) {
          expect(
              window.contains(rect.topLeft) &&
                  window.contains(rect.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: '$rect is not whole inside the window $size');
        }
        expect(
            find.descendant(of: dialog, matching: find.text('White to move')),
            findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(opened, isEmpty);
      });
    }

    for (final size in const [Size(360, 640), Size(1280, 800)]) {
      testWidgets(
          'a flagged position opens standing on itself, after its game\'s '
          'moves, with every move played there, on $size', (tester) async {
        api.nodes = [_realNode];
        await pumpAt(tester, size);

        final door = await reach(
            tester, find.byKey(const ValueKey('open-in-analysis-$_afterD6')));
        expect(tester.takeException(), isNull);
        await tester.tap(door);
        await tester.pumpAndSettle();

        expect(opened, hasLength(1));
        final got = opened.single;
        expect(got.root.fen, _start);
        var node = got.root;
        for (var i = 0; i < 4; i++) {
          node = node.children.first;
        }
        expect(node, same(got.standOn),
            reason: 'it stands on the fourth move of the tree it opens');
        expect(_pathTo(got.standOn), ['e4', 'c5', 'Nf3', 'd6']);
        expect([
          for (final c in got.standOn.children) c.moveSan
        ], [
          'd4',
          'Nc3',
          'Bb5+'
        ], reason: 'the moves played, most played first, then the engine\'s');
      });

      testWidgets(
          'a losing habit opens on its position with the habit and the '
          'better move, on $size', (tester) async {
        api.losingHabits = [_realHabit];
        await pumpAt(tester, size);

        await tester.tap(await reach(
            tester,
            find.byKey(
                const ValueKey('open-in-analysis-habit-$_afterC5-b1c3'))));
        await tester.pumpAndSettle();

        expect(opened, hasLength(1));
        expect(_pathTo(opened.single.standOn), ['e4', 'c5']);
        expect([for (final c in opened.single.standOn.children) c.moveSan],
            ['Nc3', 'Nf3']);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the enlarged board faces the side the player plays',
        (tester) async {
      api.nodes = [_realNode];
      await pumpAt(tester, const Size(1280, 800));
      await tester.tap(find.text('Black'));
      await tester.pumpAndSettle();

      await tester.tap(await reach(
          tester, find.byKey(const ValueKey('zoom-node-$_afterD6'))));
      await tester.pumpAndSettle();
      final big = find.byKey(const Key('board-zoom-board'));
      expect(
          tester
              .widget<BoardThumbnail>(find.descendant(
                  of: big, matching: find.byType(BoardThumbnail)))
              .isWhiteBottom,
          isFalse);
    });

    testWidgets(
        'the enlarged board\'s door closes the dialog first, then opens '
        'Analysis', (tester) async {
      fakeAnalysis(push: true);
      api.losingHabits = [_realHabit];
      await pumpAt(tester, const Size(1280, 800));

      await tester.tap(await reach(
          tester, find.byKey(const ValueKey('zoom-habit-$_afterC5-b1c3'))));
      await tester.pumpAndSettle();
      expect(find.text('Loses 11 winning chances — Nf3 was better'),
          findsNWidgets(2),
          reason: 'the row, and the enlarged board says it too');
      await tester.tap(find.byKey(const Key('board-zoom-open-in-analysis')));
      await tester.pumpAndSettle();

      // In the other order the pop would take Analysis down again and leave
      // the dialog standing.
      expect(find.byKey(const Key('fake-analysis')), findsOneWidget);
      expect(find.byKey(const Key('board-zoom-dialog')), findsNothing);
      expect(opened, hasLength(1));

      Navigator.of(tester.element(find.byKey(const Key('fake-analysis'))))
          .pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('board-zoom-dialog')), findsNothing);
      expect(find.byType(OpeningLeakReportScreen), findsOneWidget);
    });

    testWidgets(
        'coming back from Analysis finds the report as it was left: the '
        'colour, the scroll, and nothing asked again', (tester) async {
      fakeAnalysis(push: true);
      // The door at the bottom of a long list, so the case stands on a list
      // that has really been scrolled.
      api.nodes = [for (var i = 0; i < 20; i++) _filler(i), _realNode];
      api.losingHabits = [_realHabit];
      await pumpAt(tester, const Size(1280, 800));

      // Black first, so the colour is part of what has to survive.
      await tester.tap(find.text('Black'));
      await tester.pumpAndSettle();
      final door = await reach(
          tester, find.byKey(const ValueKey('open-in-analysis-$_afterD6')));
      final before =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      final offset = before.position.pixels;
      expect(offset, greaterThan(600),
          reason: 'the case needs a list that has been scrolled');
      final asked = api.leaksAsked;

      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-analysis')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('fake-analysis'))))
          .pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fake-analysis')), findsNothing);
      final after =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(after.position.pixels, offset);
      expect(api.leaksAsked, asked, reason: 'coming back asks nothing again');
      expect(
          tester
              .widget<SegmentedButton<String>>(
                  find.byType(SegmentedButton<String>))
              .selected,
          {'b'});
      expect(door, findsOneWidget, reason: 'the row is where it was');
    });

    testWidgets(
        'a position the server sent no line for has no door to '
        'Analysis, on the card or on the enlarged board', (tester) async {
      await pumpAt(tester, const Size(1280, 800));

      final card = await reach(tester, find.byKey(const ValueKey('fen1')));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Open in Analysis')),
          findsNothing);
      await tester.tap(find.byKey(const ValueKey('zoom-node-fen1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('board-zoom-dialog')), findsOneWidget);
      expect(
          find.byKey(const Key('board-zoom-open-in-analysis')), findsNothing);
    });

    testWidgets(
        'moves that do not reach the position are said, and Analysis is '
        'not opened on another board', (tester) async {
      api.nodes = const [
        LeakReportNode(
          fenKey: _afterD6,
          fen: '$_afterD6 0 1',
          ply: 5,
          games: 10,
          score: 0.3,
          // One move short: the board after 2.Nf3, not after 2...d6.
          line:
              OpeningLine(startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3']),
          moves: [
            LeakReportMove(
                san: 'd4', uci: 'd2d4', games: 6, score: 0.25, share: 0.6),
          ],
        ),
      ];
      await pumpAt(tester, const Size(1280, 800));

      await tester.tap(await reach(
          tester, find.byKey(const ValueKey('open-in-analysis-$_afterD6'))));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.textContaining('could not be replayed'), findsOneWidget);
    });
  });

  // The owner, 30.9.2026: the losing habits at the top, and a position's
  // games one tap away.
  group('the losing habits on top, and a position\'s games', () {
    PositionGame game(String id, String san, int ply, double score) =>
        PositionGame(
          id: id,
          playedAt: DateTime.utc(2026, 9, 1, 12),
          opponent: 'someone',
          opponentElo: 1810,
          result: score == 1 ? '1-0' : '0-1',
          score: score,
          speed: 'blitz',
          own: true,
          san: san,
          ply: ply,
        );

    for (final size in const [Size(360, 640), Size(1280, 800)]) {
      testWidgets(
          'the losing habits and their button come before the positions, '
          'which say what flagged them, on $size', (tester) async {
        // The order is a property of the list, and a list builds nothing
        // below its fold: the phone's width, tall enough to hold it all.
        tester.view.physicalSize = Size(size.width, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        api.losingHabits = [_realHabit];
        api.minGames = 8;
        api.maxScore = 0.42;
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        double top(Finder f) => tester.getTopLeft(f).dy;
        final section = find.byKey(const Key('losing-habits-section'));
        final drill = find.byKey(const Key('drill-losing-habits'));
        final heading = find.byKey(const Key('positions-heading'));
        final card = find.byKey(const ValueKey('fen1'));
        for (final f in [section, drill, heading, card]) {
          expect(f, findsOneWidget);
        }
        expect(top(section), lessThan(top(drill)));
        expect(tester.getBottomLeft(drill).dy, lessThanOrEqualTo(top(heading)),
            reason: 'the button belongs to the habits, above the positions');
        expect(top(heading), lessThan(top(card)));
        expect(find.text('Reached at least 8 times, scoring under 42%.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          '„Games" lists a position\'s games, and a habit\'s opens on the '
          'games it was played in, on $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        api.nodes = [_realNode];
        api.losingHabits = [_realHabit];
        api.positionGames = PositionGames(total: 3, games: [
          game('1', 'd4', 5, 0),
          game('2', 'Nc3', 5, 1),
          game('3', 'Nc3', 5, 0),
        ]);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final cardDoor = find.byKey(const ValueKey('position-games-$_afterD6'));
        await tester.scrollUntilVisible(cardDoor, 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.descendant(of: cardDoor, matching: find.text('Games (10)')),
            findsOneWidget);
        await tester.tap(cardDoor);
        await tester.pumpAndSettle();
        expect(find.byType(PositionGamesScreen), findsOneWidget);
        expect(api.gamesAsked.last,
            (subject: 'test_user', color: 'w', fenKey: _afterD6));
        expect(find.byKey(const ValueKey('position-game-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('position-game-3')), findsOneWidget);
        expect(tester.takeException(), isNull);

        Navigator.of(tester.element(find.byType(PositionGamesScreen))).pop();
        await tester.pumpAndSettle();
        final habitDoor =
            find.byKey(const ValueKey('position-games-habit-$_afterC5-b1c3'));
        await tester.scrollUntilVisible(habitDoor, -200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.descendant(of: habitDoor, matching: find.text('Games (8)')),
            findsOneWidget);
        await tester.tap(habitDoor);
        await tester.pumpAndSettle();
        expect(api.gamesAsked.last.fenKey, _afterC5);
        expect(
            tester
                .widget<ChoiceChip>(
                    find.byKey(const ValueKey('position-games-move-Nc3')))
                .selected,
            isTrue);
        expect(find.byKey(const ValueKey('position-game-1')), findsNothing,
            reason: 'd4 was not the habit');
        expect(find.byKey(const ValueKey('position-game-2')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a position\'s games are asked for the colour on screen',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      api.nodes = [_realNode];
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Black'));
      await tester.pumpAndSettle();

      final door = find.byKey(const ValueKey('position-games-$_afterD6'));
      await tester.scrollUntilVisible(door, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(api.gamesAsked.single,
          (subject: 'test_user', color: 'b', fenKey: _afterD6));
    });
  });
}
