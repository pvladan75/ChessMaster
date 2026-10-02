/// The one vocabulary the app's voice is made of — `docs/PLAN-GOVOR-IZ-KLIPOVA.md`.
///
/// Every sentence the app speaks from clips is a list of these tokens. Each
/// token has the `text` the screen draws for it and the recipe its clip was
/// rendered by: a **phrase** is a whole sentence, rendered as one and trimmed
/// to the speech floor; a **cut** token is a word, or two, cut out of a
/// *carrier* sentence of the same shape — a square from „Black plays bishop
/// d7.", a piece from „Black plays knight e5." — at the word times Azure's SDK
/// reports (D12). Phase 0's finding, paid for on the owner's ear: a word
/// rendered alone is an utterance of its own and falls like the end of a
/// sentence, and no pause between such words fixes that.
///
/// This file is the home (D7). `tool/speech_manifest.dart` writes
/// `assets/speech/manifest.json` from it, `tools/speech_clips/render.js`
/// renders the clips from that manifest, and `test/speech_clips_test.dart`
/// holds the manifest, the lock the renderer leaves behind and every clip to
/// what is written here — so a text edited here without a regeneration and a
/// re-render is a red test, not a clip that says the old word.
library;

import 'dart:collection';
import 'dart:convert';

/// The one voice (D2), chosen by the owner by ear on 2.10.2026.
const String kSpeechVoice = 'en-US-AndrewNeural';

/// The format every clip is in — the server's own, so `wav.js` and the app
/// read the same bytes. 22050 Hz, 16-bit, mono.
const int kSpeechSampleRate = 22050;
const int kSpeechBitsPerSample = 16;
const int kSpeechChannels = 1;

/// Silence before a square, and nowhere else (D6): 50 ms.
const int kPauseBeforeSquareMs = 50;

enum SpeechTokenKind { phrase, cut }

class SpeechToken {
  const SpeechToken._({
    required this.id,
    required this.kind,
    required this.text,
    required this.carrier,
    this.wordFrom,
    this.wordTo,
  });

  /// A sentence of its own, rendered whole.
  const SpeechToken.phrase(String id, String text)
      : this._(id: id, kind: SpeechTokenKind.phrase, text: text, carrier: text);

  /// Words [wordFrom]..[wordTo] (1-based, inclusive, punctuation not counted)
  /// of [carrier], cut out at the midpoints between neighbouring words.
  const SpeechToken.cut(
    String id,
    String text, {
    required String carrier,
    required int wordFrom,
    required int wordTo,
  }) : this._(
          id: id,
          kind: SpeechTokenKind.cut,
          text: text,
          carrier: carrier,
          wordFrom: wordFrom,
          wordTo: wordTo,
        );

  /// The clip's file name without `.wav`, and the manifest's key.
  final String id;
  final SpeechTokenKind kind;

  /// What the screen draws for this token.
  final String text;

  /// What Azure is told, whole. For a phrase it is [text].
  final String carrier;
  final int? wordFrom;
  final int? wordTo;

  /// Whether this token is a square — the one place a pause goes before (D6).
  bool get isSquare => id.startsWith('sq_') || id.startsWith('sqx_');

  /// The number of words in [carrier], punctuation not counted, which the
  /// renderer holds the SDK's report to before it trusts a cut.
  int get carrierWordCount => wordCountOf(carrier);

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'carrier': carrier,
        if (wordFrom != null) 'wordFrom': wordFrom,
        if (wordTo != null) 'wordTo': wordTo,
      };
}

/// Words of a carrier the way the renderer counts them: split on spaces,
/// punctuation stripped, so „e5. Check." is two words.
int wordCountOf(String carrier) => carrier
    .replaceAll(RegExp(r'[.,]'), '')
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .length;

const List<String> kPieces = [
  'king',
  'queen',
  'rook',
  'bishop',
  'knight',
  'pawn'
];
const List<String> kPromotionPieces = ['queen', 'rook', 'bishop', 'knight'];
const String kFiles = 'abcdefgh';

/// The tokens, by id, in a fixed order — the manifest's order.
class SpeechVocabulary {
  SpeechVocabulary._();

  static final UnmodifiableListView<SpeechToken> tokens =
      UnmodifiableListView(_build());

  static final Map<String, SpeechToken> _byId = {
    for (final t in tokens) t.id: t,
  };

  /// The token with [id], or null. Callers that build lines use the typed
  /// helpers below and never spell an id by hand.
  static SpeechToken? byId(String id) => _byId[id];

  static SpeechToken _must(String id) {
    final t = _byId[id];
    if (t == null) throw StateError('no speech token "$id"');
    return t;
  }

  // Phrases — each a sentence of its own.
  static SpeechToken get whiteToMove => _must('white_to_move');
  static SpeechToken get blackToMove => _must('black_to_move');
  static SpeechToken get findWinningPath => _must('find_winning_path');
  static SpeechToken get correctKeepGoing => _must('correct_keep_going');
  static SpeechToken get incorrectTryAnother => _must('incorrect_try_another');
  static SpeechToken get checkmate => _must('checkmate');
  static SpeechToken get puzzleSolved => _must('puzzle_solved');
  static SpeechToken get stockfishWinsTryAgain =>
      _must('stockfish_wins_try_again');
  static SpeechToken get whiteCastlesKingside =>
      _must('white_castles_kingside');
  static SpeechToken get whiteCastlesQueenside =>
      _must('white_castles_queenside');
  static SpeechToken get blackCastlesKingside =>
      _must('black_castles_kingside');
  static SpeechToken get blackCastlesQueenside =>
      _must('black_castles_queenside');

