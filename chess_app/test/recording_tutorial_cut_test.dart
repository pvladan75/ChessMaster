// Phase 8b of docs/PLAN-PRIPREMA.md — a sentence is cut where the board
// changed while it was being said (R1, amended on the owner's word of
// 27.9.2026: in „Proba 5" four arrows drawn at the end of a sixteen-second
// sentence stood on the board from its first word).
//
// Two kinds of fixture, as in recording_to_tutorial_test.dart. The five under
// test/fixtures/recording_tutorial/cut/ are the owner's real recordings: the
// timeline as recorded and the transcript as the server sends it since this
// phase, each sentence with its words and their times, every letter and digit
// replaced by „w". Beside each is what tools/stt_measure/cuts.js answers on
// it — a second reading of the rule, written from the plan and not from the
// app's code. The rest are built here, each standing on one boundary.
//
// A transcript that comes without its words is cut at sentences and nowhere
// else, which recording_to_tutorial_test.dart still holds on four of the same
// recordings.
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

class _Timeline {
  _Timeline() {
    events.add(TimelineEvent(
        timestampMs: 0,
        eventType: 'init',
        data: {'fen': TutorialDraft.startFen, 'pgn': ''}));
  }

  final _game = chess.Chess();
  final events = <TimelineEvent>[];

  /// A move, and the marks the board holds once it is made — none, unless
  /// the move is one the tree already held with its arrows.
  void move(int ms, String san, {List<String> holding = const []}) {
    expect(_game.move(san), isTrue, reason: 'fixture move $san must be legal');
    events.add(TimelineEvent(timestampMs: ms, eventType: 'move', data: {
      'fen': _game.fen,
      'arrows': [
        for (final a in holding)
          {'from': a.substring(0, 2), 'to': a.substring(2), 'color': 'G'}
      ],
    }));
  }

  /// The marks standing after the trainer drew or took one off — every one
  /// of them, as the board stamps them.
  void arrows(int ms, List<String> fromTo) {
    events.add(TimelineEvent(timestampMs: ms, eventType: 'arrow_drawn', data: {
      'arrows': [
        for (final a in fromTo)
          {'from': a.substring(0, 2), 'to': a.substring(2), 'color': 'G'}
      ],
      'squares': const <Map<String, String>>[],
    }));
  }
}

/// A sentence as the server sends it: [heard] word by word, each beginning
/// at its own entry of [starts] and lasting until the next begins, the last
/// until [endMs]. [text] is what the trainer made of it, when anything.
TranscriptSentence _sentence(String heard, List<int> starts, int endMs,
    {String? text}) {
  final tokens = heard.split(' ');
  expect(tokens.length, starts.length, reason: 'one start for each word');
  return TranscriptSentence(
    startMs: starts.first,
    endMs: endMs,
    text: text ?? heard,
    heard: heard,
    words: [
      for (var i = 0; i < tokens.length; i++)
        TranscriptWord(
            text: tokens[i],
            startMs: starts[i],
            endMs: i + 1 < starts.length ? starts[i + 1] : endMs),
    ],
  );
}

RecordingTutorial _make(_Timeline t, List<TranscriptSentence> sentences,
        {int durationMs = 60000}) =>
    recordingTutorialOf(
        events: t.events, durationMs: durationMs, sentences: sentences);

List<FilmBeat> _stops(RecordingTutorial made) => filmBeatsOf(made.draft);

List<String> _captions(RecordingTutorial made) =>
    [for (final s in _stops(made)) s.caption];

List<List<String>> _arrows(RecordingTutorial made) => [
      for (final s in _stops(made))
        [for (final a in s.beat.say.arrows) '${a.from}${a.to}']..sort()
    ];

