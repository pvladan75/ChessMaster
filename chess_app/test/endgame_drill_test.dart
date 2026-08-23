import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/drill_step.dart';

DrillStep step({
  bool held = true,
  String goal = 'win',
  String outcome = 'win',
  String playedSan = 'Kd7',
  bool? closer,
  String? replySan,
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
      finished: finished,
    );

void main() {
  group('what the drill says', () {
    test('a move that held the win and gained ground says both', () {
      final text = drillFeedbackText(
          step(closer: true, replySan: 'Kd5', playedSan: 'Rf6'));
      expect(text, contains('zadržan'));
      expect(text, contains('bliže'));
      expect(text, contains('Kd5'));
    });

    test('holding without gaining is said out loud, not hidden behind "tačno"',
        () {
      // A child who shuffles will read a bare "tačno" as "that was the move"
      // and keep shuffling. Naming it is the only feedback that changes it.
      final text = drillFeedbackText(step(closer: false));
      expect(text, contains('zadržan'));
      expect(text, contains('niste prišli bliže'));
    });

    test('a lost win names the move that lost it', () {
      final text = drillFeedbackText(
          step(held: false, outcome: 'draw', playedSan: 'Ke7'));
      expect(text, contains('Ke7'));
      expect(text, contains('ispušta dobitak'));
    });

    test('a win that becomes a loss is not called a draw', () {
      // Reported from a drill on Da Silva - Gazel Pereira 2010. After Kc3 the
      // five-piece tables give White the win, and Qa1+ is the only move that
      // takes it: the king on c3 and the queen on e5 stand on one diagonal, so
      // the check wins the queen. The screen said "ostaje remi", which is not a
      // softer way of putting it - it is a different result.
      final text = drillFeedbackText(
          step(held: false, outcome: 'loss', playedSan: 'Kc3'));
      expect(text, contains('Kc3'));
      expect(text, contains('ispušta dobitak'));
      expect(text, contains('izgubljena'));
      expect(text, isNot(contains('remi')));
    });

    test('a lost draw is worded as a draw, not as a win', () {
      final text = drillFeedbackText(
          step(held: false, goal: 'draw', outcome: 'loss', playedSan: 'Kf8'));
      expect(text, contains('gubi remi'));
      expect(text, isNot(contains('dobitak')));
    });

    test('mate is the end of a drill, and is said as an achievement', () {
      expect(drillFeedbackText(step(finished: 'mate')), contains('Mat!'));
    });

    test('a repetition is named for what it was', () {
      // A dead drawn rook ending repeats within a few moves. Calling that
      // "fifty moves without a capture" points at a counter that has barely
      // started, and the two are not the same thing to say.
      final text =
          drillFeedbackText(step(goal: 'draw', finished: 'repetition'));
      expect(text, contains('ponovila'));
      expect(text, isNot(contains('Pedeset')));
    });

    test('running the fifty moves out is not reported as success', () {
      // The one ending that looks like a win held. It was: the win was there
      // the whole way and the moves ran out, which is the lesson.
      final text = drillFeedbackText(step(finished: 'fifty_moves'));
      expect(text, contains('Pedeset poteza'));
      expect(text, contains('previše poteza'));
    });

    test('a held draw does not talk about getting nearer', () {
      // There is nothing to get nearer to when the task is to hold.
      final text = drillFeedbackText(step(goal: 'draw', outcome: 'draw'));
      expect(text, contains('remi je održan'));
      expect(text, isNot(contains('bliže')));
    });

    test('no sentence ever counts down the moves left', () {
      // DTZ is half-moves to the next capture or pawn move, not moves to mate,
      // and it restarts after a conversion - so any countdown built on it would
      // be wrong twice over. Guarded here because the temptation is permanent.
      final samples = [
        step(closer: true, replySan: 'Kd5'),
        step(closer: false),
        step(goal: 'draw', outcome: 'draw'),
        step(held: false, outcome: 'draw'),
        step(finished: 'mate'),
        step(finished: 'draw_rule'),
        step(finished: 'stalemate'),
        step(finished: 'insufficient'),
      ];
      for (final s in samples) {
        final text = drillFeedbackText(s);
        expect(text, isNot(matches(RegExp(r'\b\d+\s+poteza do\b'))),
            reason: 'ne sme da broji poteze do kraja: $text');
      }
    });
  });

  group('holding a claimed draw out', () {
    test('the countdown is said in the right case', () {
      // A position can be drawn and still have something to get wrong, and no
      // rule about material can honestly close that one. What can be asked is
      // the demonstration: hold it this many more moves.
      expect(holdOutText(1), 'Držite remi još 1 potez.');
      expect(holdOutText(2), 'Držite remi još 2 poteza.');
      expect(holdOutText(8), 'Držite remi još 8 poteza.');
    });

    test('reaching the end says what was actually proved', () {
      // Not "the position is dead" - that was never established. What was
      // established is that the reader held it.
      final text = holdOutText(0);
      expect(text, contains('$holdOutMoves'));
      expect(text, contains('zaključena'));
      expect(text, isNot(contains('mrtva')));
    });

    test('the claim is long enough to be worth something', () {
      // Four moves each side: long enough for a defence about to collapse to
      // collapse inside it, short enough not to be the shuffling it replaces.
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
