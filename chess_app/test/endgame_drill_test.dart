import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/drill_step.dart';

DrillStep step({
  bool held = true,
  String goal = 'win',
  String outcome = 'win',
  String playedSan = 'Kd7',
  bool? closer,
  String? replySan,
  String? replyUci,
  String? finished,
}) =>
    DrillStep(
      held: held,
      goal: goal,
      outcome: outcome,
      playedSan: playedSan,
      fen: '8/8/8/8/8/8/8/8 w - - 0 1',
      closer: closer,
      replySan: replySan,
      replyUci: replyUci,
      finished: finished,
    );

/// White king a1 and rook h1 against the black king a3. Rh8 holds the win and
/// the reply is Kb3.
const _before = '8/8/8/8/8/k7/8/K6R w - - 0 1';

String ids(DrillVerdict v) =>
    v.lines.map((l) => l.tokens.map((t) => t.id).join(' ')).join(' | ');

String texts(DrillVerdict v) => v.lines.map((l) => l.text).join(' | ');

DrillVerdict said(
  DrillStep s, {
  String uci = 'h1h8',
  bool claimed = false,
  int? holdLeft,
}) =>
    drillVerdict(s,
        fenBefore: _before, uci: uci, claimed: claimed, holdLeft: holdLeft);

void main() {
  // Until phase 4b of docs/PLAN-GOVOR-IZ-KLIPOVA.md these cases read
  // `drillFeedbackText`, a function of English sentences, and `holdOutText`.
  // Both are superseded: the sentences are lines of tokens now, drawn and
  // played from the same list, and every rule these cases held still holds —
  // a lost win is not called a draw, a rule's end is not a success, no
  // sentence counts moves to the end — and is held here on `drillVerdict`.
  group('what the drill says', () {
    test('a move that held says so, and the reply is said as a move', () {
      final v = said(step(
          closer: true, replySan: 'Kb3', replyUci: 'a3b3', playedSan: 'Rh8'));
      expect(ids(v), 'good_keep_going | black_plays piece_king sq_b3');
      expect(texts(v), 'Good. Keep going. | Black plays king b3.');
      expect(v.good, isTrue);
    });

    test('moving closer or not is not said: the table has no row for it', () {
      // A child who shuffles used to be told so. The spoken table says "Good.
      // Keep going." and nothing more, on the owner's word of 3.10.2026.
      for (final closer in [true, false, null]) {
        final v = said(step(closer: closer));
        expect(ids(v), 'good_keep_going');
      }
    });

    test('a lost win names the move that lost it, and where it landed', () {
      final draw = said(step(held: false, outcome: 'draw', playedSan: 'Rh8'));
      expect(ids(draw), 'piece_rook sq_h8 lets_win_go_draw');
      expect(texts(draw), contains('lets the win go'));
      expect(texts(draw), contains('now a draw'));
      expect(draw.good, isFalse);
    });

    test('a win that becomes a loss is not called a draw', () {
      // Reported from a drill on Da Silva - Gazel Pereira 2010. After Kc3 the
      // five-piece tables give White the win, and Qa1+ is the only move that
      // takes it. The screen said "remains a draw", which is not a softer way
      // of putting it - it is a different result.
      final v = said(step(held: false, outcome: 'loss', playedSan: 'Rh8'));
      expect(ids(v), 'piece_rook sq_h8 lets_win_go_lost');
      expect(texts(v), contains('now lost'));
      expect(texts(v), isNot(contains('draw')));
    });

    test('a lost draw is worded as a draw, not as a win', () {
      final v = said(
          step(held: false, goal: 'draw', outcome: 'loss', playedSan: 'Rh8'));
      expect(ids(v), 'piece_rook sq_h8 loses_draw_drill_stops');
      expect(texts(v), contains('loses the draw'));
      expect(texts(v), isNot(contains('win')));
    });

    test('mate is the end of a drill', () {
      expect(ids(said(step(finished: 'mate'))), 'checkmate_completed');
    });

    test('a draw held to a rule\'s end completes the drill', () {
      for (final end in [
        'repetition',
        'stalemate',
        'insufficient',
        'fifty_moves',
        'draw_rule'
      ]) {
        final v = said(step(goal: 'draw', finished: end));
        expect(ids(v), 'draw_held_completed', reason: end);
        expect(v.good, isTrue);
      }
    });

    test('running a rule out on a win is not reported as success', () {
      // The one ending that looks like a win held. It was: the win was there
      // the whole way and the moves ran out, which is the lesson.
      for (final end in ['repetition', 'fifty_moves', 'stalemate']) {
        final v = said(step(finished: end));
        expect(ids(v), 'piece_rook sq_h8 lets_win_go_draw', reason: end);
        expect(v.good, isFalse);
      }
    });

    test('a claimed draw says how many moves are left, and closes at the end',
        () {
      final v = said(step(goal: 'draw', outcome: 'draw'), holdLeft: 5);
      expect(ids(v), 'good_keep_going moves_left_to_hold n_5');
      expect(texts(v), 'Good. Keep going. Moves left to hold: 5.');
      // No claim, no count.
      expect(ids(said(step(goal: 'draw', outcome: 'draw'))), 'good_keep_going');
      // A win has nothing to hold out.
      expect(ids(said(step(), holdLeft: 5)), 'good_keep_going');
      final done = said(step(goal: 'draw'), claimed: true, holdLeft: 0);
      expect(ids(done), 'draw_held_completed');
    });

    test('no sentence ever counts down the moves to the end', () {
      // DTZ is half-moves to the next capture or pawn move, not moves to mate,
      // and it restarts after a conversion - so any countdown built on it would
      // be wrong twice over. Guarded here because the temptation is permanent.
      final samples = [
        step(closer: true, replySan: 'Kb3'),
        step(closer: false),
        step(goal: 'draw', outcome: 'draw'),
        step(held: false, outcome: 'draw'),
        step(finished: 'mate'),
        step(finished: 'draw_rule'),
        step(finished: 'stalemate'),
        step(finished: 'insufficient'),
      ];
      for (final s in samples) {
        final text = texts(said(s));
        expect(text, isNot(matches(RegExp(r'\b\d+\s+moves? to\b'))),
            reason: 'must not count moves to the end: $text');
      }
    });

    test('a move this client cannot read is drawn, never left unsaid', () {
      final v = said(step(held: false, outcome: 'draw', playedSan: 'Zz9'),
          uci: 'a1a1');
      expect(v.lines, isEmpty);
      expect(v.note, 'Zz9 did not hold.');
    });
  });

  group('holding a claimed draw out', () {
    test('the claim is long enough to be worth something', () {
      // Eight of the reader's own moves: long enough for a defence about to
      // collapse to collapse inside it, short enough not to be the shuffling
      // it replaces.
      expect(holdOutMoves, greaterThanOrEqualTo(6));
    });
  });

  group('when the drill is over', () {
    test('a move that lost the result ends it', () {
      expect(step(held: false).isOver, isTrue);
    });

    test('a finished game ends it', () {
      expect(step(finished: 'mate').isOver, isTrue);
    });

    test('an ordinary held move does not', () {
      expect(step(closer: true).isOver, isFalse);
    });
  });

  group('reading the server', () {
    test('a verdict is read whole, and a missing reply is not invented', () {
      final parsed = DrillStep.fromJson({
        'held': true,
        'goal': 'win',
        'outcome': 'win',
        'playedSan': 'd5+',
        'fen': '8/8/4kp1p/3p3P/4KP2/8/8/8 w - - 0 54',
        'closer': true,
        'reply': {'uci': 'e4d4', 'san': 'Kd4'},
        'finished': null,
      });

      expect(parsed.held, isTrue);
      expect(parsed.playedSan, 'd5+');
      expect(parsed.closer, isTrue);
      expect(parsed.replySan, 'Kd4');
      expect(parsed.finished, isNull);
      expect(parsed.isOver, isFalse);
    });

    test('an absent "closer" stays absent rather than becoming false', () {
      // Null is "the question does not apply"; false is "you gained nothing".
      // Collapsing the two would have a drawn position told it made no
      // progress, which is not a thing a drawn position can do.
      final parsed = DrillStep.fromJson({
        'held': true,
        'goal': 'draw',
        'outcome': 'draw',
        'playedSan': 'Rf1',
        'fen': '8/8/8/8/8/8/8/8 w - - 0 1',
      });
      expect(parsed.closer, isNull);
      expect(parsed.replySan, isNull);
    });
  });
}