String _marks(FilmBeat stop) {
  final a = [
    for (final x in stop.beat.say.arrows) '${x.colorCode}${x.from}${x.to}'
  ]..sort();
  final s = [for (final x in stop.beat.say.squares) '${x.colorCode}${x.square}']
    ..sort();
  return '${a.join(',')}|${s.join(',')}';
}

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/recording_tutorial/cut/$name.json')
        .readAsStringSync()) as Map<String, dynamic>;

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
  group('the owner\'s recordings, against the sketch', () {
    for (final name in ['proba1', 'proba2', 'proba3', 'proba4', 'proba5']) {
      test('$name: beat for beat — position, caption, marks and marker', () {
        final f = _fixture(name);
        final sketch = f['sketch'] as Map<String, dynamic>;
        final made = _fromFixture(f);
        final stops = _stops(made);
        final beats = (sketch['beats'] as List).cast<Map<String, dynamic>>();

        expect(made.draft.sections.length, sketch['parts']);
        expect([
          for (final section in made.draft.sections)
            stops.where((s) => identical(s.section, section)).length
        ], sketch['beatsPerPart']);
        expect(made.wordlessBeats, sketch['wordlessBeats']);
        expect(stops.length, beats.length);
        expect(stops.length,
            greaterThan((sketch['wholeSentences'] as Map)['beats'] as int),
            reason: 'the fixture is one the rule cuts');
        for (var i = 0; i < stops.length; i++) {
          final want = beats[i];
          expect(
              MoveTree.samePosition(
                  stops[i].beat.node.fen, want['fen'] as String),
              isTrue,
              reason: 'beat ${i + 1} stands on the sketch\'s position');
          expect(stops[i].caption, want['caption'], reason: 'beat ${i + 1}');
          expect(_marks(stops[i]), want['marks'], reason: 'beat ${i + 1}');
          expect(made.markersMs[i], want['markerMs'], reason: 'beat ${i + 1}');
        }
      });

      test('$name: every word is written once, in the order it was said', () {
        final f = _fixture(name);
        final made = _fromFixture(f);
        final sentences = ((f['transcript'] as Map)['sentences'] as List)
            .map((s) => (s as Map)['text'] as String)
            .toList();
        expect(_captions(made).where((c) => c.isNotEmpty).join(' '),
            sentences.join(' '));
      });

      test('$name: no mark that was drawn is left off the film', () {
        final f = _fixture(name);
        final made = _fromFixture(f);
        final shown = <String>{
          for (final s in _stops(made))
            for (final a in s.beat.say.arrows)
              '${s.beat.node.fen.split(' ').first} ${a.from}${a.to}'
        };
        String? board;
        for (final e in f['events'] as List) {
          final data = (e as Map)['data'] as Map;
          if (data['fen'] is String) {
            board = (data['fen'] as String).split(' ').first;
          }
          for (final a in (data['arrows'] as List? ?? const [])) {
            final drawn = '$board ${(a as Map)['from']}${a['to']}';
            expect(shown, contains(drawn),
                reason: 'drawn at ${e['timestampMs']} ms');
          }
        }
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
      });
    }

    test(
        '„Proba 5": the arrows after Qxe5+ come clause by clause, not with '
        'the move', () {
      // The owner's report. Qxe5+ was played at 84.8 s and the arrows drawn
      // at 92.1, 93.3, 95.4 and 98.1 s, all inside one sentence that began at
      // 82.8 s — where, whole, it put all four on the board.
      final made = _fromFixture(_fixture('proba5'));
      final stops = _stops(made);
      final on = [
        for (var i = 0; i < stops.length; i++)
          if (stops[i].beat.node.moveSan == 'Qxe5+') i
      ];
      expect([for (final i in on) made.markersMs[i]],
          [82804, 86924, 93064, 95284, 99204]);
      expect([for (final i in on) stops[i].beat.say.arrows.length],
          [0, 1, 2, 4, 5]);
    });
  });

  group('where the cut goes', () {
    // e4 is on the board from 500; everything below is said over it.
    _Timeline board() => _Timeline()..move(500, 'e4');

    TranscriptSentence twoClauses(String mark) => _sentence(
        'First the pawn$mark then the knight.',
        [1000, 1300, 1600, 3000, 3300, 3600],
        4500);

    test(
        'an arrow drawn in the second clause is on the second clause, from '
        'its first word', () {
      final t = board()..arrows(3400, ['g1f3']);
      final made = _make(t, [twoClauses(',')]);
      expect(_captions(made), ['', 'First the pawn,', 'then the knight.']);
      expect(_arrows(made), [
        <String>[],
        <String>[],
        ['g1f3']
      ]);
      expect(made.markersMs, [0, 1000, 3000]);
      final stops = _stops(made);
      expect(identical(stops[1].beat.node, stops[2].beat.node), isTrue,
          reason: 'two beats on one position');
      expect(made.draft.sections.length, 1);
    });

    test('a semicolon and a colon begin a clause; a full stop inside does not',
        () {
      for (final mark in [';', ':']) {
        final t = board()..arrows(3400, ['g1f3']);
        expect(_captions(_make(t, [twoClauses(mark)])),
            ['', 'First the pawn$mark', 'then the knight.'],
            reason: mark);
      }
      // „1." is how a vendor writes „prvi" — a word, in the middle of a
      // sentence, that ends in a full stop.
      for (final mark in ['.', '']) {
        final t = board()..arrows(3400, ['g1f3']);
        final made = _make(t, [twoClauses(mark)]);
        expect(_captions(made), ['', 'First the pawn$mark then the knight.'],
            reason: '„$mark"');
        expect(_arrows(made).last, ['g1f3']);
      }
    });

    test('a sentence that came without its words is never cut', () {
      final t = board()..arrows(3400, ['g1f3']);
      final whole = twoClauses(',');
      final made = _make(t, [
        TranscriptSentence(
            startMs: whole.startMs,
            endMs: whole.endMs,
            text: whole.text,
            heard: whole.heard)
      ]);
      expect(_captions(made), ['', 'First the pawn, then the knight.']);
      expect(made.markersMs, [0, 1000]);
    });

    test(
        'a change at the sentence\'s last millisecond is the next '
        'sentence\'s; one a millisecond sooner is its own', () {
      final after = board()..arrows(4500, ['g1f3']);
      expect(_captions(_make(after, [twoClauses(',')])),
          ['', 'First the pawn, then the knight.']);
      final inside = board()..arrows(4499, ['g1f3']);
      expect(_captions(_make(inside, [twoClauses(',')])),
          ['', 'First the pawn,', 'then the knight.']);
    });

    test(
        'a stamp that repeats the marks standing is not a change of the '
        'board', () {
      // The arrow was drawn before anything was said. Stamped again at 2000
      // it is the same arrow, so nothing was drawn in this sentence and the
      // move takes it whole — were it a drawing, the move would be cut off
      // to keep it.
      final t = board()
        ..arrows(700, ['e7e5'])
        ..arrows(2000, ['e7e5'])
        ..move(4000, 'e5');
      final made = _make(t, [
        _sentence('Here the pawn is met so it moves away.',
            [1000, 1400, 1800, 2200, 2600, 3400, 3800, 4200, 4600], 5000)
      ]);
      expect(
          _captions(made), ['', '', 'Here the pawn is met so it moves away.']);
      expect(_arrows(made)[1], ['e7e5'], reason: 'seen on the move before');
    });

    test('an arrow drawn in the first clause leaves the sentence whole', () {
      final t = board()..arrows(1400, ['g1f3']);
      final made = _make(t, [twoClauses(',')]);
      expect(_captions(made), ['', 'First the pawn, then the knight.']);
      expect(_arrows(made).last, ['g1f3']);
    });

    test('two arrows drawn in one clause are one cut', () {
      final t = board()
        ..arrows(3100, ['g1f3'])
        ..arrows(3700, ['g1f3', 'f1c4']);
      final made = _make(t, [twoClauses(',')]);
      expect(_captions(made), ['', 'First the pawn,', 'then the knight.']);
      expect(_arrows(made).last, ['f1c4', 'g1f3']);
    });

    test(
        'an arrow in each clause gives each clause its own, and the second '
        'keeps the first', () {
      final t = board()
        ..arrows(3100, ['g1f3'])
        ..arrows(5200, ['g1f3', 'f1c4']);
      final made = _make(t, [
        _sentence('First the pawn, then the knight, then the bishop.',
            [1000, 1300, 1600, 3000, 3300, 3600, 5000, 5300, 5600], 6500)
      ]);
      expect(_captions(made),
          ['', 'First the pawn,', 'then the knight,', 'then the bishop.']);
      expect(_arrows(made), [
        <String>[],
        <String>[],
        ['g1f3'],
        ['f1c4', 'g1f3']
      ]);
      expect(made.markersMs, [0, 1000, 3000, 5000]);
    });
  });

  group('how far back a cut may go', () {
    // One clause, a word a second, from 1000.
    TranscriptSentence long() => _sentence('We look at the long diagonal here.',
        [1000, 2000, 3000, 4000, 5000, 6000, 7000], 8000);

    test(
        'six seconds from the clause\'s start the arrow is still the '
        'clause\'s; a millisecond later it is the word\'s', () {
      expect(cutMaxEarlyMs, 6000);
      final at = _Timeline()
        ..move(500, 'e4')
        ..arrows(7000, ['a1h8']);
      final whole = _make(at, [long()]);
      expect(_captions(whole), ['', 'We look at the long diagonal here.']);
      expect(_arrows(whole).last, ['a1h8']);
      expect(whole.markersMs, [0, 1000]);

      final after = _Timeline()
        ..move(500, 'e4')
        ..arrows(7001, ['a1h8']);
      final cut = _make(after, [long()]);
      expect(_captions(cut), ['', 'We look at the long diagonal', 'here.']);
      expect(_arrows(cut), [
        <String>[],
        <String>[],
        ['a1h8']
      ]);
      expect(cut.markersMs, [0, 1000, 7000]);
    });

    test('the word is the one being said when the board changed', () {
      TranscriptSentence said() => _sentence(
          'We look at the long diagonal here.',
          [1000, 2000, 3000, 4000, 5000, 7000, 8000],
          9000);
      // Drawn at 7999, seven seconds into the clause: „diagonal" began at
      // 7000 and „here." has not yet.
      final during = _Timeline()
        ..move(500, 'e4')
        ..arrows(7999, ['a1h8']);
      final made = _make(during, [said()]);
      expect(_captions(made), ['', 'We look at the long', 'diagonal here.']);
      expect(made.markersMs, [0, 1000, 7000]);

      // Drawn as „here." begins, it is „here." that is being said — and the
      // piece in front of it ended before the arrow, so it does not show it.
      final at = _Timeline()
        ..move(500, 'e4')
        ..arrows(8000, ['a1h8']);
      final cut = _make(at, [said()]);
      expect(_captions(cut), ['', 'We look at the long diagonal', 'here.']);
      expect(_arrows(cut), [
        <String>[],
        <String>[],
        ['a1h8']
      ]);
      expect(cut.markersMs, [0, 1000, 8000]);
    });
  });

  group('the shortest piece', () {
    TranscriptSentence short(int second) =>
        _sentence('Look, here it is.', [1000, second, 2500, 3000], 4000);

    test('a cut that would leave less than a second in front is not made', () {
      expect(cutMinPieceMs, 1000);
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(2600, ['g1f3']);
      final joined = _make(t, [short(1999)]);
      expect(_captions(joined), ['', 'Look, here it is.']);
      expect(_arrows(joined).last, ['g1f3']);

      final cut = _make(t, [short(2000)]);
      expect(_captions(cut), ['', 'Look,', 'here it is.']);
      expect(cut.markersMs, [0, 1000, 2000]);
    });
  });

  group('a move inside a sentence', () {
    test(
        'what was said before it stays on the position it was said over, and '
        'the rest goes with the move', () {
      final t = _Timeline()
        ..move(500, 'e4')
        ..move(800, 'e5')
        ..move(3500, 'Nf3');
      final made = _make(t, [
        _sentence('The pawns meet, and the knight follows.',
            [1000, 1300, 1600, 3000, 3300, 3600, 4000], 5000)
      ]);
      final stops = _stops(made);
      expect(_captions(made),
          ['', '', 'The pawns meet,', 'and the knight follows.']);
      expect([for (final s in stops) s.beat.node.moveSan],
          [null, 'e4', 'e5', 'Nf3']);
      expect(made.markersMs, [0, 500, 1000, 3000]);
    });

    test(
        'a move never takes the piece in which something was drawn before '
        'it', () {
      // One clause: the arrow at 2000 and the move at 4000 are both within
      // six seconds of its start. Whole, it would go to the position after
      // the move, and the arrow to no beat at all.
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(2000, ['e7e5'])
        ..move(4000, 'e5');
      final made = _make(t, [
        _sentence('Here the pawn is met so it moves away.',
            [1000, 1400, 1800, 2200, 2600, 3400, 3800, 4200, 4600], 5000)
      ]);
      expect(
          _captions(made), ['', 'Here the pawn is met so', 'it moves away.']);
      expect(_arrows(made), [
        <String>[],
        ['e7e5'],
        <String>[]
      ]);
      expect([for (final s in _stops(made)) s.beat.node.moveSan],
          [null, 'e4', 'e5']);
      expect(made.markersMs, [0, 1000, 3800]);
    });

    test('and keeps it even where the piece in front is under a second', () {
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(1200, ['e7e5'])
        ..move(1800, 'e5');
      final made = _make(t, [
        _sentence('See this move.', [1000, 1300, 1700], 2500)
      ]);
      expect(_captions(made), ['', 'See this', 'move.']);
      expect(_arrows(made)[1], ['e7e5']);
    });

    test('marks that were taken off before the move are not kept for', () {
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(1200, ['e7e5'])
        ..arrows(2000, [])
        ..move(4000, 'e5');
      final made = _make(t, [
        _sentence('Here the pawn is met so it moves away.',
            [1000, 1400, 1800, 2200, 2600, 3400, 3800, 4200, 4600], 5000)
      ]);
      expect(
          _captions(made), ['', '', 'Here the pawn is met so it moves away.']);
    });

    test('marks that arrive with a position are kept for as drawn ones are',
        () {
      // e5 is a move the tree already held, with its arrow: it arrives at
      // 1250 with the arrow on it, and Nf3 follows in the same clause.
      final t = _Timeline()
        ..move(500, 'e4')
        ..move(1250, 'e5', holding: ['g1f3'])
        ..move(4000, 'Nf3');
      final made = _make(t, [
        _sentence('Here the pawn is met so it moves away.',
            [1000, 1400, 1800, 2200, 2600, 3400, 3800, 4200, 4600], 5000)
      ]);
      expect(_captions(made),
          ['', '', 'Here the pawn is met so', 'it moves away.']);
      expect([for (final s in _stops(made)) s.beat.node.moveSan],
          [null, 'e4', 'e5', 'Nf3']);
      expect(_arrows(made)[2], ['g1f3']);
    });

    test('what a move wiped is not kept for at the next move', () {
      // The arrow and the first move both fall in the sentence's first
      // word, where nothing can be cut off: the arrow stood for 50 ms and
      // went with the move. The second move has nothing drawn before it.
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(1200, ['e7e5'])
        ..move(1250, 'e5')
        ..move(4000, 'Nf3');
      final made = _make(t, [
        _sentence('Here the pawn is met so it moves away.',
            [1000, 1400, 1800, 2200, 2600, 3400, 3800, 4200, 4600], 5000)
      ]);
      expect(_captions(made).last, 'Here the pawn is met so it moves away.');
      expect(_stops(made).last.beat.node.moveSan, 'Nf3');
    });
  });

  group('a corrected sentence', () {
    test(
        'words put in where there were fewer share the time of the ones '
        'they replace', () {
      // The owner's own correction in „Proba 5": the vendor heard „1." where
      // he said „uzima na". Here „1." was said from 8000 to 8800.
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(8500, ['f3e5']);
      final made = _make(t, [
        _sentence('The knight 1. e5 at once.',
            [1000, 1400, 8000, 8800, 9200, 9600], 10000,
            text: 'The knight takes on e5 at once.')
      ]);
      // „takes" has 8000–8400 and „on" 8400–8800; the arrow, more than six
      // seconds into the clause, is drawn while „on" is said.
      expect(_captions(made), ['', 'The knight takes', 'on e5 at once.']);
      expect(made.markersMs, [0, 1000, 8400]);
    });

    test(
        'a word keeps its time through a capital and a comma the trainer '
        'gave it', () {
      // „1." was said from 8000 and „e5" from 8900. „E5," is still that
      // word, so „takes on" share 8000–8900 and the arrow at 8420 falls in
      // „takes"; were it a new word, the three would share 8000–9200 and the
      // arrow would fall in „on".
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(8420, ['f3e5']);
      final made = _make(t, [
        _sentence('The knight 1. e5 at once.',
            [1000, 1400, 8000, 8900, 9200, 9600], 10000,
            text: 'The knight takes on E5, at once.')
      ]);
      expect(_captions(made), ['', 'The knight', 'takes on E5, at once.']);
      expect(made.markersMs, [0, 1000, 8000]);
    });

    test('as many words as there were keep their times one for one', () {
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(8300, ['f1c4']);
      final made = _make(t, [
        _sentence('Now the loc iskret comes out.',
            [1000, 1400, 8000, 8200, 9200, 9600], 10000,
            text: 'Now the bishop forward comes out.')
      ]);
      // „loc" was said from 8000 and „iskret" from 8200. Shared evenly over
      // 8000–9200, „forward" would begin at 8600 and the arrow would fall in
      // „bishop"; it begins where „iskret" did.
      expect(_captions(made), ['', 'Now the bishop', 'forward comes out.']);
      expect(made.markersMs.last, 8200);
    });

    test(
        'a comma the trainer put in begins a clause, and one taken out no '
        'longer does', () {
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(3400, ['g1f3']);
      final heard = [1000, 1300, 1600, 3000, 3300, 3600];
      expect(
          _captions(_make(t, [
            _sentence('First the pawn then the knight.', heard, 4500,
                text: 'First the pawn, then the knight.')
          ])),
          ['', 'First the pawn,', 'then the knight.']);
      expect(
          _captions(_make(t, [
            _sentence('First the pawn, then the knight.', heard, 4500,
                text: 'First the pawn then the knight.')
          ])),
          ['', 'First the pawn then the knight.']);
    });

    test(
        'the sentence\'s own times stand, whatever words were taken from '
        'its ends', () {
      // „Well now," and „you see." were taken out; the sentence still runs
      // from 1000 to 9000, so its first piece begins at 1000 and its last
      // holds the move played at 8500, while „you see." was being said.
      final t = _Timeline()
        ..move(500, 'e4')
        ..move(8500, 'e5');
      final made = _make(t, [
        _sentence('Well now, first the pawn, then the knight, you see.',
            [1000, 1500, 2000, 2400, 2800, 5000, 5300, 5600, 8000, 8400], 9000,
            text: 'First the pawn, then the knight,')
      ]);
      expect(_captions(made), ['', 'First the pawn,', 'then the knight,']);
      expect([for (final s in _stops(made)) s.beat.node.moveSan],
          [null, 'e4', 'e5']);
      expect(made.markersMs, [0, 1000, 5000]);
    });

    test('a sentence written anew is spread over its own time', () {
      final t = _Timeline()
        ..move(500, 'e4')
        ..arrows(9500, ['g1f3']);
      final made = _make(t, [
        _sentence('aa bb cc dd', [1000, 2000, 3000, 4000], 11000,
            text: 'One two three four five')
      ]);
      // Five words over 1000–11000 are two seconds each; 9500 is in „five".
      expect(_captions(made), ['', 'One two three four', 'five']);
      expect(made.markersMs.last, 9000);
    });
  });

  group('the wire', () {
    test('a sentence reads its words, and one broken word leaves it none', () {
      final read = TranscriptSentence.fromJson({
        'startMs': 1000,
        'endMs': 2000,
        'text': 'Kralj na',
        'heard': 'Kralj na',
        'words': [
          {'text': 'Kralj', 'startMs': 1000, 'endMs': 1500},
          {'text': 'na', 'startMs': 1500, 'endMs': 2000},
        ],
      });
      expect([for (final w in read.words) '${w.text} ${w.startMs} ${w.endMs}'],
          ['Kralj 1000 1500', 'na 1500 2000']);

      final broken = TranscriptSentence.fromJson({
        'startMs': 1000,
        'endMs': 2000,
        'text': 'Kralj na',
        'heard': 'Kralj na',
        'words': [
          {'text': 'Kralj', 'startMs': 1000, 'endMs': 1500},
          {'text': 'na', 'startMs': 1500},
        ],
      });
      expect(broken.words, isEmpty);
      expect(
          TranscriptSentence.fromJson(
              {'startMs': 1, 'endMs': 2, 'text': 'x', 'heard': 'x'}).words,
          isEmpty);
    });
  });
}
