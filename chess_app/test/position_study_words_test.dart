// The words of a position study — docs/PLAN-STUDIJA-POZICIJE.md, §3: the
// request the app sends and the judgement of what comes back.
//
// The request stands on `docs/gates/study_words_request.json`, the fixture
// the server's tests are held to as well (rule 12) — and it is this builder's
// own output, from the engine's recorded answers, so the two ends agree on
// what the app really sends and not on what somebody remembered it sending.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/position_study/study_board.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words.dart';

import 'support/recorded_engine.dart';

const _owner2 =
    'rn2kbnr/pp2pppp/2p5/3PN3/4b3/1P4P1/1P1PPP1P/RNB1KB1R w KQkq - 1 8';

final Map<String, dynamic> _fixture = jsonDecode(
        File('../docs/gates/study_words_request.json').readAsStringSync())
    as Map<String, dynamic>;

Future<PositionStudy> _study(String name) async {
  final engine = RecordedEngine.read(name);
  final study = await PositionStudyBuilder(
    analyzer: engine.analyzer,
    depth: engine.depth,
    tablebase: engine.tablebase,
  ).build(engine.fen);
  expect(engine.unanswered, isEmpty);
  return study;
}

StudySlot _slot(StudyWordsRequest request, String id) =>
    request.slots.firstWhere((s) => s.id == id);

/// [request] judged with one slot's words replaced by [text].
StudyWordsVerdict _judge(StudyWordsRequest request, String id, String text) =>
    judgeStudyWords(request, {id: text});

