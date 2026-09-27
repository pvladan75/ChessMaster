// The gate for phase 6 of `docs/PLAN-PRIPREMA.md`, second half — the film's
// walk over a tutorial whose positions hold several beats. Pure.
//
// Drafted by the lead on 27.9.2026. It moves to
// `chess_app/test/tutorial_beats_film_test.dart` when the phase is briefed.
// **Not yet compiled and not yet watched going red.**
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT
//
// **`TutorialBeat` is still a stop on the line**, and gains where it stands
// inside its position:
//
//     int index     where on the line, from 0 at the opening position — as
//                   it is today, and what the map of the parts reads
//     int at        which of its position's beats, from 0
//     int of        how many beats its position holds
//     NodeBeat say  the sentence and the marks of this stop
//
// `beatsOf(root, current, {int currentAt = 0})` gives one stop for every beat
// of every position on the line, in order. `isCurrent` is true of one stop:
// the beat [currentAt] of the position the author stands on.
//
// **`filmBeatsOf` gives one stop for every beat**, and a stop's caption is its
// own sentence.
//
// **In the film's events** the first beat of a position is the `init` or the
// `move` that put it on the board, as ever. Every later beat is an event of
// kind `beat`: the position's `fen`, the beat's `text`, `arrows` and
// `squares`, the part's `orientation` — and no `san`, `from`, `to` or `join`.
//
// **A part opens on the first beat of its opening position and nowhere
// else**: `partOpeningsOf` answers for a stop with `index == 0 && at == 0`.
//
// **The film's signature** is position and sentence of every stop, as ever —
// so a tutorial with one beat to a position has the signature it has today,
// and every narration recorded over it still follows it.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_part_map.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/move_tree.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
const _afterE5 =
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
const _afterC5 =
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';

ChessArrow _arrow(String s) =>
    ChessArrow(colorCode: s[0], from: s.substring(1, 3), to: s.substring(3, 5));

/// Part 1: the start (two beats), 1. e4 (two beats), 1... e5 (one).
/// Part 2: back on the position after 1. e4 (two beats), then 1... c5.
TutorialDraft _draft() {
  final one = AnalysisNode(fen: _start, comment: 'This is where it begins.');
  one.addBeat()
    ..comment = 'Both sides want the centre.'
    ..arrows.add(_arrow('Ge2e4'));
  final e4 = one.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4')
    ..comment = 'The pawn takes it.';
  e4.addBeat()
    ..comment = 'And the bishop can come out.'
    ..arrows.add(_arrow('Bf1c4'));
  e4.addChild(childFen: _afterE5, san: 'e5', uci: 'e7e5').comment =
      'Black answers in kind.';

  final two = AnalysisNode(fen: _afterE4, comment: 'There was another way.');
  two.addBeat().comment = 'From the side.';
  two.addChild(childFen: _afterC5, san: 'c5', uci: 'c7c5').comment =
      'The Sicilian.';

  return TutorialDraft(
    title: 'First moves',
    sections: [
      TutorialSection(root: one, title: 'The centre'),
      TutorialSection(root: two, title: 'The other way'),
    ],
  );
}

