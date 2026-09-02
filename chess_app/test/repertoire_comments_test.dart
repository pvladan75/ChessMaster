import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_comment_panel.dart';
import 'package:chess_app/models/analysis_models.dart';

/// 1.e4 e6 2.d4 d5 3.e5 — the French Advance, Black to move, and the root of
/// the repertoire here, as in the other repertoire tests.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// After 3...c5, White to move.
const afterC5 = 'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4';

/// After 4.c3, Black to move — the position the board opens on.
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

String keyOf(String fen) => fen.split(' ').take(4).join(' ');

class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What the store holds, and every write that reached it.
  final Map<String, RepertoireComment> stored = {};
  final List<({String fen, String body})> written = [];

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
  }) async =>
      const RepertoireFrontier(
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
      const {};

  @override
  Future<Map<String, RepertoireComment>> comments(
          {required String color}) async =>
      Map.of(stored);

  final List<String> deleted = [];

  @override
  Future<bool> deleteComment({
    required String color,
    required String fen,
  }) async {
    deleted.add(fen);
    stored.remove(keyOf(fen));
    return true;
  }

  @override
  Future<({bool saved, RepertoireComment? comment})> putComment({
    required String color,
    required String fen,
    required String body,
  }) async {
    written.add((fen: fen, body: body));
    final key = keyOf(fen);
    if (body.trim().isEmpty) {
      stored.remove(key);
      return (saved: true, comment: null);
    }
    final one = RepertoireComment(
      fenKey: key,
      body: body.trim(),
      updatedAt: DateTime(2026, 9, 2),
    );
    stored[key] = one;
    return (saved: true, comment: one);
  }
}

/// A judge with nothing behind it: nothing here is about what Lichess says.
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

/// The list screen's server: enough of it to answer the two delete doors.
class _FakeListApi extends RepertoireApiService {
  _FakeListApi({this.items = const []})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  final List<RepertoireSummary> items;

  RepertoireRemoval? preview = const RepertoireRemoval(
    name: 'Francuska',
    color: 'b',
    positions: 12,
    moves: 18,
    decisions: 15,
    drafts: 3,
    comments: 2,
    shared: 4,
  );

  RepertoireColorStats? stats = const RepertoireColorStats(
    color: 'b',
    repertoires: 0,
    positions: 40,
    moves: 61,
    decisions: 55,
    drafts: 6,
    comments: 3,
  );

  final List<({int id, bool withMoves, bool withComments})> deleted = [];
  final List<({String color, bool withComments})> erased = [];

  @override
  Future<List<RepertoireSummary>> list() async => items;

  @override
  Future<RepertoireRemoval?> removalPreview(int id, {int? minRating}) async =>
      preview;

  @override
  Future<bool> deleteRepertoire(
    int id, {
    bool withMoves = false,
    bool includeComments = false,
  }) async {
    deleted.add((id: id, withMoves: withMoves, withComments: includeComments));
    return true;
  }

  @override
  Future<RepertoireColorStats?> colorStats({required String color}) async =>
      stats;

