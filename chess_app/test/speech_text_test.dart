import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/speech_text.dart';

void main() {
  group('reading a move out loud', () {
    test('a quiet move is the file by name and the rank as a number', () {
      // "de" and not "d": the voice says the letter's name, which is what a
      // player says. The rank is a word rather than a digit, because a digit
      // before a full stop is how Serbian writes an ordinal.
      expect(speakable('d4'), 'de četiri');
      expect(speakable('Kf2'), 'kralj ef dva');
      expect(speakable('Rd3'), 'top de tri');
    });

    test('a capture names the piece that takes', () {
      expect(speakable('Rxd3'), 'top uzima de tri');
    });

    test('a pawn capture names the pawn, which the notation does not', () {
      // `exd5` has no piece letter at all, and "e uzima de 5" sounds like a
      // name was swallowed.
      expect(speakable('exd5'), 'pešak sa e uzima de pet');
    });

    test('a disambiguated move says where the piece came from', () {
      // The one case where the square in front matters. Running the two
      // together - "skakač be de 7" - re-creates the ambiguity the notation
      // exists to remove.
      expect(speakable('Nbd7'), 'skakač sa be na de sedam');
      expect(speakable('R1e2'), 'top sa jedan na e dva');
    });

    test('check and mate are said, not spelled', () {
      expect(speakable('Qg3+'), 'dama ge tri, šah');
      expect(speakable('Qf1#'), 'dama ef jedan, mat');
    });

    test('promotion says what the pawn becomes', () {
      expect(speakable('e8=Q'), 'e osam postaje dama');
      expect(speakable('a1=N+'), 'a jedan postaje skakač, šah');
    });

    test('castling has its own words', () {
      expect(speakable('O-O'), 'mala rokada');
      expect(speakable('O-O-O'), 'velika rokada');
      expect(speakable('0-0-0'), 'velika rokada');
    });
  });

  group('moves inside a sentence', () {
    test('the prose is left alone and only the moves change', () {
      expect(
        speakable('Rd3 takođe ispušta dobitak. Probajte drugi potez.'),
        'top de tri takođe ispušta dobitak. Probajte drugi potez.',
      );
    });

    test('a Serbian word that looks like notation is not a move', () {
      // "Na" is a preposition, and a piece letter followed by a file is
      // exactly what the pattern is looking for. It is not a move because no
      // rank follows, and that is what saves it.
      expect(speakable('Na d4 stoji top.'), 'Na de četiri stoji top.');
    });

    test('several moves in one sentence all get read', () {
      expect(
        speakable('Držalo je: Qc8+, Qf3 i Qg3+.'),
        'Držalo je: dama ce osam, šah, dama ef tri i dama ge tri, šah.',
      );
    });

    test('a rating is a number, not a square', () {
      expect(speakable('Rejting 2400 je visok'), 'Rejting 2400 je visok');
    });
  });

  group('typography that a voice would otherwise announce', () {
    test('quotation marks go, because voices read them out', () {
      expect(speakable('Dugme „Pokaži" otvara prolaz.'),
          'Dugme Pokaži otvara prolaz.');
    });

    test('a dash between clauses becomes a comma, not silence', () {
      expect(
          speakable('Tačno — dobitak je zadržan'), 'Tačno, dobitak je zadržan');
    });

    test('an ellipsis becomes a pause', () {
      expect(speakable('Proveravam u tablicama…'), 'Proveravam u tablicama,');
    });

    test('the newlines a panel wraps at are one pause, not several', () {
      expect(speakable('Prvi red\n  drugi red'), 'Prvi red drugi red');
    });
  });

  group('the full stop that turns a number into an ordinal', () {
    test('a move at the end of a sentence is said as a number', () {
      // The report from the phone: `e6.` came out as "e šesti". The rank is a
      // word now, so there is no digit left for the stop to act on.
      expect(speakable('Odigrano je e6.'), 'Odigrano je e šest.');
      expect(speakable('Držalo je Kf2.'), 'Držalo je kralj ef dva.');
    });

    test('other numbers keep the number and lose the stop', () {
      // "Nađeno 3 od 12." would be read "dvanaesti" for the same reason.
      // Dropping the stop costs a pause at the end of a sentence, and the
      // number itself is worth hearing as a number.
      expect(speakable('Nađeno 3 od 12.'), 'Nađeno 3 od 12');
      expect(speakable('Rejting 2400.'), 'Rejting 2400');
    });

    test('a stop after a word is left alone', () {
      expect(speakable('Tačno. Probajte drugi potez.'),
          'Tačno. Probajte drugi potez.');
    });

    test('a move number is not an ordinal and is not touched', () {
      expect(speakable('1.e4'), '1.e četiri');
    });
  });

  test('nothing to say comes back empty, so the caller has one case', () {
    expect(speakable(null), '');
    expect(speakable('   '), '');
  });
}
