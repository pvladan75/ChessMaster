// A tutorial's moments on the mistake rule — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
// phase 1b.
//
// Until 1b a moment was a move that cost `minCost` pawns, the eight most
// expensive; „+19 against +14" was a moment and a real mistake in an equal
// position under a pawn was not. Now the review's own judge decides and writes
// its verdict into the facts (`review_verdicts.dart`), and the skeleton reads
// only that: the settled mistakes, worst first by chances lost, then the only
// moves the player found, widest gap first; at most eight; in game order. The
// right answers to a question are the moves that would not themselves be a
// mistake — `A`, the rule's own number — and an only move is told as what it
// is: the game played it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart'
    show kFactsMate;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/review_verdicts.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ReviewedMove _move(
  int ply, {
  MoveJudgement? judgement,
  bool unsettled = false,
  String? unjudgedWhy,
}) =>
    ReviewedMove(
      ply: ply,
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _fen,
      fenAfter: _fen,
      whiteMoved: true,
      judgement: judgement,
      unsettled: unsettled,
      unjudgedWhy: unjudgedWhy,
    );

Map<String, dynamic> _row({
  required String played,
  required String best,
  Map<String, dynamic>? judged,
}) =>
    {
      'fen': _fen,
      'played': {'move': played, if (judged != null) 'judged': judged},
      'candidates': [
        {'move': best}
      ],
    };

Map<String, dynamic> _mistake(double lost) => {
      'lost': lost,
      'mistake': true,
      'reason': 'lostChances',
      'unsettled': false,
      'only': false,
    };

Map<String, dynamic> _only(double gap) => {
      'lost': 0.0,
      'mistake': false,
      'reason': null,
      'unsettled': false,
      'only': true,
      'gap': gap,
    };

Map<String, dynamic> _fixture(String game) => jsonDecode(
        File('test/fixtures/game_tutorial/$game.json').readAsStringSync())
    as Map<String, dynamic>;

