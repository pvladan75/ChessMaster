// A tutorial as the frames of a video — the pure core, gated before the
// renderer is taught to draw any of it.
//
// Phase 2 of `docs/PLAN-ZAVRSNICA.md`, and the lead's half of it on purpose:
// batch 61's lesson was that a batch with a finished core has nothing left to
// be wrong about. Everything about *what the film says* is decided here; the
// renderer's half is drawing a caption, an arrow and a coloured square.
//
// The three rules worth breaking a build over:
//
//   * the order is the child's, from `beatsOf` — marks, then sentence, then the
//     move, which is what the narration loop does;
//   * two beats can never land in the same second, because the renderer draws
//     one frame per second and would show only the later of them;
//   * a part that asks carries its task on its **last** beat, where the child
//     meets it, not on its first.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/move_tree.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _endgame = '4k3/8/5K2/4P3/8/8/8/8 w - - 0 12';

TutorialSection partFrom({
  String fen = _start,
  String? pgn,
  String title = 'Deo 1',
  LessonStepKind kind = LessonStepKind.show,
  String? instruction,
  bool blackOrientation = false,
}) {
  final read = readStepTree(fen: fen, pgn: pgn);
  return TutorialSection(
    root: read.root,
    title: title,
    kind: kind,
    instruction: instruction,
    blackOrientation: blackOrientation,
  );
}

TutorialDraft draftOf(List<TutorialSection> sections) =>
    TutorialDraft(title: 'Film', sections: sections);

List<Map<String, dynamic>> dataOf(TutorialVideo video) => [
      for (final event in video.events)
        Map<String, dynamic>.from(event['data'] as Map),
    ];

