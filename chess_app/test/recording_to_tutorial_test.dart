// Phase 8 of docs/PLAN-PRIPREMA.md — a recording becomes a tutorial.
//
// Two kinds of fixture. The four under test/fixtures/recording_tutorial/ are
// phase 5's real recordings with the sound and the words taken out: the
// timeline as it was recorded, and the sentences the server builds from the
// vendor's real answer, each word replaced by a placeholder of the same
// length. Beside each is what phase 5's measurement sketch
// (tools/stt_measure/beats.js) answers on the same sentences — an
// independent reading of R1–R7 that the owner accepted numbers from. The rest
// are built here, each standing on one rule's boundary.
import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/recording_tutorial.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/models/recording_transcript.dart';
import 'package:chess_app/move_tree.dart';

const _start = TutorialDraft.startFen;

/// A timeline written the way `LessonTake` writes one: an `init` at 0, then
/// whatever the trainer did.
class _Timeline {
  _Timeline([String fen = _start]) {
    _game = chess.Chess.fromFEN(fen);
    events.add(TimelineEvent(
        timestampMs: 0, eventType: 'init', data: {'fen': fen, 'pgn': ''}));
  }

  late chess.Chess _game;
  final events = <TimelineEvent>[];
  final _history = <String>[];

  String get fen => _game.fen;

  /// A move played on the board, as the board stamps it.
  String move(int ms, String san, {Map<String, dynamic> extra = const {}}) {
    _history.add(_game.fen);
    final m = _game.move(san);
    expect(m, isTrue, reason: 'fixture move $san must be legal');
    events.add(TimelineEvent(
        timestampMs: ms,
        eventType: 'move',
        data: {'fen': _game.fen, ...extra}));
    return _game.fen;
  }

  /// ← on the board: back one move, which the timeline writes as a `move`
  /// event whose position is not one legal move from the one before.
  void back(int ms) {
    final fen = _history.removeLast();
    _game = chess.Chess.fromFEN(fen);
    events.add(
        TimelineEvent(timestampMs: ms, eventType: 'move', data: {'fen': fen}));
  }

  void arrows(int ms, List<Map<String, String>> arrows,
      [List<Map<String, String>> squares = const []]) {
    events.add(TimelineEvent(
        timestampMs: ms,
        eventType: 'arrow_drawn',
        data: {'arrows': arrows, 'squares': squares}));
  }

  void load(int ms, String fen) {
    _game = chess.Chess.fromFEN(fen);
    _history.clear();
    events.add(TimelineEvent(
        timestampMs: ms, eventType: 'init', data: {'fen': fen, 'pgn': ''}));
  }
}

TranscriptSentence _s(int startMs, int endMs, String text) =>
    TranscriptSentence(startMs: startMs, endMs: endMs, text: text, heard: text);

RecordingTutorial _make(_Timeline t, List<TranscriptSentence> sentences,
        {int durationMs = 60000}) =>
    recordingTutorialOf(
        events: t.events, durationMs: durationMs, sentences: sentences);

List<FilmBeat> _stops(RecordingTutorial made) => filmBeatsOf(made.draft);

Map<String, dynamic> _fixture(String name) => jsonDecode(
        File('test/fixtures/recording_tutorial/$name.json').readAsStringSync())
    as Map<String, dynamic>;

RecordingTutorial _fromFixture(Map<String, dynamic> f) {
  final transcript = f['transcript'] as Map<String, dynamic>;
  return recordingTutorialOf(
    events: [
      for (final e in f['events'] as List)
        TimelineEvent.fromJson(Map<String, dynamic>.from(e as Map))
    ],
    durationMs: f['durationMs'] as int,
    sentences: [
      for (final s in transcript['sentences'] as List)
        TranscriptSentence.fromJson(Map<String, Object?>.from(s as Map))
    ],
    language: transcript['language'] as String,
    title: 'Proba',
  );
}