void main() {
  group('the request', () {
    test('is the shared fixture, word for word', () async {
      final request = studyWordsRequest(await _study('owner1'));
      expect(
        jsonDecode(jsonEncode(request.toJson())),
        _fixture['request'],
        reason: 'the app\'s builder and the server\'s fixture have drifted: '
            'run tool/position_study.dart with STUDY_RECORD=1 and look at '
            'what changed before replacing either',
      );
    });

    test('names the pieces and never sends a FEN', () async {
      final request = studyWordsRequest(await _study('owner1'));
      final sent = jsonEncode(request.toJson());
      expect(request.position, startsWith('White: K'));
      expect(sent, isNot(contains('rn2kbnr')));
      expect(sent, isNot(contains('KQkq')));
    });

    test(
        'the owner\'s line is in it: the move, the reply, the trap, the '
        'punishment', () async {
      final request = studyWordsRequest(await _study('owner1'));
      final t1 =
          request.items.firstWhere((i) => i.kind == StudyItemKind.tempting);
      expect(t1.label, '7... Be4');
      expect([for (final s in t1.slots) s.id],
          ['t1.move', 't1.reply', 't1.greedy', 't1.punish']);
      expect(t1.lines['trap']!.take(3), ['Bxh1', 'Rxa7', 'Rxa7']);
      expect(_slot(request, 't1.greedy').text,
          contains('it wins material and loses the position'));
      expect(_slot(request, 't1.punish').text,
          contains('gives up the rook on a7 for a pawn'));
      expect(_slot(request, 't1.punish').text, contains('becomes a queen'));
    });

    test('no threat, no slot for one', () async {
      final request = studyWordsRequest(await _study('owner1'));
      expect(
          [for (final s in request.slots) s.id], isNot(contains('s.threat')));
      final other = studyWordsRequest(await _study('owner2'));
      expect([for (final s in other.slots) s.id], contains('s.threat'));
    });

    test(
        'a move that leaves a trap says so, and the trap is an item beside '
        'it', () async {
      final study = await _study('owner2');
      final request = studyWordsRequest(study);
      expect(_slot(request, 'm1.move').text,
          contains('It leaves Bxh1 to be played, which takes the rook on h1'));
      final trap =
          request.items.firstWhere((i) => i.kind == StudyItemKind.trap);
      expect(trap.id, 'w1');
      expect(trap.label, '8... Bxh1');
      expect([for (final s in trap.slots) s.id], ['w1.capture', 'w1.punish']);
    });

    test('a recapture that is a mistake is called that, not a trap', () async {
      final request = studyWordsRequest(await _study('owner2'));
      final text = _slot(request, 'w2.capture').text;
      expect(text, contains('The recapture 9. Nxc6'));
      expect(text, contains('looks automatic'));
      expect(text, isNot(contains('It is a trap')));
    });

    test('the material in the middle of an exchange is said both ways',
        () async {
      final request = studyWordsRequest(await _study('owner1'));
      final text = _slot(request, 's.position').text;
      expect(text, contains('On the board as it stands: White is a pawn up.'));
      expect(text, contains('once the captures of the main line are made'));
    });

    test(
        'with the tablebase, its result is the fact and the engine\'s '
        'number is not said', () async {
      final request = studyWordsRequest(await _study('classic5'));
      final text = _slot(request, 's.position').text;
      expect(text, contains('The tablebase knows the result'));
      expect(text, contains('a win for Black'));
      expect(text, contains('The moves that keep it: Rc1+, Rxc6.'));
      expect(text, isNot(contains('With the best play, Black is')));
    });

    test(
        'the moves offered words and the tree\'s slots are counted by one '
        'rule', () async {
      final study = await _study('owner2');
      final request = studyWordsRequest(study);
      final offered = [
        for (var i = 0; i < study.mainLine.length; i++)
          if (stepGetsWords(study, i)) study.mainLine[i].move.label,
      ];
      expect(
        [
          for (final i in request.items)
            if (i.kind == StudyItemKind.move) i.label,
        ],
        offered,
      );
      expect(offered.first, '8. dxc6', reason: 'the first move always');
      expect(offered, isNot(contains('10. fxe4')),
          reason: 'a pawn taking a bishop is a move on the board');
    });
  });

  group('one move, and one position', () {
    test('a comment on a position is the study\'s first item alone', () async {
      final engine = RecordedEngine.read('owner2');
      final study = await PositionStudyBuilder(
        analyzer: engine.analyzer,
        depth: engine.depth,
      ).buildOverview(_owner2);
      final request = positionCommentRequest(study);
      expect(request.items, hasLength(1));
      expect(request.items.single.kind, StudyItemKind.position);
      expect([for (final s in request.slots) s.id], ['s.position', 's.threat']);
    });

    test(
        'a comment on a move that is a mistake says what the engine plays '
        'and what follows', () async {
      final engine = RecordedEngine.read('owner2');
      final facts = await PositionStudyBuilder(
        analyzer: engine.analyzer,
        depth: engine.depth,
      ).moveFacts(playSan(_owner2, 'dxc6')!.fenAfter, 'e4h1');
      final request = moveCommentRequest(facts);
      expect(request.items, hasLength(1));
      expect(request.items.single.kind, StudyItemKind.move);
      expect(request.items.single.id, 'm1');
      final text = request.slots.single.text;
      expect(text, contains('The move 8... Bxh1'));
      expect(text, contains('It takes the rook on h1.'));
      expect(text, contains('It is a mistake: the engine plays Nxc6.'));
      expect(text, contains('What follows it: 9. Rxa7 Rxa7 10. c7'));
      expect(request.items.single.lines.keys, ['played', 'best']);
    });
  });

  group('the judgement', () {
    late StudyWordsRequest request;
    setUp(() async => request = studyWordsRequest(await _study('owner1')));

    test('the fixture\'s answer is kept, every slot of it', () {
      final slots = ((jsonDecode(_fixture['answer'] as String)
              as Map<String, dynamic>)['slots'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      final verdict = judgeStudyWords(request, slots);
      expect(verdict.refused, isEmpty);
      expect(verdict.kept.keys.toSet(), slots.keys.toSet());
    });

    test('a move from outside the item\'s lines is refused', () {
      final verdict = _judge(request, 't1.greedy',
          'Taking the rook loses to Qh5, which nobody can meet.');
      expect(verdict.kept, isEmpty);
      expect(verdict.refused.single, contains('Qh5'));
    });

    test(
        'a move from the item\'s lines is kept, a promotion with or '
        'without its piece', () {
      expect(
        _judge(request, 't1.punish',
                'After Rxa7 the pawn cannot be stopped, and cxb8 queens it.')
            .kept,
        hasLength(1),
      );
      expect(
        _judge(request, 't1.punish', 'The point is cxb8=Q+ at the end.').kept,
        hasLength(1),
      );
    });

    test('a word about the structure must be in the slot\'s facts', () {
      final refused = _judge(request, 't1.greedy',
          'Taking the rook leaves Black with a passed pawn to stop.');
      expect(refused.kept, isEmpty);
      expect(refused.refused.single, contains('passed pawn'));

      // The position's own facts name the isolated pawns; the slot about
      // the position may.
      final kept = _judge(request, 's.position',
          'White is a pawn up, and the pawns on b2 and b3 are isolated.');
      expect(kept.kept, hasLength(1));
    });

    test('whether a piece has a defender is a claim about that piece', () {
      // Phase 0: the facts said it of the pawn on d5, and the model said it
      // of the knight on b1.
      expect(
          _slot(request, 's.position').text,
          contains('The white pawn on d5 is attacked by the black pawn on c6 '
              'and has no defender.'));
      final refused = _judge(request, 'm1.move',
          'The knight on b1 has no defender, so the bishop takes it.');
      expect(refused.kept, isEmpty);
      expect(refused.refused.single, contains('on b1 has no defender'));

      for (final said in [
        'The pawn on d5 has no defender, so Black gets it back.',
        'The d5 pawn is hanging, and the c6 pawn takes it next.',
        'The pawn is undefended and falls.',
      ]) {
        expect(_judge(request, 's.position', said).kept, hasLength(1),
            reason: said);
      }
    });

    test('an evaluation in numbers is refused', () {
      final verdict =
          _judge(request, 'e.outcome', 'The line ends at +0.14, about even.');
      expect(verdict.kept, isEmpty);
      expect(verdict.refused.single, contains('prints an evaluation'));
    });

    test('„nothing has been won" is not a claim that something was', () {
      final verdict = _judge(request, 't2.reply',
          'Nothing has been won or lost, but White is clearly better.');
      expect(verdict.refused, isEmpty);
      expect(verdict.kept, hasLength(1));
    });

    test('a slot that was not offered, or is empty, is not kept', () {
      final verdict = judgeStudyWords(request, {
        's.threat': 'White threatens mate.',
        'm1.move': '   ',
      });
      expect(verdict.kept, isEmpty);
      expect(verdict.refused, isEmpty);
    });
  });
}
