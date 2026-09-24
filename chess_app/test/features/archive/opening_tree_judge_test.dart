// `docs/PLAN-MOJE-PARTIJE.md` §9.3 — judging a player's opening habits on the
// desktop. No engine, no server: a fake analyzer stands in for
// `UciEngine.analyze` and a fake sender stands in for
// `ArchiveApiService.sendJudgements`, so what is under test is the judge's
// own logic — which moves it asks about, how it builds what it sends, and
// when it stops.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/opening_tree_judge.dart';
import 'package:chess_app/models/analysis_models.dart';

const _whiteToMove = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _blackToMove =
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

AnalysisLine _line(String fen,
        {required int rank,
        required String eval,
        required String uci,
        int depth = 20}) =>
    AnalysisLine.fromPv(
        multipv: rank,
        depth: depth,
        eval: eval,
        pvString: uci,
        startingFen: fen);

LeakReportMove _habit(String san,
        {String? uci, HabitJudgement? judgement, int? bookGames}) =>
    LeakReportMove(
      san: san,
      games: 10,
      score: 0.4,
      share: 0.3,
      uci: uci,
      habit: true,
      bookGames: bookGames,
      judgement: judgement,
    );

LeakReportMove _notHabit(String san, {String? uci}) => LeakReportMove(
      san: san,
      games: 2,
      score: 0.5,
      share: 0.05,
      uci: uci,
      habit: false,
    );

LeakReportNode _node(String fen, List<LeakReportMove> moves,
        {String? fenKey}) =>
    LeakReportNode(
      fenKey: fenKey ?? fen,
      fen: fen,
      ply: 2,
      games: 10,
      score: 0.4,
      moves: moves,
    );

HabitJudgement _judgedAt(int depth) => HabitJudgement(
      verdict: HabitVerdict.holds,
      lostChances: 2,
      bestUci: 'd2d4',
      bestLine: const ['d4'],
      moveLine: const ['e4'],
      depth: depth,
      engine: 'old-engine',
    );

/// One search call, recorded so a test can tell which position and which
/// shape of search (two lines, or one move alone) the judge actually asked.
typedef _Call = ({
  int depth,
  int multiPV,
  List<String>? searchMoves,
  String fen
});

class _FakeEngine {
  _FakeEngine(this._answer);

  final List<AnalysisLine> Function(_Call call) _answer;
  final calls = <_Call>[];

  Future<List<AnalysisLine>> call(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final call =
        (depth: depth, multiPV: multiPV, searchMoves: searchMoves, fen: fen);
    calls.add(call);
    return _answer(call);
  }
}

/// An engine that must never be asked anything — for „never searched".
Future<List<AnalysisLine>> _neverAsk(
  String fen, {
  required int depth,
  required int multiPV,
  List<String>? searchMoves,
  Duration timeout = const Duration(minutes: 2),
}) async {
  fail('the engine should not have been asked about $fen');
}

