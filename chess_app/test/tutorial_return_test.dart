// Coming back to a position the viewer has already seen — the pure core, gated
// before the renderer is taught to draw any of it.
//
// `docs/PLAN-VRACANJE-NA-POZICIJU.md`, from the owner's requirement of
// 12.9.2026 after the first tutorial was published: „Vraćanje na zajedničku
// poziciju treba da bude takvo da gledalac zna da sam se vratio na već viđenu
// poziciju."
//
// The rule has to answer three ways, and telling the first two apart is most of
// the point: a part that opens where the previous beat already stood does not
// move the board at all, and announcing that would be words over a picture that
// did not change. The fixture is the shape of the published tutorial — a line
// cut into three parts, and then a second variation from the same fork.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';

// The chain, every move spelled the way the board itself spells it.
const _openOne = '8/8/8/3k4/8/8/4K3/7R w - - 0 1';
const _afterKf3 = '8/8/8/4k3/7R/5K2/8/8 b - - 3 2';
const _fork = '8/8/3k4/7R/8/5K2/8/8 w - - 6 4';
// The same board, reached with a different clock. A clock is not a position.
const _forkOtherClock = '8/8/3k4/7R/8/5K2/8/8 w - - 9 40';
const _elsewhere = '8/8/8/8/8/5k2/8/R6K b - - 0 1';

TutorialSection partFrom({
  required String fen,
  String? pgn,
  String title = 'Part',
}) {
  final read = readStepTree(fen: fen, pgn: pgn);
  return TutorialSection(root: read.root, title: title);
}

TutorialDraft draftOf(List<TutorialSection> sections) =>
    TutorialDraft(title: 'Rook and king', sections: sections);

/// The published tutorial's shape: one line in three parts, then a second
/// variation out of the position the third one opened on.
TutorialDraft _published({String fourthFen = _fork}) => draftOf([
      partFrom(fen: _openOne, pgn: '1. Rh4 Ke5 2. Kf3'),
      partFrom(fen: _afterKf3, pgn: '2... Kd5 3. Rh5+ Kd6'),
      partFrom(fen: _fork, pgn: '4. Kf4 Kc6'),
      partFrom(fen: fourthFen, pgn: '4. Ke4 Ke6 5. Rh8'),
    ]);

List<PartOpening?> _openings(TutorialDraft draft) =>
    partOpeningsOf(filmBeatsOf(draft));

void main() {
  group('how a part opens', () {
    test('fresh, then two joins, then the return', () {
      final openings = _openings(_published());
      final answered = openings.whereType<PartOpening>().toList();

      expect(answered.map((o) => o.entry), [
        PartEntry.fresh,
        PartEntry.continues,
        PartEntry.continues,
        PartEntry.returns,
      ]);
      // Named from the beat that arrived at the position, which is in the part
      // before the one that opened on it.
      expect(answered.last.afterMove, '3... Kd6');
    });

    test('only a part-opening beat is asked', () {
      final draft = _published();
      final stops = filmBeatsOf(draft);
      final openings = partOpeningsOf(stops);

      expect(stops.length, greaterThan(4));
      for (var i = 0; i < stops.length; i++) {
        expect(openings[i] == null, stops[i].beat.index != 0,
            reason: 'beat $i of the film');
      }
    });

    test('a clock is not a position', () {
      // The fourth part is written from the same board with a halfmove and a
      // move number that could not have been reached by this line. It is the
      // same position, so it is still a return, named the same way.
      final answered = _openings(_published(fourthFen: _forkOtherClock))
          .whereType<PartOpening>();

      expect(answered.last.entry, PartEntry.returns);
      expect(answered.last.afterMove, '3... Kd6');
    });

    test('a position only ever shown as a part opening has no move to name',
        () {
      final answered = _openings(draftOf([
        // A bare diagram: one beat, and nothing arrived at it.
        partFrom(fen: _openOne),
        partFrom(fen: _elsewhere, pgn: '1... Kg3'),
        partFrom(fen: _openOne),
      ])).whereType<PartOpening>().toList();

      expect(answered.map((o) => o.entry),
          [PartEntry.fresh, PartEntry.fresh, PartEntry.returns]);
      expect(answered.last.afterMove, isNull,
          reason: 'the renderer says „a position already shown" instead');
    });
  });

  group('what the film sends', () {
    test('the opening beat carries the join, and a move beat carries none', () {
      final video = tutorialVideoOf(_published());
      final inits = <Map<String, dynamic>>[];
      final moves = <Map<String, dynamic>>[];
      for (final event in video.events) {
        final data = Map<String, dynamic>.from(event['data'] as Map);
        (event['eventType'] == 'init' ? inits : moves).add(data);
      }

      expect(inits.map((d) => d['join']),
          ['fresh', 'continues', 'continues', 'returns']);
      expect(inits.last['afterMove'], '3... Kd6');
      // Only where there is something to say: three of the four openings did
      // not jump anywhere.
      expect(inits.where((d) => d.containsKey('afterMove')).length, 1);
      expect(moves.every((d) => !d.containsKey('join')), isTrue);
    });

    test('a returning beat holds long enough to be read', () {
      final video = tutorialVideoOf(_published());
      final events = video.events;
      final returnAt =
          events.indexWhere((e) => (e['data'] as Map)['join'] == 'returns');
      expect(returnAt, isNot(-1));

      final held = (events[returnAt + 1]['timestampMs'] as int) -
          (events[returnAt]['timestampMs'] as int);
      // The note is about 35 characters at twelve a second, and the two seconds
      // a wordless beat gets are not enough to notice the board went back.
      expect(held, 4000);
    });

    test('a sentence of its own still decides the length', () {
      final long = 'A' * 240;
      final draft = draftOf([
        partFrom(fen: _openOne, pgn: '1. Rh4 Ke5 2. Kf3'),
        partFrom(fen: _elsewhere, pgn: '1... Kg3'),
        partFrom(fen: _openOne, pgn: '{ $long } 1. Rh4'),
      ]);
      final events = tutorialVideoOf(draft).events;
      final returnAt =
          events.indexWhere((e) => (e['data'] as Map)['join'] == 'returns');

      final held = (events[returnAt + 1]['timestampMs'] as int) -
          (events[returnAt]['timestampMs'] as int);
      expect(held, 12000,
          reason: 'the caption is longer than the minimum hold');
    });
  });
}
