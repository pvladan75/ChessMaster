import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';

/// 1.e4 e6 2.d4 d5 3.e5 — the French Advance, Black to move, and the root of
/// the repertoire here. The same three positions the layout tests use, because
/// what is being tested is what happens *along* a line and three plies is the
/// shortest line that has a middle.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// After 3...c5, White to move.
const afterC5 = 'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4';

/// After 4.c3, Black to move — a position this screen can ask about.
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

String keyOf(String fen) => fen.split(' ').take(4).join(' ');

AnalysisLine line({
  String eval = '+0.35',
  int depth = 20,
  String lan = 'c7c5',
  String san = 'c5',
  String continuation = '3... c5 4. c3',
}) =>
    AnalysisLine(
      multipv: 1,
      depth: depth,
      evaluation: eval,
      bestMoveLan: lan,
      bestMoveSan: san,
      continuationLan: lan,
      continuationSan: continuation,
      sanMoveList: [san],
      fenList: const [],
      fromSquare: lan.substring(0, 2),
      toSquare: lan.substring(2, 4),
    );

class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What the store holds, and everything written into it.
  final Map<String, RepertoireNote> stored = {};
  final List<Map<String, Object?>> written = [];

  /// The review list the server would answer with, and how it was asked for.
  DisagreementReport? report;
  String? askedFrom;

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
  }) async =>
      const RepertoireFrontier(
        // The board starts three plies in, so the line above it has a middle.
        open: [
          FrontierNode(
              fen: afterC3, path: ['c5', 'c3'], reach: 1, kind: 'undecided')
        ],
        decided: 1,
      );

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      const [];

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int maxPly = 16,
    String? gateUci,
    String? breadth,
  }) async =>
      const RepertoireTree(
        rootFen: advance,
        rootPath: ['e4', 'e6', 'd4', 'd5', 'e5'],
        children: [
          RepertoireTreeMove(
            uci: 'c7c5',
            san: 'c5',
            fen: afterC5,
            mine: true,
            role: 'primary',
            children: [
              RepertoireTreeMove(
                uci: 'c2c3',
                san: 'c3',
                fen: afterC3,
                mine: false,
                share: 0.64,
                state: 'open',
              ),
            ],
          ),
        ],
      );

  @override
  Future<Map<String, RepertoireNote>> notes({required String color}) async =>
      Map.of(stored);

  @override
  Future<RepertoireNote?> putNote({
    required String color,
    required String fen,
    required int evalCp,
    int? mateIn,
    int evalDepth = 0,
    String? bestUci,
    String? bestLineSan,
  }) async {
    written.add({
      'fen': fen,
      'evalCp': evalCp,
      'mateIn': mateIn,
      'evalDepth': evalDepth,
      'bestUci': bestUci,
      'bestLineSan': bestLineSan,
    });
    final note = RepertoireNote(
      fenKey: keyOf(fen),
      evalCp: evalCp,
      mateIn: mateIn,
      evalDepth: evalDepth,
      bestUci: bestUci,
      bestLineSan: bestLineSan,
      updatedAt: DateTime(2026, 8, 31),
    );
    stored[note.fenKey] = note;
    return note;
  }

  @override
  Future<DisagreementReport?> disagreements({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? fromFen,
    String? gateUci,
  }) async {
    askedFrom = fromFen;
    return report;
  }
}

class _SilentJudge implements OpeningJudgeService {
  @override
  bool get hasPersonalToken => false;

  @override
  Future<OpeningJudgeLookup> judge(String fen, String move,
          {int? minRating}) async =>
      const OpeningJudgeLookup.unavailable('no-token');

  @override
  Future<OpponentRepliesLookup> replies(String fen, {int? minRating}) async =>
      const OpponentRepliesLookup.unavailable('no-token');