void main() {
  group('the verdicts written into the facts', () {
    test(
        'a mistake, a fine move, an unsettled one, an unjudged one, and an '
        'only move found', () {
      final rows = [
        for (var i = 0; i < 6; i++)
          <String, dynamic>{
            'fen': _fen,
            'played': <String, dynamic>{'move': 'e4'},
          },
        <String, dynamic>{'fen': _fen},
      ];
      final result = GameReviewResult(reviewDepth: 20, moves: [
        _move(0,
            judgement: const MoveJudgement(18.4567, MistakeReason.lostChances)),
        _move(1, judgement: const MoveJudgement(2.004, null)),
        _move(2,
            judgement: const MoveJudgement(12, MistakeReason.lostChances),
            unsettled: true),
        _move(3, unjudgedWhy: 'the position before it was never answered'),
        _move(4, judgement: const MoveJudgement(0, null)),
        _move(5, judgement: const MoveJudgement(8, MistakeReason.missedMate)),
      ]);

      applyReviewVerdicts(rows, result, onlyMoves: {4: 31.456});

      Map<String, dynamic> judged(int i) =>
          (rows[i]['played'] as Map)['judged'] as Map<String, dynamic>;
      expect(judged(0), {
        'lost': 18.46,
        'mistake': true,
        'reason': 'lostChances',
        'unsettled': false,
        'only': false,
      });
      expect(judged(1)['mistake'], isFalse);
      expect(judged(1)['lost'], 2.0);
      expect(judged(2)['mistake'], isFalse,
          reason: 'an unsettled mistake is never a mistake');
      expect(judged(2)['unsettled'], isTrue);
      expect(
          judged(3), {'unjudged': 'the position before it was never answered'});
      expect(judged(4)['only'], isTrue);
      expect(judged(4)['gap'], 31.46);
      expect(judged(5)['reason'], 'missedMate',
          reason: 'a missed mate is a mistake whatever the chances say');
      expect(judged(5)['mistake'], isTrue);
      expect(rows[6].containsKey('played'), isFalse);
    });

    test('a facts value in chances: a mate is 100 or 0 whatever its distance',
        () {
      expect(chancesOfValue(0), 50);
      expect(chancesOfValue(kFactsMate - 12), 100);
      expect(chancesOfValue(-(kFactsMate - 3)), 0);
      expect(chancesOfValue(300),
          closeTo(winningChances(const EngineValue.cp(300)), 1e-12));
    });
  });

  group('which moves are moments', () {
    test('the mistakes worst first, then the only moves, capped, in game order',
        () {
      final rows = [
        _row(played: 'e4', best: 'd4', judged: _mistake(12)), // 0
        _row(played: 'e4', best: 'e4', judged: _only(40)), // 1
        _row(played: 'e4', best: 'd4', judged: _mistake(30)), // 2
        _row(played: 'e4', best: 'e4', judged: _only(20)), // 3
        _row(played: 'e4', best: 'd4', judged: _mistake(20)), // 4
      ];
      expect(momentIndices(rows, 8), [0, 1, 2, 3, 4]);
      // Three places: the three mistakes, and no only move.
      expect(momentIndices(rows, 3), [0, 2, 4]);
      // Four: the three mistakes and the only move with the widest gap.
      expect(momentIndices(rows, 4), [0, 1, 2, 4]);
      // Two: the two worst mistakes, whatever their order in the game.
      expect(momentIndices(rows, 2), [2, 4]);
      expect(momentCounts({'rows': rows}), (mistakes: 3, onlyMoves: 2));
    });

    test('a tie in chances lost goes to the earlier move', () {
      final rows = [
        _row(played: 'e4', best: 'd4', judged: _mistake(15)),
        _row(played: 'e4', best: 'd4', judged: _mistake(15)),
        _row(played: 'e4', best: 'd4', judged: _mistake(15)),
      ];
      expect(momentIndices(rows, 2), [0, 1]);
    });

    test(
        'nothing the judge did not call: a fine move, an unsettled one, a row '
        'with no verdict', () {
      final rows = [
        _row(played: 'e4', best: 'd4', judged: {
          ..._mistake(40),
          'mistake': false,
          'unsettled': true,
        }),
        _row(
            played: 'e4',
            best: 'd4',
            judged: {..._mistake(8), 'mistake': false}),
        _row(played: 'e4', best: 'd4'),
        _row(played: 'e4', best: 'd4', judged: {'unjudged': 'no answer'}),
      ];
      expect(momentIndices(rows, 8), isEmpty);
      expect(momentCounts({'rows': rows}), (mistakes: 0, onlyMoves: 0));
    });

    test('a verdict the facts contradict is left out, not told', () {
      // A mistake whose facts' best is the move played, and an only move
      // whose facts' best is another: either would say something false.
      final rows = [
        _row(played: 'e4', best: 'e4', judged: _mistake(30)),
        _row(played: 'e4', best: 'd4', judged: _only(30)),
      ];
      expect(momentIndices(rows, 8), isEmpty);
      expect(momentCounts({'rows': rows}), (mistakes: 0, onlyMoves: 0));
    });
  });

  group('the right answers to a question', () {
    Map<String, dynamic> c(String move, int value) =>
        {'move': move, 'value_for_mover': value};

    test('every move that would not be a mistake, in chances', () {
      // +19 against +14: five pawns and no difference at all.
      expect(
          correctCandidates([c('Qh5', 1900), c('Rd1', 1400)])
              .map((x) => x['move']),
          ['Qh5', 'Rd1']);
      // +1 against −1: two pawns and a game changing hands.
      expect(
          correctCandidates([c('Nf3', 100), c('a3', -100)])
              .map((x) => x['move']),
          ['Nf3']);
    });

    // A loss of exactly A cannot be built from whole centipawns, so `<`
    // against `<=` here is a mutation no fixture can tell apart (measured,
    // phase 1b): what this holds is the edge to the centipawn.
    test('the edge: the last centipawn under A counts, the first over it not',
        () {
      // Solve W(0) − W(v) = A for v, to the centipawn below and above.
      final edge = [
        for (var v = 0; v > -400; v--)
          if (chancesOfValue(0) - chancesOfValue(v) >= kMistakeLoss) v
      ].first;
      final at = correctCandidates([c('best', 0), c('edge', edge)]);
      final inside = correctCandidates([c('best', 0), c('in', edge + 1)]);
      expect(at.map((x) => x['move']), ['best']);
      expect(inside.map((x) => x['move']), ['best', 'in']);
    });
  });

  group('an only move is told as what it is', () {
    test('the game played it, and nothing says it did not', () {
      final facts =
          _fixture('g08_nimzowitsch-defense')['facts'] as Map<String, dynamic>;
      final moments = skeletonMoments(facts);
      final only = moments.where((m) => m['kind'] == 'only').toList();
      final mistakes = moments.where((m) => m['kind'] == 'mistake').toList();
      expect(only, isNotEmpty,
          reason: 'g08 must hold an only move, or this cannot fail');
      expect(mistakes, isNotEmpty);

      for (final m in only) {
        final slots = (m['slots'] as Map).cast<String, String>();
        final program = (m['program'] as Map).cast<String, String>();
        expect(m['cost_text'], 'was the only move that held');
        expect(
            program.values.single, endsWith('found the only move that held…'));
        expect(slots['${m['id']}.answer.1'],
            contains('; the move played in the game, the only one that held'));
        expect(slots.values.join(' '),
            isNot(contains('which the game did not play')));
        expect(slots.values.join(' '), isNot(contains('was played instead')));
      }
      for (final m in mistakes) {
        final slots = (m['slots'] as Map).cast<String, String>();
        expect(slots['${m['id']}.answer.1'],
            contains('; the best move, which the game did not play'));
      }
    });
  });
}
