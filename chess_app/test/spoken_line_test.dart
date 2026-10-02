/// The pure half of phase 2's gate — `docs/PLAN-GOVOR-IZ-KLIPOVA.md`: a
/// `SpokenLine` draws what it says, `MoveWords` is the one place a move
/// becomes words (D1, D11), and `ClipVoice.stitch` joins clips with 50 ms
/// before a square and nothing anywhere else (D6).
///
/// Written by the lead before the three files existed; the implementer
/// builds `lib/core/speech/spoken_line.dart`, `move_words.dart` and
/// `clip_voice.dart` to it. The screen half is `test/speech_pilot_test.dart`.
library;

import 'dart:typed_data';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/move_words.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/core/speech/wav_clip.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> ids(SpokenLine line) => line.tokens.map((t) => t.id).toList();

void main() {
  group('SpokenLine.text is the sentence the screen draws', () {
    test('cut tokens are joined with spaces and the line ends with a full stop',
        () {
      final line = SpokenLine([
        SpeechVocabulary.whitePlays,
        SpeechVocabulary.piece('rook'),
        SpeechVocabulary.square('a8'),
      ]);
      expect(line.text, 'White plays rook a8.');
    });

    test('a phrase carries its own punctuation and is not given a second one',
        () {
      expect(
        SpokenLine([SpeechVocabulary.checkmate, SpeechVocabulary.puzzleSolved])
            .text,
        'Checkmate. Puzzle solved.',
      );
      expect(
        SpokenLine([
          SpeechVocabulary.whiteToMove,
          SpeechVocabulary.mateIn,
          SpeechVocabulary.number(2),
        ]).text,
        'White to move. Mate in 2.',
      );
    });

    test('a cut token followed by a phrase closes its sentence first', () {
      final line = SpokenLine([
        SpeechVocabulary.blackPlays,
        SpeechVocabulary.piece('queen'),
        SpeechVocabulary.takes,
        SpeechVocabulary.square('f7', afterTakes: true),
        SpeechVocabulary.checkmate,
      ]);
      expect(line.text, 'Black plays queen takes f7. Checkmate.');
    });

    test('two lines with the same tokens are equal, so a dedupe can see them',
        () {
      final a = SpokenLine([SpeechVocabulary.correctKeepGoing]);
      final b = SpokenLine([SpeechVocabulary.correctKeepGoing]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(SpokenLine([SpeechVocabulary.puzzleSolved])));
    });
  });

  group('MoveWords says a move the way players say it (D1)', () {
    test('a plain move: side, piece, square', () {
      final line = MoveWords.line(
          const MoveFacts(side: 'black', piece: 'knight', to: 'd7'));
      expect(ids(line), ['black_plays', 'piece_knight', 'sq_d7']);
      expect(line.text, 'Black plays knight d7.');
    });

    test('a capture says takes, and the square is the one cut after takes', () {
      final line = MoveWords.line(const MoveFacts(
          side: 'white', piece: 'queen', to: 'f7', capture: true));
      expect(ids(line), ['white_plays', 'piece_queen', 'takes', 'sqx_f7']);
      expect(line.text, 'White plays queen takes f7.');
    });

    test('check and checkmate follow the move', () {
      expect(
        ids(MoveWords.line(const MoveFacts(
            side: 'white', piece: 'rook', to: 'a8', check: true))),
        ['white_plays', 'piece_rook', 'sq_a8', 'check'],
      );
      final mate = MoveWords.line(const MoveFacts(
          side: 'white', piece: 'queen', to: 'f7', capture: true, mate: true));
      expect(ids(mate).last, 'checkmate');
      expect(ids(mate), isNot(contains('check')));
      expect(mate.text, 'White plays queen takes f7. Checkmate.');
    });

    test('castling is its own sentence per side and wing', () {
      expect(
        ids(MoveWords.line(const MoveFacts(
            side: 'black', piece: 'king', to: 'g8', castles: 'kingside'))),
        ['black_castles_kingside'],
      );
      expect(
        ids(MoveWords.line(const MoveFacts(
            side: 'white',
            piece: 'king',
            to: 'c1',
            castles: 'queenside',
            check: true))),
        ['white_castles_queenside', 'check'],
      );
    });

    test('a promotion names the piece it becomes', () {
      final line = MoveWords.line(const MoveFacts(
          side: 'white', piece: 'pawn', to: 'e8', promotion: 'queen'));
      expect(ids(line),
          ['white_plays', 'piece_pawn', 'sq_e8', 'promotes_to', 'prom_queen']);
      expect(line.text, 'White plays pawn e8 promotes to queen.');
    });

    test(
        'an ambiguous move says the file letter between piece and square, '
        'and the rank only when the file does not settle it (D11)', () {
      expect(
        ids(MoveWords.line(const MoveFacts(
            side: 'white', piece: 'rook', to: 'a8', fromFile: 'a'))),
        ['white_plays', 'piece_rook', 'file_a', 'sq_a8'],
      );
      expect(
        ids(MoveWords.line(const MoveFacts(
            side: 'white', piece: 'rook', to: 'a8', fromRank: 1))),
        ['white_plays', 'piece_rook', 'rank_1', 'sq_a8'],
      );
      expect(
        MoveWords.line(const MoveFacts(
                side: 'black', piece: 'knight', to: 'd7', fromFile: 'b'))
            .text,
        'Black plays knight b d7.',
      );
    });

    test('a pawn says pawn, and a pawn capture names the file it came from',
        () {
      expect(
        MoveWords.line(const MoveFacts(
                side: 'white',
                piece: 'pawn',
                to: 'd5',
                capture: true,
                fromFile: 'e'))
            .text,
        'White plays pawn e takes d5.',
      );
    });

    test('the other defence is said as a supposition, then the move (D3)', () {
      final line = MoveWords.supposeLine(
          const MoveFacts(side: 'black', piece: 'pawn', to: 'd4'));
      expect(ids(line), ['now_suppose_black_plays', 'piece_pawn', 'sq_d4']);
      expect(line.text, 'Now suppose Black plays pawn d4.');
      expect(
        ids(MoveWords.supposeLine(const MoveFacts(
            side: 'white',
            piece: 'knight',
            to: 'e5',
            capture: true,
            check: true))),
        ['now_suppose_white_plays', 'piece_knight', 'takes', 'sqx_e5', 'check'],
      );
      // Castling carries the side in its own sentence, so it is said plainly.
      expect(
        ids(MoveWords.supposeLine(const MoveFacts(
            side: 'black', piece: 'king', to: 'g8', castles: 'kingside'))),
        ['black_castles_kingside'],
      );
    });

    test('every legal shape of move names only tokens with a clip', () {
      for (final side in ['white', 'black']) {
        for (final piece in kPieces) {
          for (final f in kFiles.split('')) {
            for (var r = 1; r <= 8; r++) {
              for (final capture in [false, true]) {
                final line = MoveWords.line(MoveFacts(
                    side: side,
                    piece: piece,
                    to: '$f$r',
                    capture: capture,
                    check: r.isEven,
                    fromFile: capture && piece == 'pawn' ? 'e' : null));
                for (final t in line.tokens) {
                  expect(SpeechVocabulary.byId(t.id), isNotNull,
                      reason: '${line.text} names ${t.id}');
                }
              }
            }
          }
        }
      }
      for (final p in kPromotionPieces) {
        final line = MoveWords.line(
            MoveFacts(side: 'black', piece: 'pawn', to: 'a1', promotion: p));
        expect(ids(line).last, 'prom_$p');
      }
    });
  });

  group('ClipVoice.stitch', () {
    WavClip clipOf(int ms) => WavClip(
          sampleRate: kSpeechSampleRate,
          channels: 1,
          bitsPerSample: 16,
          pcm: Uint8List((kSpeechSampleRate * ms ~/ 1000) * 2),
        );

    test('joins the clips with 50 ms before a square and nothing elsewhere',
        () {
      final line = SpokenLine([
        SpeechVocabulary.whitePlays,
        SpeechVocabulary.piece('rook'),
        SpeechVocabulary.square('a8'),
        SpeechVocabulary.check,
      ]);
      final lengths = {
        'white_plays': 500,
        'piece_rook': 300,
        'sq_a8': 400,
        'check': 350,
      };
      final wav = ClipVoice.stitch(line, (t) => clipOf(lengths[t.id]!));
      final out = WavClip.parse(wav)!;
      expect(out.sampleRate, kSpeechSampleRate);
      expect(out.channels, 1);
      // Frames, not milliseconds: 350 ms is 7717.5 frames and 50 ms is
      // 1102.5, and a sum of rounded parts is not the rounding of the sum.
      final expectedFrames = [500, 300, 400, 350]
              .map((ms) => kSpeechSampleRate * ms ~/ 1000)
              .reduce((a, b) => a + b) +
          kSpeechSampleRate * kPauseBeforeSquareMs ~/ 1000;
      expect(out.pcm.length, expectedFrames * 2);
      expect(wav.length, 44 + out.pcm.length);
    });

    test('a square after takes gets the same pause', () {
      final line = SpokenLine([
        SpeechVocabulary.takes,
        SpeechVocabulary.square('f7', afterTakes: true),
      ]);
      final out = WavClip.parse(ClipVoice.stitch(line, (_) => clipOf(100)))!;
      expect(
          out.pcm.length,
          (2 * (kSpeechSampleRate * 100 ~/ 1000) +
                  kSpeechSampleRate * kPauseBeforeSquareMs ~/ 1000) *
              2);
    });

    test('a clip in another format is refused, not resampled', () {
      final odd = WavClip(
          sampleRate: 24000,
          channels: 1,
          bitsPerSample: 16,
          pcm: Uint8List(480));
      final line =
          SpokenLine([SpeechVocabulary.whitePlays, SpeechVocabulary.takes]);
      expect(
        () =>
            ClipVoice.stitch(line, (t) => t.id == 'takes' ? odd : clipOf(100)),
        throwsA(isA<StateError>()),
      );
    });

    test('an empty line has nothing to stitch', () {
      expect(() => ClipVoice.stitch(SpokenLine(const []), (_) => clipOf(1)),
          throwsA(isA<StateError>()));
    });
  });
}
