// The facts of a position study — docs/PLAN-STUDIJA-POZICIJE.md, §1 and §2.
//
// Built from the real engine's answers, recorded (`support/recorded_engine`):
// Stockfish 19 at depth 20, for the owner's two positions of 28.9.2026, one
// position of his own games with a threat in it, and three rook endings the
// tablebase knows — a win, the owner's own of 30.9.2026, and a draw. What is
// held here is what the owner asked for in his own
// words: the line 7...Be4 8.dxc6 Bxh1 9.Rxa7, „a capture that wins material
// and loses evaluation", and the threat as what the other side does if the
// side to move passes.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_board.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';

import 'support/recorded_engine.dart';

const _owner1 =
    'rn2kbnr/pp2pppp/2p5/3PNb2/8/1P4P1/1P1PPP1P/RNB1KB1R b KQkq - 0 7';
const _owner2 =
    'rn2kbnr/pp2pppp/2p5/3PN3/4b3/1P4P1/1P1PPP1P/RNB1KB1R w KQkq - 1 8';

Future<(PositionStudy, RecordedEngine)> _study(String name) async {
  final engine = RecordedEngine.read(name);
  final study = await PositionStudyBuilder(
    analyzer: engine.analyzer,
    depth: engine.depth,
    tablebase: engine.tablebase,
  ).build(engine.fen);
  expect(engine.unanswered, isEmpty,
      reason: 'the recording answers every question the builder asks');
  return (study, engine);
}

List<String> _sans(Iterable<StudyMove> line) => [for (final m in line) m.san];

