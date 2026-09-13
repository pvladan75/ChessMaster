import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/finding_sentences.dart';

/// The words a finding is said in, and the one way they are put together.
///
/// A move's comment reaches three readers that cannot share a machine
/// separator: a trainer in the checklist dialog, a language model reading the
/// review, and a voice reading an imported tutorial aloud. So findings are
/// sentences, and a comment is sentences joined by a space.
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

  group('splitCommentForChecklist', () {
    const pinA =
        'The white rook on e1 pins the black knight on e5 to the king.';
    const pinB =
        'The white bishop on b5 pins the black knight on c6 to the king.';
    const open = 'The white rook on e1 stands on the open e-file.';

    test('a comment it wrote comes back checked, and the note stays a note',
        () {
      final comment = joinSentences(['my own note', pinA, open]);
      final split =
          splitCommentForChecklist(comment, const [pinA, pinB], const [open]);

      expect(split.tactical, {pinA});
      expect(split.positional, {open});
      expect(split.leftover, 'my own note.');
    });

    test('two findings of one kind are two lines, and both come back checked',
        () {
      // Under the old separator two pins were one clause, „Pin: a | b", which
      // the dialog split in two and could then never match again.
      final comment = joinSentences([pinA, pinB]);
      final split =
          splitCommentForChecklist(comment, const [pinA, pinB], const []);

      expect(split.tactical, {pinA, pinB});
      expect(split.leftover, '');
    });

    test('a comment in an older wording is kept whole as a note', () {
      const legacy = 'Pin: the black knight on e5 is pinned | Resolved — x';
      final split =
          splitCommentForChecklist(legacy, const [pinA, pinB], const [open]);

      expect(split.tactical, isEmpty);
      expect(split.positional, isEmpty);
      expect(split.leftover, legacy);
    });
  });
}
