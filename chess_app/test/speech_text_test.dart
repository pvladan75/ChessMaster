import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/speech_text.dart';

void main() {
  group('reading a move out loud', () {
    test('a quiet move is the file by name and the rank as a number', () {
      // The file is the bare letter and the rank is a word. The letter goes
      // through the voice's own names; the rank cannot be a digit, because a
      // digit before a full stop is how Serbian writes an ordinal.
      expect(speakable('d4'), 'd four');
      expect(speakable('Kf2'), 'king f two');
      expect(speakable('Rd3'), 'rook d three');
    });

    test('a capture names the piece that takes', () {
      expect(speakable('Rxd3'), 'rook takes d three');
    });

    test('a pawn capture names the pawn, which the notation does not', () {
      // `exd5` has no piece letter at all, and "e uzima de 5" sounds like a
      // name was swallowed.
      expect(speakable('exd5'), 'pawn from e takes d five');
    });

    test('a disambiguated move says where the piece came from', () {
      // The one case where the square in front matters. Running the two
      // together - "knight b d 7" - re-creates the ambiguity the notation
      // exists to remove.
      expect(speakable('Nbd7'), 'knight from b to d seven');
      expect(speakable('R1e2'), 'rook from one to e two');
    });

    test('check and mate are said, not spelled', () {
      expect(speakable('Qg3+'), 'queen g three, check');
      expect(speakable('Qf1#'), 'queen f one, mate');
    });

    test('promotion says what the pawn becomes', () {
      expect(speakable('e8=Q'), 'e eight promotes to queen');
      expect(speakable('a1=N+'), 'a one promotes to knight, check');
    });

    test('castling has its own words', () {
      expect(speakable('O-O'), 'castles kingside');
      expect(speakable('O-O-O'), 'castles queenside');
      expect(speakable('0-0-0'), 'castles queenside');
    });
  });

  group('moves inside a sentence', () {
    test('the prose is left alone and only the moves change', () {
      expect(
        speakable('Rd3 also throws the win away. Try another move.'),
        'rook d three also throws the win away. Try another move.',
      );
    });

    test('an ordinary word that looks like notation is not a move', () {
      // "Be" is a verb, and a piece letter followed by a file is exactly what
      // the pattern is looking for. It is not a move because no rank follows,
      // and that is what saves it.
      expect(speakable('Be a good sport.'), 'Be a good sport.');
      // The Serbian case this test was written for, kept because the file is
      // still fed pasted prose: "Na" is a preposition, not a knight move.
      expect(speakable('Na d4 stoji top.'), 'Na d four stoji top.');
    });

    test('several moves in one sentence all get read', () {
      expect(
        speakable('It held: Qc8+, Qf3 and Qg3+.'),
        'It held: queen c eight, check, queen f three and queen g three, check.',
      );
    });

    test('a rating is a number, not a square', () {
      expect(speakable('A rating of 2400 is high'), 'A rating of 2400 is high');
    });
  });

  group('typography that a voice would otherwise announce', () {
    test('quotation marks go, because voices read them out', () {
      expect(speakable('The „Show" button opens the way through.'),
          'The Show button opens the way through.');
    });

    test('a dash between clauses becomes a comma, not silence', () {
      expect(
          speakable('Correct — the win is held'), 'Correct, the win is held');
    });

    test('an ellipsis becomes a pause', () {
      expect(speakable('Checking the tablebases…'), 'Checking the tablebases,');
    });

    test('the newlines a panel wraps at are one pause, not several', () {
      expect(speakable('First line\n  second line'), 'First line second line');
    });
  });

  test('a file is a bare letter, because the voice knows their names', () {
    // Writing them out is what caused the trouble in the Serbian build: "ge"
    // went through an English letter table and the g-file came out as "dzh". A
    // one-letter token goes through the voice's own letter-name table instead,
    // which in English gives exactly what a player says.
    expect(speakable('b4'), 'b four');
    expect(speakable('g4'), 'g four');
    expect(speakable('Rg7'), 'rook g seven');
  });

  group('the full stop that turns a number into an ordinal', () {
    test('a move at the end of a sentence is said as a number', () {
      // The report from the phone: `e6.` came out as "e sixth". The rank is a
      // word now, so there is no digit left for the stop to act on.
      expect(speakable('It played e6.'), 'It played e six.');
      expect(speakable('It held with Kf2.'), 'It held with king f two.');
    });

    test('a sentence that ends on a number loses the stop', () {
      // "Found 3 of 12." would be read "twelfth". At the end of the text the
      // stop costs a pause and nothing else.
      expect(speakable('Found 3 of 12.'), 'Found 3 of 12');
      expect(speakable('A rating of 2400.'), 'A rating of 2400');
    });

    test('a real ordinal keeps its stop', () {
      // The other direction, and the one that was broken in the Serbian build:
      // here the stop is not punctuation, it is part of the number. English
      // trips this far less often, but "See 3. diagram" still has to survive,
      // and the rule is the same one either way.
      expect(
          speakable('See 3. diagram on page 40.'), 'See 3. diagram on page 40');
      // The Serbian ordinal the rule was written for, kept as the case that
      // proves the lower-case branch still exists.
      expect(speakable('Greska je napravljena u 8. potezu.'),
          'Greska je napravljena u 8. potezu.');
    });

    test('a stop before a new sentence still goes', () {
      expect(
          speakable('Found 3 of 12. Moving on.'), 'Found 3 of 12 Moving on.');
    });

    test('a stop after a word is left alone', () {
      expect(speakable('Correct. Try another move.'),
          'Correct. Try another move.');
    });

    test('a move number is not an ordinal and is not touched', () {
      expect(speakable('1.e4'), '1.e four');
    });
  });

  test('nothing to say comes back empty, so the caller has one case', () {
    expect(speakable(null), '');
    expect(speakable('   '), '');
  });
}