void main() {
  group('a habit move out of book', () {
    // best +2.00 (67.62 winning chances) against played 0.00 (50.00): a loss
    // of 17.62 — inside (kMistakeLoss, kGrossLossInBook), so bookGames decides
    // the verdict on its own.
    _FakeEngine engineFor(String moveUci) => _FakeEngine((call) {
          if (call.searchMoves == null) {
            return [
              _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
              _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
            ];
          }
          expect(call.searchMoves, [moveUci]);
          return [_line(_whiteToMove, rank: 1, eval: '0.00', uci: moveUci)];
        });

    test('loses 17.6 chances, sent as a mistake when it is not theory',
        () async {
      final engine = engineFor('e2e4');
      final sent = <Map<String, dynamic>>[];
      final judge = OpeningTreeJudge(
        analyzers: [engine.call],
        engine: 'test-engine',
        send: (batch) async => sent.addAll(batch),
      );
      await judge.run([
        _node(_whiteToMove, [_habit('e4', uci: 'e2e4', bookGames: 0)])
      ]);

      expect(sent, hasLength(1));
      final item = sent.single;
      expect(item['verdict'], 'mistake');
      expect(item['reason'], 'lostChances');
      expect(item['moveUci'], 'e2e4');
      expect(item['bestUci'], 'd2d4');
      expect(item['bestLine'], ['d4']);
      expect(item['moveLine'], ['e4']);
      expect((item['wBest'] as double) - (item['wMove'] as double),
          closeTo(17.62, 0.1));
    });

    test('the same loss holds when the masters play it 10 times', () async {
      final engine = engineFor('e2e4');
      final sent = <Map<String, dynamic>>[];
      final judge = OpeningTreeJudge(
        analyzers: [engine.call],
        engine: 'test-engine',
        send: (batch) async => sent.addAll(batch),
      );
      await judge.run([
        _node(_whiteToMove, [_habit('e4', uci: 'e2e4', bookGames: 10)])
      ]);

      expect(sent.single['verdict'], 'holds');
      expect(sent.single['reason'], isNull);
    });
  });

  test('a move that is not a habit is never searched and never sent', () async {
    final sent = <Map<String, dynamic>>[];
    final judge = OpeningTreeJudge(
      analyzers: [_neverAsk],
      engine: 'test-engine',
      send: (batch) async => sent.addAll(batch),
    );
    await judge.run([
      _node(_whiteToMove, [_notHabit('e4', uci: 'e2e4')])
    ]);
    expect(sent, isEmpty);
  });

  test(
      'a habit already judged at the asked depth is not searched again; a '
      'shallower one is', () async {
    // An engine that answers the position it is asked about, and the move it
    // is asked about when `searchmoves` names one.
    final engine = _FakeEngine((call) => call.searchMoves != null
        ? [
            _line(call.fen,
                rank: 1, eval: '0.00', uci: call.searchMoves!.single)
          ]
        : call.fen == _blackToMove
            ? [
                _line(_blackToMove, rank: 1, eval: '-0.20', uci: 'c7c5'),
                _line(_blackToMove, rank: 2, eval: '-0.10', uci: 'e7e6'),
              ]
            : [
                _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
                _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
              ]);
    final sent = <Map<String, dynamic>>[];
    final judge = OpeningTreeJudge(
      analyzers: [engine.call],
      engine: 'test-engine',
      depth: 20,
      send: (batch) async => sent.addAll(batch),
    );
    final deep = _node(
        _whiteToMove, [_habit('e4', uci: 'e2e4', judgement: _judgedAt(20))],
        fenKey: 'deep');
    final shallow = _node(
        _blackToMove, [_habit('e5', uci: 'e7e5', judgement: _judgedAt(16))],
        fenKey: 'shallow');

    await judge.run([deep, shallow]);

    expect(engine.calls.any((c) => c.fen == _whiteToMove), isFalse,
        reason: 'the move already judged at this depth needs no search');
    expect(engine.calls.every((c) => c.fen == _blackToMove), isTrue);
    expect(sent, hasLength(1));
    expect(sent.single['fenKey'], 'shallow');
  });

  test('a habit move that heads one of the two lines costs no extra search',
      () async {
    final engine = _FakeEngine((call) => [
          _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
          _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
        ]);
    final sent = <Map<String, dynamic>>[];
    final judge = OpeningTreeJudge(
      analyzers: [engine.call],
      engine: 'test-engine',
      send: (batch) async => sent.addAll(batch),
    );
    await judge.run([
      _node(_whiteToMove, [_habit('Nf3', uci: 'g1f3')])
    ]);

    expect(engine.calls, hasLength(1),
        reason: 'g1f3 already heads the second line; nothing more to ask');
    expect(sent.single['moveUci'], 'g1f3');
    expect(sent.single['verdict'], 'holds');
  });

  test('after cancel, nothing more is sent', () async {
    final engine = _FakeEngine((call) => call.searchMoves != null
        ? [
            _line(call.fen,
                rank: 1, eval: '0.00', uci: call.searchMoves!.single)
          ]
        : [
            _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
            _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
          ]);
    final sent = <List<Map<String, dynamic>>>[];
    late final OpeningTreeJudge judge;
    judge = OpeningTreeJudge(
      analyzers: [engine.call],
      engine: 'test-engine',
      batchSize: 1,
      send: (batch) async {
        sent.add(batch);
        judge.cancel();
        return null;
      },
    );

    await judge.run([
      _node(_whiteToMove, [_habit('e4', uci: 'e2e4')], fenKey: 'n1'),
      _node(_whiteToMove, [_habit('e4', uci: 'e2e4')], fenKey: 'n2'),
      _node(_whiteToMove, [_habit('e4', uci: 'e2e4')], fenKey: 'n3'),
    ]);

    expect(sent, hasLength(1),
        reason: 'the first batch went out, then it stopped');
    expect(sent.single.single['fenKey'], 'n1');
    // Only the first node's two-line search (and its searchmoves follow-up,
    // since e2e4 heads neither line) ran; the other two nodes were never
    // reached once the run was cancelled.
    expect(engine.calls.every((c) => c.fen == _whiteToMove), isTrue);
    expect(engine.calls.length, 2);
  });

  group('an answer that is not one is never sent, and is counted', () {
    // Added by the lead after grading: a search stopped by its timeout answers
    // what it had, and the first draft sent it labelled with the depth asked.

    OpeningTreeJudge judgeWith(_FakeEngine engine, List<Object?> sent,
            {Object? Function()? answer}) =>
        OpeningTreeJudge(
          analyzers: [engine.call],
          engine: 'test-engine',
          send: (batch) async {
            sent.addAll(batch);
            return answer?.call();
          },
        );

    test('two lines that stopped short of the depth asked', () async {
      final engine = _FakeEngine((call) => [
            _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4', depth: 14),
            _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3', depth: 14),
          ]);
      final sent = <Object?>[];
      final result = await judgeWith(engine, sent).run([
        _node(_whiteToMove, [_habit('Nf3', uci: 'g1f3')])
      ]);
      expect(sent, isEmpty);
      expect(result.judged, 0);
      expect(result.unjudged.single.why, 'a line stopped at depth 14/14 of 20');
    });

    test('a searchmoves answer that stopped short', () async {
      final engine = _FakeEngine((call) => call.searchMoves == null
          ? [
              _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
              _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
            ]
          : [
              _line(_whiteToMove, rank: 1, eval: '0.00', uci: 'e2e4', depth: 17)
            ]);
      final sent = <Object?>[];
      final result = await judgeWith(engine, sent).run([
        _node(_whiteToMove, [_habit('e4', uci: 'e2e4')])
      ]);
      expect(sent, isEmpty);
      expect(result.unjudged.single.moveUci, 'e2e4');
    });

    test('an engine that ignored searchmoves is not read as the move asked',
        () async {
      // It answers its own best move: read as e2e4, e4 would lose nothing.
      final engine = _FakeEngine((call) => call.searchMoves == null
          ? [
              _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
              _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
            ]
          : [_line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4')]);
      final sent = <Object?>[];
      final result = await judgeWith(engine, sent).run([
        _node(_whiteToMove, [_habit('e4', uci: 'e2e4')])
      ]);
      expect(sent, isEmpty);
      expect(result.unjudged.single.why, contains('not e2e4'));
    });

    test('an engine that fails on one position leaves the others judged',
        () async {
      final engine = _FakeEngine((call) {
        if (call.fen == _blackToMove) throw StateError('engine gone');
        return [
          _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
          _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
        ];
      });
      final sent = <Object?>[];
      final result = await judgeWith(engine, sent).run([
        _node(_blackToMove, [_habit('e5', uci: 'e7e5')], fenKey: 'broken'),
        _node(_whiteToMove, [_habit('Nf3', uci: 'g1f3')], fenKey: 'fine'),
      ]);
      expect(sent, hasLength(1));
      expect(result.unjudged.single.fenKey, 'broken');
      expect(result.summary, 'Judged 1 move. 1 move could not be judged.');
    });

    test('what the server refused is counted and said', () async {
      final engine = _FakeEngine((call) => [
            _line(_whiteToMove, rank: 1, eval: '+2.00', uci: 'd2d4'),
            _line(_whiteToMove, rank: 2, eval: '+1.00', uci: 'g1f3'),
          ]);
      final sent = <Object?>[];
      final result = await judgeWith(engine, sent,
          answer: () => const JudgementTally(
              read: 1,
              stored: 0,
              replaced: 0,
              keptDeeper: 0,
              rejected: 1)).run([
        _node(_whiteToMove, [_habit('Nf3', uci: 'g1f3')])
      ]);
      expect(result.rejected, 1);
      expect(result.summary, 'Judged 1 move. The server refused 1.');
    });
  });

  test('a node whose side to move is Black is judged from Black\'s side',
      () async {
    // +1.50 from White's view is good for White and bad for Black — the side
    // actually to move here. If the judge forgot to flip perspective, this
    // would read as a *strong* position for the side to move instead.
    final engine = _FakeEngine((call) {
      if (call.searchMoves == null) {
        return [
          _line(_blackToMove, rank: 1, eval: '+1.50', uci: 'e7e5'),
          _line(_blackToMove, rank: 2, eval: '+1.60', uci: 'c7c5'),
        ];
      }
      return [_line(_blackToMove, rank: 1, eval: '+1.55', uci: 'g8f6')];
    });
    final sent = <Map<String, dynamic>>[];
    final judge = OpeningTreeJudge(
      analyzers: [engine.call],
      engine: 'test-engine',
      send: (batch) async => sent.addAll(batch),
    );
    await judge.run([
      _node(_blackToMove, [_habit('Nf6', uci: 'g8f6')])
    ]);

    final wBest = sent.single['wBest'] as double;
    expect(wBest, lessThan(50),
        reason: 'White stands better, so the side to move (Black) should '
            'read as worse than even, not better');
  });
}