void main() {
  group('the order the child meets it in', () {
    test('one event per beat, the first one setting the position', () {
      final video = tutorialVideoOf(draftOf([
        partFrom(pgn: '1. e4 e5 2. Nf3'),
      ]));

      expect(video.events, hasLength(4),
          reason: 'the opening position is a beat too — it is the diagram the '
              'part opens on');
      expect(video.events.first['eventType'], 'init');
      expect(
        [for (final e in video.events.skip(1)) e['eventType']],
        everyElement('move'),
      );
      expect(
          [for (final d in dataOf(video)) d['san']], [null, 'e4', 'e5', 'Nf3']);
    });

    test('a move carries the squares it came from and went to', () {
      final video = tutorialVideoOf(draftOf([partFrom(pgn: '1. e4')]));
      final move = dataOf(video).last;

      expect(move['from'], 'e2');
      expect(move['to'], 'e4',
          reason: 'the renderer highlights the last move from these two');
    });

    test('every part is in the film, in the order it is written', () {
      final video = tutorialVideoOf(draftOf([
        partFrom(pgn: '1. e4', title: 'Prvi'),
        partFrom(fen: _endgame, pgn: '12. Ke6', title: 'Drugi'),
      ]));

      expect(video.events, hasLength(4));
      expect(dataOf(video)[2]['fen'], _endgame,
          reason: 'the second part opens on its own board');
      expect(video.events[2]['eventType'], 'init');
    });
  });

  group('what stands under the board', () {
    test('the sentence written on a beat', () {
      final video = tutorialVideoOf(draftOf([
        partFrom(pgn: '1. e4 { Zauzimamo centar. }'),
      ]));

      expect(dataOf(video).last['text'], 'Zauzimamo centar.');
    });

    test('a beat with nothing written carries no caption at all', () {
      final video = tutorialVideoOf(draftOf([partFrom(pgn: '1. e4')]));

      for (final data in dataOf(video)) {
        expect(data.containsKey('text'), isFalse,
            reason: 'an empty caption is a band of nothing under the board');
      }
    });

    test('a part that asks carries its task on the last beat', () {
      final video = tutorialVideoOf(draftOf([
        partFrom(
          pgn: '1. e4 e5',
          kind: LessonStepKind.askMove,
          instruction: 'Nađi najbolji potez.',
        ),
      ]));

      final texts = [for (final d in dataOf(video)) d['text']];
      expect(texts.last, 'Nađi najbolji potez.');
      expect(texts.sublist(0, texts.length - 1), everyElement(isNull),
          reason: 'the question was asked before the demonstration finished');
    });

    test('and keeps what was written there above it', () {
      final video = tutorialVideoOf(draftOf([
        partFrom(
          pgn: '1. e4 { Beli je zauzeo centar. }',
          kind: LessonStepKind.askMove,
          instruction: 'Šta crni igra?',
        ),
      ]));

      expect(
          dataOf(video).last['text'], 'Beli je zauzeo centar.\nŠta crni igra?');
    });

    test('a part that only shows never carries its task', () {
      // `instruction` is not emptied when a trainer changes a part back to
      // „Samo prikaži" — the field keeps what was typed. A film that read it
      // anyway would ask a question the child is never asked.
      final video = tutorialVideoOf(draftOf([
        partFrom(
          pgn: '1. e4',
          instruction: 'Ovo se ne pita.',
        ),
      ]));

      expect([for (final d in dataOf(video)) d['text']], everyElement(isNull));
    });
  });

  group('the drawings travel', () {
    test('arrows and squares ride on the beat they were drawn on', () {
      final part = partFrom(pgn: '1. e4 e5');
      final e4 = part.root.children.first;
      e4.arrows.add(ChessArrow(from: 'd2', to: 'd4', colorCode: 'G'));
      e4.squares.add(SquareMark(square: 'd5', colorCode: 'R'));

      final video = tutorialVideoOf(draftOf([part]));
      final data = dataOf(video);

      expect(data[1]['arrows'], [
        {'from': 'd2', 'to': 'd4', 'color': 'G'}
      ]);
      expect(data[1]['squares'], [
        {'square': 'd5', 'color': 'R'}
      ]);
      expect(data[2].containsKey('arrows'), isFalse,
          reason: 'a mark drawn on one move was left standing on the next');
    });

    test('a part with no moves still shows what was drawn on it', () {
      // „Pogledaj polje d5" is a whole part. Its beat is the opening position
      // and everything it says is on the root.
      final part = partFrom(fen: _endgame);
      part.root.comment = 'Pogledaj polje e5.';
      part.root.squares.add(SquareMark(square: 'e5', colorCode: 'G'));

      final video = tutorialVideoOf(draftOf([part]));

      expect(video.events, hasLength(1));
      expect(dataOf(video).single['text'], 'Pogledaj polje e5.');
      expect(dataOf(video).single['squares'], hasLength(1));
    });
  });

  group('which way round the board stands', () {
    test('is on every event, and is the part own choice', () {
      final video = tutorialVideoOf(draftOf([
        partFrom(pgn: '1. e4', title: 'Beli'),
        partFrom(fen: _endgame, title: 'Crni', blackOrientation: true),
      ]));

      final data = dataOf(video);
      expect(data[0]['orientation'], 'white');
      expect(data[1]['orientation'], 'white');
      expect(data[2]['orientation'], 'black',
          reason: 'a tutorial written from Black in one part and White in '
              'another is drawn from one side for the whole film');
    });
  });

  group('the clock', () {
    test('a beat is never shorter than the frame it is drawn in', () {
      expect(dwellSecondsFor(''), greaterThanOrEqualTo(2));
      expect(dwellSecondsFor('Kratko.'), greaterThanOrEqualTo(2));
    });

    test('a long sentence stays up longer than a short one', () {
      final short = dwellSecondsFor('Centar.');
      final long = dwellSecondsFor(
          'Beli zauzima centar i priprema razvoj lakih figura, a crni mora '
          'da odluči hoće li odgovoriti simetrično.');

      expect(long, greaterThan(short));
    });

    test('and no sentence holds the film for ever', () {
      expect(dwellSecondsFor('x' * 5000), lessThanOrEqualTo(12));
    });

    test('no two beats land in the same second', () {
      // The renderer draws one frame per second and applies every event whose
      // timestamp has passed. Two beats inside one second are one frame, and
      // the first of them is never seen.
      final video = tutorialVideoOf(draftOf([
        partFrom(pgn: '1. e4 e5 2. Nf3 Nc6 3. Bb5'),
        partFrom(fen: _endgame, pgn: '12. Ke6'),
      ]));

      final stamps = [for (final e in video.events) e['timestampMs'] as int];
      for (var i = 1; i < stamps.length; i++) {
        expect(stamps[i] - stamps[i - 1], greaterThanOrEqualTo(1000),
            reason: 'beats $i and ${i - 1} are drawn in the same frame');
      }
      expect(stamps.first, 0);
    });

    test('the film is as long as its beats add up to', () {
      final video = tutorialVideoOf(draftOf([
        partFrom(pgn: '1. e4 { Centar. } e5'),
      ]));

      final last = video.events.last['timestampMs'] as int;
      expect(video.seconds * 1000, greaterThan(last),
          reason: 'the last beat is cut off at the moment it appears');
    });
  });

  group('what is refused before anything is rendered', () {
    test('a film with no frames is refused before ffmpeg sees it', () {
      // Asked of the record rather than through a draft, because a
      // `TutorialDraft` cannot be empty — its constructor puts a blank part in
      // an empty list, since the studio always stands on one. The guard is for
      // the caller, and it exists because ffmpeg given no frames fails with a
      // message about a pipe, which tells a trainer nothing about their
      // tutorial.
      const empty = (events: <Map<String, dynamic>>[], seconds: 0);

      expect(canRenderVideo(empty), isFalse);
    });

    test('and a draft handed no parts is one blank part, not nothing', () {
      final video =
          tutorialVideoOf(TutorialDraft(title: 'Prazan', sections: []));

      expect(video.events, hasLength(1));
      expect(canRenderVideo(video), isTrue);
    });

    test('a single bare diagram is', () {
      final video = tutorialVideoOf(draftOf([partFrom(fen: _endgame)]));
      expect(canRenderVideo(video), isTrue);
    });

    test('an hour is the most that will be drawn', () {
      final video = tutorialVideoOf(draftOf([
        for (var i = 0; i < 400; i++)
          partFrom(fen: _endgame)..root.comment = 'x' * 200,
      ]));

      expect(fitsInOneFilm(video), isFalse);
      expect(renderableSeconds(video), maxVideoSeconds);
    });
  });
}
