import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_beats.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_speech.dart';

/// Phase 5 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`: the tour speaks, and mostly
/// does not — and, since phase 4d of `docs/PLAN-GOVOR-IZ-KLIPOVA.md`, what it
/// says is a `SpokenLine` of vocabulary tokens, so the cases assert the token
/// ids the clips are played from and the text the card draws.
///
/// The failure this is written against is not silence, it is a voice that
/// reads every ply. So the test that matters most is the budget at the bottom:
/// a twelve-move trunk must not produce twelve sentences, however good they
/// are.
///
/// The positions are real: a sentence names a move, and a move is read off the
/// position it is played from, so a fixture of made-up FENs could not say
/// anything.

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

String _fenAfter(String fen, String uci) {
  final board = chess.Chess.fromFEN(fen);
  final ok = board.move({
    'from': uci.substring(0, 2),
    'to': uci.substring(2, 4),
    if (uci.length > 4) 'promotion': uci.substring(4, 5),
  });
  if (!ok) throw StateError('$uci is not legal in $fen');
  return board.fen;
}

/// The position after 1.e4, Black to move: where the opponent's replies live.
final _afterE4 = _fenAfter(_start, 'e2e4');

RepertoireTreeMove _mine(String fenBefore, String uci, String san,
        {String role = 'primary',
        List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: uci,
      san: san,
      fen: _fenAfter(fenBefore, uci),
      mine: true,
      role: role,
      state: 'decided',
      children: children,
    );

RepertoireTreeMove _theirs(
        String fenBefore, String uci, String san, double share, String state,
        {List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: uci,
      san: san,
      fen: _fenAfter(fenBefore, uci),
      mine: false,
      share: share,
      state: state,
      children: children,
    );

RepertoireTreeMove _e4({List<RepertoireTreeMove> children = const []}) =>
    _mine(_start, 'e2e4', 'e4', children: children);

/// The stop of [move], played from [fenBefore] (the root unless said).
WalkthroughStop _only(RepertoireTreeMove move) =>
    walkthroughOrder(RepertoireTree(rootFen: _start, children: [move])).first;

/// The stop of a reply of the opponent's to 1.e4, the last in the tour.
WalkthroughStop _replyStop(RepertoireTreeMove reply) =>
    walkthroughOrder(RepertoireTree(rootFen: _start, children: [
      _e4(children: [reply])
    ])).last;

String _ids(WalkthroughLine line) =>
    line.line.tokens.map((t) => t.id).join(' ');

// Black's replies to 1.e4, with the share the cases give them.
RepertoireTreeMove _e5(double share, [String state = 'decided']) =>
    _theirs(_afterE4, 'e7e5', 'e5', share, state);
RepertoireTreeMove _c5(double share, [String state = 'decided']) =>
    _theirs(_afterE4, 'c7c5', 'c5', share, state);
RepertoireTreeMove _e6(double share, [String state = 'decided']) =>
    _theirs(_afterE4, 'e7e6', 'e6', share, state);
RepertoireTreeMove _c6(double share, [String state = 'decided']) =>
    _theirs(_afterE4, 'c7c6', 'c6', share, state);
RepertoireTreeMove _d5(double share, [String state = 'decided']) =>
    _theirs(_afterE4, 'd7d5', 'd5', share, state);

void main() {
  group('what the tour says', () {
    test('an ordinary move on the trunk is not spoken', () {
      final line = walkthroughLine(_only(_e4()), fenBefore: _start);

      // Supersedes: `parts == ['Your move — main line.']`. One token, drawn
      // with its own full stops.
      expect(_ids(line), 'your_move_main_line');
      expect(line.text, 'Your move. Main line.');
      expect(line.speak, isFalse);
    });

    test('an alternative says so', () {
      final line = walkthroughLine(
          _only(_mine(_start, 'd2d4', 'd4', role: 'alternate')),
          fenBefore: _start);

      expect(_ids(line), 'your_move_alternative');
      expect(line.text, 'Your move. The alternative.');
      expect(line.speak, isFalse);
    });

    test('an answered reply of theirs is not spoken either', () {
      final reply = _replyStop(_e5(0.55));

      final line = walkthroughLine(reply, fenBefore: _afterE4);

      // Supersedes: 'Opponent plays e5 — 55% of games.' The move is said as a
      // move, the share as „in 55 of 100 games" — „55 percent" is one word to
      // the speech engine and the clip cannot be cut out of it.
      expect(_ids(line),
          'black_plays piece_pawn sq_e5 in_head nmid_55 of_100_games');
      expect(line.text, 'Black plays pawn e5. In 55 of 100 games.');
      expect(line.speak, isFalse);
    });

    test('a share of a hundred is said as a hundred', () {
      final reply = _replyStop(_e5(1.0));

      expect(_ids(walkthroughLine(reply, fenBefore: _afterE4)),
          'black_plays piece_pawn sq_e5 in_head nmid_100 of_100_games');
    });

    test('a share under one in a hundred is said as that, not as zero', () {
      final reply = _replyStop(_e5(0.004));

      final line = walkthroughLine(reply, fenBefore: _afterE4);

      expect(_ids(line), 'black_plays piece_pawn sq_e5 less_than_one_in_100');
      expect(line.text, 'Black plays pawn e5. In less than one of 100 games.');
    });

    test('the line between „under one" and „one" is one in a hundred', () {
      // Added after a mutation survived: with the threshold at two in a
      // hundred, nothing here had a share between one and two. Both sides of
      // the boundary, and a rounding up from the half: 1.4 rounds to 1.
      String ids(double share) =>
          _ids(walkthroughLine(_replyStop(_e5(share)), fenBefore: _afterE4));

      expect(ids(0.0099), 'black_plays piece_pawn sq_e5 less_than_one_in_100');
      expect(ids(0.01),
          'black_plays piece_pawn sq_e5 in_head nmid_1 of_100_games');
      expect(ids(0.014),
          'black_plays piece_pawn sq_e5 in_head nmid_1 of_100_games');
      expect(ids(0.016),
          'black_plays piece_pawn sq_e5 in_head nmid_2 of_100_games');
    });

    test('a reply with no share is the move and nothing else', () {
      final reply = _replyStop(_e5(0));

      final line = walkthroughLine(reply, fenBefore: _afterE4);

      expect(_ids(line), 'black_plays piece_pawn sq_e5');
      expect(line.text, 'Black plays pawn e5.');
      expect(line.speak, isFalse);
    });

    test(
        'a hole is spoken, and says which move, how often, and that it is '
        'unanswered', () {
      final reply = _replyStop(_c5(0.31, 'open'));

      final line = walkthroughLine(reply, fenBefore: _afterE4);

      // Supersedes: 'Against c5, in 31% of games, you have no reply.'
      expect(
          _ids(line),
          'black_plays piece_pawn sq_c5 in_head nmid_31 of_100_games '
          'no_reply_here');
      expect(line.text,
          'Black plays pawn c5. In 31 of 100 games. You have no reply here.');
      expect(line.speak, isTrue);
    });

    test('a fork is spoken, and names the replies with their shares', () {
      final stop = _only(_e4());
      final line = walkthroughLine(
        stop,
        fenBefore: _start,
        replies: [_e5(0.55), _c5(0.31, 'open')],
      );

      expect(line.speak, isTrue);
      // The reason this clause exists rather than „ovde ima više odgovora":
      // a listener who cannot see the chips still learns what is coming and
      // which of it is unanswered. Supersedes 'e5 in 55% and c5 in 31%, no
      // reply.' — the hole is closed by its own sentence now.
      expect(
          _ids(line),
          'your_move_main_line opponent_has_replies nmid_2 replies_tail '
          'piece_pawn sq_e5 in_games nmid_55 of_100_games '
          'piece_pawn sq_c5 in_games nmid_31 of_100_games no_reply');
      expect(
        line.text,
        'Your move. Main line. From here the opponent has 2 replies. '
        'Pawn e5 in 55 of 100 games. Pawn c5 in 31 of 100 games. No reply.',
      );
    });

    test('a fork names the replies in the order it was handed them', () {
      final line = walkthroughLine(
        _only(_e4()),
        fenBefore: _start,
        replies: [_c5(0.2), _e5(0.5)],
      );

      expect(
          _ids(line),
          contains('sq_c5 in_games nmid_20 of_100_games '
              'piece_pawn sq_e5'));
    });

    test('a reply under one in a hundred in a fork says so after its name', () {
      final line = walkthroughLine(
        _only(_e4()),
        fenBefore: _start,
        replies: [_e5(0.55), _c5(0.003)],
      );

      expect(_ids(line), endsWith('piece_pawn sq_c5 less_than_one_in_100'));
      expect(line.text, endsWith('Pawn c5. In less than one of 100 games.'));
    });

    test('a wide fork names three and counts the rest', () {
      final line = walkthroughLine(
        _only(_e4()),
        fenBefore: _start,
        replies: [
          _e5(0.30),
          _c5(0.25),
          _e6(0.20),
          _c6(0.15),
          _d5(0.10),
        ],
      );

      expect(
          _ids(line),
          endsWith('piece_pawn sq_e6 in_games nmid_20 of_100_games '
              'and_head nmid_2 more_replies_tail'));
      expect(_ids(line), contains('opponent_has_replies nmid_5 replies_tail'));
      expect(line.text,
          endsWith('Pawn e6 in 20 of 100 games. And 2 more replies.'));
      // Three named, not four.
      expect(_ids(line), isNot(contains('sq_c6')));
    });

    test('a fork of four counts one more reply, in its own words', () {
      final line = walkthroughLine(
        _only(_e4()),
        fenBefore: _start,
        replies: [_e5(0.30), _c5(0.25), _e6(0.20), _c6(0.15)],
      );

      expect(_ids(line), endsWith('of_100_games one_more_reply'));
      expect(line.text,
          endsWith('Pawn e6 in 20 of 100 games. And one more reply.'));
      expect(_ids(line), isNot(contains('and_head')));
    });

    test('a note is spoken as „you left a note", and the note itself is not',
        () {
      final line = walkthroughLine(_only(_e4()),
          fenBefore: _start, note: '  Pazi na f7.  ');

      expect(line.speak, isTrue);
      expect(_ids(line), 'your_move_main_line left_note');
      expect(line.text, 'Your move. Main line. You left a note here.');
      // Drawn under the line, in the student's own words, and in no token:
      // supersedes `parts.last == 'Your note: Pazi na f7.'`.
      expect(line.note, 'Pazi na f7.');
      expect(line.text, isNot(contains('Pazi')));
      // An empty note is not a note.
      final empty =
          walkthroughLine(_only(_e4()), fenBefore: _start, note: '   ');
      expect(empty.speak, isFalse);
      expect(empty.note, isNull);
    });

    test('one move of theirs is not a fork', () {
      final line = walkthroughLine(
        _only(_e4()),
        fenBefore: _start,
        replies: [_e5(0.55)],
      );

      expect(line.speak, isFalse);
      expect(_ids(line), 'your_move_main_line');
    });

    test('my own alternatives are not the opponent having answers', () {
      // The clause is about what awaits the reader, not about their own
      // choices — and a position holds one kind or the other.
      final after = _fenAfter(_afterE4, 'e7e5');
      final reply = _replyStop(_e5(0.55));
      final line = walkthroughLine(
        reply,
        fenBefore: _afterE4,
        replies: [
          _mine(after, 'g1f3', 'Nf3'),
          _mine(after, 'f1c4', 'Bc4', role: 'alternate'),
        ],
      );

      expect(line.speak, isFalse);
      expect(_ids(line),
          'black_plays piece_pawn sq_e5 in_head nmid_55 of_100_games');
    });

    test('a move the position does not allow is refused, not left out', () {
      // A sentence without its move would be another sentence said as this
      // one. `e2e5` is nobody's move.
      final bad = RepertoireTreeMove(
        uci: 'e2e5',
        san: 'e5',
        fen: _afterE4,
        mine: false,
        share: 0.5,
        state: 'decided',
      );
      final stop =
          walkthroughOrder(RepertoireTree(rootFen: _start, children: [bad]))
              .first;

      expect(() => walkthroughLine(stop, fenBefore: _start),
          throwsA(isA<StateError>()));
    });
  });

  group('coming back to a fork', () {
    WalkthroughBeat beat(
            {RepertoireTreeMove? done, RepertoireTreeMove? next}) =>
        WalkthroughBeat(stopIndex: 0, returning: true, done: done, next: next);

    test('names the line just seen and the one that comes next', () {
      final line = walkthroughReturn(
        beat(done: _e5(0.55), next: _c5(0.31)),
        forkFen: _afterE4,
      );

      // Supersedes: 'We saw the line after e5. Now comes c5.'
      expect(_ids(line),
          'we_saw_line_after piece_pawn sq_e5 now_comes piece_pawn sq_c5');
      expect(line.text, 'We saw the line after pawn e5. Now comes pawn c5.');
      expect(line.speak, isTrue);
    });

    test('with nothing seen, only what comes next', () {
      final line = walkthroughReturn(beat(next: _c5(0.31)), forkFen: _afterE4);

      expect(_ids(line), 'now_comes piece_pawn sq_c5');
      expect(line.text, 'Now comes pawn c5.');
    });

    test('with nothing to name, back to the fork', () {
      final line = walkthroughReturn(beat(), forkFen: _afterE4);

      expect(_ids(line), 'back_to_fork');
      expect(line.text, 'Back to the fork.');
      expect(line.speak, isTrue);
    });

    test('the fork clause follows, and is read from the fork\'s position', () {
      final line = walkthroughReturn(
        beat(done: _e5(0.55), next: _c5(0.31)),
        forkFen: _afterE4,
        replies: [_e5(0.55), _c5(0.31, 'open')],
      );

      expect(
          _ids(line),
          endsWith('now_comes piece_pawn sq_c5 opponent_has_replies nmid_2 '
              'replies_tail piece_pawn sq_e5 in_games nmid_55 of_100_games '
              'piece_pawn sq_c5 in_games nmid_31 of_100_games no_reply'));
    });
  });

  group('the position before a move', () {
    test('a first move is played from the root, a later one from its parent',
        () {
      final e5 = _e5(0.55);
      final stops = walkthroughOrder(RepertoireTree(rootFen: _start, children: [
        _e4(children: [e5, _c5(0.3)])
      ]));

      expect(fenBeforeStop(stops, 0, _start), _start);
      expect(fenBeforeStop(stops, 1, _start), stops[0].move.fen);
      // The second reply is a sibling of the first, not its child: it is
      // played from the same position, which a „previous stop" rule would get
      // wrong.
      expect(fenBeforeStop(stops, 2, _start), stops[0].move.fen);
    });
  });

  group('the budget', () {
    /// A trunk of [moves] plies, alternating mine and their answered reply,
    /// played from the start position (1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 ...).
    List<WalkthroughStop> trunk(int moves) {
      const ucis = [
        'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5a4', 'g8f6', //
        'e1g1', 'f8e7', 'f1e1', 'b7b5', 'a4b3', 'd7d6', 'c2c3', 'e8g8',
        'h2h3', 'c6a5', 'b3c2', 'c7c5', 'd2d4', 'd8c7', 'b1d2', 'a5c6',
      ];
      final sans = [
        'e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', //
        'O-O', 'Be7', 'Re1', 'b5', 'Bb3', 'd6', 'c3', 'O-O',
        'h3', 'Na5', 'Bc2', 'c5', 'd4', 'Qc7', 'Nbd2', 'Nc6',
      ];
      final fens = [_start];
      for (final uci in ucis.take(moves)) {
        fens.add(_fenAfter(fens.last, uci));
      }
      RepertoireTreeMove? built;
      for (var i = moves; i >= 1; i--) {
        final children = built == null ? <RepertoireTreeMove>[] : [built];
        final from = fens[i - 1];
        built = i.isOdd
            ? _mine(from, ucis[i - 1], sans[i - 1], children: children)
            : _theirs(from, ucis[i - 1], sans[i - 1], 0.5, 'decided',
                children: children);
      }
      return walkthroughOrder(
          RepertoireTree(rootFen: _start, children: [built!]));
    }

    int spokenIn(List<WalkthroughStop> stops) {
      var said = 0;
      for (var i = 0; i < stops.length; i++) {
        // Every stop on a trunk has at most one move out of it, which is what
        // makes it a trunk.
        if (walkthroughLine(stops[i],
                fenBefore: fenBeforeStop(stops, i, _start))
            .speak) {
          said += 1;
        }
      }
      return said;
    }

    test('a twelve-move trunk produces at most four spoken sentences', () {
      final stops = trunk(24);

      expect(stops.length, 24, reason: 'twelve moves is twenty-four plies');
      expect(spokenIn(stops), lessThanOrEqualTo(4));
    });

    test('and the same trunk with a fork and a note still fits', () {
      // The budget is not „say nothing" — it is that what is said is worth
      // hearing. A fork and a note in twelve moves is a realistic line and it
      // must still come in under the ceiling.
      final stops = trunk(24);
      var said = 0;
      for (var i = 0; i < stops.length; i++) {
        final line = walkthroughLine(
          stops[i],
          fenBefore: fenBeforeStop(stops, i, _start),
          replies: i == 5
              ? [
                  _theirs(stops[5].move.fen, 'b5a4', 'Ba4', 0.4, 'open'),
                  _theirs(stops[5].move.fen, 'b5c6', 'Bxc6', 0.3, 'decided'),
                ]
              : const [],
          note: i == 9 ? 'Ovde se igra na kraljevom krilu.' : null,
        );
        if (line.speak) said += 1;
      }

      expect(said, lessThanOrEqualTo(4));
    });
  });
}
