import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// The drawing has to contain the position the board is standing on.
///
/// Reported live 5.9.2026, and the way in was „Idi" on an opponent's reply:
/// „posle izbora poteza protivnika, taj potez se ne prikazuje na stablu poteza,
/// a trebalo bi — da vidim i u stablu na šta treba da odgovaram."
///
/// The read is made *from where the board is*: `maxPly` since 4.9.2026 and
/// `alongPath` since 5.9.2026. A drawing fetched at an earlier position can
/// therefore genuinely lack the card for this one, and the screen used to
/// re-read only when the store changed — „the tree only moves when the moves
/// do", which stopped being true when the picture started following the reader.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// After 3...c5 — the student's own move, and the position the replies answer.
const afterC5 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4';

/// After 4.c3 — the reply the reader presses „Idi" on.
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

/// A server that answers the way the real one does: the card for the reply is
/// in the drawing only when the read was made from a line that reaches it.
///
/// Not a stub that always answers everything — that is the shape of fake that
/// let this bug through, because the screen never had to ask again.
class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  final List<List<String>> treeReads = [];

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
        open: [
          FrontierNode(fen: advance, path: [], reach: 1, kind: 'undecided')
        ],
        decided: 1,
        draft: 0,
      );

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int maxPly = 16,
    String? gateUci,
    String? breadth,
    List<String> alongPath = const [],
  }) async {
    treeReads.add(alongPath);
    // The opponent's reply is drawn only when the walk was asked to follow the
    // line the reader is on — which is what `alongPath` is for.
    final reaches = alongPath.contains('c3');
    return RepertoireTree(
      rootFen: advance,
      rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
      children: [
        RepertoireTreeMove(
          uci: 'c7c5',
          san: 'c5',
          fen: afterC5,
          mine: true,
          role: 'primary',
          children: [
            if (reaches)
              const RepertoireTreeMove(
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
  }

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      fen == advance
          ? const [RepertoireMove(uci: 'c7c5', san: 'c5', role: 'primary')]
          : const [];

  /// The book for the position after the student's move, with one reply that
  /// is already being prepared — which is what puts „Idi" on its row.
  @override
  Future<StoredBook?> storedBook({
    required String color,
    required String fen,
    int? minRating,
  }) async =>
      const StoredBook(
        fen: afterC5,
        opened: true,
        replies: [
          StoredReply(
              uci: 'c2c3',
              san: 'c3',
              games: 640,
              share: 0.64,
              covered: true,
              prepared: true),
        ],
      );

  @override
  Future<RepertoireUnconfirmedWalk?> unconfirmedPositions({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
    String? breadth,
    int? minRating,
    int? limit,
  }) async =>
      const RepertoireUnconfirmedWalk();
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

  late _FakeApi api;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        id: 7,
        api: api,
        judge: _SilentJudge(),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Stands the board after the student's own move, which is what puts the
  /// „Posle c5 — šta igra protivnik" panel and its „Idi" on screen.
  Future<void> standAfterC5(WidgetTester tester) async {
    // The card's label carries the mark as well as the move: „c5 ★".
    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();
  }

  testWidgets('„Idi" puts the opponent reply on the drawing', (tester) async {
    await pump(tester);
    await standAfterC5(tester);

    expect(find.text('Idi'), findsOneWidget,
        reason: 'nema dugmeta „Idi" — pripremljen odgovor nije ponuđen');
    // In the drawing, not in the list of replies under the board — that row
    // says „c3" whatever the picture holds, and matching it would be the test
    // passing on the wrong widget.
    final cardForC3 = find.descendant(
      of: find.byType(VisualMoveTreeWidget),
      matching: find.textContaining('c3'),
    );
    expect(find.byType(VisualMoveTreeWidget), findsOneWidget);
    expect(cardForC3, findsNothing,
        reason: 'crtež već sadrži potez, pa test ne dokazuje ništa');

    await tester.tap(find.text('Idi'));
    await tester.pumpAndSettle();

    // The board went there, and so did the picture.
    expect(cardForC3, findsWidgets,
        reason: 'potez protivnika se ne vidi u stablu posle „Idi"');
    expect(api.treeReads.last, contains('c3'),
        reason: 'crtež nije ponovo pročitan sa linije na kojoj tabla stoji');
  });

  testWidgets('a board move inside the drawing costs no second read',
      (tester) async {
    // The other half of the rule, and the reason it is a condition rather than
    // a re-read on every advance: walking around inside a picture that already
    // holds the line asks the server nothing.
    await pump(tester);
    final reads = api.treeReads.length;

    await standAfterC5(tester);

    expect(api.treeReads.length, reads,
        reason: 'crtež je ponovo čitan iako već sadrži poziciju');
  });
}