  /// „Draw by stalemate. Try again." and the other endings the drill names.
  static SpeechToken drawTryAgain(String endingId) => _must('draw_$endingId');

  // Cut from the frame sentences.
  static SpeechToken get whitePlays => _must('white_plays');
  static SpeechToken get blackPlays => _must('black_plays');
  static SpeechToken get takes => _must('takes');
  static SpeechToken get check => _must('check');
  static SpeechToken get promotesTo => _must('promotes_to');
  static SpeechToken get mateIn => _must('mate_in');

  static SpeechToken piece(String piece) => _must('piece_$piece');
  static SpeechToken promotionPiece(String piece) => _must('prom_$piece');

  /// A square after a piece or a letter („rook a8"), or, [afterTakes], after
  /// „takes" („rook takes a8") — spoken differently, so two clips (D12).
  static SpeechToken square(String square, {bool afterTakes = false}) =>
      _must('${afterTakes ? 'sqx' : 'sq'}_$square');

  /// The file letter said between the piece and the square when two pieces
  /// of a kind can reach it (D11): „rook a a8".
  static SpeechToken fileLetter(String file) => _must('file_$file');

  /// The rank, said only where the file does not settle it: „rook 1 a8".
  static SpeechToken rank(int rank) => _must('rank_$rank');

  /// 0–99, as a whole number („twenty-one" is one clip), cut from „Mate in N."
  static SpeechToken number(int n) => _must('n_$n');

  static List<SpeechToken> _build() {
    final list = <SpeechToken>[];
    void phrase(String id, String text) =>
        list.add(SpeechToken.phrase(id, text));
    void cut(String id, String text, String carrier, int from, int to) =>
        list.add(SpeechToken.cut(id, text,
            carrier: carrier, wordFrom: from, wordTo: to));

    phrase('white_to_move', 'White to move.');
    phrase('black_to_move', 'Black to move.');
    phrase('find_winning_path', 'Find the winning path.');
    phrase('correct_keep_going', 'Correct. Keep going.');
    phrase('incorrect_try_another', 'Incorrect. Try another move.');
    phrase('checkmate', 'Checkmate.');
    phrase('puzzle_solved', 'Puzzle solved.');
    phrase('stockfish_wins_try_again', 'Stockfish wins. Try again.');
    phrase('white_castles_kingside', 'White castles kingside.');
    phrase('white_castles_queenside', 'White castles queenside.');
    phrase('black_castles_kingside', 'Black castles kingside.');
    phrase('black_castles_queenside', 'Black castles queenside.');
    // The endings `endingLabel` names for a drawn drill, in its words.
    phrase('draw_stalemate', 'Draw by stalemate. Try again.');
    phrase('draw_insufficientMaterial',
        'Draw: not enough material to mate. Try again.');
    phrase('draw_threefoldRepetition',
        'Draw: the same position three times. Try again.');
    phrase('draw_fiftyMoves',
        'Draw: fifty moves without a capture or a pawn move. Try again.');
    phrase('draw_moveLimit', 'Draw: the move limit was reached. Try again.');

    // The frame of a move sentence (D12).
    const frame = 'Black plays bishop e5.';
    cut('black_plays', 'Black plays', frame, 1, 2);
    cut('white_plays', 'White plays', 'White plays bishop e5.', 1, 2);
    cut('takes', 'takes', 'Black plays bishop takes e5.', 4, 4);
    cut('check', 'Check', 'Black plays bishop e5. Check.', 5, 5);
    cut('promotes_to', 'promotes to', 'Black plays pawn e8, promotes to queen.',
        5, 6);
    cut('mate_in', 'Mate in', 'Mate in 3.', 1, 2);

    for (final p in kPieces) {
      cut('piece_$p', p, 'Black plays $p e5.', 3, 3);
    }
    for (final p in kPromotionPieces) {
      cut('prom_$p', p, 'Black plays pawn e8, promotes to $p.', 7, 7);
    }
    for (final f in kFiles.split('')) {
      for (var r = 1; r <= 8; r++) {
        cut('sq_$f$r', '$f$r', 'Black plays bishop $f$r.', 4, 4);
        cut('sqx_$f$r', '$f$r', 'Black plays bishop takes $f$r.', 5, 5);
      }
    }
    for (final f in kFiles.split('')) {
      cut('file_$f', f, 'White plays rook $f a8.', 4, 4);
    }
    for (var r = 1; r <= 8; r++) {
      cut('rank_$r', '$r', 'White plays rook $r a8.', 4, 4);
    }
    for (var n = 0; n <= 99; n++) {
      cut('n_$n', '$n', 'Mate in $n.', 3, 3);
    }
    return list;
  }

  /// `assets/speech/manifest.json`, byte for byte — what the tool writes and
  /// what the gate expects to find on disk.
  static String manifestText() =>
      '${const JsonEncoder.withIndent('  ').convert(manifest())}\n';

  /// The manifest the renderer reads, in a stable shape and order.
  static Map<String, Object?> manifest() => {
        'voice': kSpeechVoice,
        'format': {
          'sampleRate': kSpeechSampleRate,
          'bitsPerSample': kSpeechBitsPerSample,
          'channels': kSpeechChannels,
        },
        'tokens': [for (final t in tokens) t.toJson()],
      };
}
