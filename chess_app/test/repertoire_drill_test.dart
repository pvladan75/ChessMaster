import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// The Smith-Morra accepted, Black to move.
const smithMorra = 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

/// A drill server with no server: it hands back one question and grades the
/// answer against a fixed decision.
class _FakeApi extends RepertoireApiService {
  _FakeApi({
    this.outcomeFor,
    this.reply = 'g1f3',
    this.replyCovered = true,
    this.item = smithMorra,
    this.stats = const DrillStats(positions: 6, due: 2, known: 1, fresh: 3),
  }) : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What this student decided to play here: 4...Nc6 in the Smith-Morra.
  static const primaryUci = 'b8c6';
  static const primarySan = 'Nc6';

  final String? outcomeFor;
  final String? reply;
  final bool replyCovered;
  final String? item;
  final DrillStats stats;

  int loads = 0;
  int reveals = 0;
  bool? lastRevealedFlag;

  @override
  Future<({DrillItem? item, DrillStats stats})> nextDrill(
      {required String color}) async {
    loads += 1;
    return (
      item: item == null
          ? null
          : DrillItem(fen: item!, fresh: false, repetitions: 3, moves: 2),
      stats: stats,
    );
  }

  @override
  Future<RepertoireMove?> revealDrill({
    required String color,
    required String fen,
  }) async {
    reveals += 1;
    return RepertoireMove(uci: primaryUci, san: primarySan, role: 'primary');
  }

  @override
  Future<DrillAnswer?> answerDrill({
    required String color,
    required String fen,
    required String uci,
    bool revealed = false,
    int? minRating,
  }) async {
    lastRevealedFlag = revealed;
    final outcome = outcomeFor ?? (uci == primaryUci ? 'primary' : 'unknown');
    return DrillAnswer(
      outcome: outcome,
      primary: outcome == 'unprepared'
          ? null
          : RepertoireMove(uci: primaryUci, san: primarySan, role: 'primary'),
      intervalDays: outcome == 'primary' ? 6 : 0,
      reply: outcome == 'unprepared' ? null : reply,
      replyCovered: replyCovered,
    );
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeApi api, {
    void Function(String fen)? onBuildHere,
    Size size = const Size(500, 1000),
    Key? key,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RepertoireDrillScreen(
        key: key,
        name: 'Smit-Mora, crni',
        color: 'b',
        api: api,
        onBuildHere: onBuildHere,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final square = widget.boardSize / 8;
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    await tester.tapAt(at(from));
    await tester.pumpAndSettle();
    await tester.tapAt(at(to));
    await tester.pumpAndSettle();
  }

  testWidgets('the question comes without its answer', (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    // The move the student decided on is nowhere on the screen until they ask
    // for it or play something.
    expect(find.textContaining('Nc6'), findsNothing);
    expect(find.textContaining('na redu: 2'), findsOneWidget);
  });

  testWidgets('the move they decided on is a pass, and says when it returns',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'b8', 'c6');

    expect(find.textContaining('Tačno'), findsOneWidget);
    expect(find.textContaining('Vraća se za 6 dana'), findsOneWidget);
    expect(api.lastRevealedFlag, false);
  });

  testWidgets('good chess that is not their decision is still a miss',
      (tester) async {
    // The drill asks about a decision. Accepting anything sound would make the
    // schedule meaningless, because everything would always be a pass.
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'g8', 'f6');

    expect(find.textContaining('Nije to'), findsOneWidget);
    expect(find.textContaining('Vaš potez je Nc6'), findsOneWidget);
  });

  testWidgets('asking to be shown marks the answer as recognised',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await tester.tap(find.text('Pokaži'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vaš potez je Nc6'), findsOneWidget);
    expect(api.reveals, 1);

    await play(tester, 'b8', 'c6');
    expect(api.lastRevealedFlag, true,
        reason: 'prepoznato nije isto što i zapamćeno');
  });

  testWidgets('the opponent answers, and an unprepared reply is named as such',
      (tester) async {
    final api = _FakeApi(reply: 'a2a3', replyCovered: false);
    await pump(tester, api);

    await play(tester, 'b8', 'c6');

    expect(find.textContaining('Protivnik je odgovorio a3'), findsOneWidget);
    expect(find.textContaining('to niste pokrili'), findsOneWidget);
  });

  testWidgets('a position that was never built offers to build it',
      (tester) async {
    String? asked;
    final api = _FakeApi(outcomeFor: 'unprepared');
    await pump(tester, api, onBuildHere: (fen) => asked = fen);

    await play(tester, 'b8', 'c6');
    expect(find.textContaining('niste pokrili'), findsOneWidget);

    await tester.tap(find.text('Izgradi ovu poziciju'));
    await tester.pumpAndSettle();
    expect(asked, smithMorra,
        reason: 'gradi se pozicija u kojoj je stao, ne neka druga');
  });

  testWidgets('an empty schedule is told apart from an empty repertoire',
      (tester) async {
    final nothingBuilt = _FakeApi(
      item: null,
      stats: const DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
    );
    // A key per case: without one Flutter reuses the same State across the two
    // pumps, initState never runs again, and the second case quietly asserts
    // against the first one's data.
    await pump(tester, nothingBuilt, key: const ValueKey('nista-izgradjeno'));
    expect(find.text('Još nema šta da se vežba.'), findsOneWidget);

    final nothingDue = _FakeApi(
      item: null,
      stats: const DrillStats(positions: 20, due: 0, known: 9, fresh: 0),
    );
    await pump(tester, nothingDue, key: const ValueKey('nista-na-redu'));
    expect(find.text('Ništa nije na redu.'), findsOneWidget);
    expect(find.textContaining('znate 9 od 20'), findsOneWidget);
  });

  testWidgets('the drill fits a 360 dp phone', (tester) async {
    final api = _FakeApi();
    await pump(tester, api, size: const Size(360, 640));
    expect(tester.takeException(), isNull);

    await play(tester, 'b8', 'c6');
    expect(tester.takeException(), isNull);
  });
}