  @override
  Future<bool> eraseColor({
    required String color,
    bool includeComments = false,
  }) async {
    erased.add((color: color, withComments: includeComments));
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the panel itself', () {
    testWidgets('under the board it draws nothing until there is something',
        (tester) async {
      // The column under a board at 360 dp is the most expensive space in the
      // app. A card saying "nothing written" would push the question off the
      // bottom to say what the reader already knows.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RepertoireCommentPanel(
            body: null,
            dense: true,
            onEdit: () {},
          ),
        ),
      ));

      expect(find.text('Moj komentar'), findsNothing);
    });

    testWidgets('beside the board an empty comment is an invitation',
        (tester) async {
      // The other mounting, where the space was going to be empty anyway.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RepertoireCommentPanel(body: null, onEdit: () {}),
        ),
      ));

      expect(find.text('Moj komentar'), findsOneWidget);
      expect(find.byTooltip('Napiši komentar'), findsOneWidget);
      // Nothing to delete yet, so no button that would do it.
      expect(find.byTooltip('Obriši komentar'), findsNothing);
    });

    testWidgets('what was written is on screen, in both mountings',
        (tester) async {
      for (final dense in [true, false]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: RepertoireCommentPanel(
              body: 'Plan: c5 pa Nc6, i pritisak na d4.',
              dense: dense,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ));
        expect(find.text('Plan: c5 pa Nc6, i pritisak na d4.'), findsOneWidget,
            reason: 'komentar se ne vidi (dense: $dense)');
        expect(find.byTooltip('Obriši komentar'), findsOneWidget);
      }
    });
  });

  group('writing one from the build screen', () {
    late _FakeApi api;

    Future<void> pump(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: RepertoireBuildScreen(
          name: 'French Advance — crni',
          color: 'b',
          rootFen: advance,
          rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
          api: api,
          judge: _SilentJudge(),
          analyse: (fen, depth, multiPV) async => const <AnalysisLine>[],
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the strip under the board carries the two buttons',
        (tester) async {
      // Where the Analysis Studio keeps its comment button. Somebody who has
      // learned one screen should not have to hunt on the next.
      api = _FakeApi();
      await pump(tester, const Size(400, 900));

      expect(find.byTooltip('Dodaj komentar'), findsOneWidget);
      expect(find.byTooltip('Pitaj AI o poziciji'), findsOneWidget);
      // A phone folds them onto a second line rather than clipping them, which
      // in a release build is silent.
      expect(tester.takeException(), isNull);
    });

    testWidgets('what is typed reaches the server and then the screen',
        (tester) async {
      api = _FakeApi();
      await pump(tester, const Size(400, 900));

      await tester.tap(find.byTooltip('Dodaj komentar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pazi na Qb6 i Bd7-b5.');
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();

      expect(api.written.length, 1);
      expect(api.written.single.body, 'Pazi na Qb6 i Bd7-b5.');
      // The position the board is standing on, not the repertoire's root.
      expect(keyOf(api.written.single.fen), keyOf(afterC3));
      // Do the thing, then say it: the panel is drawn from what came back.
      expect(find.text('Pazi na Qb6 i Bd7-b5.'), findsOneWidget);
    });

    testWidgets('closing the editor without saving writes nothing',
        (tester) async {
      // An empty box is "clear this comment" and a closed sheet is "leave it
      // alone". They must not be the same answer.
      api = _FakeApi();
      await pump(tester, const Size(400, 900));

      await tester.tap(find.byTooltip('Dodaj komentar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nešto');
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(api.written, isEmpty);
    });

    testWidgets('a stored comment is on screen when the position comes back',
        (tester) async {
      // The whole point of storing it: come back to the position months later
      // and what you wrote is there.
      api = _FakeApi();
      api.stored[keyOf(afterC3)] = RepertoireComment(
        fenKey: keyOf(afterC3),
        body: 'Ovde se igra na kraljičino krilo.',
        updatedAt: DateTime(2026, 9, 1),
      );
      await pump(tester, const Size(400, 900));

      expect(find.text('Ovde se igra na kraljičino krilo.'), findsOneWidget);
    });

    testWidgets('the delete button takes the comment off the position',
        (tester) async {
      // Its own door rather than an emptied box: a screen with a delete button
      // should not have to send an empty string and hope.
      api = _FakeApi();
      api.stored[keyOf(afterC3)] = RepertoireComment(
        fenKey: keyOf(afterC3),
        body: 'Ovo više ne važi.',
        updatedAt: DateTime(2026, 9, 1),
      );
      await pump(tester, const Size(400, 900));

      await tester.tap(find.byTooltip('Obriši komentar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Obriši'));
      await tester.pumpAndSettle();

      expect(api.deleted.length, 1);
      expect(keyOf(api.deleted.single), keyOf(afterC3));
      expect(find.text('Ovo više ne važi.'), findsNothing);
    });

    testWidgets('on a wide desktop window the comment gets its own column',
        (tester) async {
      // Beside the board, not under it — and only one of them, or the same
      // comment would be on screen twice.
      api = _FakeApi();
      api.stored[keyOf(afterC3)] = RepertoireComment(
        fenKey: keyOf(afterC3),
        body: 'Kolona za komentar.',
        updatedAt: DateTime(2026, 9, 1),
      );
      await pump(tester, const Size(1400, 900));

      expect(tester.takeException(), isNull);
      expect(find.byType(RepertoireCommentPanel), findsOneWidget);
      expect(
        tester
            .widget<RepertoireCommentPanel>(find.byType(RepertoireCommentPanel))
            .dense,
        isFalse,
      );
    });

    testWidgets(
        'a window with room for two columns but not three keeps it '
        'under the board', (tester) async {
      // 840 is where the tree comes alongside; a third panel carved out at that
      // width would leave a picture too narrow to read.
      api = _FakeApi();
      api.stored[keyOf(afterC3)] = RepertoireComment(
        fenKey: keyOf(afterC3),
        body: 'Ispod table.',
        updatedAt: DateTime(2026, 9, 1),
      );
      await pump(tester, const Size(1000, 900));

      expect(tester.takeException(), isNull);
      expect(find.byType(RepertoireCommentPanel), findsOneWidget);
      expect(
        tester
            .widget<RepertoireCommentPanel>(find.byType(RepertoireCommentPanel))
            .dense,
        isTrue,
      );
    });
  });

  group('deleting moves from the list screen', () {
    testWidgets('deleting a repertoire still takes only the name by default',
        (tester) async {
      // The old behaviour, and it stays the default: the moves belong to the
      // colour, and another repertoire may be standing on them.
      final api = _FakeListApi(items: const [
        RepertoireSummary(
            id: 4, name: 'Francuska', color: 'b', rootFen: advance, moves: 61),
      ]);
      await tester
          .pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Još'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obriši repertoar'));
      await tester.pumpAndSettle();

      // The count is read out before anything is decided.
      expect(find.textContaining('18'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Obriši'));
      await tester.pumpAndSettle();

      expect(api.deleted.single.withMoves, isFalse);
      expect(api.deleted.single.withComments, isFalse);
    });

    testWidgets('ticking the box takes the moves with it, comments left alone',
        (tester) async {
      final api = _FakeListApi(items: const [
        RepertoireSummary(
            id: 4, name: 'Francuska', color: 'b', rootFen: advance, moves: 61),
      ]);
      await tester
          .pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Još'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obriši repertoar'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Obriši i poteze'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Obriši'));
      await tester.pumpAndSettle();

      expect(api.deleted.single.withMoves, isTrue);
      // Prose is the one thing here nothing can recompute, so it is not taken
      // unless it is asked for by name.
      expect(api.deleted.single.withComments, isFalse);
    });

    testWidgets('a colour can be emptied with no repertoire left at all',
        (tester) async {
      // The state the owner was in: every repertoire deleted, every move still
      // stored, and nothing anywhere that could reach them.
      final api = _FakeListApi(items: const []);
      await tester
          .pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Brisanje poteza iz baze'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obriši sve poteze za crnog'));
      await tester.pumpAndSettle();

      // Counted first, and the sentence says what else goes with the moves.
      expect(find.textContaining('61'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Obriši'));
      await tester.pumpAndSettle();

      expect(api.erased.single.color, 'b');
      expect(api.erased.single.withComments, isFalse);
    });

    testWidgets('the empty screen says where the moves went', (tester) async {
      // This is where it surprises somebody: no repertoires, and the next one
      // opens onto a tree full of moves already answered.
      final api = _FakeListApi(items: const []);
      await tester
          .pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.textContaining('sačuvani uz boju'), findsOneWidget);
    });
  });
}