  @override
  void clearCache() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the note itself', () {
    test('reads as an evaluation, and a mate reads as a mate', () {
      // A forced mate written as a large number of pawns is a number that reads
      // as an evaluation, which is why the two are stored apart.
      const plain = RepertoireNote(fenKey: 'x', evalCp: 35, evalDepth: 20);
      expect(plain.text, '+0.35');
      const mate =
          RepertoireNote(fenKey: 'x', evalCp: 9600, mateIn: 4, evalDepth: 20);
      expect(mate.text, 'M4');
      const against =
          RepertoireNote(fenKey: 'x', evalCp: -9600, mateIn: -4, evalDepth: 20);
      expect(against.text, '-M4');
    });

    test('hands the tree the units that widget already draws', () {
      // VisualMoveTreeWidget reads a mate back as ±(1000 − moves). Converting
      // in one place is the whole point: this app has had one node carrying two
      // evaluations two orders of magnitude apart.
      const plain = RepertoireNote(fenKey: 'x', evalCp: 35);
      expect(plain.treeEval, closeTo(0.35, 0.0001));
      const mate = RepertoireNote(fenKey: 'x', evalCp: 9600, mateIn: 4);
      expect(mate.treeEval, 996);
      const against = RepertoireNote(fenKey: 'x', evalCp: -9600, mateIn: -4);
      expect(against.treeEval, -996);
    });
  });

  group('on the build screen', () {
    late _FakeApi api;
    late List<String> asked;

    Future<void> pump(
      WidgetTester tester, {
      Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
          analyse,
      Map<String, RepertoireNote> seed = const {},
      Size size = const Size(1600, 1200),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      api = _FakeApi();
      // Seeded before the screen reads them: the notes are read once, beside
      // the picture, so a store changed afterwards is a store the screen has
      // not been told about.
      api.stored.addAll(seed);
      asked = [];
      await tester.pumpWidget(MaterialApp(
        home: RepertoireBuildScreen(
          name: 'French Advance — crni',
          color: 'b',
          rootFen: advance,
          rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
          api: api,
          judge: _SilentJudge(),
          analyse: analyse ??
              (fen, depth, multiPV) async {
                asked.add(fen);
                return [line()];
              },
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('asking the engine keeps what it said, with its depth',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Pitaj motor'));
      await tester.pumpAndSettle();

      expect(api.written.length, 1);
      final note = api.written.single;
      expect(note['fen'], afterC3);
      // 0.35 pawns, White-relative, as centipawns — and the engine's move by
      // UCI, because comparing SAN spelled by two different libraries is the
      // silent mismatch this codebase keeps meeting.
      expect(note['evalCp'], 35);
      expect(note['evalDepth'], 20);
      expect(note['bestUci'], 'c7c5');
      expect(note['mateIn'], isNull);
    });

    testWidgets('a mate is stored as a mate', (tester) async {
      await pump(tester, analyse: (fen, depth, multiPV) async {
        asked.add(fen);
        return [line(eval: '-M4')];
      });
      await tester.tap(find.text('Pitaj motor'));
      await tester.pumpAndSettle();

      expect(api.written.single['mateIn'], -4);
      // Collapsed into centipawns as well, so anything that sorts or subtracts
      // has one number to use.
      expect(api.written.single['evalCp'], -9600);
    });

    testWidgets('the stored evaluation is on screen with its depth and date',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Pitaj motor'));
      await tester.pumpAndSettle();

      // An eval without its depth is a number that ages invisibly: depth 12
      // from a fortnight ago and depth 30 from a minute ago look identical.
      expect(find.textContaining('Sačuvano: +0.35'), findsOneWidget);
      expect(find.textContaining('dubina 20'), findsOneWidget);
      expect(find.textContaining('31.8.2026.'), findsOneWidget);
    });

    testWidgets('a position the engine never answered stores nothing',
        (tester) async {
      // Silence is said out loud rather than written down as an evaluation of
      // zero, which is a real number about a position nobody looked at.
      await pump(tester, analyse: (fen, depth, multiPV) async => const []);
      await tester.tap(find.text('Pitaj motor'));
      await tester.pumpAndSettle();

      expect(api.written, isEmpty);
      expect(find.textContaining('Motor nije odgovorio'), findsOneWidget);
    });
  });
}
