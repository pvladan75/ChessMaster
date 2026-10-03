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
    .replaceAll(RegExp(r'[.,?]'), '')
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
  static SpeechToken get findBestMove => _must('find_best_move');
  static SpeechToken get solved => _must('solved');
  static SpeechToken get solvedWithHelp => _must('solved_with_help');
  static SpeechToken get notSolved => _must('not_solved');
  static SpeechToken get oneAttempt => _must('one_attempt');
  // The endgame trainer and the blunder walk (phase 4b).
  static SpeechToken get keepTheWin => _must('keep_the_win');
  static SpeechToken get holdTheDraw => _must('hold_the_draw');
  static SpeechToken get correctWinKept => _must('correct_win_kept');
  static SpeechToken get correctDrawHeld => _must('correct_draw_held');
  static SpeechToken get onlyMove => _must('only_move');
  static SpeechToken get foundEveryMove => _must('found_every_move');
  static SpeechToken get otherMovesToFind => _must('other_moves_to_find');
  static SpeechToken get wrongDropsWin => _must('wrong_drops_win');
  static SpeechToken get wrongLosesDraw => _must('wrong_loses_draw');
  static SpeechToken get engineDropsWin => _must('engine_drops_win');
  static SpeechToken get engineLosesDraw => _must('engine_loses_draw');
  static SpeechToken get alreadyFound => _must('already_found');
  static SpeechToken get restored => _must('restored');
  static SpeechToken get solvedWinKept => _must('solved_win_kept');
  static SpeechToken get solvedDrawHeld => _must('solved_draw_held');
  static SpeechToken get onlyMoveKeepsWinIs => _must('only_move_keeps_win_is');
  static SpeechToken get onlyMoveHoldsDrawIs =>
      _must('only_move_holds_draw_is');
  static SpeechToken get theseMovesKeepWin => _must('these_moves_keep_win');
  static SpeechToken get theseMovesHoldDraw => _must('these_moves_hold_draw');
  static SpeechToken inTheGamePlayed(String side) =>
      _must('in_the_game_${side}_played');
  static SpeechToken get andDroppedTheWin => _must('and_dropped_the_win');
  static SpeechToken get andLostTheDraw => _must('and_lost_the_draw');
  static SpeechToken get playToEndWin => _must('play_to_end_win');
  static SpeechToken get playToEndDraw => _must('play_to_end_draw');
  static SpeechToken get punishBlunder => _must('punish_blunder');
  static SpeechToken get goodKeepGoing => _must('good_keep_going');
  static SpeechToken get movesLeftToHold => _must('moves_left_to_hold');
  static SpeechToken get losesDrawDrillStops => _must('loses_draw_drill_stops');
  static SpeechToken get letsWinGoLost => _must('lets_win_go_lost');
  static SpeechToken get letsWinGoDraw => _must('lets_win_go_draw');
  static SpeechToken get drawHeldCompleted => _must('draw_held_completed');
  static SpeechToken get checkmateCompleted => _must('checkmate_completed');
  static SpeechToken get drawNothingToHold => _must('draw_nothing_to_hold');
  static SpeechToken get tablebaseSilent => _must('tablebase_silent');
  static SpeechToken playedHere(String side) => _must('${side}_played');
  static SpeechToken get hereLetWinGo => _must('here_let_win_go');
  static SpeechToken get hereLostDraw => _must('here_lost_draw');
  static SpeechToken get playMoveHoldsWin => _must('play_move_holds_win');
  static SpeechToken get playMoveHoldsDraw => _must('play_move_holds_draw');
  static SpeechToken get goForward => _must('go_forward');
  static SpeechToken get correct => _must('correct');
  static SpeechToken get gameContinues => _must('game_continues');
  static SpeechToken get lastMistakeGameOver => _must('last_mistake_game_over');
  static SpeechToken get alsoLetsWinGo => _must('also_lets_win_go');
  static SpeechToken get doesNotHoldDraw => _must('does_not_hold_draw');
  static SpeechToken get watchRefutationOf => _must('watch_refutation_of');
  static SpeechToken get gameFinishedFound => _must('game_finished_found');
  static SpeechToken get ofToken => _must('of');
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

  /// „Now suppose Black plays" — the head of the sentence a puzzle says when
  /// it goes back to try the opponent's other defence.
  static SpeechToken nowSuppose(String side) =>
      _must('now_suppose_${side}_plays');

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

  /// 0–99 inside a sentence („Found 3 of 5"), cut from that position.
  static SpeechToken numberInside(int n) => _must('nmid_$n');

  // The repertoire, build and drill (phase 4c).
  static SpeechToken whatDoYouPlay(String side) => _must('what_play_$side');
  static SpeechToken get afterHead => _must('after_head');
  static SpeechToken get whichOpponentMoves => _must('which_opponent_moves');
  static SpeechToken get isInYourRepertoire => _must('is_in_your_repertoire');
  static SpeechToken get mostPlayedReplyIs => _must('most_played_reply_is');
  static SpeechToken get bookNoReply => _must('book_no_reply');
  static SpeechToken get answeredEveryPosition =>
      _must('answered_every_position');
  static SpeechToken get moveNotSaved => _must('move_not_saved');
  static SpeechToken get opponentMoveNotSaved =>
      _must('opponent_move_not_saved');
  static SpeechToken get opponentMoveNotRemoved =>
      _must('opponent_move_not_removed');
  static SpeechToken get engineNoResponse => _must('engine_no_response');
  static SpeechToken get progressNotRead => _must('progress_not_read');
  static SpeechToken get yourMoveIs => _must('your_move_is');
  static SpeechToken get playIt => _must('play_it');
  static SpeechToken get alsoYours => _must('also_yours');
  static SpeechToken get yourMainMoveIs => _must('your_main_move_is');
  static SpeechToken get incorrect => _must('incorrect');
  static SpeechToken get notCoveredPosition => _must('not_covered_position');
  static SpeechToken get notCoveredReply => _must('not_covered_reply');
  static SpeechToken get aheadOfSchedule => _must('ahead_of_schedule');
  static SpeechToken get returnsTomorrow => _must('returns_tomorrow');
  static SpeechToken get returnsMinutes => _must('returns_minutes');
  static SpeechToken get returnsWeek => _must('returns_week');
  static SpeechToken get returnsMonth => _must('returns_month');
  static SpeechToken get returnsIn => _must('returns_in');
  static SpeechToken get daysTail => _must('days_tail');
  static SpeechToken get weeksTail => _must('weeks_tail');
  static SpeechToken get monthsTail => _must('months_tail');
  static SpeechToken get nothingDue => _must('nothing_due');
  static SpeechToken get nothingToDrillYet => _must('nothing_to_drill_yet');
  static SpeechToken get nothingDueBranch => _must('nothing_due_branch');
  static SpeechToken get nothingToDrillBranch =>
      _must('nothing_to_drill_branch');
  static SpeechToken get nothingDueAfter => _must('nothing_due_after');
  static SpeechToken get nothingToDrillAfter => _must('nothing_to_drill_after');
  static SpeechToken get yetTail => _must('yet_tail');

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
    // The tactics trainer (phase 4a, 3.10.2026).
    phrase('find_best_move', 'Find the best move.');
    phrase('solved', 'Solved.');
    phrase('solved_with_help', 'Solved with help.');
    phrase('not_solved', 'Not solved.');
    phrase('one_attempt', 'Incorrect. The assignment allows one attempt.');
    // The endgame trainer and the blunder walk (phase 4b, 3.10.2026).
    phrase('keep_the_win', 'Keep the win.');
    phrase('hold_the_draw', 'Hold the draw.');
    phrase('correct_win_kept', 'Correct. The win is kept.');
    phrase('correct_draw_held', 'Correct. The draw is held.');
    phrase('only_move', 'That was the only move.');
    phrase('found_every_move', 'You found every move that holds.');
    phrase('wrong_drops_win', 'That move drops the win. Try another.');
    phrase('wrong_loses_draw', 'That move loses the draw. Try another.');
    phrase('engine_drops_win',
        'The engine judges that this move drops the win. Try another.');
    phrase('engine_loses_draw',
        'The engine judges that this move loses the draw. Try another.');
    phrase('already_found', 'You already found that move. Look for another.');
    phrase(
        'restored', 'Restored to the position before that move. Try another.');
    phrase('solved_win_kept', 'Solved. The win is kept.');
    phrase('solved_draw_held', 'Solved. The draw is held.');
    phrase('play_to_end_win', 'Play to the end. Keep the win.');
    phrase('play_to_end_draw', 'Play to the end. Hold the draw.');
    phrase('punish_blunder', 'Punish the blunder. Play the win to the end.');
    phrase('good_keep_going', 'Good. Keep going.');
    phrase('draw_held_completed', 'Draw held. Drill completed.');
    phrase('checkmate_completed', 'Checkmate. Drill completed.');
    phrase('draw_nothing_to_hold', 'Draw. Nothing left to hold.');
    phrase('tablebase_silent',
        'The tablebase is not answering. Try again in a moment.');
    phrase('play_move_holds_win', 'Play the move that holds the win.');
    phrase('play_move_holds_draw', 'Play the move that holds the draw.');
    phrase('go_forward', 'Go forward to the next mistake.');
    phrase('correct', 'Correct.');
    phrase('game_continues', 'The game continues as played.');
    phrase('last_mistake_game_over', 'That was the last mistake. Game over.');
    // The repertoire, build and drill (phase 4c, 3.10.2026).
    phrase('what_play_white', 'What do you play with White?');
    phrase('what_play_black', 'What do you play with Black?');
    phrase('book_no_reply',
        'The book has no reply here. Play the opponent move you want to prepare.');
    phrase('answered_every_position',
        'You have answered every position in this repertoire.');
    phrase('move_not_saved',
        'The move was not saved. The server did not respond.');
    phrase('opponent_move_not_saved',
        'The opponent move was not saved. The server did not respond.');
    phrase('opponent_move_not_removed',
        'The opponent move was not removed. The server did not respond.');
    phrase('engine_no_response', 'The engine did not respond in time.');
    phrase('progress_not_read',
        'Could not read your progress. Starting from the opening position.');
    phrase('play_it', 'Play it.');
    phrase('also_yours', 'Also yours.');
    phrase('incorrect', 'Incorrect.');
    phrase('not_covered_position',
        'You have not covered this position. Open build to decide what you play.');
    phrase('not_covered_reply', 'You have not covered this reply.');
    phrase(
        'ahead_of_schedule', 'Ahead of schedule. The rating is not recorded.');
    phrase('returns_tomorrow', 'Returns tomorrow.');
    phrase('returns_minutes', 'Returns in a few minutes.');
    phrase('returns_week', 'Returns in a week.');
    phrase('returns_month', 'Returns in a month.');
    phrase('nothing_due', 'Nothing due.');
    phrase('nothing_to_drill_yet', 'Nothing to drill yet.');
    phrase('nothing_due_branch', 'Nothing due in this branch.');
    phrase('nothing_to_drill_branch', 'Nothing to drill in this branch.');

    // The frame of a move sentence (D12).
    const frame = 'Black plays bishop e5.';
    cut('black_plays', 'Black plays', frame, 1, 2);
    cut('white_plays', 'White plays', 'White plays bishop e5.', 1, 2);
    cut('takes', 'takes', 'Black plays bishop takes e5.', 4, 4);
    cut('check', 'Check', 'Black plays bishop e5. Check.', 5, 5);
    cut('promotes_to', 'promotes to', 'Black plays pawn e8, promotes to queen.',
        5, 6);
    cut('mate_in', 'Mate in', 'Mate in 3.', 1, 2);
    // Fragments around a move or a number (phase 4b). A move after a head is
    // in the position the move clips were cut for; a tail follows a square.
    cut('in_the_game_white_played', 'In the game, White played',
        'In the game, White played bishop e5 and dropped the win.', 1, 5);
    cut('in_the_game_black_played', 'In the game, Black played',
        'In the game, Black played bishop e5 and dropped the win.', 1, 5);
    cut('and_dropped_the_win', 'and dropped the win',
        'In the game, White played bishop e5 and dropped the win.', 8, 11);
    cut('and_lost_the_draw', 'and lost the draw',
        'In the game, White played bishop e5 and lost the draw.', 8, 11);
    cut('other_moves_to_find', 'Other moves to find:',
        'Other moves to find: 3.', 1, 4);
    cut('only_move_keeps_win_is', 'The only move that keeps the win is',
        'The only move that keeps the win is bishop e5.', 1, 8);
    cut('only_move_holds_draw_is', 'The only move that holds the draw is',
        'The only move that holds the draw is bishop e5.', 1, 8);
    cut('these_moves_keep_win', 'These moves keep the win:',
        'These moves keep the win: bishop e5, rook a1.', 1, 5);
    cut('these_moves_hold_draw', 'These moves hold the draw:',
        'These moves hold the draw: bishop e5, rook a1.', 1, 5);
    cut('moves_left_to_hold', 'Moves left to hold:', 'Moves left to hold: 5.',
        1, 4);
    cut('loses_draw_drill_stops', 'loses the draw. The drill stops here.',
        'Bishop e5 loses the draw. The drill stops here.', 3, 9);
    cut('lets_win_go_lost', 'lets the win go. The position is now lost.',
        'Bishop e5 lets the win go. The position is now lost.', 3, 11);
    cut('lets_win_go_draw', 'lets the win go. The position is now a draw.',
        'Bishop e5 lets the win go. The position is now a draw.', 3, 12);
    cut('white_played', 'White played',
        'White played bishop e5 here and let the win go.', 1, 2);
    cut('black_played', 'Black played',
        'Black played bishop e5 here and let the win go.', 1, 2);
    cut('here_let_win_go', 'here and let the win go',
        'White played bishop e5 here and let the win go.', 5, 10);
    cut('here_lost_draw', 'here and lost the draw',
        'White played bishop e5 here and lost the draw.', 5, 9);
    cut('also_lets_win_go', 'also lets the win go. Try another move.',
        'Bishop e5 also lets the win go. Try another move.', 3, 10);
    cut('does_not_hold_draw', 'does not hold the draw. Try another move.',
        'Bishop e5 does not hold the draw. Try another move.', 3, 10);
    cut('watch_refutation_of', 'Watch the refutation of',
        'Watch the refutation of bishop e5.', 1, 4);
    cut('game_finished_found', 'Game finished. Found',
        'Game finished. Found 3 of 5.', 1, 3);
    cut('of', 'of', 'Game finished. Found 3 of 5.', 5, 5);
    // The repertoire (phase 4c): heads before a move, tails after one, and
    // the tails after a number inside „Returns in N days."
    cut('after_head', 'After',
        'After bishop e5, which opponent moves do you prepare?', 1, 1);
    cut('which_opponent_moves', 'which opponent moves do you prepare?',
        'After bishop e5, which opponent moves do you prepare?', 4, 9);
    cut(
        'is_in_your_repertoire',
        'is in your repertoire.',
        'Bishop e5 is in your repertoire. The most played reply is knight c6.',
        3,
        6);
    cut(
        'most_played_reply_is',
        'The most played reply is',
        'Bishop e5 is in your repertoire. The most played reply is knight c6.',
        7,
        11);
    cut('your_move_is', 'Your move is', 'Your move is bishop e5. Play it.', 1,
        3);
    cut('your_main_move_is', 'Your main move is',
        'Your main move is bishop e5.', 1, 4);
    // The SDK hears „3 days" as one word and splits „3 weeks" and „3 more
    // days" (measured 3.10.2026), so the head and the days are cut from those.
    cut('returns_in', 'Returns in', 'Returns in 3 weeks.', 1, 2);
    cut('days_tail', 'days.', 'Returns in 3 more days.', 5, 5);
    cut('weeks_tail', 'weeks.', 'Returns in 3 weeks.', 4, 4);
    cut('months_tail', 'months.', 'Returns in 3 months.', 4, 4);
    cut('nothing_due_after', 'Nothing due after',
        'Nothing due after bishop e5.', 1, 3);
    cut('nothing_to_drill_after', 'Nothing to drill after',
        'Nothing to drill after bishop e5 yet.', 1, 4);
    cut('yet_tail', 'yet.', 'Nothing to drill after bishop e5 yet.', 7, 7);
    // A number inside a sentence („Found 3 of 5") is cut from that position;
    // the plain numbers end a sentence („Mate in 3.").
    for (var n = 0; n <= 99; n++) {
      cut('nmid_$n', '$n', 'Found $n of 5.', 2, 2);
    }
    // The second defence of a puzzle: the board goes back and the voice says
    // what the opponent plays instead, before the move is drawn.
    cut('now_suppose_white_plays', 'Now suppose White plays',
        'Now suppose White plays bishop e5.', 1, 4);
    cut('now_suppose_black_plays', 'Now suppose Black plays',
        'Now suppose Black plays bishop e5.', 1, 4);

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