void main() {
  group('the owner\'s recordings, as phase 5 measured them', () {
    for (final name in ['proba1', 'proba2', 'proba3', 'proba4']) {
      test('$name: the parts and beats the sketch found', () {
        final f = _fixture(name);
        final sketch = f['sketch'] as Map<String, dynamic>;
        final made = _fromFixture(f);
        final stops = _stops(made);

        expect(made.draft.sections.length, sketch['parts']);
        expect(stops.length, sketch['beats']);
        expect(made.wordlessBeats, sketch['wordlessBeats']);
        expect([
          for (final section in made.draft.sections)
            stops.where((s) => identical(s.section, section)).length
        ], sketch['beatsPerPart']);
        final fens = (sketch['fens'] as List).cast<String>();
        for (var i = 0; i < stops.length; i++) {
          expect(MoveTree.samePosition(stops[i].beat.node.fen, fens[i]), isTrue,
              reason: 'beat ${i + 1} stands on the sketch\'s position');
        }
        final perBeat = (sketch['sentencesPerBeat'] as List).cast<int>();
        final sentences = ((f['transcript'] as Map)['sentences'] as List)
            .map((s) => (s as Map)['text'] as String)
            .toList();
        for (var i = 0; i < stops.length; i++) {
          final inIt = sentences.where((t) => stops[i].caption.contains(t));
          expect(inIt.length, perBeat[i], reason: 'beat ${i + 1}');
        }
      });

      test('$name: every sentence is in exactly one beat, whole', () {
        final f = _fixture(name);
        final made = _fromFixture(f);
        final captions = [for (final s in _stops(made)) s.caption];
        final sentences = ((f['transcript'] as Map)['sentences'] as List)
            .map((s) => (s as Map)['text'] as String)
            .toList();
        for (final text in sentences) {
          expect(captions.where((c) => c.contains(text)).length, 1,
              reason: '„$text" stands on one beat');
        }
        // And nothing else is written: the captions are the sentences, in
        // the order they were said.
        expect(
            captions.where((c) => c.isNotEmpty).join(' '), sentences.join(' '));
      });

      test('$name: one marker per beat, from 0, rising, inside the sound', () {
        final f = _fixture(name);
        final made = _fromFixture(f);
        expect(made.markersMs.length, _stops(made).length);
        expect(made.markersMs.first, 0);
        for (var i = 1; i < made.markersMs.length; i++) {
          expect(made.markersMs[i], greaterThan(made.markersMs[i - 1]),
              reason: 'marker ${i + 1}');
        }
        expect(made.markersMs.last, lessThan(f['durationMs'] as int));
        // The draft handed back is the reading: every part carries the very
        // text that was read back, so what is saved is what was checked.
        // (A part that is only a position — nothing said, drawn or played —
        // has no text to carry.)
        final withText =
            made.draft.sections.where((s) => s.pgnForSave.isNotEmpty);
        expect(withText, isNotEmpty);
        expect(withText.every((s) => s.isPristine), isTrue);
        expect(made.draft.language, 'sr-Latn');
        expect(made.draft.title, 'Proba');
      });
    }
  });

  group('R3 — a sentence belongs to the position standing when it ends', () {
    test('a sentence split evenly over a move goes to the later position', () {
      final t = _Timeline();
      t.move(2000, 'e4');
      final made = _make(t, [_s(1000, 3000, 'The king pawn goes forward.')]);
      final stops = _stops(made);
      expect(stops.length, 2);
      expect(stops[0].caption, isEmpty, reason: 'the start is wordless');
      expect(stops[1].caption, 'The king pawn goes forward.');
      expect(stops[1].beat.node.moveSan, 'e4');
    });

    test(
        'a move at the sentence\'s last millisecond takes it; one a '
        'millisecond later does not', () {
      final at = _Timeline()..move(3000, 'e4');
      expect(_stops(_make(at, [_s(1000, 3000, 'Now.')]))[1].caption, 'Now.');

      final after = _Timeline()..move(3001, 'e4');
      final stops = _stops(_make(after, [_s(1000, 3000, 'Now.')]));
      expect(stops[0].caption, 'Now.');
      expect(stops[1].caption, isEmpty);
    });
  });

  group('R4 — beats on one position', () {
    test('an arrow drawn in mid-sentence is on the beat that sentence is in',
        () {
      final t = _Timeline()..move(500, 'e4');
      t.arrows(2000, [
        {'from': 'g1', 'to': 'f3', 'color': 'G'}
      ]);
      final stops = _stops(_make(t, [_s(1000, 3000, 'The knight comes out.')]));
      final beat = stops.last;
      expect(beat.caption, 'The knight comes out.');
      expect(beat.beat.say.arrows.map((a) => '$a'), ['Gg1f3']);
    });

    test(
        'three sentences over unchanged marks are one beat, and a fourth '
        'over a new arrow is a second beat on the same position, in the same '
        'part', () {
      final t = _Timeline()..move(500, 'e4');
      t.arrows(10500, [
        {'from': 'd2', 'to': 'd4', 'color': 'R'}
      ]);
      final made = _make(t, [
        _s(1000, 3000, 'One.'),
        _s(3500, 6000, 'Two.'),
        _s(6500, 9000, 'Three.'),
        _s(9500, 12000, 'Four.'),
      ]);
      final stops = _stops(made);
      expect(made.draft.sections.length, 1);
      expect(stops.length, 3, reason: 'the start, then two beats on e4');
      expect(stops[1].caption, 'One. Two. Three.');
      expect(stops[1].beat.say.arrows, isEmpty);
      expect(stops[2].caption, 'Four.');
      expect(stops[2].beat.say.arrows.map((a) => '$a'), ['Rd2d4']);
      expect(identical(stops[1].beat.node, stops[2].beat.node), isTrue);
      expect([stops[1].beat.at, stops[2].beat.at], [0, 1]);
    });

    test('a caption that would pass its four lines starts a new beat', () {
      final long = 'x' * 100;
      final t = _Timeline();
      final made = _make(t, [
        _s(1000, 2000, '$long.'),
        _s(2500, 3000, '${'y' * 60}.'), // 101 + 1 + 61 = 163: fits
        _s(3500, 4000, 'z.'), // 163 + 1 + 2 = 166: fits
        _s(4500, 5000, 'w w.'), // 166 + 1 + 4 = 171: does not
      ]);
      final stops = _stops(made);
      expect(stops.length, 2);
      expect(stops[0].caption.length, 166);
      expect(stops[1].caption, 'w w.');
    });
  });

  group('R5 — what is seen', () {
    test(
        'a move nobody spoke over is a beat; a position only passed through '
        'on the way to a jump is not', () {
      final t = _Timeline();
      t.move(1000, 'e4');
      t.move(2000, 'e5'); // passed through: ← follows
      t.back(2300);
      t.move(4000, 'c5');
      final made = _make(t, [_s(4500, 6000, 'The Sicilian.')]);
      final stops = _stops(made);
      final fens = [for (final s in stops) s.beat.node.fen];
      expect(stops.map((s) => s.beat.node.moveSan).toList(),
          [null, 'e4', null, 'c5']);
      expect(fens.any((f) => f.startsWith('rnbqkbnr/pppp1ppp/8/4p3')), isFalse,
          reason: 'e5 was only passed through');
      expect(stops[1].caption, isEmpty, reason: 'e4 is wordless and seen');
    });

    test('a sentence the trainer emptied stands on no beat', () {
      final t = _Timeline()..move(500, 'e4');
      final made = _make(t, [
        _s(1000, 2000, '  '),
        _s(2500, 3000, 'Good.'),
      ]);
      expect([for (final s in _stops(made)) s.caption], ['', 'Good.']);
    });

    test(
        'a sentence with braces in it is kept, the braces as parentheses — '
        'a brace would close the comment it is kept in', () {
      final t = _Timeline()..move(500, 'e4');
      final made = _make(t, [_s(1000, 2000, 'The plan {f4} works.')]);
      expect(_stops(made).last.caption, 'The plan (f4) works.');
    });

    test(
        'a corrected sentence with a line break in it reads back as one '
        'line', () {
      final t = _Timeline()..move(500, 'e4');
      final made = _make(t, [_s(1000, 2000, 'The plan\n  works.')]);
      expect(_stops(made).last.caption, 'The plan works.');
    });

    test(
        'a sentence the reader would read as something else is refused, '
        'not kept changed', () {
      // `[%csl …]` in a comment is a coloured square to the reader, so the
      // words would come back without it and a square would appear.
      final t = _Timeline()..move(500, 'e4');
      expect(
          () => _make(t, [_s(1000, 2000, 'Look at [%csl Rd4] here.')]),
          throwsA(isA<RecordingTutorialRefused>().having(
              (r) => r.reason, 'reason', contains('did not read back'))));
      // And a clock, which changes the words alone.
      expect(
          () => _make(t, [_s(1000, 2000, 'Time [%clk 0:03:00] now.')]),
          throwsA(isA<RecordingTutorialRefused>().having(
              (r) => r.reason, 'reason', contains('did not read back'))));
    });

    test(
        'with no transcript every beat is wordless, and the voice still '
        'lies under it', () {
      final t = _Timeline()
        ..move(1500, 'e4')
        ..move(3000, 'e5');
      final made = _make(t, const [], durationMs: 5000);
      expect(made.wordlessBeats, 3);
      expect(made.markersMs, [0, 1500, 3000]);
    });
  });

  group('R6 and R7 — parts and moves', () {
    test(
        'a jump back opens a part that returns, and three quick presses of '
        '← make one part, not three', () {
      final t = _Timeline();
      t.move(1000, 'e4');
      t.move(2000, 'e5');
      t.move(3000, 'Nf3');
      t.move(4000, 'Nc6');
      t.back(6000);
      t.back(6200);
      t.back(6400);
      t.move(8000, 'c5');
      final made = _make(t, [
        _s(4200, 5500, 'The main line.'),
        _s(8200, 9500, 'Or the Sicilian.'),
      ]);
      expect(made.draft.sections.length, 2);
      final stops = _stops(made);
      final openings = partOpeningsOf(stops);
      final second = stops.indexWhere((s) =>
          identical(s.section, made.draft.sections[1]) && s.beat.index == 0);
      expect(openings[second]!.entry, PartEntry.returns);
      expect(openings[second]!.afterMove, '1. e4');
      expect(made.draft.sections[1].root.children.single.moveSan, 'c5');
    });

    test(
        'a new board opens a part; a move\'s squares are derived, never read '
        'from the event', () {
      final t = _Timeline();
      // The event lies about its squares; the positions do not.
      t.move(1000, 'e4', extra: {'from': 'a2', 'to': 'a3', 'san': 'a3'});
      t.load(3000, '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1');
      t.move(4000, 'Rc4');
      final made = _make(t, [
        // Spoken over, or R5 would pass e4 by on the way to the new board.
        _s(1200, 2500, 'The king pawn.'),
        _s(4200, 5000, 'Cut the king off.'),
      ]);
      expect(made.draft.sections.length, 2);
      final e4 = made.draft.sections[0].root.children.single;
      expect([e4.moveSan, e4.moveUci], ['e4', 'e2e4']);
      final video = tutorialVideoOf(made.draft);
      final e4Event = video.events[1];
      expect([e4Event['eventType'], e4Event['from'] ?? e4Event['data']['from']],
          ['move', 'e2']);
      final rook = made.draft.sections[1].root.children.single;
      expect([rook.moveSan, rook.moveUci], ['Rc4', 'c1c4']);
    });

    test(
        'a move that one legal move reaches is a move, whatever the event '
        'calls it — a jump forward by one in the tree', () {
      final t = _Timeline();
      final after = t.move(1000, 'e4');
      t.back(1500);
      // → in the tree: the same position again, written with no squares.
      t.events.add(TimelineEvent(
          timestampMs: 2000, eventType: 'move', data: {'fen': after}));
      final made = _make(t, [_s(2200, 3000, 'Back to e4.')]);
      final part = made.draft.sections.last;
      expect(part.root.children.single.moveSan, 'e4');
    });

    test('two beats on a position the board jumped to are one part', () {
      final t = _Timeline()..move(500, 'e4');
      t.load(3000, '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1');
      t.arrows(5500, [
        {'from': 'c1', 'to': 'c4', 'color': 'G'},
      ]);
      final made = _make(t, [
        _s(1000, 2000, 'The king pawn.'),
        _s(3500, 5000, 'A rook ending.'),
        _s(6000, 7000, 'The rook cuts it off.'),
      ]);
      expect(made.draft.sections.length, 2);
      final beats = _stops(made)
          .where((s) => identical(s.section, made.draft.sections[1]))
          .map((s) => s.caption)
          .toList();
      expect(beats, ['A rook ending.', 'The rook cuts it off.']);
    });

    test(
        'a board set from the Library opens a part even when one legal move '
        'would have reached it', () {
      final t = _Timeline();
      final afterE4 = (chess.Chess()..move('e4')).fen;
      t.load(3000, afterE4);
      final made = _make(t, [
        _s(500, 2000, 'The start.'),
        _s(3500, 5000, 'A position loaded.'),
      ]);
      expect(made.draft.sections.length, 2);
      expect(made.draft.sections[1].root.children, isEmpty);
    });

    test('a part stands the way the board stood for most of it', () {
      _Timeline turnedAt(int ms) {
        final t = _Timeline();
        t.events.add(TimelineEvent(
            timestampMs: ms,
            eventType: 'orientation_changed',
            data: {'orientation': 'black'}));
        t.move(1000, 'e4');
        return t;
      }

      bool black(int turnedMs) =>
          _make(turnedAt(turnedMs), [_s(1200, 2000, 'From Black\'s side.')],
                  durationMs: 10000)
              .draft
              .sections
              .single
              .blackOrientation;
      // Turned a moment after it was set up: Black's part.
      expect(black(100), isTrue);
      // Turned in its last seconds: still White's.
      expect(black(9000), isFalse);
    });
  });

  group('R8 — the markers are the voice\'s, and the tutorial has no clock', () {
    test(
        'a beat begins where its first sentence does; a wordless beat where '
        'its position arose', () {
      final t = _Timeline();
      t.move(4000, 'e4');
      t.move(9000, 'e5');
      final made = _make(
          t,
          [
            _s(1000, 3000, 'The start.'),
            _s(3500, 6000, 'The king pawn.'),
          ],
          durationMs: 12000);
      // start (spoken from 1000, but the film opens at 0), e4 (from 3500),
      // e5 (wordless, played at 9000).
      expect(made.markersMs, [0, 3500, 9000]);
    });

    test(
        'moves played inside one sentence are shown when they were played, '
        'and the sentence\'s beat waits for its own position', () {
      final t = _Timeline();
      t.move(2000, 'e4');
      t.move(3000, 'e5');
      t.move(4000, 'Nf3');
      final made =
          _make(t, [_s(1000, 5000, 'e4 e5 and the knight.')], durationMs: 8000);
      expect([for (final s in _stops(made)) s.caption],
          ['', '', '', 'e4 e5 and the knight.']);
      expect(made.markersMs, [0, 2000, 3000, 4000]);
    });

    test(
        'a move played at the sound\'s last millisecond still starts '
        'inside it', () {
      final t = _Timeline()
        ..move(1000, 'e4')
        ..move(5000, 'e5');
      final made = _make(t, const [], durationMs: 5000);
      expect(made.markersMs, [0, 1000, 4999]);
    });

    test(
        'the tutorial is the same film whenever the recording\'s things '
        'happened — only the markers move', () {
      _Timeline shifted(int by) {
        final t = _Timeline();
        t.move(1000 + by, 'e4');
        t.arrows(2500 + by, [
          {'from': 'g1', 'to': 'f3', 'color': 'G'}
        ]);
        t.move(5000 + by, 'e5');
        return t;
      }

      List<TranscriptSentence> said(int by) => [
            _s(1500 + by, 3000 + by, 'The king pawn.'),
            _s(5500 + by, 7000 + by, 'And the answer.'),
          ];
      final a = _make(shifted(0), said(0), durationMs: 20000);
      final b = _make(shifted(7000), said(7000), durationMs: 27000);
      expect(jsonEncode(tutorialVideoOf(b.draft).events),
          jsonEncode(tutorialVideoOf(a.draft).events));
      expect(
          jsonEncode(b.draft.positionList), jsonEncode(a.draft.positionList));
      expect(b.markersMs, isNot(a.markersMs));
    });
  });

  group('D18 — the copied voice is held to positions, not words', () {
    test('a corrected sentence keeps the signature; a replaced move does not',
        () {
      final t = _Timeline()..move(1000, 'e4');
      final made = _make(t, [_s(1500, 3000, 'The kng pawn.')]);
      final before = made.signature;
      final wordsBefore = filmSignatureOf(_stops(made));
      expect(filmPositionsSignatureOf(_stops(made)), before);

      final e4 = made.draft.sections.single.root.children.single;
      e4.comment = 'The king pawn.';
      expect(filmPositionsSignatureOf(_stops(made)), before);
      expect(filmSignatureOf(_stops(made)), isNot(wordsBefore),
          reason: 'the words signature sees the correction; this one must '
              'not');

      final other = _make(
          _Timeline()..move(1000, 'd4'), [_s(1500, 3000, 'The kng pawn.')]);
      expect(other.signature, isNot(before));
    });

    test('the two kinds of signature can never be equal', () {
      final made = _make(_Timeline(), const []);
      expect(filmPositionsSignatureOf(_stops(made)),
          isNot(filmSignatureOf(_stops(made))));
    });
  });

  group('refusals', () {
    test('a recording with no sound or no board is refused with a sentence',
        () {
      expect(
          () => recordingTutorialOf(
              events: _Timeline().events, durationMs: 0, sentences: const []),
          throwsA(isA<RecordingTutorialRefused>()));
      expect(
          () => recordingTutorialOf(
              events: const [], durationMs: 1000, sentences: const []),
          throwsA(isA<RecordingTutorialRefused>()));
    });
  });
}