void main() {
  group('the beats of a line', () {
    test('are one for every sentence of every position, in order', () {
      final root = _draft().sections.first.root;
      final beats = beatsOf(root, root);
      expect([
        for (final b in beats) '${b.index}.${b.at}/${b.of} ${b.say.comment}'
      ], [
        '0.0/2 This is where it begins.',
        '0.1/2 Both sides want the centre.',
        '1.0/2 The pawn takes it.',
        '1.1/2 And the bishop can come out.',
        '2.0/1 Black answers in kind.',
      ]);
      expect([for (final b in beats) b.say.arrows.length], [0, 1, 0, 1, 0]);
      // A stop's move is its position's, whichever of its beats it is.
      expect([for (final b in beats) b.arrivedLabel],
          [null, null, '1. e4', '1. e4', '1... e5']);
      expect([for (final b in beats) b.playsLabel],
          ['1. e4', '1. e4', '1... e5', '1... e5', null]);
    });

    test('one of them is where the author stands', () {
      final root = _draft().sections.first.root;
      final e4 = root.children.single;
      expect([for (final b in beatsOf(root, e4)) b.isCurrent],
          [false, false, true, false, false]);
      expect([for (final b in beatsOf(root, e4, currentAt: 1)) b.isCurrent],
          [false, false, false, true, false]);
      // A beat that is not there any more is the position's last, not none.
      expect([for (final b in beatsOf(root, e4, currentAt: 7)) b.isCurrent],
          [false, false, false, true, false]);
    });

    test('a line with one beat to a position is the line it is today', () {
      final root = AnalysisNode(fen: _start, comment: 'Start.');
      root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4').comment = 'Go.';
      final beats = beatsOf(root, root);
      expect([for (final b in beats) '${b.index}.${b.at}/${b.of}'],
          ['0.0/1', '1.0/1']);
    });
  });

  group('the film', () {
    test('has a stop for every beat, each with its own sentence', () {
      final stops = filmBeatsOf(_draft());
      expect([for (final s in stops) s.caption], [
        'This is where it begins.',
        'Both sides want the centre.',
        'The pawn takes it.',
        'And the bishop can come out.',
        'Black answers in kind.',
        'There was another way.',
        'From the side.',
        'The Sicilian.',
      ]);
    });

    test('puts a position on the board once, and then only speaks and draws',
        () {
      final events = tutorialVideoOf(_draft()).events;
      expect([for (final e in events) e['eventType']], [
        'init', 'beat', 'move', 'beat', 'move', // part 1
        'init', 'beat', 'move', // part 2
      ]);

      final second = events[1]['data'] as Map<String, dynamic>;
      expect(second['fen'], _start);
      expect(second['text'], 'Both sides want the centre.');
      expect(second['arrows'], [
        {'from': 'e2', 'to': 'e4', 'color': 'G'},
      ]);
      expect(second['orientation'], 'white');
      for (final key in ['san', 'from', 'to', 'join', 'afterMove']) {
        expect(second.containsKey(key), isFalse,
            reason: 'a beat is not a move and not a new part: `$key`');
      }

      final move = events[2]['data'] as Map<String, dynamic>;
      expect(move['san'], 'e4');
      expect(move['text'], 'The pawn takes it.');
      expect(move.containsKey('arrows'), isFalse,
          reason: 'the second beat\'s arrow was drawn over the first');

      final fourth = events[3]['data'] as Map<String, dynamic>;
      expect(fourth['fen'], _afterE4);
      expect(fourth['arrows'], [
        {'from': 'f1', 'to': 'c4', 'color': 'B'},
      ]);
    });

    test('every event starts after the one before it', () {
      final film = tutorialVideoOf(_draft());
      final at = [for (final e in film.events) e['timestampMs'] as int];
      for (var i = 1; i < at.length; i++) {
        expect(at[i], greaterThan(at[i - 1]), reason: 'event $i');
      }
      expect(film.seconds * 1000, greaterThan(at.last));
    });

    test('a part opens on the first beat of its opening position only', () {
      final stops = filmBeatsOf(_draft());
      final openings = partOpeningsOf(stops);
      expect([for (final o in openings) o?.entry], [
        PartEntry.fresh, null, null, null, null, //
        PartEntry.returns, null, null,
      ]);
      expect(openings[5]!.afterMove, '1. e4');
      // It hangs from the move it names: the first beat of 1. e4.
      expect(openings[5]!.from, 2);

      final second = (tutorialVideoOf(_draft()).events[5]['data']
          as Map<String, dynamic>);
      expect(second['join'], 'returns');
      expect(second['afterMove'], '1. e4');
    });

    test('the map of the parts hangs a part from the move, not from a beat',
        () {
      final map = partMapOf(_draft());
      expect(map.entries, hasLength(2));
      expect(map.entries[1].entry, PartEntry.returns);
      expect(map.entries[1].from, (part: 0, beat: 1),
          reason: 'the place on the line, which a second sentence does not '
              'move');
    });
  });

  group('the film\'s signature', () {
    test('sees every sentence', () {
      final draft = _draft();
      final before = filmSignatureOf(filmBeatsOf(draft));
      draft.sections.first.root.children.single.beats[1].comment =
          'And the queen can come out.';
      expect(filmSignatureOf(filmBeatsOf(draft)), isNot(before));
    });

    test('does not see a mark, as it never did', () {
      final draft = _draft();
      final before = filmSignatureOf(filmBeatsOf(draft));
      draft.sections.first.root.children.single.beats[1].arrows.clear();
      expect(filmSignatureOf(filmBeatsOf(draft)), before);
    });

    test('of a tutorial with one beat to a position is what it is today', () {
      // A literal, taken on master: sha256 of
      // `<start>|Start.;<afterE4>|Go.;`
      final root = AnalysisNode(fen: _start, comment: 'Start.');
      root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4').comment = 'Go.';
      final draft = TutorialDraft(sections: [TutorialSection(root: root)]);
      expect(filmSignatureOf(filmBeatsOf(draft)), _signatureOnMaster);
    });
  });
}

/// Filled in from a run on `master` before the phase is briefed — the gate is
/// not handed over with this empty.
const _signatureOnMaster = '';
