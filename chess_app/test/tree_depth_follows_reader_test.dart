import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// The drawing has to be able to hold the move being decided.
///
/// The tree was asked for at the client default of sixteen plies — eight moves
/// — and the depth was never sent at all. Standing on move seven, as the owner
/// was on 4.9.2026, the move you take next lands on ply fifteen and the one
/// after it past the edge: „aplikacija ne upisuje taj potez u stablo odmah".
/// It was written. The picture could not reach it.
class _WireApi extends RepertoireApiService {
  _WireApi._(this.seen, http.Client client) : super(client: client);

  factory _WireApi() {
    final seen = <Uri>[];
    return _WireApi._(
      seen,
      MockClient((req) async {
        seen.add(req.url);
        return http.Response('{}', 200);
      }),
    );
  }

  final List<Uri> seen;

  /// One open position, deep in a line, so the board lands there and the depth
  /// the screen computes is not the same number as the old default.
  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int? limit,
    String? gateUci,
    String? breadth,
  }) async =>
      RepertoireFrontier(
        open: [
          FrontierNode(
            fen: _fenAfterLine(),
            path: _line,
            reach: 1,
            kind: 'undecided',
          ),
        ],
      );

  Uri? lastFor(String suffix) {
    for (final u in seen.reversed) {
      if (u.path.endsWith(suffix)) return u;
    }
    return null;
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

/// Seven of the reader's own moves past this repertoire's root, which is
/// already six plies in — the depth the owner was working at on 4.9.2026.
///
/// Played out rather than typed: a FEN copied by hand into a test is a FEN
/// nobody checked, and the board would refuse it long before the assertion ran.
const _line = [
  'O-O', 'Nf6', 'd3', 'a6', 'c3', 'Ba7', 'Bb3', 'd6', //
  'h3', 'O-O', 'Re1', 'Ne7', 'Nbd2', 'Ng6',
];

String _fenAfterLine() {
  final board = chess.Chess.fromFEN(_italian);
  for (final san in _line) {
    if (!board.move(san)) throw StateError('nemoguć potez u testu: \$san');
  }
  return board.fen;
}

const _italian =
    'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the rule itself', () {
    test('shallow work keeps the old depth', () {
      expect(treeDepthFor(0), 16);
      expect(treeDepthFor(7), 16);
      // Eight plies in, sixteen is still four moves of room.
      expect(treeDepthFor(8), 16);
    });

    test('deep work is followed, with room past the board', () {
      // The owner's line: 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.O-O Nf6 5.d3 a6 6.c3
      // Ba7 7.Bb3 is thirteen plies from move one — seven past this
      // repertoire's own root.
      expect(treeDepthFor(13), 21);
      expect(treeDepthFor(20), 28);
    });

    test('never past what the server allows', () {
      expect(treeDepthFor(40), 40);
      expect(treeDepthFor(400), 40);
    });
  });

  testWidgets('the screen sends a depth at all', (tester) async {
    // The half the arithmetic cannot prove: the number has to leave the app.
    // It did not, for as long as this endpoint existed — the same shape as the
    // width, which was stored and never sent.
    final api = _WireApi();
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'Italian Game: Giuoco Piano — beli',
        color: 'w',
        rootFen: _italian,
        rootPath: const ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5'],
        api: api,
        judge: _SilentJudge(),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    final asked = api.lastFor('/repertoire/tree');
    expect(asked, isNotNull, reason: 'stablo se uopšte nije tražilo');
    final sent = int.tryParse(asked!.queryParameters['maxPly'] ?? '');
    expect(sent, treeDepthFor(_line.length), reason: 'dubina ne prati tablu');
    // And it has to be a different number from the one the client would send
    // on its own, or this proves nothing at all — which is what the first
    // version of this test did, and it passed with the depth ripped out.
    expect(sent, greaterThan(16),
        reason: 'ista brojka kao stari podrazumevani — test ništa ne dokazuje');
  });
}