void main() {
  group('the owner\'s position, Black to move', () {
    test('the main line is the engine\'s, and it is not the tempting move',
        () async {
      final (study, _) = await _study('owner1');
      expect(study.fen, _owner1);
      expect(study.side, 'Black');
      expect(_sans(study.mainLine.map((s) => s.move)).first, 'Bxb1');
      expect(study.mainLine.length,
          inInclusiveRange(kStudyMinPlies, kStudyMaxPlies));
    });

    test(
        '7...Be4 is shown, with the capture it was played for and what '
        'punishes it', () async {
      final (study, _) = await _study('owner1');
      final be4 = study.tempting.firstWhere((t) => t.move.san == 'Be4');
      expect(be4.natural.kind, NaturalKind.attack,
          reason: 'neither a capture nor a check: an attack on the rook');
      expect(be4.natural.aim?.san, 'Bxh1');
      expect(be4.defence.first.san, 'dxc6');

      final greedy = be4.greedy;
      expect(greedy, isNotNull, reason: 'the engine never plays 8...Bxh1');
      expect(greedy!.move.san, 'Bxh1');
      expect(greedy.move.captured, 'rook');
      expect(_sans(greedy.punishment).take(3), ['Rxa7', 'Rxa7', 'c7'],
          reason: 'the rook is taken, and the pawn runs');
      expect(_sans(greedy.punishment).any((s) => s.contains('=Q')), isTrue,
          reason: 'the line runs until the pawn queens');
      expect(_sans(greedy.declined).first, 'Nxc6',
          reason: 'the engine\'s own defence stands beside it');
      expect(greedy.lost, greaterThanOrEqualTo(kMistakeLoss));
    });

    test('a move that is only worse is shown as worse, not as a mistake',
        () async {
      final (study, _) = await _study('owner1');
      final be4 = study.tempting.firstWhere((t) => t.move.san == 'Be4');
      expect(be4.lost, lessThan(kMistakeLoss));
      expect(be4.lost, greaterThanOrEqualTo(kStudyCloseChoice));
      expect(be4.nag, '?!');
    });

    test(
        'a move that prepares nothing the line plays has no idea said of '
        'it', () async {
      final (study, engine) = await _study('owner1');
      final first = study.mainLine.first.move;
      expect(engine.asked, contains((passedFen(first.fenAfter)!, 1)),
          reason: 'what 7...Bxb1 prepares was asked');
      expect(study.idea, isNull);
    });

    test('passing costs Black the pawn back, and that is not a threat',
        () async {
      // With the other side to move the engine is three pawns happier and
      // plays a developing move: nothing is threatened, Black has only not
      // taken his pawn back.
      final (study, engine) = await _study('owner1');
      final passed = passedFen(_owner1)!;
      expect(engine.asked, contains((passed, 1)),
          reason: 'the threat was looked for');
      expect(study.threat, isNull);
    });
  });

  group('the owner\'s position after 7...Be4, White to move', () {
    test('8.dxc6 is the move, and 8...Bxh1 beside the main line is a trap',
        () async {
      final (study, _) = await _study('owner2');
      expect(study.fen, _owner2);
      expect(study.mainLine.first.move.san, 'dxc6');
      expect(study.mainLine.first.trap, isNull,
          reason: 'a trap belongs to the move it stands beside');

      final reply = study.mainLine[1];
      expect(reply.move.san, 'Nxc6');
      final trap = reply.trap;
      expect(trap, isNotNull);
      expect(trap!.move.san, 'Bxh1');
      expect(trap.recapture, isFalse);
      expect(_sans(trap.punishment).take(3), ['Rxa7', 'Rxa7', 'c7']);
      expect(trap.lost, greaterThanOrEqualTo(kMistakeLoss));
      expect(trap.move.taken, 5, reason: 'it wins material');
    });

    test('taking back on c6 with the knight only looks automatic', () async {
      final (study, _) = await _study('owner2');
      final third = study.mainLine[2];
      expect(third.move.san, 'f3');
      expect(third.trap?.move.san, 'Nxc6');
      expect(third.trap?.recapture, isTrue);
      expect(third.trap?.punishment.first.san, 'Bxh1');
    });

    test('the threat is the capture, with what it wins', () async {
      final (study, _) = await _study('owner2');
      final threat = study.threat;
      expect(threat, isNotNull);
      expect(threat!.move.san, 'Bxh1');
      expect(threat.won, greaterThanOrEqualTo(5));
      expect(threat.cost, greaterThanOrEqualTo(kMistakeLoss));
    });

    test('a pawn that takes a bishop is no only move worth a mark', () async {
      final (study, _) = await _study('owner2');
      final fxe4 = study.mainLine.firstWhere((s) => s.move.san == 'fxe4');
      expect(fxe4.trivial, isTrue);
      expect(fxe4.onlyMove, isFalse);
    });
  });

  group('a position from the owner\'s own games', () {
    test('the threat is a check that wins the queen', () async {
      final (study, _) = await _study('own1');
      expect(study.threat?.move.san, 'Nxe2+');
      expect(study.threat?.wonWords, contains('queen'));
    });

    test('no more positions are searched than the study says it may', () async {
      for (final name in ['owner1', 'owner2', 'own1', 'classic5']) {
        final (study, engine) = await _study(name);
        expect(study.searches, engine.asked.length, reason: name);
        expect(study.searches, lessThanOrEqualTo(kStudySearchBudget),
            reason: name);
        expect(study.problems, isEmpty, reason: name);
      }
    });
  });

  group('seven men or fewer', () {
    test('the tablebase says the result and which moves keep it', () async {
      final (study, engine) = await _study('classic5');
      expect(engine.askedTablebase.first, engine.fen);
      final tb = study.tablebase;
      expect(tb, isNotNull);
      expect(tb!.outcome, TablebaseOutcome.win);
      // In the tablebase's own order, best first — Rxc6 mates in 76 plies,
      // and Rc1+'s distance to mate is not known. Until 30.9.2026 the app
      // sorted again by the smallest DTZ and this read Rc1+, Rxc6.
      expect([for (final k in tb.keeping) k.san], ['Rxc6', 'Rc1+']);
      expect(tb.spoiling, isNotEmpty);
      expect(study.mainLine.first.move.san, 'Rxc6');
      expect(study.tempting, isEmpty,
          reason: 'the tablebase\'s list says which moves fail');
    });

    // The owner's rook ending of 30.9.2026. The engine's line kept the win
    // and went nowhere — 52...Kf3 53.Rb7 Kg3 54.Rg7+ Kf3, a repetition — and
    // the study stood on it, because the tablebase was asked only whether
    // the engine's move gave the result away. Where the tablebase knows a
    // win or a loss, the line is now its own: the first move it lists that
    // keeps the result, at every step, which is Lichess's line.
    test('the owner\'s rook ending: the line is the tablebase\'s own',
        () async {
      final (study, _) = await _study('owner3');
      expect(_sans(study.mainLine.map((s) => s.move)),
          ['Kf3', 'Rb7', 'Rd2', 'Rf7', 'Rd1+', 'Kh2', 'Ke3', 'Kg2']);
      for (final step in study.mainLine) {
        expect(step.tablebase, isNotNull, reason: step.move.san);
        expect(step.move.uci, step.tablebase!.keeping.first.uci,
            reason: '${step.move.san} is not the tablebase\'s first move');
      }
    });

    test('the owner\'s rook ending: no position of the line comes back',
        () async {
      final (study, _) = await _study('owner3');
      String board(String fen) => fen.split(' ').take(2).join(' ');
      final seen = <String>{board(study.fen)};
      for (final step in study.mainLine) {
        expect(seen.add(board(step.move.fenAfter)), isTrue,
            reason: 'the line repeats after ${step.move.san}');
      }
    });

    test('the overview walks the same line, not the engine\'s', () async {
      final engine = RecordedEngine.read('owner3');
      final overview = await PositionStudyBuilder(
        analyzer: engine.analyzer,
        depth: engine.depth,
        tablebase: engine.tablebase,
      ).buildOverview(engine.fen);
      expect(engine.unanswered, isEmpty);
      final line = _sans(overview.mainLine.map((s) => s.move));
      expect(line.length, greaterThanOrEqualTo(kStudyMinPlies));
      expect(
          line, ['Kf3', 'Rb7', 'Rd2', 'Rf7', 'Rd1+', 'Kh2'].take(line.length));
    });

    test('in a draw the engine\'s move stands while it keeps the draw',
        () async {
      // Every drawing move is as good as the next, and the tablebase's first
      // is only the first of its list: here Ra2, where the engine plays Rh6.
      // Following the list would show an arbitrary draw — or a stalemate or a
      // trade into bare kings, which Lichess lists first among draws.
      final (study, _) = await _study('classic6');
      final tb = study.tablebase!;
      expect(tb.outcome, TablebaseOutcome.draw);
      expect(tb.keeping.first.san, 'Ra2');
      expect(study.mainLine.first.move.san, 'Rh6');
    });

    test('with more than seven men the tablebase is never asked', () async {
      final (_, engine) = await _study('owner1');
      expect(engine.askedTablebase, isEmpty);
    });
  });

  group('what cannot be studied, and what is lost on the way', () {
    test('a position that is not chess is refused before the engine is asked',
        () async {
      final engine = RecordedEngine.read('owner1');
      final builder =
          PositionStudyBuilder(analyzer: engine.analyzer, depth: 20);
      await expectLater(
        builder.build('8/8/8/8/8/8/8/8 w - - 0 1'),
        throwsA(isA<StudyRefused>()),
      );
      await expectLater(
        builder.build('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1'),
        throwsA(isA<StudyRefused>()
            .having((e) => e.reason, 'reason', contains('over'))),
        reason: 'stalemate: the game is over',
      );
      expect(engine.asked, isEmpty);
    });

    test(
        'a search its timeout stopped is not a fact: the branch is left '
        'out and the study says so', () async {
      final engine = RecordedEngine.read('owner1');
      // The position after 7...Be4 comes back three plies short.
      engine.short.add(_owner2);
      final study = await PositionStudyBuilder(
        analyzer: engine.analyzer,
        depth: engine.depth,
      ).build(engine.fen);
      expect(study.tempting.where((t) => t.move.san == 'Be4'), isEmpty);
      // The next move in line is tried in its place, and the recording has
      // no answer for it: that one is the fixture's limit, this one the rule.
      expect(study.problems.first, contains('Trying Be4'));
      expect(study.problems.first, contains('of 20'));
      expect(study.mainLine.first.move.san, 'Bxb1',
          reason: 'the rest of the study stands');
    });

    test('the start\'s own search coming back short refuses the study',
        () async {
      final engine = RecordedEngine.read('owner1')..short.add(_owner1);
      await expectLater(
        PositionStudyBuilder(analyzer: engine.analyzer, depth: engine.depth)
            .build(engine.fen),
        throwsA(isA<StudyRefused>()),
      );
    });

    test('cancelled between two searches, the second is never asked', () async {
      // Asked before a search and after it: the third time it is asked is
      // before the second search.
      final engine = RecordedEngine.read('owner1');
      var asks = 0;
      await expectLater(
        PositionStudyBuilder(
          analyzer: engine.analyzer,
          depth: engine.depth,
          isCancelled: () => ++asks >= 3,
        ).build(engine.fen),
        throwsA(isA<StudyCancelled>()),
      );
      expect(engine.asked, hasLength(1));
    });

    test('a study that was cancelled stops asking', () async {
      final engine = RecordedEngine.read('owner1');
      var searches = 0;
      await expectLater(
        PositionStudyBuilder(
          analyzer: (fen,
              {required depth,
              required multiPV,
              timeout = const Duration(seconds: 1)}) {
            searches++;
            return engine.analyzer(fen, depth: depth, multiPV: multiPV);
          },
          depth: engine.depth,
          isCancelled: () => searches >= 2,
        ).build(engine.fen),
        throwsA(isA<StudyCancelled>()),
      );
      expect(searches, 2);
    });
  });

  group('one move, and one position', () {
    test('a move that is not the engine\'s: what it loses and what follows',
        () async {
      final engine = RecordedEngine.read('owner2');
      // 8...Bxh1 in the position after 8.dxc6 — both searches are in the
      // study's own recording.
      final afterDxc6 = playSan(_owner2, 'dxc6')!.fenAfter;
      final facts = await PositionStudyBuilder(
        analyzer: engine.analyzer,
        depth: engine.depth,
      ).moveFacts(afterDxc6, 'e4h1');
      expect(engine.unanswered, isEmpty);
      expect(facts.move.san, 'Bxh1');
      expect(facts.isBest, isFalse);
      expect(facts.best.san, 'Nxc6');
      expect(facts.lost, greaterThanOrEqualTo(kMistakeLoss));
      expect(_sans(facts.follows).take(3), ['Rxa7', 'Rxa7', 'c7']);
      expect(facts.searches, 3);
    });

    test('the engine\'s own move is said to be it', () async {
      final engine = RecordedEngine.read('owner2');
      final facts = await PositionStudyBuilder(
        analyzer: engine.analyzer,
        depth: engine.depth,
      ).moveFacts(_owner2, 'd5c6');
      expect(engine.unanswered, isEmpty);
      expect(facts.isBest, isTrue);
      expect(facts.lost, 0);
      expect(facts.idea?.move.san, 'cxb7');
    });

    test('a move that does not play is refused', () async {
      final engine = RecordedEngine.read('owner2');
      await expectLater(
        PositionStudyBuilder(analyzer: engine.analyzer, depth: 20)
            .moveFacts(_owner2, 'a1a8'),
        throwsA(isA<StudyRefused>()),
      );
      expect(engine.asked, isEmpty);
    });

    test('a position alone costs two searches', () async {
      final engine = RecordedEngine.read('owner2');
      final study = await PositionStudyBuilder(
        analyzer: engine.analyzer,
        depth: engine.depth,
      ).buildOverview(_owner2);
      expect(engine.unanswered, isEmpty);
      expect(engine.asked, hasLength(2));
      expect(study.threat?.move.san, 'Bxh1');
      expect(study.mainLine.first.move.san, 'dxc6');
      expect(study.tempting, isEmpty);
      expect(study.mainLine.every((s) => !s.onlyMove), isTrue,
          reason: 'no move of the line was searched again');
    });
  });
}
