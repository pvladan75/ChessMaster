import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/finding_sentences.dart';

/// The words a finding is said in, and the one way they are put together.
///
/// A finding reaches readers that cannot share a machine separator: a
/// language model reading the review, and a voice reading an imported
/// tutorial aloud. So findings are sentences, and a comment is sentences
/// joined by a space.
void main() {
  group('sentence', () {
    test('capitalises the first letter and ends with a full stop', () {
      expect(sentence('the white pawn on a2 is isolated'),
          'The white pawn on a2 is isolated.');
    });

    test('leaves an ending that is already there', () {
      expect(sentence('Mate!'), 'Mate!');
      expect(sentence('Is it?'), 'Is it?');
      expect(sentence('Done.'), 'Done.');
    });

    test('says nothing for nothing', () {
      expect(sentence('   '), '');
    });
  });

  group('joinSentences', () {
    test('joins with a space, skipping empty parts', () {
      expect(joinSentences(['The a.', '', '  ', 'The b.']), 'The a. The b.');
    });

    test('ends a part that has no ending, without rewriting it', () {
      expect(joinSentences(['my own note', 'The a.']), 'my own note. The a.');
    });

    test('is idempotent over its own output', () {
      final once = joinSentences(['my own note', 'The a.']);
      expect(joinSentences([once]), once);
    });
  });

  group('joinAnd, countWord, timesWord', () {
    test('join a list the way a sentence does', () {
      expect(joinAnd(const []), '');
      expect(joinAnd(const ['a']), 'a');
      expect(joinAnd(const ['a', 'b']), 'a and b');
      expect(joinAnd(const ['a', 'b', 'c']), 'a, b and c');
    });

    test('write small counts as words', () {
      expect(countWord(3), 'three');
      expect(countWord(8), 'eight');
      expect(countWord(12), '12');
      expect(timesWord(1), 'once');
      expect(timesWord(2), 'twice');
      expect(timesWord(3), 'three times');
    });
  });
}
