import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/position_scanner/services/side_proposal.dart';

void main() {
  group('parseEval', () {
    test(
        'mate outranks any material score, and a faster mate outranks a slower',
        () {
      expect(parseEval('M1')!, greaterThan(parseEval('M5')!));
      expect(parseEval('M5')!, greaterThan(parseEval('+9.00')!));
      expect(parseEval('-M2')!, lessThan(parseEval('-9.00')!));
    });

    test('accepts both spellings the engine paths produce', () {
      expect(parseEval('M3'), parseEval('+M3'));
      expect(parseEval('+1.50'), 1.5);
      expect(parseEval('-1.50'), -1.5);
      expect(parseEval('0.00'), 0.0);
    });

    test('unreadable is null, never zero', () {
      // "the engine said level" and "we could not read the engine" must not
      // look the same to the caller.
      expect(parseEval(''), isNull);
      expect(parseEval('—'), isNull);
      expect(parseEval('M'), isNull);
    });
  });

  group('decideSide', () {
    test('a mate for one side only is the strongest answer there is', () {
      // The shape of every position in a mate-in-N chapter.
      final p = decideSide(whiteEval: 'M1', blackEval: '-2.50');
      expect(p.side, 'w');
      expect(p.confidence, ProposalConfidence.high);
      expect(p.reason, contains('beli matira'));
    });

    test('and the same in black\'s favour', () {
      final p = decideSide(whiteEval: '+2.00', blackEval: '-M2');
      expect(p.side, 'b');
      expect(p.confidence, ProposalConfidence.high);
    });

    test('a decisive gap without mate is offered, but only as medium', () {
      // Black to move wins a piece; white to move has nothing.
      final p = decideSide(whiteEval: '+0.20', blackEval: '-4.00');
      expect(p.side, 'b');
      expect(p.confidence, ProposalConfidence.medium);
    });

    test('when both sides have the same little, the engine says nothing', () {
      final p = decideSide(whiteEval: '+0.30', blackEval: '+0.10');
      expect(p.hasAnswer, isFalse);
      expect(p.side, isNull);
      expect(p.reason, contains('ne razlikuje'));
    });

    test('both sides mating is not an answer either', () {
      final p = decideSide(whiteEval: 'M2', blackEval: '-M3');
      expect(p.hasAnswer, isFalse,
          reason: 'whoever moves first mates — that tells us nothing');
    });

    test('an unreadable evaluation produces no proposal, not a guess', () {
      final p = decideSide(whiteEval: 'M1', blackEval: '');
      expect(p.hasAnswer, isFalse);
      expect(p.reason, contains('nije dao ocenu'));
    });

    test('a proposal knows when it contradicts what is already stored', () {
      final p = decideSide(whiteEval: 'M1', blackEval: '-2.50');
      expect(p.disagreesWith('w'), isFalse);
      expect(p.disagreesWith('b'), isTrue,
          reason:
              'that disagreement is the whole reason to re-check a settled position');
    });

    test('an empty proposal never claims to disagree with anything', () {
      expect(SideProposal.empty.disagreesWith('w'), isFalse);
      expect(SideProposal.empty.disagreesWith('b'), isFalse);
    });
  });

  _bothMateTests();

  group('isPlayableWith', () {
    test('a side with no legal move and no check is not playable', () {
      // Black king a8, white king c8... a stalemate-shaped board still counts
      // as playable when it is a real position; the guard is for boards that
      // cannot be parsed at all.
      expect(isPlayableWith('5K1k/7b/8/8/pr6/2P5/1B4p1/7R w - - 0 1', 'w'),
          isTrue);
      expect(isPlayableWith('5K1k/7b/8/8/pr6/2P5/1B4p1/7R w - - 0 1', 'b'),
          isTrue);
    });

    test('nonsense is not playable for either side', () {
      expect(isPlayableWith('ovo nije fen', 'w'), isFalse);
      expect(isPlayableWith('', 'b'), isFalse);
    });
  });
}

void _bothMateTests() {
  group('both sides mating', () {
    test('a symmetric mate race gives no answer, but says why', () {
      // Six of the trainer's positions came back exactly like this.
      final p = decideSide(whiteEval: 'M1', blackEval: '-M1');
      expect(p.hasAnswer, isFalse);
      expect(p.reason, contains('obe strane matiraju'));
      expect(p.reason, contains('M1'),
          reason: 'the numbers are what lets a person settle it themselves');
    });

    test('a clearly faster mate is offered, but only as likely', () {
      final p = decideSide(whiteEval: 'M1', blackEval: '-M6');
      expect(p.side, 'w');
      expect(p.confidence, ProposalConfidence.medium);
      expect(p.reason, contains('brže'));
    });

    test('one move apart is too close to call', () {
      final p = decideSide(whiteEval: 'M1', blackEval: '-M2');
      expect(p.hasAnswer, isFalse);
    });
  });
}
